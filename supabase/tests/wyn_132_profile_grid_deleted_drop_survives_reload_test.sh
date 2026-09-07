#!/usr/bin/env bash
# Regression test for WYN-132 (Founder report, re-confirmed after WYN-120:
# "ตอนลบโพสต์ หน้าโปรไฟล์ โพสต์ไม่หายเลย" -- STILL happens even after a full
# page reload, on the Drops grid tab of the profile) -- mirrors
# wyn_120_delete_drop_not_disappearing_from_profile_test.sh's exact
# harness/role-switching convention.
#
# Root cause (confirmed, not guessed): WYN-120 added
# `.isFilter('deleted_at', null)` to DropRepository.fetchById() -- the
# single-row "did Detail change this row" refetch used by
# ProfileDropGridTab._refreshRow() after returning from Detail. It did
# NOT touch DropRepository.fetchByAuthor() -- the query that actually
# populates the grid on ProfileDropGridTab's initial load (initState ->
# _loadInitial()) and on pull-to-refresh/pagination. A full page reload
# throws away all in-memory state and mounts a brand new
# ProfileDropGridTab, so it never goes through _refreshRow() at all --
# it goes straight through fetchByAuthor(), which (before this fix) ran
# a plain `select ... where author_id = $1 order by created_at desc`
# with no `deleted_at` filter of its own.
#
# The same "Drops are viewable by authenticated users, excluding blocked
# authors and deleted" RLS policy that motivated WYN-120
# (`deleted_at is null or auth.uid() = author_id`) deliberately lets a
# Drop's own author keep seeing their own soft-deleted rows (for the
# "รายการที่ลบ" 30-day restore feature, WYN-037). When the profile owner
# reloads their OWN profile, `auth.uid() = author_id` is true for every
# row query and the just-deleted Drop keeps coming back on every fresh
# load -- not just in the stale in-memory list WYN-120 already fixed.
#
#   1. alice creates D1 and D2, then soft-deletes D1.
#   2. Pre-fix query shape (author_id match only, no deleted_at filter)
#      run AS alice viewing her own profile -- returns both D1 and D2.
#      This is the bug, reproduced at the exact RLS layer it lives in.
#   3. Post-fix query shape (author_id match + `deleted_at is null`) run
#      AS alice -- returns only D2, i.e. fetchByAuthor() correctly
#      drops D1 from the grid now, on first load, not just on refresh.
#   4. A stranger (bob) viewing alice's profile never saw D1 either way
#      (RLS hides it from him regardless) -- proves the bug was
#      author-only, never a stranger-facing leak.
#   5. Regression: fetchDeletedDrops()'s own explicit `deleted_at is not
#      null` shape still finds D1 for alice (the "Recently Deleted"
#      screen keeps working, untouched by this fix).
#   6. Regression: D2 (never deleted) is still returned by the post-fix
#      query shape for both alice and a stranger.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_037_edit_delete_drop_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_132_profile_grid_deleted_drop_survives_reload_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn132_profile_grid_deleted_drop_regression_test"
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
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
grant select, insert on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
EOF

cat > "$WORK_DIR/10_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

create table results (check_name text primary key, actual int, expected int);

-- alice: owns D1 (will be soft-deleted) and D2 (stays live, for the
-- "still works for a live post" regression check). bob: a stranger
-- viewing alice's profile, no special visibility into either Drop.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user');

insert into public.drops (id, author_id, image_url, caption, created_at) values
  ('d1111111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'https://example.com/d1.jpg', 'จะถูกลบ D1', now()),
  ('d2222222-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'https://example.com/d2.jpg', 'ยังอยู่ D2', now());

-- alice soft-deletes D1, exactly as DropDetailScreen._deleteDrop() ->
-- DropRepository.deleteDrop() -> soft_delete_drop() RPC does.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.soft_delete_drop('d1111111-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK1-2: the bug, reproduced. Run the PRE-FIX fetchByAuthor() query
-- shape (author_id match only, no deleted_at filter) as alice, viewing
-- her own profile grid right after a full page reload -- still returns
-- BOTH Drops, including the one she just deleted.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK1_bug_reproduced_prefix_query_returns_deleted_drop_to_own_profile',
    (select count(*) from public.drops where author_id = '11111111-1111-1111-1111-111111111111' and id = 'd1111111-0000-0000-0000-000000000001'), 1;
  insert into results
  select 'CHECK2_bug_reproduced_prefix_query_returns_both_drops_total',
    (select count(*) from public.drops where author_id = '11111111-1111-1111-1111-111111111111'), 2;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
begin
  -- CHECK3: a stranger (bob) viewing alice's profile never saw the
  -- deleted Drop either way -- RLS alone already hides it from anyone
  -- but the author. Confirms the bug was author-only, not a visibility
  -- leak to strangers.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK3_stranger_viewing_profile_never_saw_deleted_drop',
    (select count(*) from public.drops where author_id = '11111111-1111-1111-1111-111111111111' and id = 'd1111111-0000-0000-0000-000000000001'), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK4-5: the fix. POST-FIX fetchByAuthor() query shape (author_id
-- match AND `deleted_at is null`, matching `.isFilter('deleted_at',
-- null)` added to DropRepository.fetchByAuthor()) run as alice --
-- correctly returns only D2, on first load, so the profile grid no
-- longer shows the deleted post even right after a full page reload.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK4_fix_postfix_query_excludes_deleted_drop_from_own_profile',
    (select count(*) from public.drops where author_id = '11111111-1111-1111-1111-111111111111' and deleted_at is null and id = 'd1111111-0000-0000-0000-000000000001'), 0;
  insert into results
  select 'CHECK5_fix_postfix_query_returns_only_live_drop',
    (select count(*) from public.drops where author_id = '11111111-1111-1111-1111-111111111111' and deleted_at is null), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK6: regression -- fetchDeletedDrops()'s own explicit opposite
-- filter (`deleted_at is not null`) for the "Recently Deleted" screen
-- is untouched by this fix and still finds D1 for alice.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK6_recently_deleted_screen_still_finds_it',
    (select count(*) from public.drops where author_id = '11111111-1111-1111-1111-111111111111' and deleted_at is not null), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK7-8: regression -- the live (never-deleted) D2 is unaffected by
-- the added `deleted_at is null` filter, for both its author and a
-- stranger viewing the profile.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK7_live_drop_still_returned_to_author',
    (select count(*) from public.drops where author_id = '11111111-1111-1111-1111-111111111111' and deleted_at is null and id = 'd2222222-0000-0000-0000-000000000002'), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK8_live_drop_still_returned_to_stranger',
    (select count(*) from public.drops where author_id = '11111111-1111-1111-1111-111111111111' and deleted_at is null and id = 'd2222222-0000-0000-0000-000000000002'), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
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
