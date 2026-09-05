#!/usr/bin/env bash
# Regression test for WYN-071 (WYNOS Visual Refresh, Screen 5's
# Profile Recommendation Section backend): the new
# profile_recommendation_dismissals table and its exclusion inside
# suggested_users(). Mirrors wyn_063_unified_home_feed_test.sh's exact
# harness/role-switching convention.
#
#   1. Dismissing an account removes it from suggested_users() for the
#      dismissing user.
#   2. suggested_users() for a different user is unaffected by someone
#      else's dismissal (dismissal is per-viewer, not global).
#   3. Self-dismissal is rejected by the CHECK constraint.
#   4. RLS: a user can only see their own dismissal rows.
#   5. RLS: a user cannot insert a dismissal row as someone else.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_063_unified_home_feed_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_071_recommendation_dismissal_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn071_recommendation_dismissal_regression_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "FAIL: schema file not found at $SCHEMA_FILE" >&2
  exit 1
fi

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

alter table storage.objects enable row level security;

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
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
grant execute on function auth.role() to authenticated, anon;
grant select on auth.users to authenticated, anon;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
grant select, insert on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
EOF

cat > "$WORK_DIR/10_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

-- Seed 3 users: me (the viewer), someone-else, a-third-user.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'me@test.local'),
  ('00000000-0000-0000-0000-000000000002', 'someone_else@test.local'),
  ('00000000-0000-0000-0000-000000000003', 'a_third_user@test.local');

insert into profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001', 'me'),
  ('00000000-0000-0000-0000-000000000002', 'someone_else'),
  ('00000000-0000-0000-0000-000000000003', 'a_third_user');

-- suggested_users() now excludes an incomplete-onboarding account
-- (schema.sql's 2026-09-05 fix) -- someone_else/a_third_user need a
-- completed profile_private row so this test's own baseline still
-- holds "both suggested" the same way a real fully-onboarded account
-- would read. "me" doesn't need one: suggested_users() ranks and
-- filters candidates, never the caller's own completeness.
insert into profile_private (id, onboarding_completed) values
  ('00000000-0000-0000-0000-000000000002', true),
  ('00000000-0000-0000-0000-000000000003', true);

create table results (check_name text primary key, actual int, expected int);

-- Baseline: "me" is suggested both "someone_else" and "a_third_user"
-- before any dismissal.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
insert into results
select 'CHECK1_baseline_both_suggested', count(*), 2
from suggested_users(10);
reset role;
reset request.jwt.claim.sub;

-- "me" dismisses "someone_else".
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
insert into profile_recommendation_dismissals (user_id, dismissed_profile_id) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');

insert into results
select 'CHECK2_dismissed_excluded', count(*), 0
from suggested_users(10)
where profile_id = '00000000-0000-0000-0000-000000000002';

insert into results
select 'CHECK2b_other_still_suggested', count(*), 1
from suggested_users(10)
where profile_id = '00000000-0000-0000-0000-000000000003';
reset role;
reset request.jwt.claim.sub;

-- Someone else's suggested_users() is unaffected by "me"'s dismissal.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
insert into results
select 'CHECK3_dismissal_is_per_viewer', count(*), 1
from suggested_users(10)
where profile_id = '00000000-0000-0000-0000-000000000002';
reset role;
reset request.jwt.claim.sub;

-- Self-dismissal rejected by the CHECK constraint (see CHECK4b below
-- for the actual behavioral proof -- this block intentionally has no
-- standalone CHECK4).
do $$
begin
  begin
    set local role authenticated;
    perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
    insert into profile_recommendation_dismissals (user_id, dismissed_profile_id)
      values ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');
    raise exception 'self-dismissal should have been rejected';
  exception
    when check_violation then
      insert into results values ('CHECK4b_self_dismissal_check_violation', 1, 1);
  end;
end
$$;

-- RLS: "someone_else" cannot see "me"'s dismissal rows.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
insert into results
select 'CHECK5_rls_view_own_rows_only', count(*), 0
from profile_recommendation_dismissals;
reset role;
reset request.jwt.claim.sub;

-- RLS: "someone_else" cannot insert a dismissal row on "me"'s behalf.
do $$
begin
  begin
    set local role authenticated;
    perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
    insert into profile_recommendation_dismissals (user_id, dismissed_profile_id)
      values ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003');
    insert into results values ('CHECK6_rls_insert_as_other_blocked', 0, 1);
  exception
    when insufficient_privilege then
      insert into results values ('CHECK6_rls_insert_as_other_blocked', 1, 1);
  end;
end
$$;

select check_name, actual, expected from results order by check_name;
EOF

if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then
  echo "FAIL: stub script errored" >&2
  cat "$WORK_DIR/psql.out" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$SCHEMA_FILE"; then
  echo "FAIL: schema.sql errored while loading" >&2
  cat "$WORK_DIR/psql.out" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/10_seed_and_assert.sql"; then
  echo "FAIL: seed/assert script errored" >&2
  cat "$WORK_DIR/psql.out" >&2
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
