#!/usr/bin/env bash
# Web Beta2 WYN-137: Club announcements are staff-only to write, member-only
# to read, developer-gated while in Beta2, and notify developer members only.
# Disposable PostgreSQL only. CI runs every maintained supabase/tests/*.sh file.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="wynos_club_announcements_$$"
WORK="$(mktemp -d)"
cleanup() { dropdb --if-exists "$DB" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
for executable in psql createdb dropdb; do command -v "$executable" >/dev/null; done

cat >"$WORK/stub.sql" <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
create schema if not exists internal;
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
create table public.clubs (id uuid primary key default gen_random_uuid());
create table public.club_members (club_id uuid references public.clubs(id) on delete cascade, user_id uuid references public.profiles(id), role text, status text, primary key (club_id, user_id));
create table public.club_notification_mutes (club_id uuid, user_id uuid, primary key (club_id, user_id));
create table public.developer_accounts (user_id uuid primary key);
create table public.notification_off (user_id uuid primary key);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id),
  actor_id uuid references public.profiles(id),
  type text not null,
  club_id uuid references public.clubs(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint notifications_type_check check (type in ('follow', 'club_post_new', 'club_post_pinned', 'production_only_type'))
);
create or replace function public.club_role(p_club_id uuid, p_user_id uuid) returns text
language sql stable security definer set search_path = public
as $$ select role from public.club_members where club_id = p_club_id and user_id = p_user_id and status = 'approved' $$;
create or replace function public.is_developer_account() returns boolean language sql security definer set search_path = public stable
as $$ select exists(select 1 from public.developer_accounts where user_id = auth.uid()) $$;
grant execute on function public.is_developer_account() to authenticated;
create or replace function internal.notification_enabled(p_user_id uuid, p_category text) returns boolean
language sql stable security definer set search_path = public
as $$ select not exists(select 1 from public.notification_off where user_id = p_user_id) $$;
-- a: owner (dev)  b: moderator (dev)  c: member (dev)  d: member (not dev)
-- e: admin (not dev)  f: member (dev, 'club' notifications off)
-- 8: developer outside the club  9: pending member (dev)
insert into auth.users(id) select ('97000000-0000-0000-0000-00000000000' || x)::uuid from unnest(array['a','b','c','d','e','f','8','9']) x;
insert into public.profiles(id) select id from auth.users;
insert into public.clubs(id) values ('97100000-0000-0000-0000-000000000001');
insert into public.club_members values
 ('97100000-0000-0000-0000-000000000001','97000000-0000-0000-0000-00000000000a','owner','approved'),
 ('97100000-0000-0000-0000-000000000001','97000000-0000-0000-0000-00000000000b','moderator','approved'),
 ('97100000-0000-0000-0000-000000000001','97000000-0000-0000-0000-00000000000c','member','approved'),
 ('97100000-0000-0000-0000-000000000001','97000000-0000-0000-0000-00000000000d','member','approved'),
 ('97100000-0000-0000-0000-000000000001','97000000-0000-0000-0000-00000000000e','admin','approved'),
 ('97100000-0000-0000-0000-000000000001','97000000-0000-0000-0000-00000000000f','member','approved'),
 ('97100000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000009','member','pending');
insert into public.developer_accounts values
 ('97000000-0000-0000-0000-00000000000a'),('97000000-0000-0000-0000-00000000000b'),('97000000-0000-0000-0000-00000000000c'),
 ('97000000-0000-0000-0000-00000000000f'),('97000000-0000-0000-0000-000000000008'),('97000000-0000-0000-0000-000000000009');
insert into public.notification_off values ('97000000-0000-0000-0000-00000000000f');
-- A row that exists only in production must survive the constraint rebuild.
insert into public.notifications(recipient_id, type) values ('97000000-0000-0000-0000-00000000000a', 'production_only_type');
SQL

cat >"$WORK/assert.sql" <<'SQL'
\set ON_ERROR_STOP on
-- The type constraint kept production-only types and gained the new one.
do $$ begin
  if pg_get_constraintdef((select oid from pg_constraint where conname = 'notifications_type_check')) not like '%production_only_type%' then
    raise exception 'Constraint rebuild dropped a production-only type';
  end if;
end $$;

-- Owner (developer) posts; developer members are notified, nobody else.
set request.jwt.claim.sub='97000000-0000-0000-0000-00000000000a';
set role authenticated;
select public.create_club_announcement('97100000-0000-0000-0000-000000000001', '  ประชุมวันเสาร์  ');
do $$ begin
  if (select body from public.club_announcements) <> 'ประชุมวันเสาร์' then raise exception 'Body was not trimmed'; end if;
  begin
    insert into public.club_announcements(club_id, author_id, body) values ('97100000-0000-0000-0000-000000000001','97000000-0000-0000-0000-00000000000a','x');
    raise exception 'Direct insert bypassed the RPC';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.create_club_announcement('97100000-0000-0000-0000-000000000001', '   ');
    raise exception 'Empty announcement accepted';
  exception when raise_exception then
    if sqlerrm not like 'Announcement must be%' then raise; end if;
  end;
end $$;
reset role;
do $$ begin
  -- b (dev moderator) and c (dev member) only: not the author a, not d/e
  -- (not developers), not f (club notifications off), not the pending member.
  if (select string_agg(right(recipient_id::text, 1), ',' order by recipient_id::text)
      from public.notifications where type = 'club_announcement') <> 'b,c' then
    raise exception 'Wrong recipients: %', (select string_agg(recipient_id::text, ',') from public.notifications where type = 'club_announcement');
  end if;
end $$;

