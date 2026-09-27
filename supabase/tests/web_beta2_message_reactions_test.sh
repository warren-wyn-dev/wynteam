#!/usr/bin/env bash
# Web Beta2 WYN-159: message reactions and "delete for me" are
# participant-only, developer-gated while in Beta2, and private where needed.
# Disposable PostgreSQL only. CI runs every maintained supabase/tests/*.sh file.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="wynos_msg_reactions_$$"
WORK="$(mktemp -d)"
cleanup() { dropdb --if-exists "$DB" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
for executable in psql createdb dropdb; do command -v "$executable" >/dev/null; done

cat >"$WORK/stub.sql" <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
create table auth.users (id uuid primary key default gen_random_uuid());
create or replace function auth.uid() returns uuid
language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
do $$ begin
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
end $$;
grant usage on schema public, auth to anon, authenticated, service_role;
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade);
create table public.conversations (id uuid primary key default gen_random_uuid(), user_a_id uuid references public.profiles(id), user_b_id uuid references public.profiles(id));
create table public.messages (id uuid primary key default gen_random_uuid(), conversation_id uuid references public.conversations(id) on delete cascade, sender_id uuid references public.profiles(id), text text, deleted_at timestamptz);
create table public.developer_accounts (user_id uuid primary key);
create or replace function public.is_developer_account() returns boolean language sql security definer set search_path = public stable
as $$ select exists(select 1 from public.developer_accounts where user_id = auth.uid()) $$;
grant execute on function public.is_developer_account() to authenticated;
-- alice (developer) and bob chat; carol is outside the conversation.
insert into auth.users(id) values ('98000000-0000-0000-0000-00000000000a'),('98000000-0000-0000-0000-00000000000b'),('98000000-0000-0000-0000-00000000000c'),('98000000-0000-0000-0000-00000000000d');
insert into public.profiles(id) select id from auth.users;
grant select on public.messages, public.conversations to authenticated;
insert into public.developer_accounts values ('98000000-0000-0000-0000-00000000000a'),('98000000-0000-0000-0000-00000000000c');
insert into public.conversations(id,user_a_id,user_b_id) values ('98100000-0000-0000-0000-000000000001','98000000-0000-0000-0000-00000000000a','98000000-0000-0000-0000-00000000000b');
insert into public.messages(id,conversation_id,sender_id,text) values
 ('98200000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','98000000-0000-0000-0000-00000000000b','hi'),
 ('98200000-0000-0000-0000-000000000002','98100000-0000-0000-0000-000000000001','98000000-0000-0000-0000-00000000000a','hello');
insert into public.messages(id,conversation_id,sender_id,text,deleted_at) values
 ('98200000-0000-0000-0000-000000000003','98100000-0000-0000-0000-000000000001','98000000-0000-0000-0000-00000000000b',null,now());
SQL

cat >"$WORK/assert.sql" <<'SQL'
\set ON_ERROR_STOP on
-- Alice (participant, developer) reacts, changes and removes her reaction.
set request.jwt.claim.sub='98000000-0000-0000-0000-00000000000a';
set role authenticated;
select public.set_message_reaction('98200000-0000-0000-0000-000000000001','❤️');
select public.set_message_reaction('98200000-0000-0000-0000-000000000001','😂');
do $$ begin
  if (select string_agg(emoji, ',') from public.message_reactions) <> '😂' then raise exception 'Reaction was not replaced'; end if;
  begin
    perform public.set_message_reaction('98200000-0000-0000-0000-000000000001','🍕');
    raise exception 'Unknown emoji accepted';
  exception when check_violation then null;
  end;
  begin
    perform public.set_message_reaction('98200000-0000-0000-0000-000000000003','👍');
    raise exception 'Reacting to a deleted message was allowed';
  exception when raise_exception then
    if sqlerrm like 'Unknown emoji%' or sqlerrm like 'Reacting%' then raise; end if;
  end;
  begin
    insert into public.message_reactions(message_id,user_id,emoji) values ('98200000-0000-0000-0000-000000000002','98000000-0000-0000-0000-00000000000a','👍');
    raise exception 'Direct insert bypassed the RPC';
  exception when insufficient_privilege then null;
  end;
end $$;
select public.hide_message_for_me('98200000-0000-0000-0000-000000000001');
reset role;

-- Bob (participant, not a developer yet) sees Alice's reaction but not her hide, and cannot write while gated.
set request.jwt.claim.sub='98000000-0000-0000-0000-00000000000b';
set role authenticated;
do $$ begin
  if (select count(*) from public.message_reactions) <> 1 then raise exception 'Participant cannot read reactions'; end if;
  if (select count(*) from public.message_hides) <> 0 then raise exception 'Another participant can see a delete-for-me'; end if;
  begin
    perform public.set_message_reaction('98200000-0000-0000-0000-000000000002','👍');
    raise exception 'Beta2 gate did not block a non-developer';
  exception when raise_exception then
    if sqlerrm not like '%not available yet%' then raise; end if;
  end;
end $$;
reset role;

-- Carol (developer, outside the conversation) can neither read nor write.
set request.jwt.claim.sub='98000000-0000-0000-0000-00000000000c';
set role authenticated;
do $$ begin
  if (select count(*) from public.message_reactions) <> 0 then raise exception 'Outsider can read reactions'; end if;
  begin
    perform public.set_message_reaction('98200000-0000-0000-0000-000000000001','👍');
    raise exception 'Outsider reacted';
  exception when raise_exception then
    if sqlerrm not like 'Message not found%' then raise; end if;
  end;
  begin
    perform public.hide_message_for_me('98200000-0000-0000-0000-000000000001');
    raise exception 'Outsider hid a message';
  exception when raise_exception then
    if sqlerrm not like 'Message not found%' then raise; end if;
  end;
end $$;
reset role;

-- Alice sees her own hide; removing her reaction works; anon sees nothing.
set request.jwt.claim.sub='98000000-0000-0000-0000-00000000000a';
set role authenticated;
select public.set_message_reaction('98200000-0000-0000-0000-000000000001', null);
do $$ begin
  if (select count(*) from public.message_hides) <> 1 then raise exception 'Owner cannot read their hide'; end if;
  if (select count(*) from public.message_reactions) <> 0 then raise exception 'Reaction was not removed'; end if;
end $$;
reset role;
set role anon;
do $$ begin
  begin
    perform 1 from public.message_reactions;
    raise exception 'anon can read reactions';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- Deleting the message removes its reactions and hides.
delete from public.messages where id='98200000-0000-0000-0000-000000000001';
do $$ begin
  if exists(select 1 from public.message_hides) then raise exception 'Hide outlived the message'; end if;
end $$;
SQL

createdb "$DB"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$WORK/stub.sql" >/dev/null
# Apply twice to prove the migration is idempotent.
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/migrations_web_beta2_message_reactions.sql" >/dev/null
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/migrations_web_beta2_message_reactions.sql" >/dev/null
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$WORK/assert.sql" >/dev/null
echo "web_beta2_message_reactions_test: PASS"
