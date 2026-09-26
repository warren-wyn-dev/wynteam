#!/usr/bin/env bash
# Web Beta1 full-system QA hardening (WEB-B1-QA-02/03 + referral_code guard);
# disposable PostgreSQL only. CI already runs every maintained supabase/tests/*.sh file.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="wynos_qa_hardening_$$"
WORK="$(mktemp -d)"
cleanup() { dropdb --if-exists "$DB" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
for executable in psql createdb dropdb; do command -v "$executable" >/dev/null; done

cat >"$WORK/stub.sql" <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
create table auth.users (id uuid primary key default gen_random_uuid(), email text,
  created_at timestamptz not null default now(), is_anonymous boolean not null default false);
create or replace function auth.uid() returns uuid
language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create or replace function auth.role() returns text
language sql stable as $$ select nullif(current_setting('request.jwt.claim.role',true),'') $$;
create or replace function auth.jwt() returns jsonb
language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb)
$$;
create schema if not exists storage;
-- Supabase's real storage.buckets carries these limit columns.
create table storage.buckets(id text primary key,name text not null,public boolean not null default false,
  allowed_mime_types text[], file_size_limit bigint);
create table storage.objects(
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),name text,owner uuid
);
create or replace function storage.foldername(name text) returns text[]
language sql immutable as $$ select string_to_array(name, '/') $$;
alter table storage.objects enable row level security;
do $$ begin
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
end $$;
alter role service_role bypassrls;
grant usage on schema public,auth,storage to anon,authenticated,service_role;
alter default privileges in schema public
  grant select,insert,update,delete on tables to anon,authenticated,service_role;
SQL

cat >"$WORK/seed.sql" <<'SQL'
insert into auth.users(id,email) values
 ('98000000-0000-0000-0000-000000000001','alice@example.invalid'),
 ('98000000-0000-0000-0000-000000000002','bob@example.invalid'),
 ('98000000-0000-0000-0000-000000000003','carol@example.invalid');
insert into public.profiles(id,username) values
 ('98000000-0000-0000-0000-000000000001','alice_qa_test'),
 ('98000000-0000-0000-0000-000000000002','bob_qa_test'),
 ('98000000-0000-0000-0000-000000000003','carol_qa_test');
insert into public.drops(id,author_id,image_url,caption) values
 ('98000000-0000-0000-0000-0000000000d1','98000000-0000-0000-0000-000000000002','x.jpg','Bob post');
SQL

cat >"$WORK/assert.sql" <<'SQL'
-- ---- WEB-B1-QA-02: toggling follow/like must not flood notifications ----
set request.jwt.claim.sub='98000000-0000-0000-0000-000000000001';
set request.jwt.claim.role='authenticated';
set role authenticated;
insert into public.follows(follower_id,following_id) values
 ('98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000002');
delete from public.follows where follower_id='98000000-0000-0000-0000-000000000001';
insert into public.follows(follower_id,following_id) values
 ('98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000002');
delete from public.follows where follower_id='98000000-0000-0000-0000-000000000001';
insert into public.follows(follower_id,following_id) values
 ('98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000002');
insert into public.drop_likes(drop_id,user_id) values ('98000000-0000-0000-0000-0000000000d1','98000000-0000-0000-0000-000000000001');
delete from public.drop_likes where user_id='98000000-0000-0000-0000-000000000001';
insert into public.drop_likes(drop_id,user_id) values ('98000000-0000-0000-0000-0000000000d1','98000000-0000-0000-0000-000000000001');
reset role;
do $$ begin
  if (select count(*) from public.follows where follower_id='98000000-0000-0000-0000-000000000001') <> 1 then
    raise exception 'The follow itself must still succeed';
  end if;
  if (select count(*) from public.notifications where recipient_id='98000000-0000-0000-0000-000000000002' and type='follow') <> 1 then
    raise exception 'follow toggling flooded notifications: %',
      (select count(*) from public.notifications where type='follow');
  end if;
  if (select count(*) from public.notifications where recipient_id='98000000-0000-0000-0000-000000000002' and type='like_drop') <> 1 then
    raise exception 'like toggling flooded notifications';
  end if;
end $$;

