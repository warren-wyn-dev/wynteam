#!/usr/bin/env bash
# WYN-157 regression: WYN-155 must not reopen backend-only RPCs, and Guest
# disablement must be enforced at the database layer for every RLS-protected
# public table plus storage.objects.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
MIGRATION_149="$SCRIPT_DIR/../migrations_wyn149_location_search_rate_limit.sql"
MIGRATION_155="$SCRIPT_DIR/../migrations_wyn155_security_definer_privileges.sql"
MIGRATION_157="$SCRIPT_DIR/../migrations_wyn157_full_system_hardening.sql"
DB_NAME="wyn157_full_system_hardening_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

for required in "$SCHEMA_FILE" "$MIGRATION_149" "$MIGRATION_155" "$MIGRATION_157"; do
  if [ ! -f "$required" ]; then
    echo "FAIL: required file not found: $required" >&2
    exit 1
  fi
done

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
  if createdb "$db" >/dev/null 2>&1; then
    return 0
  elif command -v sudo >/dev/null 2>&1 && sudo -u postgres createdb "$db" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

dropdb_any() {
  local db="$1"
  dropdb --if-exists "$db" >/dev/null 2>&1 \
    || { command -v sudo >/dev/null 2>&1 && sudo -u postgres dropdb --if-exists "$db" >/dev/null 2>&1; } \
    || true
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
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
EOF

cat > "$WORK_DIR/10_assert.sql" <<'EOF'
\pset pager off

-- WYN-149 deliberately made this service-only. WYN-155 broadens all public
-- SECURITY DEFINER functions, and WYN-157 must restore the narrower contract.
select 'CHECK1_location_rpc_not_authenticated' as check_name,
       has_function_privilege('authenticated', 'public.reserve_location_search_request(uuid,integer,integer)'::regprocedure, 'EXECUTE')::int as actual,
       0 as expected;
select 'CHECK2_location_rpc_service_role' as check_name,
       has_function_privilege('service_role', 'public.reserve_location_search_request(uuid,integer,integer)'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;

select 'CHECK3_refresh_trending_not_authenticated' as check_name,
       has_function_privilege('authenticated', 'public.refresh_trending_scores(timestamptz)'::regprocedure, 'EXECUTE')::int as actual,
       0 as expected;
select 'CHECK4_refresh_top100_not_authenticated' as check_name,
       has_function_privilege('authenticated', 'public.refresh_top100_scores(timestamptz)'::regprocedure, 'EXECUTE')::int as actual,
       0 as expected;
select 'CHECK5_refresh_quality_not_authenticated' as check_name,
       has_function_privilege('authenticated', 'public.refresh_feed_content_quality(timestamptz)'::regprocedure, 'EXECUTE')::int as actual,
       0 as expected;
select 'CHECK6_refresh_similarity_not_authenticated' as check_name,
       has_function_privilege('authenticated', 'public.refresh_feed_similarities(timestamptz)'::regprocedure, 'EXECUTE')::int as actual,
       0 as expected;

select 'CHECK7_refresh_trending_service_role' as check_name,
       has_function_privilege('service_role', 'public.refresh_trending_scores(timestamptz)'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;
select 'CHECK8_refresh_top100_service_role' as check_name,
       has_function_privilege('service_role', 'public.refresh_top100_scores(timestamptz)'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;
select 'CHECK9_refresh_quality_service_role' as check_name,
       has_function_privilege('service_role', 'public.refresh_feed_content_quality(timestamptz)'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;
select 'CHECK10_refresh_similarity_service_role' as check_name,
       has_function_privilege('service_role', 'public.refresh_feed_similarities(timestamptz)'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;

-- User-facing authenticated RPCs remain available; the repair is intentionally
-- narrow rather than undoing WYN-155 wholesale.
select 'CHECK11_normal_authenticated_rpc_still_open' as check_name,
       has_function_privilege('authenticated', 'public.block_user(uuid)'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;
select 'CHECK12_pre_auth_allowlist_still_open' as check_name,
       has_function_privilege('anon', 'public.is_invite_gate_enabled()'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;

-- Every RLS-protected public table that existed when WYN-157 ran must have all
-- three RESTRICTIVE permanent-account write guards.
with rls_tables as (
  select n.nspname, c.relname
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r','p')
    and c.relrowsecurity
), missing as (
  select t.relname
  from rls_tables t
  where not exists (
    select 1 from pg_policies p
    where p.schemaname=t.nspname and p.tablename=t.relname
      and p.policyname='wyn157_permanent_insert'
      and p.permissive='RESTRICTIVE' and p.cmd='INSERT'
  ) or not exists (
    select 1 from pg_policies p
    where p.schemaname=t.nspname and p.tablename=t.relname
      and p.policyname='wyn157_permanent_update'
      and p.permissive='RESTRICTIVE' and p.cmd='UPDATE'
  ) or not exists (
    select 1 from pg_policies p
    where p.schemaname=t.nspname and p.tablename=t.relname
      and p.policyname='wyn157_permanent_delete'
      and p.permissive='RESTRICTIVE' and p.cmd='DELETE'
  )
)
select 'CHECK13_public_tables_missing_guest_write_guard' as check_name,
       count(*)::int as actual,
       0 as expected
from missing;

select 'CHECK14_storage_insert_guard' as check_name,
       count(*)::int as actual,
       1 as expected
from pg_policies
where schemaname='storage' and tablename='objects'
  and policyname='wyn157_permanent_insert'
  and permissive='RESTRICTIVE' and cmd='INSERT';
select 'CHECK15_storage_update_guard' as check_name,
       count(*)::int as actual,
       1 as expected
from pg_policies
where schemaname='storage' and tablename='objects'
  and policyname='wyn157_permanent_update'
  and permissive='RESTRICTIVE' and cmd='UPDATE';
select 'CHECK16_storage_delete_guard' as check_name,
       count(*)::int as actual,
       1 as expected
from pg_policies
where schemaname='storage' and tablename='objects'
  and policyname='wyn157_permanent_delete'
  and permissive='RESTRICTIVE' and cmd='DELETE';

select 'CHECK17_refresh_wrapper_exists' as check_name,
       (to_regprocedure('internal.refresh_feed_caches()') is not null)::int as actual,
       1 as expected;
select 'CHECK18_refresh_wrapper_not_authenticated' as check_name,
       has_function_privilege('authenticated', 'internal.refresh_feed_caches()'::regprocedure, 'EXECUTE')::int as actual,
       0 as expected;
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
if ! run_psql "$DB_NAME" "$MIGRATION_149"; then
  echo "FAIL: WYN-149 migration failed to apply" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi
if ! run_psql "$DB_NAME" "$MIGRATION_155"; then
  echo "FAIL: WYN-155 migration failed to apply" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi
if ! run_psql "$DB_NAME" "$MIGRATION_157"; then
  echo "FAIL: WYN-157 migration failed to apply" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi
if ! run_psql "$DB_NAME" "$WORK_DIR/10_assert.sql"; then
  echo "FAIL: WYN-157 assertions errored" >&2
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
