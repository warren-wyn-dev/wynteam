#!/usr/bin/env bash
# Regression test for WYN-120 (Founder report: "ตอนลบโพสต์ หน้าโปรไฟล์
# โพสต์ไม่หายเลย" -- deleting your own post leaves it on your own
# Profile grid) -- mirrors wyn_037_edit_delete_drop_test.sh's exact
# harness/role-switching convention.
#
# Root cause (confirmed, not guessed): the "Drops are viewable by
# authenticated users, excluding blocked authors and deleted" RLS
# policy on public.drops DELIBERATELY lets a Drop's own author keep
# seeing their own soft-deleted row (`deleted_at is null or auth.uid()
# = author_id`) -- this is what makes the "รายการที่ลบ" (Recently
# Deleted) restore feature (WYN-037) work at all. Every app screen
# that refreshes a single row after returning from Detail
# (ProfileDropGridTab/_refreshRow, profile_likes_tab,
# hashtag_feed_screen, etc.) uses DropRepository.fetchById(dropId),
# which -- before this fix -- ran a plain `select ... where id = $1`
# with no `deleted_at` filter of its own. When the viewer IS the
# Drop's author (the exact case of "you just deleted your own post"),
# RLS's author-exception means that query still returns the row
# instead of null, so the UI's "row missing => remove it from the
# list" logic never fires and the deleted post stays on screen
# forever (until the next full page reload/refetch).
#
# This proves the query DropRepository.fetchById() now runs (id match
# + `deleted_at is null`, mirroring `.isFilter('deleted_at', null)`
# added in app/lib/features/drop/data/drop_repository.dart) returns
# NULL for the author's own just-deleted Drop, whereas the
# pre-fix query (id match only) would have returned it -- while
# fetchDeletedDrops()'s own opposite-direction filter (`deleted_at is
# not null`), used by the "Recently Deleted" screen, keeps working
# correctly and is NOT broken by this change.
#
#   1. alice creates and then soft-deletes her own Drop D1.
#   2. Pre-fix query shape (id-only, no deleted_at filter) run AS
#      alice (the author) -- still returns the row. This is the bug,
#      reproduced at the exact RLS layer it lives in.
#   3. Post-fix query shape (id + `deleted_at is null`) run AS alice
#      -- returns zero rows, i.e. fetchById() correctly returns null
#      now, so the profile grid removes it.
#   4. A stranger (bob) already got nothing from either query shape
#      (RLS hides it from him regardless) -- proves the bug was
#      author-only, never a stranger-facing leak.
#   5. Regression: fetchDeletedDrops()'s own explicit `deleted_at is
#      not null` shape still finds D1 for alice (the "Recently
#      Deleted" screen keeps working).
#   6. Regression: a live (never-deleted) Drop D2 is still returned by
#      the post-fix query shape for both its author and a stranger.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_037_edit_delete_drop_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_120_delete_drop_not_disappearing_from_profile_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn120_delete_drop_profile_regression_test"
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
-- who never has any special visibility into either Drop.
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
-- CHECK1-2: the bug, reproduced. Run the PRE-FIX fetchById() query
-- shape (id match only, no deleted_at filter) as alice, the Drop's
-- own author -- the exact case of "you just deleted your own post
-- and are back on your own Profile".
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK1_bug_reproduced_prefix_query_still_returns_row_to_author',
    (select count(*) from public.drops where id = 'd1111111-0000-0000-0000-000000000001'), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
begin
  -- CHECK2: a stranger (bob) never saw it either way -- RLS alone
  -- already hides it from anyone but the author. Confirms the bug was
  -- author-only, not a visibility leak to strangers.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK2_stranger_never_saw_deleted_drop_either_way',
    (select count(*) from public.drops where id = 'd1111111-0000-0000-0000-000000000001'), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK3: the fix. POST-FIX fetchById() query shape (id match AND
-- `deleted_at is null`, matching `.isFilter('deleted_at', null)`
-- added to DropRepository.fetchById()) run as alice -- now correctly
-- returns nothing, so the Dart code's `if (fresh == null) remove row`
-- branch fires and the profile grid drops D1.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK3_fix_postfix_query_returns_nothing_to_author',
    (select count(*) from public.drops where id = 'd1111111-0000-0000-0000-000000000001' and deleted_at is null), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK4: regression -- fetchDeletedDrops()'s own explicit opposite
-- filter (`deleted_at is not null`) for the "Recently Deleted" screen
-- is untouched by this fix and still finds D1 for alice.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK4_recently_deleted_screen_still_finds_it',
    (select count(*) from public.drops where author_id = '11111111-1111-1111-1111-111111111111' and deleted_at is not null), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK5-6: regression -- a live (never-deleted) Drop is unaffected
-- by the added `deleted_at is null` filter, for both its author and a
-- stranger.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK5_live_drop_still_returned_to_author',
    (select count(*) from public.drops where id = 'd2222222-0000-0000-0000-000000000002' and deleted_at is null), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK6_live_drop_still_returned_to_stranger',
    (select count(*) from public.drops where id = 'd2222222-0000-0000-0000-000000000002' and deleted_at is null), 1;
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
