#!/usr/bin/env bash
# Regression test for the WYNOS Home reference spec 4.6 verified badge:
# `profiles.is_verified` (admin-only, guarded the same way
# platform_role already is -- WYN-029) and `home_feed.author_is_verified`.
# Mirrors wyn_071_home_feed_top_reply_test.sh's exact harness.
#
#   1. A client cannot self-verify on insert (is_verified pinned to
#      false by the INSERT policy regardless of what a raw upsert
#      sends).
#   2. A client cannot self-verify via a raw UPDATE either (the
#      before-update trigger rejects any change to is_verified).
#   3. An unrelated column (display_name) can still be updated
#      normally -- the trigger only blocks changes to is_verified
#      itself, not every update to the row.
#   4. home_feed.author_is_verified reflects a verified author
#      correctly (set directly here, simulating the admin-only SQL-
#      editor path the schema comment describes -- never through a
#      client-facing insert/update).
#   5. An unverified author reports author_is_verified = false.
#   6. The ReDrop branch carries the *original* Drop author's
#      verification status, not the redropper's.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.
#
# Usage:
#   bash supabase/tests/wyn_071_verified_badge_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn071_verified_badge_regression_test"
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

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'wynos-official@test.local'),
  ('00000000-0000-0000-0000-000000000002', 'ordinary@test.local'),
  ('00000000-0000-0000-0000-000000000003', 'redropper@test.local'),
  ('00000000-0000-0000-0000-000000000004', 'selfinsert@test.local');

insert into profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001', 'wynos'),
  ('00000000-0000-0000-0000-000000000002', 'ordinary'),
  ('00000000-0000-0000-0000-000000000003', 'redropper');

create table results (check_name text primary key, actual text, expected text);
grant select, insert on results to authenticated;

-- CHECK1: a client's own insert cannot set is_verified true, even by
-- sending it directly in the upsert payload -- the INSERT policy's
-- WITH CHECK rejects the row outright (RLS violation), it does not
-- silently coerce it to false. Mirrors wyn_029's own CHECK1 harness
-- exactly (same "set role authenticated + both jwt claims, reset at
-- the end of the block" shape) for platform_role's identical guard.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into profiles (id, username, is_verified) values
      ('00000000-0000-0000-0000-000000000004', 'selfinsert', true);
    insert into results values ('CHECK1_self_insert_verified_true_rejected', 'not blocked', 'blocked');
  exception when insufficient_privilege or others then
    insert into results values ('CHECK1_self_insert_verified_true_rejected', 'blocked', 'blocked');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK2: a client cannot self-verify via UPDATE either.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  begin
    update profiles set is_verified = true where id = '00000000-0000-0000-0000-000000000002';
    insert into results values ('CHECK2_self_update_cannot_set_verified', 'not blocked', 'blocked');
  exception when others then
    insert into results values ('CHECK2_self_update_cannot_set_verified', 'blocked', 'blocked');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK3: an unrelated column can still be updated normally by the
-- account itself -- the trigger only blocks is_verified changes.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
update profiles set display_name = 'Ordinary Person' where id = '00000000-0000-0000-0000-000000000002';
reset role;
reset request.jwt.claim.sub;

insert into results
select 'CHECK3_unrelated_column_update_still_works', display_name, 'Ordinary Person'
from profiles where id = '00000000-0000-0000-0000-000000000002';

-- Admin-only path (never through client-facing insert/update): disable
-- the guard trigger directly, same escape hatch the schema comment
-- describes, to simulate an operator actually verifying an account.
alter table public.profiles disable trigger profiles_prevent_is_verified_change;
update profiles set is_verified = true where id = '00000000-0000-0000-0000-000000000001';
alter table public.profiles enable trigger profiles_prevent_is_verified_change;

insert into drops (id, author_id, image_url, caption) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000001', 'https://x/verified.jpg', 'from a verified account'),
  ('10000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000002', 'https://x/ordinary.jpg', 'from an ordinary account');

insert into redrops (id, drop_id, redropper_id) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000003');

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';

insert into results
select 'CHECK4_verified_author_reports_true', author_is_verified::text, 'true'
from home_feed
where id = '10000000-0000-0000-0000-00000000000a' and redrop_id is null;

insert into results
select 'CHECK5_unverified_author_reports_false', author_is_verified::text, 'false'
from home_feed
where id = '10000000-0000-0000-0000-00000000000b';

insert into results
select 'CHECK6_redrop_branch_carries_original_authors_verification',
  author_is_verified::text, 'true'
from home_feed
where id = '10000000-0000-0000-0000-00000000000a' and redrop_id is not null;

reset role;
reset request.jwt.claim.sub;

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
        echo "FAIL: $name -- expected '$expected', got '$actual'"
        FAILURES=$((FAILURES + 1))
      else
        echo "PASS: $name (expected '$expected', got '$actual')"
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