-- Muting the Club stops the notification.
insert into public.club_notification_mutes values ('97100000-0000-0000-0000-000000000001','97000000-0000-0000-0000-00000000000c');
set request.jwt.claim.sub='97000000-0000-0000-0000-00000000000b';
set role authenticated;
select public.create_club_announcement('97100000-0000-0000-0000-000000000001', 'จาก moderator');
reset role;
do $$ begin
  if exists (select 1 from public.notifications where type = 'club_announcement' and recipient_id = '97000000-0000-0000-0000-00000000000c' and actor_id = '97000000-0000-0000-0000-00000000000b') then
    raise exception 'Muted member was notified';
  end if;
end $$;

-- A developer member (not staff) reads but cannot post, edit or delete.
set request.jwt.claim.sub='97000000-0000-0000-0000-00000000000c';
set role authenticated;
do $$ begin
  if (select count(*) from public.club_announcements) <> 2 then raise exception 'Member cannot read announcements'; end if;
  begin
    perform public.create_club_announcement('97100000-0000-0000-0000-000000000001', 'hi');
    raise exception 'Member posted an announcement';
  exception when raise_exception then
    if sqlerrm not like 'Only Club staff%' then raise; end if;
  end;
end $$;
reset role;

-- Non-developer admin is blocked by the Beta2 gate even though staff.
set request.jwt.claim.sub='97000000-0000-0000-0000-00000000000e';
set role authenticated;
do $$ begin
  begin
    perform public.create_club_announcement('97100000-0000-0000-0000-000000000001', 'hi');
    raise exception 'Beta2 gate did not block a non-developer';
  exception when raise_exception then
    if sqlerrm not like '%not available yet%' then raise; end if;
  end;
end $$;
reset role;

-- Outsider developer and pending member see nothing and cannot post.
set request.jwt.claim.sub='97000000-0000-0000-0000-000000000008';
set role authenticated;
do $$ begin
  if (select count(*) from public.club_announcements) <> 0 then raise exception 'Outsider can read announcements'; end if;
  begin
    perform public.create_club_announcement('97100000-0000-0000-0000-000000000001', 'hi');
    raise exception 'Outsider posted';
  exception when raise_exception then
    if sqlerrm not like 'Only Club staff%' then raise; end if;
  end;
end $$;
reset role;
set request.jwt.claim.sub='97000000-0000-0000-0000-000000000009';
set role authenticated;
do $$ begin
  if (select count(*) from public.club_announcements) <> 0 then raise exception 'Pending member can read announcements'; end if;
end $$;
reset role;
set role anon;
do $$ begin
  begin
    perform 1 from public.club_announcements;
    raise exception 'anon can read announcements';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
SQL

# Edit/delete permissions need the ids, so they run as their own file.
cat >"$WORK/edit.sql" <<'SQL'
\set ON_ERROR_STOP on
-- Owner a edits own; moderator b cannot edit a's; owner a deletes b's; b deletes own (none left then).
create temp table ids as select id, author_id from public.club_announcements;
grant select on ids to authenticated;
set request.jwt.claim.sub='97000000-0000-0000-0000-00000000000b';
set role authenticated;
do $$ begin
  begin
    perform public.update_club_announcement((select id from ids where right(author_id::text,1)='a'), 'hijack');
    raise exception 'Moderator edited the owner''s announcement';
  exception when raise_exception then
    if sqlerrm not like 'Announcement not found or not yours to edit' then raise; end if;
  end;
  begin
    perform public.delete_club_announcement((select id from ids where right(author_id::text,1)='a'));
    raise exception 'Moderator deleted the owner''s announcement';
  exception when raise_exception then
    if sqlerrm not like 'Announcement not found or not yours to delete' then raise; end if;
  end;
end $$;
reset role;
set request.jwt.claim.sub='97000000-0000-0000-0000-00000000000c';
set role authenticated;
do $$ begin
  begin
    perform public.update_club_announcement((select id from ids where right(author_id::text,1)='a'), 'hijack');
    raise exception 'Member edited an announcement';
  exception when raise_exception then
    if sqlerrm not like 'Announcement not found%' then raise; end if;
  end;
end $$;
reset role;
set request.jwt.claim.sub='97000000-0000-0000-0000-00000000000a';
set role authenticated;
select public.update_club_announcement((select id from ids where right(author_id::text,1)='a'), 'ประชุมวันอาทิตย์');
select public.delete_club_announcement((select id from ids where right(author_id::text,1)='b'));
do $$ begin
  if (select body from public.club_announcements) <> 'ประชุมวันอาทิตย์' then raise exception 'Edit did not apply'; end if;
  if (select edited_at from public.club_announcements) is null then raise exception 'edited_at not set'; end if;
  if (select count(*) from public.club_announcements) <> 1 then raise exception 'Owner could not delete the moderator''s announcement'; end if;
end $$;
reset role;
-- A demoted author can no longer edit, but can still delete their own.
update public.club_members set role = 'member' where user_id = '97000000-0000-0000-0000-00000000000a';
set role authenticated;
do $$ begin
  begin
    perform public.update_club_announcement((select id from ids where right(author_id::text,1)='a'), 'late edit');
    raise exception 'Demoted author edited';
  exception when raise_exception then
    if sqlerrm not like 'Announcement not found%' then raise; end if;
  end;
end $$;
select public.delete_club_announcement((select id from ids where right(author_id::text,1)='a'));
reset role;
do $$ begin
  if exists (select 1 from public.club_announcements) then raise exception 'Author could not delete own announcement'; end if;
end $$;
SQL

createdb "$DB"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$WORK/stub.sql" >/dev/null
# Apply twice to prove the migration is idempotent.
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/migrations_web_beta2_club_announcements.sql" >/dev/null
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/migrations_web_beta2_club_announcements.sql" >/dev/null
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$WORK/assert.sql" >/dev/null
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$WORK/edit.sql" >/dev/null
echo "web_beta2_club_announcements_test: PASS"
