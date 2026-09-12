#!/usr/bin/env bash
# WYN-155 / system-audit regression: a not-signed-in PostgREST caller must
# not inherit EXECUTE on the historical SECURITY DEFINER RPC surface.
#
# Exactly three public SECURITY DEFINER functions are deliberately callable
# by role `anon`:
#   - is_invite_gate_enabled()
#   - validate_referral_code(text)
#   - preview_club_invite_link(text)
# Everything else requires a real Supabase session (`authenticated`).
#
# The test creates its own throwaway PostgreSQL database, loads the canonical
# schema, applies the hardening migration, and checks privileges. It never
# touches dev/prod.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations_wyn155_security_definer_privileges.sql"
DB_NAME="wyn155_security_definer_privileges_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

for required in "$SCHEMA_FILE" "$MIGRATION_FILE"; do
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
end
$$;

grant usage on schema public to authenticated, anon;
grant usage on schema storage to authenticated, anon;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
EOF

cat > "$WORK_DIR/10_assert.sql" <<'EOF'
\pset pager off

-- There must be exactly three anonymous SECURITY DEFINER entrypoints.
select 'CHECK1_anon_secdef_count' as check_name,
       count(*)::int as actual,
       3 as expected
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
  and has_function_privilege('anon', p.oid, 'EXECUTE');

-- And they must be exactly the documented pre-auth allowlist, not any three.
select 'CHECK2_anon_secdef_allowlist_only' as check_name,
       count(*)::int as actual,
       0 as expected
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
  and has_function_privilege('anon', p.oid, 'EXECUTE')
  and p.oid not in (
    'public.is_invite_gate_enabled()'::regprocedure,
    'public.validate_referral_code(text)'::regprocedure,
    'public.preview_club_invite_link(text)'::regprocedure
  );

-- Each deliberate exception must remain usable before sign-in.
select 'CHECK3_invite_gate_anon' as check_name,
       has_function_privilege('anon', 'public.is_invite_gate_enabled()'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;
select 'CHECK4_referral_validate_anon' as check_name,
       has_function_privilege('anon', 'public.validate_referral_code(text)'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;
select 'CHECK5_club_invite_preview_anon' as check_name,
       has_function_privilege('anon', 'public.preview_club_invite_link(text)'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;

-- Representative high-risk RPCs from different subsystems must be closed to
-- pre-auth callers, while remaining available to authenticated app sessions.
select 'CHECK6_admin_action_closed_to_anon' as check_name,
       has_function_privilege('anon', 'public.admin_apply_user_action(uuid,text,text,integer)'::regprocedure, 'EXECUTE')::int as actual,
       0 as expected;
select 'CHECK7_moderation_action_closed_to_anon' as check_name,
       has_function_privilege('anon', 'public.apply_moderation_action(uuid,text,text,integer)'::regprocedure, 'EXECUTE')::int as actual,
       0 as expected;
select 'CHECK8_block_user_closed_to_anon' as check_name,
       has_function_privilege('anon', 'public.block_user(uuid)'::regprocedure, 'EXECUTE')::int as actual,
       0 as expected;
select 'CHECK9_admin_action_still_authenticated' as check_name,
       has_function_privilege('authenticated', 'public.admin_apply_user_action(uuid,text,text,integer)'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;
select 'CHECK10_block_user_still_authenticated' as check_name,
       has_function_privilege('authenticated', 'public.block_user(uuid)'::regprocedure, 'EXECUTE')::int as actual,
       1 as expected;
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
if ! run_psql "$DB_NAME" "$MIGRATION_FILE"; then
  echo "FAIL: WYN-155 migration failed to apply" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/10_assert.sql"; then
  echo "FAIL: privilege assertions errored" >&2
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
