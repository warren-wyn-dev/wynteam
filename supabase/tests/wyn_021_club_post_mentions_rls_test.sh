#!/usr/bin/env bash
# Regression test for WYN-021: verify `public.club_post_mentions`'s
# `select` RLS policy is gated by club membership, matching its
# sibling tables (`club_posts`/`club_post_likes`/`club_post_comments`)
# -- not `using (true)`.
#
# Background: this policy originally shipped as `using (true)`,
# letting *any* authenticated user read a private Club post's id and
# who was mentioned in it, even with zero membership (not even
# `pending`). See `.wyn/tasks/bugs/WYN-021-club-post-mentions-rls-gap.md`
# for the full writeup. This script is the first persisted,
# re-runnable live-Postgres RLS regression test in this project (see
# `.wyn/learning/IMPROVEMENTS.md`'s 2026-08-16 entry -- prior RLS
# verification against real Postgres was always a manual, throwaway
# step). Run it any time `club_post_mentions`, `club_posts`, or
# `club_role()` change.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (this sandbox has no
# Supabase platform, so we stub the handful of `auth`/`storage`
# pieces `schema.sql` assumes already exist -- mirrors the harness
# used by WYN-021's QA round 1 and this bug's own reproduction).
#
# Usage:
#   bash supabase/tests/wyn_021_club_post_mentions_rls_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway DB.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn021_rls_regression_test"
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
\set ON_ERROR_STOP on
\pset pager off

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'clubowner@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'author@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'outsider@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'mentioned@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'member2@test.com');

insert into public.profiles (id, username, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'clubowner', 'Club Owner'),
  ('22222222-2222-2222-2222-222222222222', 'author', 'Author'),
  ('33333333-3333-3333-3333-333333333333', 'outsider', 'Outsider'),
  ('44444444-4444-4444-4444-444444444444', 'mentioned', 'Mentioned'),
  ('55555555-5555-5555-5555-555555555555', 'member2', 'Member Two');

-- Private Club: clubowner is Owner (auto-membership via trigger),
-- author + member2 are approved members, outsider has NO membership
-- row at all (not even pending).
insert into public.clubs (id, name, privacy, owner_id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Private Club', 'private', '11111111-1111-1111-1111-111111111111');

insert into public.club_members (club_id, user_id, role, status) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'member', 'approved'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '55555555-5555-5555-5555-555555555555', 'member', 'approved')
on conflict (club_id, user_id) do update set status = 'approved', role = excluded.role;

insert into public.club_posts (id, club_id, author_id, content) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'Hello @mentioned');

insert into public.club_post_mentions (club_post_id, mentioned_user_id) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '44444444-4444-4444-4444-444444444444');

insert into public.drops (id, author_id, image_url) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '22222222-2222-2222-2222-222222222222', 'https://example.com/x.jpg');
insert into public.drop_mentions (drop_id, mentioned_user_id) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '44444444-4444-4444-4444-444444444444');

-- CHECK 1: outsider (zero membership, not even pending) must NOT see
-- the private Club post at all -- sanity control proving RLS is
-- actually engaged in this harness.
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
select 'CHECK1_outsider_club_posts' as check_name, count(*) as actual, 0 as expected
from public.club_posts where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

-- CHECK 2 (the WYN-021 regression itself): outsider must NOT see the
-- private Club post's mentions either -- this is 1 (bug present) on
-- the pre-fix `using (true)` policy, 0 (fixed) afterwards.
select 'CHECK2_outsider_club_post_mentions' as check_name, count(*) as actual, 0 as expected
from public.club_post_mentions where club_post_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK 3: the post's own author (approved member) must still see
-- their own mention row -- the fix must not over-tighten.
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
set request.jwt.claim.role = 'authenticated';
select 'CHECK3_author_club_post_mentions' as check_name, count(*) as actual, 1 as expected
from public.club_post_mentions where club_post_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK 4: a second approved member (not the author, not the
-- mentioned user) must also still see it -- matches
-- club_post_comments' "any approved member can view" semantics.
set role authenticated;
set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
set request.jwt.claim.role = 'authenticated';
select 'CHECK4_member2_club_post_mentions' as check_name, count(*) as actual, 1 as expected
from public.club_post_mentions where club_post_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK 5 (no-regression control): drop_mentions must remain
-- `using (true)` and unaffected -- drops have no privacy boundary, so
-- even a total outsider legitimately sees them.
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
select 'CHECK5_outsider_drop_mentions' as check_name, count(*) as actual, 1 as expected
from public.drop_mentions where drop_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
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

echo "== Seeding fixtures and running RLS checks =="
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
