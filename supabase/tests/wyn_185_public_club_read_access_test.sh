#!/usr/bin/env bash
# Regression test for WYN-185 (WYNOS Web Beta1, item 2): a Public club must
# be readable (posts, member count) by a non-member under the real
# `authenticated` role, while a Private club and the member *roster* stay
# exactly as restricted as before. Mirrors wyn_130_club_members_ghost_accounts_test.sh's
# harness: loads schema.sql, then this feature's own migration file (not yet
# folded into schema.sql, same situation WYN-161 left conversation_wynii in),
# then asserts under `set role authenticated` + a JWT sub claim.
#
#   1. A non-member CAN see a Public club's posts.
#   2. A non-member CANNOT see a Private club's posts (unchanged).
#   3. club_member_count() returns the real count for a Public club even to
#      a non-member.
#   4. club_member_count() returns 0 for a Private club to a non-member
#      (count does not leak club size for a club they can't see into).
#   5. club_member_count() returns the real count for a Private club to an
#      approved member of it.
#   6. A non-member still CANNOT insert a club_post into a Public club
#      (read-only widening only -- posting stays members-only).
#   7. A non-member still CANNOT read raw club_members rows for a Public
#      club (the roster itself stays members-only; only the count RPC and
#      posts were widened).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_130_club_members_ghost_accounts_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_185_public_club_read_access_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations_wyn185_public_club_read_access.sql"
DB_NAME="wyn185_public_club_read_access_regression_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "FAIL: schema file not found at $SCHEMA_FILE" >&2
  exit 1
fi
if [ ! -f "$MIGRATION_FILE" ]; then
  echo "FAIL: migration file not found at $MIGRATION_FILE" >&2
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

create table results (check_name text primary key, actual text, expected text);

-- alice: owner of the Public club. bob: approved member of the Public
-- club. carol: owner of the Private club, dave: approved member of it.
-- erin: a non-member of both.
insert into auth.users (id, email) values
  ('98000000-0000-0000-0000-000000000001', 'alice@test.com'),
  ('98000000-0000-0000-0000-000000000002', 'bob@test.com'),
  ('98000000-0000-0000-0000-000000000003', 'carol@test.com'),
  ('98000000-0000-0000-0000-000000000004', 'dave@test.com'),
  ('98000000-0000-0000-0000-000000000005', 'erin@test.com');

insert into public.profiles (id, username, display_name, is_private) values
  ('98000000-0000-0000-0000-000000000001', 'alice185', 'alice', false),
  ('98000000-0000-0000-0000-000000000002', 'bob185', 'bob', false),
  ('98000000-0000-0000-0000-000000000003', 'carol185', 'carol', false),
  ('98000000-0000-0000-0000-000000000004', 'dave185', 'dave', false),
  ('98000000-0000-0000-0000-000000000005', 'erin185', 'erin', false);

insert into public.profile_private (id, onboarding_completed) values
  ('98000000-0000-0000-0000-000000000001', true),
  ('98000000-0000-0000-0000-000000000002', true),
  ('98000000-0000-0000-0000-000000000003', true),
  ('98000000-0000-0000-0000-000000000004', true),
  ('98000000-0000-0000-0000-000000000005', true);

insert into public.clubs (id, name, privacy, owner_id) values
  ('98000000-0000-0000-0000-0000000000c1', 'Public Club', 'public', '98000000-0000-0000-0000-000000000001'),
  ('98000000-0000-0000-0000-0000000000c2', 'Private Club', 'private', '98000000-0000-0000-0000-000000000003');

-- alice/carol's own (owner, approved) rows are inserted automatically by
-- the clubs_add_owner_membership trigger.
insert into public.club_members (club_id, user_id, role, status) values
  ('98000000-0000-0000-0000-0000000000c1', '98000000-0000-0000-0000-000000000002', 'member', 'approved'),
  ('98000000-0000-0000-0000-0000000000c2', '98000000-0000-0000-0000-000000000004', 'member', 'approved');

-- club_posts.channel_id is not null -- use each club's auto-created
-- "ทั่วไป" default channel (clubs_add_default_channel trigger).
insert into public.club_posts (id, club_id, channel_id, author_id, content)
select '98000000-0000-0000-0000-0000000000a1', '98000000-0000-0000-0000-0000000000c1', ch.id, '98000000-0000-0000-0000-000000000001', 'Hello Public Club'
from public.club_channels ch where ch.club_id = '98000000-0000-0000-0000-0000000000c1';
insert into public.club_posts (id, club_id, channel_id, author_id, content)
select '98000000-0000-0000-0000-0000000000a2', '98000000-0000-0000-0000-0000000000c2', ch.id, '98000000-0000-0000-0000-000000000003', 'Hello Private Club'
from public.club_channels ch where ch.club_id = '98000000-0000-0000-0000-0000000000c2';

