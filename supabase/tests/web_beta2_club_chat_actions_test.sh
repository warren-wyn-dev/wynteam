#!/usr/bin/env bash
# WYN-135: disposable PostgreSQL only. Never touch the production database.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB="wynos_club_chat_actions_$$"
WORK="$(mktemp -d)"
cleanup() { dropdb --if-exists "$DB" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
for cmd in psql createdb dropdb; do command -v "$cmd" >/dev/null; done

cat > "$WORK/stub.sql" <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
create schema if not exists internal;
do $$ begin
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
end $$;
grant usage on schema public, auth to authenticated, anon;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable
  as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create table public.profiles (id uuid primary key references auth.users(id));
create table public.clubs (id uuid primary key);
create table public.club_members (
  club_id uuid references public.clubs(id), user_id uuid references public.profiles(id),
  role text not null, status text not null, primary key(club_id, user_id)
);
create table public.developer_accounts (user_id uuid primary key references public.profiles(id));
create table public.club_channels (id uuid primary key, club_id uuid not null references public.clubs(id));
create table public.club_channel_messages (
  id uuid primary key, channel_id uuid not null references public.club_channels(id),
  author_id uuid not null references public.profiles(id),
  content text, image_url text, created_at timestamptz not null default now(),
  constraint has_content check (content is not null or image_url is not null)
);
create function public.club_role(p_club uuid, p_user uuid) returns text
  language sql stable security definer set search_path=public as
  $$ select role from public.club_members where club_id=p_club and user_id=p_user and status='approved' $$;
create function public.is_developer_account() returns boolean
  language sql stable security definer set search_path=public as
  $$ select exists(select 1 from public.developer_accounts where user_id=auth.uid()) $$;
create function internal.is_posting_blocked(p_user uuid) returns boolean
  language sql stable security definer set search_path=public as $$ select false $$;
alter table public.club_channel_messages enable row level security;
create policy "members read messages" on public.club_channel_messages
  for select to authenticated using (
    exists(select 1 from public.club_channels c where c.id=channel_id
      and public.club_role(c.club_id, auth.uid()) is not null)
  );
grant select, insert, update, delete on public.club_channel_messages to authenticated;
insert into auth.users(id) select ('aaaaaaaa-0000-0000-0000-00000000000'||n)::uuid
  from unnest(array['1','2','3','4','5']) n;
insert into public.profiles(id) select id from auth.users;
insert into public.clubs(id) values
  ('bbbbbbbb-0000-0000-0000-000000000001'),
  ('bbbbbbbb-0000-0000-0000-000000000002');
insert into public.club_members values
  ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','owner','approved'),
  ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000002','moderator','approved'),
  ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000003','member','approved'),
  ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000004','member','approved');
insert into public.developer_accounts(user_id) values
  ('aaaaaaaa-0000-0000-0000-000000000001'),
  ('aaaaaaaa-0000-0000-0000-000000000002'),
  ('aaaaaaaa-0000-0000-0000-000000000003'),
  ('aaaaaaaa-0000-0000-0000-000000000005');
insert into public.club_channels values
  ('cccccccc-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001'),
  ('cccccccc-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000001'),
  ('cccccccc-0000-0000-0000-000000000003','bbbbbbbb-0000-0000-0000-000000000002');
insert into public.club_channel_messages(id,channel_id,author_id,content,image_url) values
  ('dddddddd-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000003','phoenix alpha',null),
  ('dddddddd-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000003','phoenix beta',null),
  ('dddddddd-0000-0000-0000-000000000003','cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000002','meeting gamma',null),
  ('dddddddd-0000-0000-0000-000000000004','cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','meeting delta',null),
  ('dddddddd-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','phoenix other channel',null),
  ('dddddddd-0000-0000-0000-000000000006','cccccccc-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000005','phoenix private',null),
  ('dddddddd-0000-0000-0000-000000000007','cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000003',null,'avatar.png');
SQL

cat > "$WORK/assert.sql" <<'SQL'
\set ON_ERROR_STOP on
set request.jwt.claim.sub='aaaaaaaa-0000-0000-0000-000000000003';
set role authenticated;
select public.edit_club_channel_message('dddddddd-0000-0000-0000-000000000001', '  phoenix UPDATED  ');
do $$ begin
  if (select content from public.club_channel_messages where id='dddddddd-0000-0000-0000-000000000001') <> 'phoenix UPDATED'
    or (select edited_at from public.club_channel_messages where id='dddddddd-0000-0000-0000-000000000001') is null
  then raise exception 'Edit not saved with permanent label'; end if;
  begin
    perform public.edit_club_channel_message('dddddddd-0000-0000-0000-000000000003', 'intruder');
    raise exception 'Member edited another author';
  exception when raise_exception then
    if sqlerrm not like 'Message not found%' then raise; end if;
  end;
  begin
    perform public.edit_club_channel_message('dddddddd-0000-0000-0000-000000000007', 'added text');
    raise exception 'Image-only message was editable';
  exception when raise_exception then
    if sqlerrm not like 'Message not found%' then raise; end if;
  end;
  begin
    perform public.edit_club_channel_message('dddddddd-0000-0000-0000-000000000002', '  ');
    raise exception 'Blank edit was accepted';
  exception when raise_exception then
    if sqlerrm not like 'Message must be%' then raise; end if;
  end;
  begin
    perform public.set_club_channel_message_pin('dddddddd-0000-0000-0000-000000000001', true);
    raise exception 'Member pinned a message';
  exception when raise_exception then
    if sqlerrm not like 'Only Club staff%' then raise; end if;
  end;
  if (select count(*) from public.search_club_channel_messages(
      'cccccccc-0000-0000-0000-000000000001','phoenix',100)) <> 2
  then raise exception 'Channel search returned wrong rows'; end if;
  if (select count(*) from public.search_club_channel_messages(
      'cccccccc-0000-0000-0000-000000000001','  ')) <> 0
  then raise exception 'Empty search returned data'; end if;
  begin
    perform public.search_club_channel_messages('cccccccc-0000-0000-0000-000000000003','phoenix');
    raise exception 'Cross-club search allowed';
  exception when raise_exception then
    if sqlerrm not like 'Not an approved member%' then raise; end if;
  end;
end $$;
reset role;
set request.jwt.claim.sub='aaaaaaaa-0000-0000-0000-000000000002';
set role authenticated;
select public.set_club_channel_message_pin('dddddddd-0000-0000-0000-000000000001', true);
select public.set_club_channel_message_pin('dddddddd-0000-0000-0000-000000000002', true);
select public.set_club_channel_message_pin('dddddddd-0000-0000-0000-000000000003', true);
do $$ begin
  if (select count(*) from public.club_channel_messages where pinned_at is not null) <> 3
  then raise exception 'Three pins were not saved'; end if;
  begin
    perform public.set_club_channel_message_pin('dddddddd-0000-0000-0000-000000000004', true);
    raise exception 'Pin cap bypassed';
  exception when raise_exception then
    if sqlerrm not like 'Pin limit reached%' then raise; end if;
  end;
end $$;
select public.set_club_channel_message_pin('dddddddd-0000-0000-0000-000000000002', false);
select public.set_club_channel_message_pin('dddddddd-0000-0000-0000-000000000004', true);
do $$ begin
  if (select count(*) from public.club_channel_messages
    where channel_id='cccccccc-0000-0000-0000-000000000001' and pinned_at is not null) <> 3
  then raise exception 'Unpin did not free slot'; end if;
end $$;
reset role;
set request.jwt.claim.sub='aaaaaaaa-0000-0000-0000-000000000001';
set role authenticated;
select public.set_club_channel_message_pin('dddddddd-0000-0000-0000-000000000005', true);
do $$ begin
  if (select count(*) from public.club_channel_messages
    where channel_id='cccccccc-0000-0000-0000-000000000002' and pinned_at is not null) <> 1
  then raise exception 'Channel pin leaked'; end if;
end $$;
reset role;
set request.jwt.claim.sub='aaaaaaaa-0000-0000-0000-000000000004';
set role authenticated;
do $$ begin
  begin
    perform public.search_club_channel_messages('cccccccc-0000-0000-0000-000000000001','phoenix');
    raise exception 'Beta1 member used Beta2 search';
  exception when raise_exception then
    if sqlerrm not like 'Club chat actions are not available%' then raise; end if;
  end;
  begin
    perform public.set_club_channel_message_pin('dddddddd-0000-0000-0000-000000000001', true);
    raise exception 'Beta1 member used Beta2 pin';
  exception when raise_exception then
    if sqlerrm not like 'Club chat actions are not available%' then raise; end if;
  end;
end $$;
reset role;
set request.jwt.claim.sub='aaaaaaaa-0000-0000-0000-000000000005';
set role authenticated;
do $$ begin
  begin
    perform public.search_club_channel_messages('cccccccc-0000-0000-0000-000000000001','phoenix');
    raise exception 'Outsider searched private channel';
  exception when raise_exception then
    if sqlerrm not like 'Not an approved member%' then raise; end if;
  end;
  begin
    perform public.set_club_channel_message_pin('dddddddd-0000-0000-0000-000000000001', true);
    raise exception 'Outsider pinned';
  exception when raise_exception then
    if sqlerrm not like 'Only Club staff%' then raise; end if;
  end;
end $$;
reset role;
do $$ begin
  if not exists(select 1 from pg_indexes where schemaname='public'
    and indexname='club_channel_messages_fts_idx' and lower(indexdef) like '%using gin%')
  then raise exception 'Missing GIN full-text index'; end if;
  if has_function_privilege('anon', 'public.search_club_channel_messages(uuid,text,integer)', 'EXECUTE')
  then raise exception 'Anon search is executable'; end if;
end $$;
SQL

createdb "$DB"
psql "$DB" -v ON_ERROR_STOP=1 -f "$WORK/stub.sql" >/dev/null
psql "$DB" -v ON_ERROR_STOP=1 -f "$ROOT/supabase/migrations_web_beta2_club_chat_actions.sql" >/dev/null
psql "$DB" -v ON_ERROR_STOP=1 -f "$ROOT/supabase/migrations_web_beta2_club_chat_actions.sql" >/dev/null
psql "$DB" -v ON_ERROR_STOP=1 -f "$WORK/assert.sql" >/dev/null
printf '%s\n' "WYN-135 Club chat SQL security, membership, FTS and pin tests PASS"
