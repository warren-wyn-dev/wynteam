#!/usr/bin/env bash
# WYN-191 regression: ranked, block-aware People Search.
# Loads the full schema into a throwaway PostgreSQL DB and exercises the RPC
# under the real authenticated role. Never touches dev/prod data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn191_people_search_regression_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

run_psql() {
  local db="$1"
  local file="$2"
  if psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  elif command -v sudo >/dev/null 2>&1 && sudo -u postgres psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  else
    cat "$WORK_DIR/psql.out" >&2
    return 1
  fi
}

createdb_any() {
  local db="$1"
  createdb "$db" >/dev/null 2>&1     || { command -v sudo >/dev/null 2>&1 && sudo -u postgres createdb "$db" >/dev/null 2>&1; }
}

dropdb_any() {
  local db="$1"
  dropdb --if-exists "$db" >/dev/null 2>&1     || { command -v sudo >/dev/null 2>&1 && sudo -u postgres dropdb --if-exists "$db" >/dev/null 2>&1; }     || true
}

cat > "$WORK_DIR/00_stub.sql" <<'EOF'
create extension if not exists pgcrypto;

create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text
);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create or replace function auth.role() returns text
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role', true), '')
$$;

create or replace function auth.jwt() returns jsonb
language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb)
$$;

create schema if not exists storage;
create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false
);
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text,
  owner uuid
);
alter table storage.objects enable row level security;

create or replace function storage.foldername(name text) returns text[]
language sql immutable as $$
  select string_to_array(name, '/')
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
end
$$;

grant usage on schema public to authenticated, anon, service_role;
grant usage on schema storage to authenticated, anon, service_role;
-- Supabase grants API roles access to auth helper functions. Mirror that
-- hosted permission here so SECURITY INVOKER search functions can call
-- auth.uid()/auth.jwt() under the real authenticated role in local QA.
grant usage on schema auth to authenticated, anon, service_role;
grant usage on schema extensions to authenticated, anon, service_role;
grant execute on function auth.uid() to authenticated, anon, service_role;
grant execute on function auth.role() to authenticated, anon, service_role;
grant execute on function auth.jwt() to authenticated, anon, service_role;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
EOF

cat > "$WORK_DIR/10_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

-- Mirror hosted Supabase schema USAGE for helpers called by the RPC/RLS.
-- anon intentionally does not receive internal schema usage.
grant usage on schema auth, extensions, internal to authenticated;

create table results (check_name text primary key, actual int, expected int);

insert into auth.users (id,email) values
  ('19100000-0000-0000-0000-000000000001','viewer191@test.com'),
  ('19100000-0000-0000-0000-000000000002','exact191@test.com'),
  ('19100000-0000-0000-0000-000000000003','prefix191@test.com'),
  ('19100000-0000-0000-0000-000000000004','display191@test.com'),
  ('19100000-0000-0000-0000-000000000005','displayprefix191@test.com'),
  ('19100000-0000-0000-0000-000000000006','contains191@test.com'),
  ('19100000-0000-0000-0000-000000000007','blocked191@test.com')
on conflict (id) do nothing;

insert into public.profiles (id,username,display_name) values
  ('19100000-0000-0000-0000-000000000001','viewer191','Viewer'),
  ('19100000-0000-0000-0000-000000000002','alex','Exact User'),
  ('19100000-0000-0000-0000-000000000003','alexander','Prefix User'),
  ('19100000-0000-0000-0000-000000000004','handle191','Alex Person'),
  ('19100000-0000-0000-0000-000000000005','handle192','Alex Person Extra'),
  ('19100000-0000-0000-0000-000000000006','zzalexzz','Contains User'),
  ('19100000-0000-0000-0000-000000000007','blockedperson','Blocked Person')
on conflict (id) do update
set username=excluded.username, display_name=excluded.display_name;

insert into public.blocks (blocker_id, blocked_id)
values ('19100000-0000-0000-0000-000000000001','19100000-0000-0000-0000-000000000007')
on conflict do nothing;

insert into results
select 'CHECK01_authenticated_can_execute',
       has_function_privilege('authenticated','public.search_profiles_ranked(text,integer,integer)'::regprocedure,'EXECUTE')::int,
       1;

insert into results
select 'CHECK02_anon_cannot_execute',
       has_function_privilege('anon','public.search_profiles_ranked(text,integer,integer)'::regprocedure,'EXECUTE')::int,
       0;

set role authenticated;
set request.jwt.claim.sub = '19100000-0000-0000-0000-000000000001';
set request.jwt.claim.role = 'authenticated';
set request.jwt.claims = '{"sub":"19100000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}';

insert into results
select 'CHECK03_exact_username_first',
       ((select username from public.search_profiles_ranked('alex',30,0) limit 1)='alex')::int,
       1;

insert into results
select 'CHECK04_at_username_first',
       ((select username from public.search_profiles_ranked('@alex',30,0) limit 1)='alex')::int,
       1;

insert into results
select 'CHECK05_username_prefix_before_contains',
       (
         (select username from public.search_profiles_ranked('alex',30,0) offset 1 limit 1)='alexander'
       )::int,
       1;

insert into results
select 'CHECK06_exact_display_name_first',
       ((select username from public.search_profiles_ranked('Alex Person',30,0) limit 1)='handle191')::int,
       1;

insert into results
select 'CHECK07_blocked_profile_hidden',
       (not exists(
         select 1 from public.search_profiles_ranked('blockedperson',30,0)
         where id='19100000-0000-0000-0000-000000000007'
       ))::int,
       1;

insert into results
select 'CHECK08_short_query_returns_zero',
       ((select count(*) from public.search_profiles_ranked('a',30,0))=0)::int,
       1;

reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.role;
reset request.jwt.claims;

select check_name, actual, expected from results order by check_name;
EOF

echo "== Loading WYNOS schema into fresh DB '$DB_NAME' =="
dropdb_any "$DB_NAME"
if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database '$DB_NAME'" >&2
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then
  echo "FAIL: stub setup failed" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi
if ! run_psql "$DB_NAME" "$SCHEMA_FILE"; then
  echo "FAIL: schema.sql failed to load cleanly" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi
if ! run_psql "$DB_NAME" "$WORK_DIR/10_seed_and_assert.sql"; then
  echo "FAIL: WYN-191 assertions errored" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

cat "$WORK_DIR/psql.out"

FAILURES=0
while IFS='|' read -r name actual expected; do
  name="$(echo "$name" | xargs)"
  actual="$(echo "$actual" | xargs)"
  expected="$(echo "$expected" | xargs)"
  [ -z "$name" ] && continue
  case "$name" in
    CHECK*)
      if [ "$actual" != "$expected" ]; then
        echo "FAIL: $name -- expected $expected, got $actual"
        FAILURES=$((FAILURES + 1))
      else
        echo "PASS: $name (expected $expected, got $actual)"
      fi
      ;;
  esac
done < "$WORK_DIR/psql.out"

dropdb_any "$DB_NAME"

if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES check(s) failed"
  exit 1
fi

echo "ALL CHECKS PASSED"
