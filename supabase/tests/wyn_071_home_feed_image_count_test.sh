#!/usr/bin/env bash
# Regression test for the WYN-071 follow-up that adds `image_count` to
# `public.home_feed` (WYNOS Home reference spec, section 4.7's inline
# multi-image carousel). Mirrors wyn_071_multi_image_drop_test.sh's
# exact harness.
#
#   1. A Drop with 3 drop_images rows reports image_count = 3 in
#      home_feed.
#   2. A Drop with zero drop_images rows reports image_count = 0.
#   3. The ordinary single-image case (1 drop_images row) reports
#      image_count = 1 -- HomeFeedItem.hasMultipleImages must stay
#      false for this, exactly like before this column existed.
#   4. A Pop row always reports image_count = 0 (Pop has no images at
#      all).
#   5. A ReDrop of a multi-image Drop carries the *original* Drop's
#      image_count through the redrop branch too (same "shows the
#      original Drop's real content" rule every other home_feed column
#      already follows for a ReDrop row).
#   6. get_wynos_ranked_feed()'s row_data (the "สำหรับคุณ" tab's own
#      source) carries image_count through automatically, with no
#      changes to that function itself.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_071_multi_image_drop_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_071_home_feed_image_count_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn071_home_feed_image_count_regression_test"
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
  ('00000000-0000-0000-0000-000000000002', 'redropper@test.local');

insert into profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001', 'author'),
  ('00000000-0000-0000-0000-000000000002', 'redropper');

-- Drop A: 3 images (the carousel case). Drop B: no image at all
-- (text-only, WYN-062). Drop C: the ordinary single-image case.
insert into drops (id, author_id, image_url, caption) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000001', 'https://x/a1.jpg', 'multi-image'),
  ('10000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000001', null, 'text only'),
  ('10000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000001', 'https://x/c1.jpg', 'single image');

insert into pops (id, author_id, video_url, duration_seconds, view_count) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'https://x/clip.mp4', 10, 0);

-- schema.sql's own backfill already ran once at load time against an
-- empty drops table -- re-run it here the same way
-- wyn_071_multi_image_drop_test.sh does, to simulate real pre-existing
-- Drops picking up their position-0 row.
insert into public.drop_images (drop_id, image_url, position)
select d.id, d.image_url, 0
from public.drops d
where d.image_url is not null
  and not exists (
    select 1 from public.drop_images di where di.drop_id = d.id
  );

-- Drop A gets 2 more images (positions 1, 2) for a total of 3.
insert into drop_images (drop_id, image_url, position) values
  ('10000000-0000-0000-0000-00000000000a', 'https://x/a2.jpg', 1),
  ('10000000-0000-0000-0000-00000000000a', 'https://x/a3.jpg', 2);

-- redropper ReDrops Drop A (Standard ReDrop).
insert into redrops (id, drop_id, redropper_id) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000002');

create table results (check_name text primary key, actual int, expected int);
grant select, insert on results to authenticated;

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';

insert into results
select 'CHECK1_multi_image_drop_reports_3', image_count::int, 3
from home_feed
where id = '10000000-0000-0000-0000-00000000000a' and redrop_id is null;

insert into results
select 'CHECK2_text_only_drop_reports_0', image_count::int, 0
from home_feed
where id = '10000000-0000-0000-0000-00000000000b';

insert into results
select 'CHECK3_ordinary_single_image_drop_reports_1', image_count::int, 1
from home_feed
where id = '10000000-0000-0000-0000-00000000000c';

insert into results
select 'CHECK4_pop_always_reports_0', image_count::int, 0
from home_feed
where id = '20000000-0000-0000-0000-000000000001';

insert into results
select 'CHECK5_redrop_branch_carries_original_image_count', image_count::int, 3
from home_feed
where id = '10000000-0000-0000-0000-00000000000a' and redrop_id is not null;

-- get_wynos_ranked_feed()'s row_data must carry image_count through
-- with no changes to that function -- it just selects hf.* from
-- home_feed and hands the row back as jsonb.
insert into results
select 'CHECK6_ranked_feed_row_data_carries_image_count',
  (select count(*) from get_wynos_ranked_feed()
   where (row_data->>'id') = '10000000-0000-0000-0000-00000000000a'
     and row_data->>'redrop_id' is null
     and (row_data->>'image_count')::int = 3),
  1;

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