-- ------------------------------------------------------------
-- CHECK 1: erin (non-member) CAN see the Public club's post.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '98000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.club_posts where club_id = '98000000-0000-0000-0000-0000000000c1';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK1_non_member_sees_public_club_post', v_count::text, '1');
end
$$;

-- ------------------------------------------------------------
-- CHECK 2: erin (non-member) CANNOT see the Private club's post.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '98000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.club_posts where club_id = '98000000-0000-0000-0000-0000000000c2';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK2_non_member_denied_private_club_post', v_count::text, '0');
end
$$;

-- ------------------------------------------------------------
-- CHECK 3: club_member_count() returns the real count (2: alice + bob)
-- for the Public club even to erin (non-member).
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '98000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  select public.club_member_count('98000000-0000-0000-0000-0000000000c1') into v_count;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK3_public_club_member_count_visible', v_count::text, '2');
end
$$;

-- ------------------------------------------------------------
-- CHECK 4: club_member_count() returns 0 for the Private club to erin
-- (non-member) -- no count leak for a club she can't see into.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '98000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  select public.club_member_count('98000000-0000-0000-0000-0000000000c2') into v_count;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK4_private_club_member_count_hidden_from_non_member', v_count::text, '0');
end
$$;

-- ------------------------------------------------------------
-- CHECK 5: club_member_count() returns the real count (2: carol + dave)
-- for the Private club to dave, an approved member of it.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '98000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  select public.club_member_count('98000000-0000-0000-0000-0000000000c2') into v_count;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK5_private_club_member_count_visible_to_member', v_count::text, '2');
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: erin (non-member) still CANNOT insert a club_post into the
-- Public club -- read-only widening only.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '98000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_posts (club_id, channel_id, author_id, content)
      select '98000000-0000-0000-0000-0000000000c1', ch.id, '98000000-0000-0000-0000-000000000005', 'sneaky post'
      from public.club_channels ch where ch.club_id = '98000000-0000-0000-0000-0000000000c1';
    insert into results values ('CHECK6_non_member_denied_public_club_post_insert', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK6_non_member_denied_public_club_post_insert', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: erin (non-member) still CANNOT read raw club_members rows
-- for the Public club -- the roster itself stays members-only, only the
-- count RPC and posts were widened.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '98000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.club_members where club_id = '98000000-0000-0000-0000-0000000000c1';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK7_non_member_denied_public_club_roster', v_count::text, '0');
end
$$;

-- ------------------------------------------------------------
-- CHECK 8: club_member_counts() (batched) returns both clubs for carol
-- (owner of the Private club, so she qualifies for both: Public via
-- privacy, Private via her own membership).
-- ------------------------------------------------------------
do $$
declare
  v_public int;
  v_private int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '98000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  select member_count into v_public from public.club_member_counts(array[
    '98000000-0000-0000-0000-0000000000c1'::uuid, '98000000-0000-0000-0000-0000000000c2'::uuid
  ]) where club_id = '98000000-0000-0000-0000-0000000000c1';
  select member_count into v_private from public.club_member_counts(array[
    '98000000-0000-0000-0000-0000000000c1'::uuid, '98000000-0000-0000-0000-0000000000c2'::uuid
  ]) where club_id = '98000000-0000-0000-0000-0000000000c2';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK8a_batched_count_public_club', v_public::text, '2');
  insert into results values ('CHECK8b_batched_count_private_club_own_membership', v_private::text, '2');
end
$$;

-- ------------------------------------------------------------
-- CHECK 9: club_member_counts() (batched) omits the Private club row
-- entirely for erin (non-member) -- no row, not a 0 row, but either way
-- the client-side `?? 0` fallback treats it as 0.
-- ------------------------------------------------------------
do $$
declare
  v_row_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '98000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_row_count from public.club_member_counts(array[
    '98000000-0000-0000-0000-0000000000c2'::uuid
  ]);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK9_batched_count_omits_private_club_for_non_member', v_row_count::text, '0');
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

if ! run_psql "$DB_NAME" "$MIGRATION_FILE"; then
  echo "FAIL: migrations_wyn185_public_club_read_access.sql errored while loading" >&2
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
