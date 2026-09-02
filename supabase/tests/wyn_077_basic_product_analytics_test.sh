#!/usr/bin/env bash
# Regression test for WYN-077 (Basic Product Analytics -- analytics_events
# table + admin_dashboard_metrics()'s Growth columns) -- mirrors
# wyn_050_admin_dashboard_test.sh's harness/role-switching convention
# (real `authenticated` role, not the Postgres superuser, so RLS is
# actually exercised).
#
#   1. An authenticated user can insert their own analytics_events row.
#   2. ...but cannot insert one claiming to be another user (RLS INSERT
#      policy's `auth.uid() = user_id` check).
#   3. ...and cannot read *any* row back, including their own -- there is
#      deliberately no SELECT policy at all on this table (see
#      supabase/schema.sql's WYN-077 section for why).
#   4. admin_dashboard_metrics()'s 8 new Growth columns match a hand
#      count of seeded events: signup_started_24h/signup_completed_24h/
#      signup_conversion_pct (per-user cohort, not a same-day ratio --
#      one seeded user starts without ever completing), activation_pct_24h/
#      activation_count_24h (one of two same-day completions posts a
#      Drop-equivalent core action within 24h, the other never does),
#      retention_d1_pct/retention_d7_pct (one of two users in each cohort
#      has a session_start in that cohort's day-1/day-7 window), and
#      top_sources (3 distinct source values, no ties, including the
#      null-source -> "ไม่ระบุที่มา" fallback).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.
#
# Usage:
#   bash supabase/tests/wyn_077_basic_product_analytics_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn077_basic_product_analytics_regression_test"
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
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
grant select, insert on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
EOF

cat > "$WORK_DIR/10_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

create table results (check_name text primary key, actual text, expected text);