-- A different actor is a distinct event and still notifies.
set request.jwt.claim.sub='98000000-0000-0000-0000-000000000003';
set role authenticated;
insert into public.follows(follower_id,following_id) values
 ('98000000-0000-0000-0000-000000000003','98000000-0000-0000-0000-000000000002');
reset role;
do $$ begin
  if (select count(*) from public.notifications where recipient_id='98000000-0000-0000-0000-000000000002' and type='follow') <> 2 then
    raise exception 'A second actor must still notify';
  end if;
end $$;

-- After the 10-minute window the same actor notifies again.
update public.notifications set created_at = now() - interval '11 minutes'
where actor_id='98000000-0000-0000-0000-000000000001' and type='follow';
set request.jwt.claim.sub='98000000-0000-0000-0000-000000000001';
set role authenticated;
delete from public.follows where follower_id='98000000-0000-0000-0000-000000000001';
insert into public.follows(follower_id,following_id) values
 ('98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000002');
reset role;
do $$ begin
  if (select count(*) from public.notifications where actor_id='98000000-0000-0000-0000-000000000001' and type='follow') <> 2 then
    raise exception 'Dedupe window must expire';
  end if;
end $$;

-- Distinct-content types are never deduplicated.
insert into public.notifications(recipient_id,actor_id,type,drop_id) values
 ('98000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','comment_drop','98000000-0000-0000-0000-0000000000d1'),
 ('98000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','comment_drop','98000000-0000-0000-0000-0000000000d1');
do $$ begin
  if (select count(*) from public.notifications where type='comment_drop') <> 2 then
    raise exception 'Comments must not be deduplicated';
  end if;
end $$;

-- ---- WEB-B1-QA-03: server-side upload limits ----
do $$ declare b record; begin
  for b in select * from storage.buckets where id in ('avatars','drop-images','chat-media','club-media') loop
    if b.allowed_mime_types is null or b.file_size_limit is null then
      raise exception 'Bucket % has no server-side limits', b.id;
    end if;
    if 'image/svg+xml' = any(b.allowed_mime_types) or 'text/html' = any(b.allowed_mime_types) then
      raise exception 'Bucket % allows a script-capable type', b.id;
    end if;
    if not ('image/jpeg' = any(b.allowed_mime_types) and 'image/heic' = any(b.allowed_mime_types)) then
      raise exception 'Bucket % rejects normal phone photos', b.id;
    end if;
  end loop;
  if (select file_size_limit from storage.buckets where id='avatars') <> 10485760
     or (select file_size_limit from storage.buckets where id='drop-images') <> 20971520 then
    raise exception 'Unexpected size limits';
  end if;
  if exists(select 1 from storage.buckets where id in ('pop-videos','appeal-evidence') and allowed_mime_types is not null) then
    raise exception 'Untouched buckets were modified';
  end if;
end $$;

-- ---- referral_code guard ----
set request.jwt.claim.sub='98000000-0000-0000-0000-000000000001';
set role authenticated;
update public.profiles set display_name='Alice' where id='98000000-0000-0000-0000-000000000001';
do $$ begin
  begin
    update public.profiles set referral_code='WYNOS' where id='98000000-0000-0000-0000-000000000001';
    raise exception 'Owner changed referral_code';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
update public.profiles set referral_code='SERVERSET' where id='98000000-0000-0000-0000-000000000001';
do $$ begin
  if (select referral_code from public.profiles where id='98000000-0000-0000-0000-000000000001') <> 'SERVERSET'
     or (select display_name from public.profiles where id='98000000-0000-0000-0000-000000000001') <> 'Alice' then
    raise exception 'Trusted referral update or normal profile edit regressed';
  end if;
end $$;
\echo ALL WEB BETA1 QA HARDENING CHECKS PASSED
SQL

createdb "$DB"
psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$WORK/stub.sql" >/dev/null
psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$ROOT/supabase/schema.sql" >"$WORK/schema.log" 2>&1 || { cat "$WORK/schema.log" >&2; exit 1; }
psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$WORK/seed.sql" >/dev/null
for migration in notification_flood_guard storage_upload_limits referral_code_guard; do
  # Applied twice: every migration must be idempotent.
  psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$ROOT/supabase/migrations_web_beta1_${migration}.sql" >/dev/null
  psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$ROOT/supabase/migrations_web_beta1_${migration}.sql" >/dev/null
done
psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$WORK/assert.sql"
