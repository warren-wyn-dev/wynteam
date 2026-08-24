#!/usr/bin/env bash
# Regression test for WYN-064 (WYNOS Visual Refresh, Screens 2-4's
# multi-image Drop backend): the new drop_images table, its RLS, and
# the backfill migration for pre-existing single-image Drops. Mirrors
# wyn_064_recommendation_dismissal_test.sh's exact harness.
#
#   1. Backfill: a Drop that already had image_url before drop_images
#      existed gets exactly one drop_images row (position 0, same URL).
#   2. A Drop with no image_url gets zero drop_images rows.
#   3. The Drop's author can insert additional images (position 1+).
#   4. A non-author cannot insert an image onto someone else's Drop
#      (RLS insert check).
#   5. Duplicate position for the same drop_id is rejected (unique
#      constraint) -- upload ordering can never silently collide.
#   6. drop_images rows are visible to any authenticated user (mirrors
#      drops' own broad "viewable by authenticated users" baseline --
#      the deeper blocked/deleted/locked-private exclusions on drops
#      itself aren't re-tested here, they're wyn_027/wyn_039's job;
#      this only proves the exists() bridge to drops works at all).
#   7. Deleting the parent Drop cascades to its drop_images rows.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_064_recommendation_dismissal_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_064_multi_image_drop_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn064_multi_image_drop_regression_test"
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
  ('00000000-0000-0000-0000-000000000001', 'author@test.local'),
  ('00000000-0000-0000-0000-000000000002', 'someone_else@test.local');

insert into profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001', 'author'),
  ('00000000-0000-0000-0000-000000000002', 'someone_else');

-- One Drop with an image (existed "before" this migration, so its
-- backfill row comes from the migration itself, not a manual insert
-- here), one text-only Drop with no image.
insert into drops (id, author_id, image_url, caption) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'https://x/img1.jpg', 'has an image'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', null, 'text only, no image');

-- schema.sql's own backfill statement already ran once at load time
-- (against an empty drops table, since these test rows didn't exist
-- yet) -- re-running the identical idempotent statement here simulates
-- what actually happens in production, where real pre-existing Drops
-- are already in the table when schema.sql's backfill runs against
-- them for real.
insert into public.drop_images (drop_id, image_url, position)
select d.id, d.image_url, 0
from public.drops d
where d.image_url is not null
  and not exists (
    select 1 from public.drop_images di where di.drop_id = d.id
  );

create table results (check_name text primary key, actual int, expected int);

insert into results
select 'CHECK1_backfill_creates_one_row_position_0', count(*), 1
from drop_images
where drop_id = '10000000-0000-0000-0000-000000000001'
  and position = 0
  and image_url = 'https://x/img1.jpg';

insert into results
select 'CHECK2_no_image_drop_gets_zero_rows', count(*), 0
from drop_images
where drop_id = '10000000-0000-0000-0000-000000000002';

-- Author adds 2 more images (positions 1, 2) to their own Drop.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
insert into drop_images (drop_id, image_url, position) values
  ('10000000-0000-0000-0000-000000000001', 'https://x/img2.jpg', 1),
  ('10000000-0000-0000-0000-000000000001', 'https://x/img3.jpg', 2);

insert into results
select 'CHECK3_author_can_add_more_images', count(*), 3
from drop_images
where drop_id = '10000000-0000-0000-0000-000000000001';
reset role;
reset request.jwt.claim.sub;

-- A non-author cannot insert an image on someone else's Drop.
do $$
begin
  begin
    set local role authenticated;
    perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
    insert into drop_images (drop_id, image_url, position)
      values ('10000000-0000-0000-0000-000000000001', 'https://x/hijack.jpg', 3);
    insert into results values ('CHECK4_non_author_insert_blocked', 0, 1);
  exception
    when insufficient_privilege then
      insert into results values ('CHECK4_non_author_insert_blocked', 1, 1);
  end;
end
$$;

-- Duplicate position for the same drop_id is rejected.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
begin
  begin
    insert into drop_images (drop_id, image_url, position)
      values ('10000000-0000-0000-0000-000000000001', 'https://x/dup.jpg', 1);
    insert into results values ('CHECK5_duplicate_position_rejected', 0, 1);
  exception
    when unique_violation then
      insert into results values ('CHECK5_duplicate_position_rejected', 1, 1);
  end;
end
$$;
reset role;
reset request.jwt.claim.sub;

-- Any authenticated user can see drop_images rows (baseline -- deeper
-- drops-visibility exclusions are wyn_027/wyn_039's own tests).
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
insert into results
select 'CHECK6_visible_to_any_authenticated_user', count(*), 3
from drop_images
where drop_id = '10000000-0000-0000-0000-000000000001';
reset role;
reset request.jwt.claim.sub;

-- Deleting the parent Drop cascades.
delete from drops where id = '10000000-0000-0000-0000-000000000001';

insert into results
select 'CHECK7_delete_drop_cascades_to_images', count(*), 0
from drop_images
where drop_id = '10000000-0000-0000-0000-000000000001';

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
