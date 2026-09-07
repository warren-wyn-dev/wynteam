#!/usr/bin/env bash
# Regression test for WYN-133 (requirement 7): `public.club_channel_categories`
# RLS -- any authenticated user can read a Club's categories, only that
# Club's owner/admin can create/rename/delete one, and deleting a category
# must never delete its channels (ON DELETE SET NULL on
# club_channels.category_id).
#
# See .wyn/tasks/backlog/WYN-133-club-chat-channel-navigation.md
# (requirement 7) and .wyn/docs/design/wyn-133-club-chat-channel-navigation.md.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` -- same harness as
# wyn_021_club_post_mentions_rls_test.sh (stubs the handful of
# `auth`/`storage` pieces schema.sql assumes already exist).
#
# Usage:
#   bash supabase/tests/wyn_133_club_channel_categories_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway DB.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn133_channel_categories_regression_test"
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
  ('11111111-1111-1111-1111-111111111111', 'owner@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'member@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'outsider@test.com');

insert into public.profiles (id, username, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'owner1', 'Owner'),
  ('22222222-2222-2222-2222-222222222222', 'member1', 'Member'),
  ('33333333-3333-3333-3333-333333333333', 'outsider1', 'Outsider');

-- Owner auto-membership via clubs_add_owner_membership trigger. member1
-- is approved. outsider1 has no membership row at all.
insert into public.clubs (id, name, privacy, owner_id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Club', 'public', '11111111-1111-1111-1111-111111111111');

insert into public.club_members (club_id, user_id, role, status) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'member', 'approved')
on conflict (club_id, user_id) do update set status = 'approved', role = excluded.role;

-- CHECK 1: a plain Member cannot create a category (owner/admin-only
-- insert policy).
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
set request.jwt.claim.role = 'authenticated';
do $$
begin
  begin
    insert into public.club_channel_categories (club_id, name, created_by)
    values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ทั่วไป', '22222222-2222-2222-2222-222222222222');
    raise exception 'CHECK1_FAILED: member insert should have been rejected by RLS';
  exception
    when insufficient_privilege or others then null;
  end;
end
$$;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
select 'CHECK1_member_cannot_create_category' as check_name, count(*) as actual, 0 as expected
from public.club_channel_categories where club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- CHECK 2: the Owner CAN create a category.
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
insert into public.club_channel_categories (id, club_id, name, created_by) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ฟีดแบ็กแอป', '11111111-1111-1111-1111-111111111111');
select 'CHECK2_owner_can_create_category' as check_name, count(*) as actual, 1 as expected
from public.club_channel_categories where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK 3: a total outsider (no membership row at all) can still READ
-- categories -- same "viewable by authenticated users" posture as
-- club_channels itself.
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
select 'CHECK3_outsider_can_read_category' as check_name, count(*) as actual, 1 as expected
from public.club_channel_categories where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK 4: case-insensitive duplicate category name within the same
-- Club is rejected, same shape as club_channels' own unique index.
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
do $$
begin
  begin
    insert into public.club_channel_categories (club_id, name, created_by)
    values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ฟีดแบ็กแอป', '11111111-1111-1111-1111-111111111111');
    raise exception 'CHECK4_FAILED: duplicate category name should have been rejected';
  exception
    when unique_violation then null;
  end;
end
$$;
select 'CHECK4_duplicate_category_name_rejected' as check_name, count(*) as actual, 1 as expected
from public.club_channel_categories where club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- Move the Club's default "ทั่วไป" channel (auto-created by
-- clubs_add_default_channel()) into the new category, as the Owner.
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
update public.club_channels
  set category_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  where club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK 5: a plain Member cannot delete a category (owner/admin-only
-- delete policy).
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
set request.jwt.claim.role = 'authenticated';
delete from public.club_channel_categories where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
select 'CHECK5_member_delete_had_no_effect' as check_name, count(*) as actual, 1 as expected
from public.club_channel_categories where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

-- CHECK 6 (the core requirement-7 guarantee): the Owner deletes the
-- category -- the channel that was in it must survive, with
-- category_id now null, NOT be deleted.
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
delete from public.club_channel_categories where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
select 'CHECK6_category_actually_deleted' as check_name, count(*) as actual, 0 as expected
from public.club_channel_categories where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
select 'CHECK7_channel_survived_uncategorized' as check_name, count(*) as actual, 1 as expected
from public.club_channels where club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and category_id is null;
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
