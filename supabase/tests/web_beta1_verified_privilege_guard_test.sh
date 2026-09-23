#!/usr/bin/env bash
# Web Beta1 Verified privilege regression; disposable PostgreSQL only.
# CI already runs every maintained supabase/tests/*.sh file.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="wynos_verified_guard_$$"
WORK="$(mktemp -d)"
cleanup() { dropdb --if-exists "$DB" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
for executable in psql createdb dropdb; do command -v "$executable" >/dev/null; done

cat >"$WORK/stub.sql" <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
create table auth.users (id uuid primary key default gen_random_uuid(), email text);
create or replace function auth.uid() returns uuid
language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create or replace function auth.role() returns text
language sql stable as $$ select nullif(current_setting('request.jwt.claim.role',true),'') $$;
create or replace function auth.jwt() returns jsonb
language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb)
$$;
create schema if not exists storage;
create table storage.buckets(id text primary key,name text not null,public boolean not null default false);
create table storage.objects(
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),name text,owner uuid
);
create or replace function storage.foldername(name text) returns text[]
language sql immutable as $$ select string_to_array(name, '/') $$;
alter table storage.objects enable row level security;
do $$ begin
  if not exists(select 1 from pg_roles where rolname='authenticated') then
    create role authenticated nologin;
  end if;
  if not exists(select 1 from pg_roles where rolname='anon') then
    create role anon nologin;
  end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;
alter role service_role bypassrls;
grant usage on schema public,auth,storage to anon,authenticated,service_role;
alter default privileges in schema public
  grant select,insert,update,delete on tables to anon,authenticated,service_role;
SQL

cat >"$WORK/seed.sql" <<'SQL'
insert into auth.users(id,email) values
 ('97000000-0000-0000-0000-000000000001','alice@example.invalid'),
 ('97000000-0000-0000-0000-000000000002','bob@example.invalid'),
 ('97000000-0000-0000-0000-000000000003','charlie@example.invalid'),
 ('97000000-0000-0000-0000-000000000004','dave@example.invalid');
insert into public.profiles(id,username,display_name,is_verified) values
 ('97000000-0000-0000-0000-000000000001','alice_verified_test','Alice',false),
 ('97000000-0000-0000-0000-000000000002','bob_verified_test','Bob',true);
do $$ begin
  if not has_column_privilege('authenticated','public.profiles','is_verified','INSERT')
     or not has_column_privilege('authenticated','public.profiles','is_verified','UPDATE') then
    raise exception 'Fixture must reproduce original privilege problem';
  end if;
end $$;
SQL

cat >"$WORK/assert.sql" <<'SQL'
do $$ begin
  if has_column_privilege('authenticated','public.profiles','is_verified','INSERT')
     or has_column_privilege('authenticated','public.profiles','is_verified','UPDATE')
     or has_column_privilege('anon','public.profiles','is_verified','INSERT')
     or has_column_privilege('anon','public.profiles','is_verified','UPDATE') then
    raise exception 'Client roles still have Verified writes';
  end if;
  if not has_column_privilege('authenticated','public.profiles','is_verified','SELECT')
     or not has_column_privilege('authenticated','public.profiles','display_name','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','avatar_url','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','social_links','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','id','INSERT')
     or not has_table_privilege('authenticated','public.profiles','DELETE')
     or not has_column_privilege('service_role','public.profiles','is_verified','UPDATE') then
    raise exception 'Normal profile privileges regressed';
  end if;
  if (select count(*) from public.profiles where is_verified)<>1 then
    raise exception 'Existing Verified state was modified';
  end if;
end $$;
set request.jwt.claim.sub='97000000-0000-0000-0000-000000000001';
set request.jwt.claim.role='authenticated';
set role authenticated;
update public.profiles set display_name='Alice Edited',bio='Normal profile change'
where id='97000000-0000-0000-0000-000000000001';
insert into public.profiles(id,username)
values ('97000000-0000-0000-0000-000000000001','alice_verified_test2')
on conflict(id) do update set username=excluded.username;
do $$ declare n int; begin
  update public.profiles set display_name='Cross-user write'
  where id='97000000-0000-0000-0000-000000000002';
  get diagnostics n=row_count;
  if n<>0 then raise exception 'Cross-user update succeeded'; end if;
  begin
    update public.profiles set is_verified=true
      where id='97000000-0000-0000-0000-000000000001';
    raise exception 'Untrusted Verified UPDATE unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
set request.jwt.claim.sub='97000000-0000-0000-0000-000000000003';
set role authenticated;
insert into public.profiles(id,username)
values ('97000000-0000-0000-0000-000000000003','charlie_verified_test');
reset role;
set request.jwt.claim.sub='97000000-0000-0000-0000-000000000004';
set role authenticated;
do $$ begin
  begin
    insert into public.profiles(id,username,is_verified) values
      ('97000000-0000-0000-0000-000000000004','dave_verified_test',true);
    raise exception 'Untrusted Verified INSERT unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- Defense in depth: simulate a future grant accidentally restoring access.
grant insert(is_verified),update(is_verified) on public.profiles to authenticated;
set request.jwt.claim.sub='97000000-0000-0000-0000-000000000001';
set role authenticated;
do $$ declare message text; begin
  begin
    update public.profiles set is_verified=true
    where id='97000000-0000-0000-0000-000000000001';
    raise exception 'Accidental grant bypassed Verified trigger';
  exception when insufficient_privilege then
    get stacked diagnostics message=message_text;
    if message <> 'Only trusted server roles may modify profiles.is_verified' then
      raise exception 'Unexpected Verified UPDATE denial: %',message;
    end if;
  end;
end $$;
reset role;
set request.jwt.claim.sub='97000000-0000-0000-0000-000000000004';
set role authenticated;
do $$ declare message text; begin
  begin
    insert into public.profiles(id,username,is_verified) values
      ('97000000-0000-0000-0000-000000000004','dave_verified_test',true);
    raise exception 'Accidental grant bypassed signup Verified trigger';
  exception when insufficient_privilege then
    get stacked diagnostics message=message_text;
    if message <> 'Only trusted server roles may set profiles.is_verified' then
      raise exception 'Unexpected Verified INSERT denial: %',message;
    end if;
  end;
end $$;
reset role;
revoke insert(is_verified),update(is_verified) on public.profiles from authenticated;

-- Trusted backend must retain the ability to administer Verified.
set role service_role;
update public.profiles set is_verified=false
where id='97000000-0000-0000-0000-000000000002';
update public.profiles set is_verified=true
where id='97000000-0000-0000-0000-000000000002';
reset role;
do $$ begin
  if (select count(*) from public.profiles where is_verified)<>1
    or not exists(select 1 from public.profiles
      where username='alice_verified_test2' and display_name='Alice Edited' and not is_verified)
    or not exists(select 1 from public.profiles
      where username='charlie_verified_test' and not is_verified) then
    raise exception 'Verified integrity or standard onboarding/profile write regressed';
  end if;
end $$;
\echo ALL VERIFIED REGRESSION CHECKS PASSED
SQL

createdb "$DB"
psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$WORK/stub.sql"
psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$ROOT/supabase/schema.sql" >"$WORK/schema.log" 2>&1 || { cat "$WORK/schema.log" >&2; exit 1; }
psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$WORK/seed.sql"
psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$ROOT/supabase/migrations_web_beta1_verified_privilege_guard.sql"
psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$ROOT/supabase/migrations_web_beta1_verified_privilege_guard.sql"
psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$WORK/assert.sql"