-- e1/e2: signup_started 2-3h ago (both within the 24h started window).
-- e1 also completes (signup_completed) 100 min ago -- e2 never does.
-- e3: signup_completed 1h ago with NO signup_started row at all (an
-- OAuth-style completion this round's scope doesn't log a start for --
-- see analytics_repository.dart's doc comment) -- proves
-- signup_completed_24h counts independently of signup_started.
-- e4/e5: in the D1 retention cohort (signup_completed 60h/50h ago, both
-- inside the [48h,72h) "2-3 days ago" bucket) -- only e4 gets a
-- session_start inside its own day-1 window.
-- e6/e7: same shape for D7 (signup_completed 200h/210h ago, inside the
-- [192h,216h) "8-9 days ago" bucket) -- only e6 gets a session_start
-- inside its day-7 window.
-- e8-e11 (no profiles row needed, not used elsewhere): source-only rows
-- for the top_sources check, deliberately no count ties (tiktok x3
-- overall via e1+e2+e10, "ไม่ระบุที่มา" x2 via e9+e11, facebook x1 via e8).
-- a1: admin, calls the RPC.
insert into auth.users (id, email) values
  ('80000000-0000-0000-0000-000000000001', 'a1@test.com'),
  ('80000000-0000-0000-0000-000000000002', 'e1@test.com'),
  ('80000000-0000-0000-0000-000000000003', 'e2@test.com'),
  ('80000000-0000-0000-0000-000000000004', 'e3@test.com'),
  ('80000000-0000-0000-0000-000000000005', 'e4@test.com'),
  ('80000000-0000-0000-0000-000000000006', 'e5@test.com'),
  ('80000000-0000-0000-0000-000000000007', 'e6@test.com'),
  ('80000000-0000-0000-0000-000000000008', 'e7@test.com'),
  ('80000000-0000-0000-0000-000000000009', 'e8@test.com'),
  ('80000000-0000-0000-0000-000000000010', 'e9@test.com'),
  ('80000000-0000-0000-0000-000000000011', 'e10@test.com'),
  ('80000000-0000-0000-0000-000000000012', 'e11@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('80000000-0000-0000-0000-000000000001', 'a1', 'a1', 'admin', false),
  ('80000000-0000-0000-0000-000000000002', 'e1', 'e1', 'user', false);

-- Seeded directly as the table owner (bypasses RLS by design -- this is
-- test setup, not the thing under test; RLS itself is exercised
-- separately below under `set role authenticated`).
insert into public.analytics_events (user_id, event_type, source, created_at) values
  ('80000000-0000-0000-0000-000000000002', 'signup_started', 'tiktok', now() - interval '3 hours'),
  ('80000000-0000-0000-0000-000000000002', 'signup_completed', null, now() - interval '100 minutes'),
  ('80000000-0000-0000-0000-000000000002', 'first_core_action', null, now() - interval '90 minutes'),
  ('80000000-0000-0000-0000-000000000003', 'signup_started', 'tiktok', now() - interval '2 hours'),
  ('80000000-0000-0000-0000-000000000004', 'signup_completed', null, now() - interval '1 hour'),
  ('80000000-0000-0000-0000-000000000005', 'signup_completed', null, now() - interval '60 hours'),
  ('80000000-0000-0000-0000-000000000005', 'session_start', null, now() - interval '30 hours'),
  ('80000000-0000-0000-0000-000000000006', 'signup_completed', null, now() - interval '50 hours'),
  ('80000000-0000-0000-0000-000000000007', 'signup_completed', null, now() - interval '200 hours'),
  ('80000000-0000-0000-0000-000000000007', 'session_start', null, now() - interval '20 hours'),
  ('80000000-0000-0000-0000-000000000008', 'signup_completed', null, now() - interval '210 hours'),
  -- Deliberately outside the 24h window (but inside the 7-day
  -- top_sources window) so these don't also inflate
  -- signup_started_24h/signup_conversion_pct above -- only e1/e2 should
  -- count there.
  ('80000000-0000-0000-0000-000000000009', 'signup_started', 'facebook', now() - interval '40 hours'),
  ('80000000-0000-0000-0000-000000000010', 'signup_started', null, now() - interval '50 hours'),
  ('80000000-0000-0000-0000-000000000011', 'signup_started', 'tiktok', now() - interval '30 hours'),
  ('80000000-0000-0000-0000-000000000012', 'signup_started', null, now() - interval '60 hours');

-- ------------------------------------------------------------
-- CHECK RLS-1: an authenticated user can insert their own event.
-- ------------------------------------------------------------
do $$
declare
  v_ok bigint := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '80000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.analytics_events (user_id, event_type)
    values ('80000000-0000-0000-0000-000000000002', 'session_start');
    v_ok := 1;
  exception when others then
    v_ok := 0;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK_RLS1_insert_own_event_allowed', v_ok::text, '1';
end
$$;

-- ------------------------------------------------------------
-- CHECK RLS-2: cannot insert an event claiming to be a different user.
-- ------------------------------------------------------------
do $$
declare
  v_rejected bigint := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '80000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.analytics_events (user_id, event_type)
    values ('80000000-0000-0000-0000-000000000003', 'session_start');
  exception when others then
    v_rejected := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK_RLS2_insert_as_other_user_rejected', v_rejected::text, '1';
end
$$;

-- ------------------------------------------------------------
-- CHECK RLS-3: an authenticated user cannot read back any row, not even
-- their own -- there is no SELECT policy on this table at all.
-- ------------------------------------------------------------
do $$
declare
  v_count bigint;
begin
  set role authenticated;
  set request.jwt.claim.sub = '80000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.analytics_events;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK_RLS3_no_select_policy_returns_zero_rows', v_count::text, '0';
end
$$;

-- ------------------------------------------------------------
-- CHECK 4: admin_dashboard_metrics()'s Growth columns.
-- ------------------------------------------------------------
do $$
declare
  r record;
begin
  set role authenticated;
  set request.jwt.claim.sub = '80000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select * into r from public.admin_dashboard_metrics();
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- e1 + e2 both signup_started within 24h.
  insert into results select 'CHECK4a_signup_started_24h', r.signup_started_24h::text, '2';
  -- e1 (via its own signup_completed) + e3 (completed with no start at
  -- all) both signup_completed within 24h.
  insert into results select 'CHECK4b_signup_completed_24h', r.signup_completed_24h::text, '2';
  -- Per-user cohort of the 2 who started: only e1 ever completed -> 1/2 = 50.0.
  insert into results select 'CHECK4c_signup_conversion_pct', r.signup_conversion_pct::text, '50.0';
  -- Per-user cohort of the 2 who completed today (e1, e3): only e1 has a
  -- first_core_action within 24h of completing -> 1/2 = 50.0.
  insert into results select 'CHECK4d_activation_pct_24h', r.activation_pct_24h::text, '50.0';
  insert into results select 'CHECK4e_activation_count_24h', r.activation_count_24h::text, '1';
  -- D1 cohort (e4, e5): only e4 has a session_start in its day-1 window.
  insert into results select 'CHECK4f_retention_d1_pct', r.retention_d1_pct::text, '50.0';
  -- D7 cohort (e6, e7): only e6 has a session_start in its day-7 window.
  insert into results select 'CHECK4g_retention_d7_pct', r.retention_d7_pct::text, '50.0';
  -- jsonb_build_object's text output orders keys "count" before
  -- "source" (jsonb's own key ordering, not insertion order) -- this
  -- expected string mirrors that, not visual field order.
  insert into results select 'CHECK4h_top_sources',
    r.top_sources::text,
    '[{"count": 3, "source": "tiktok"}, {"count": 2, "source": "ไม่ระบุที่มา"}, {"count": 1, "source": "facebook"}]';
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
