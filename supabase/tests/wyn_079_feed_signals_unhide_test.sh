#!/usr/bin/env bash
# Regression test for WYN-079 (Wynos V1.0.0 Beta2, item 8 -- "ไม่สนใจ
# โพสต์นี้" gets an Undo button): verifies the new "Users can delete
# their own feed signals" RLS policy on public.feed_signals (added
# alongside HomeRepository.unhideContent).
#
#   1. "me" can delete a "hide" signal row they themselves inserted.
#   2. After deleting, the row is genuinely gone (not just hidden from
#      "me"'s own SELECT) -- verified as postgres superuser.
#   3. "me" cannot delete a signal row belonging to another user
#      (stranger) -- RLS blocks it, row count unaffected, 0 rows
#      reported deleted.
#
# This is a standalone/minimal harness (just profiles + feed_signals +
# its 3 policies), not the full schema.sql -- schema.sql currently
# fails to load fresh into an empty database due to a pre-existing,
# unrelated home_feed view migration-history conflict (7 accumulated
# `create or replace view public.home_feed` statements, at least one
# pair of which reorders/renames a column in a way plain PostgreSQL
# CREATE OR REPLACE VIEW rejects -- see WYN-079 Coding Output notes,
# and .wyn/company/DECISIONS.md's WYN-071/072 P0 incidents for the
# same error class hit before in production). That is out of scope
# for this task; flagged separately for Deploy/QA to investigate.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors every other
# supabase/tests/*.sh harness in this repo).
#
# Usage:
#   bash supabase/tests/wyn_079_feed_signals_unhide_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

DB_NAME="wyn079_feed_signals_unhide_regression_test"
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
-- Same auth.uid()/auth.role() stub every other supabase/tests/*.sh
-- harness in this repo uses.
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

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end
$$;

grant usage on schema public to authenticated;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
grant execute on function auth.role() to authenticated;
grant select on auth.users to authenticated;
EOF

cat > "$WORK_DIR/01_schema.sql" <<'EOF'
-- Verbatim from supabase/schema.sql's feed_signals section (table +
-- all 3 policies), not a paraphrase -- kept in sync by hand since this
-- harness can't load schema.sql itself (see file header).
create table public.profiles (
  id uuid primary key default gen_random_uuid()
);
grant select on public.profiles to authenticated;

create table public.feed_signals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  signal_type text not null check (signal_type in ('profile_visit', 'hide', 'not_interested')),
  target_type text not null check (target_type in ('drop', 'pop', 'profile')),
  target_id uuid not null,
  created_at timestamptz not null default now()
);

alter table public.feed_signals enable row level security;

create policy "Users can view only their own feed signals"
  on public.feed_signals
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can record their own feed signals"
  on public.feed_signals
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can delete their own feed signals"
  on public.feed_signals
  for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, delete on public.feed_signals to authenticated;
EOF

cat > "$WORK_DIR/02_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'me@test.local'),
  ('00000000-0000-0000-0000-000000000002', 'stranger@test.local');

insert into public.profiles (id) values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002');

-- "me" hides a Drop.
insert into public.feed_signals (id, user_id, signal_type, target_type, target_id) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'hide', 'drop', '10000000-0000-0000-0000-000000000001');

-- "stranger" hides a different Drop -- used by CHECK3 below to prove
-- "me" can't touch it.
insert into public.feed_signals (id, user_id, signal_type, target_type, target_id) values
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'hide', 'drop', '10000000-0000-0000-0000-000000000002');

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
set request.jwt.claim.role = 'authenticated';

-- CHECK1: "me" deletes their own hide signal (mirrors
-- HomeRepository.unhideContent's exact filter shape).
delete from public.feed_signals
where user_id = '00000000-0000-0000-0000-000000000001'
  and signal_type = 'hide'
  and target_type = 'drop'
  and target_id = '10000000-0000-0000-0000-000000000001';

select 'CHECK1_own_signal_deleted_as_authenticated' as check_name, count(*) as actual, 0 as expected
from public.feed_signals
where id = '20000000-0000-0000-0000-000000000001';

-- CHECK2 (as postgres superuser below, bypassing RLS): confirm the row
-- is genuinely gone from the table, not just excluded from "me"'s own
-- SELECT by the select policy.
reset role;
select 'CHECK2_row_genuinely_gone_superuser_view' as check_name, count(*) as actual, 0 as expected
from public.feed_signals
where id = '20000000-0000-0000-0000-000000000001';

-- CHECK3: "me" attempts to delete "stranger"'s hide signal -- RLS's
-- own-row-only `using (auth.uid() = user_id)` must silently match zero
-- rows (DELETE never errors on a WHERE clause matching nothing; the
-- signal is "0 rows affected", asserted here via the row still
-- existing afterward, both as "me" and as superuser).
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
set request.jwt.claim.role = 'authenticated';

delete from public.feed_signals
where user_id = '00000000-0000-0000-0000-000000000002'
  and signal_type = 'hide'
  and target_type = 'drop'
  and target_id = '10000000-0000-0000-0000-000000000002';

reset role;
select 'CHECK3_strangers_signal_untouched' as check_name, count(*) as actual, 1 as expected
from public.feed_signals
where id = '20000000-0000-0000-0000-000000000002';
EOF

if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi
trap 'dropdb_any "$DB_NAME"; rm -rf "$WORK_DIR"' EXIT

if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then
  echo "FAIL: stub setup failed" >&2
  cat "$WORK_DIR/psql.out" >&2
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/01_schema.sql"; then
  echo "FAIL: schema setup failed" >&2
  cat "$WORK_DIR/psql.out" >&2
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/02_seed_and_assert.sql"; then
  echo "FAIL: seed/assert script errored" >&2
  cat "$WORK_DIR/psql.out" >&2
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

if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES check(s) failed"
  exit 1
fi

echo "ALL CHECKS PASSED"
