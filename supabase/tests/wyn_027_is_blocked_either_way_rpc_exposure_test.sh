#!/usr/bin/env bash
# Regression test for WYN-027: verify `is_blocked_either_way()` and its
# four author-lookup siblings (`drop_author_id`, `pop_author_id`,
# `drop_comment_author_id`, `pop_comment_author_id`) are NOT reachable
# as a client-facing RPC, while the RLS policies that depend on them
# internally still work correctly.
#
# Background: these SECURITY DEFINER helper functions originally lived
# in `public` with no explicit `grant`/`revoke` statement. Postgres
# grants EXECUTE to PUBLIC by default on function creation, and
# PostgREST auto-exposes every `public`-schema function with EXECUTE as
# `POST /rest/v1/rpc/<name>` -- so despite being intended as
# internal-only, `is_blocked_either_way(a uuid, b uuid)` (which takes
# BOTH parties as free, caller-supplied parameters, unlike
# `block_relationship()` which always resolves the caller's own
# relationship via `auth.uid()`) let any authenticated user learn
# whether any two *other* users had blocked each other, bypassing the
# `blocks` table's own privacy-preserving RLS entirely. A plain
# `revoke execute ... from authenticated` does NOT fix this -- it was
# verified (empirically, against real Postgres) to break the RLS
# policies themselves, since a policy's `using`/`with check` clause is
# evaluated under the querying role's own privileges, not the defining
# role's. The fix moves these 5 functions into a new `internal` schema
# that is never added to PostgREST's exposed-schema list (default is
# `public` only), which closes the RPC route regardless of the
# underlying SQL-level GRANT (kept, and required, for the RLS policies
# to keep working). See
# `.wyn/tasks/bugs/WYN-027-is-blocked-either-way-rpc-exposure.md` for
# the full writeup.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# `wyn_021_club_post_mentions_rls_test.sh`'s harness).
#
# Usage:
#   bash supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway DB.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn027_rls_regression_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
# mktemp -d defaults to 0700; when psql runs as a different OS user
# (e.g. via `sudo -u postgres`) it needs read access to these files.
chmod 755 "$WORK_DIR"

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "FAIL: schema file not found at $SCHEMA_FILE" >&2
  exit 1
fi

# Run psql either directly (if the invoking user already has access)
# or via the postgres OS user (typical fresh install default).
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
-- Stub of Supabase platform pieces that schema.sql assumes already exist.
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

cat > "$WORK_DIR/10_seed_and_assert.sql" <<'EOF'
\pset pager off

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'dave@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'eve@test.com');

insert into public.profiles (id, username, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice'),
  ('22222222-2222-2222-2222-222222222222', 'dave', 'Dave'),
  ('33333333-3333-3333-3333-333333333333', 'eve', 'Eve');

-- Alice blocks Dave, as Alice.
\set ON_ERROR_STOP on
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
select public.block_user('22222222-2222-2222-2222-222222222222');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- Dave (blocked by Alice) posts a Drop, used by CHECK6/7 below to
-- prove the RLS policies that internally call these functions still
-- work correctly after the schema move.
insert into public.drops (id, author_id, image_url) values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', 'https://example.com/dave.jpg');

-- CHECK 1 (sanity control): Eve, an uninvolved third party, cannot
-- browse the blocks table directly -- proves RLS is engaged in this
-- harness at all.
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
select 'CHECK1_eve_blocks_table_direct' as check_name, count(*) as actual, 0 as expected
from public.blocks;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK 2-6 (the WYN-027 fix itself): none of the 5 helper functions
-- exist in `public` any more -- this is the exact schema PostgREST
-- auto-exposes as RPC routes by default, so their absence there means
-- `POST /rest/v1/rpc/is_blocked_either_way` (etc.) has no route to
-- hit, closing the leak regardless of any SQL-level GRANT.
select 'CHECK2_public_is_blocked_either_way_gone' as check_name,
  (case when exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'is_blocked_either_way'
  ) then 1 else 0 end) as actual, 0 as expected;

select 'CHECK3_public_drop_author_id_gone' as check_name,
  (case when exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'drop_author_id'
  ) then 1 else 0 end) as actual, 0 as expected;

select 'CHECK4_public_pop_author_id_gone' as check_name,
  (case when exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'pop_author_id'
  ) then 1 else 0 end) as actual, 0 as expected;

select 'CHECK5_public_drop_comment_author_id_gone' as check_name,
  (case when exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'drop_comment_author_id'
  ) then 1 else 0 end) as actual, 0 as expected;

select 'CHECK6_public_pop_comment_author_id_gone' as check_name,
  (case when exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'pop_comment_author_id'
  ) then 1 else 0 end) as actual, 0 as expected;

-- CHECK 7-8: legitimate RLS-embedded usage still works correctly --
-- Alice (blocked) must not see Dave's drop; Eve (uninvolved) must see
-- it normally. This is the "did the schema-qualification rename break
-- a policy" regression guard.
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
select 'CHECK7_alice_cannot_see_daves_drop' as check_name, count(*) as actual, 0 as expected
from public.drops where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
select 'CHECK8_eve_can_see_daves_drop' as check_name, count(*) as actual, 1 as expected
from public.drops where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK 9: block_relationship() (the intentionally public,
-- auth.uid()-scoped RPC) must remain fully functional -- unaffected
-- by moving its unrelated sibling helpers.
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
select 'CHECK9_block_relationship_still_works' as check_name,
  (case when public.block_relationship('22222222-2222-2222-2222-222222222222') = 'blocked_by_me' then 1 else 0 end) as actual,
  1 as expected;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
EOF

echo "== Loading stub + schema.sql into fresh DB '$DB_NAME' =="
dropdb_any "$DB_NAME"
if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database '$DB_NAME' (no local Postgres access?)" >&2
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

echo "== Seeding fixtures and running RLS/RPC-exposure checks =="
if ! run_psql "$DB_NAME" "$WORK_DIR/10_seed_and_assert.sql"; then
  echo "FAIL: seed/assert script errored" >&2
  cat "$WORK_DIR/psql.out" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

cat "$WORK_DIR/psql.out"

# Parse "check_name | actual | expected" result rows out of the psql
# aligned output and compare actual vs expected per row.
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
