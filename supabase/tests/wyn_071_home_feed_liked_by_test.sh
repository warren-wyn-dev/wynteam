#!/usr/bin/env bash
# Regression test for the WYNOS Home reference spec 4.8 addition of
# `liked_by` to `public.home_feed`: up to 3 most-recent likers'
# {username, display_name, avatar_url}, as a jsonb array. Mirrors
# wyn_071_home_feed_image_count_test.sh's exact harness.
#
#   1. A Drop liked by 2 users reports both, most-recent-liker first.
#   2. A Drop liked by 5 users reports only the 3 most recent (capped),
#      not all 5.
#   3. A Drop with zero likes reports an empty array, not null (so
#      Dart's `(map['liked_by'] as List).map(...)` never needs a null
#      check).
#   4. A Pop's likers use pop_likes, independent of drop_likes.
#   5. A ReDrop of a liked Drop carries the *original* Drop's likers
#      through the redrop branch too (same "shows the original Drop's
#      real content" rule every other home_feed column already
#      follows for a ReDrop row).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.
#
# Usage:
#   bash supabase/tests/wyn_071_home_feed_liked_by_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn071_home_feed_liked_by_regression_test"
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
  ('00000000-0000-0000-0000-000000000002', 'liker2@test.local'),
  ('00000000-0000-0000-0000-000000000003', 'liker3@test.local'),
  ('00000000-0000-0000-0000-000000000004', 'liker4@test.local'),
  ('00000000-0000-0000-0000-000000000005', 'liker5@test.local'),
  ('00000000-0000-0000-0000-000000000006', 'liker6@test.local'),
  ('00000000-0000-0000-0000-000000000007', 'redropper@test.local');

insert into profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001', 'author'),
  ('00000000-0000-0000-0000-000000000002', 'liker2'),
  ('00000000-0000-0000-0000-000000000003', 'liker3'),
  ('00000000-0000-0000-0000-000000000004', 'liker4'),
  ('00000000-0000-0000-0000-000000000005', 'liker5'),
  ('00000000-0000-0000-0000-000000000006', 'liker6'),
  ('00000000-0000-0000-0000-000000000007', 'redropper');

-- Drop A: liked by 5 users (positions 2-6), each 1 second apart so
-- created_at ordering is deterministic. Drop B: liked by 0 users.
insert into drops (id, author_id, image_url, caption) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000001', 'https://x/a1.jpg', 'liked a lot'),
  ('10000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000001', 'https://x/b1.jpg', 'liked by no one');

insert into pops (id, author_id, video_url, duration_seconds, view_count) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'https://x/clip.mp4', 10, 0);

insert into drop_likes (drop_id, user_id, created_at) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000002', now() - interval '5 seconds'),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000003', now() - interval '4 seconds'),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000004', now() - interval '3 seconds'),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000005', now() - interval '2 seconds'),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000006', now() - interval '1 seconds');

insert into pop_likes (pop_id, user_id) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');

-- redropper ReDrops Drop A.
insert into redrops (id, drop_id, redropper_id) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000007');

create table results (check_name text primary key, actual text, expected text);
grant select, insert on results to authenticated;

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000007';

insert into results
select 'CHECK1_liked_by_is_capped_at_3',
  jsonb_array_length(liked_by)::text, '3'
from home_feed
where id = '10000000-0000-0000-0000-00000000000a' and redrop_id is null;

insert into results
select 'CHECK2_most_recent_liker_first',
  liked_by->0->>'username', 'liker6'
from home_feed
where id = '10000000-0000-0000-0000-00000000000a' and redrop_id is null;

insert into results
select 'CHECK3_zero_likes_reports_empty_array_not_null',
  liked_by::text, '[]'
from home_feed
where id = '10000000-0000-0000-0000-00000000000b';

insert into results
select 'CHECK4_pop_likers_from_pop_likes_not_drop_likes',
  jsonb_array_length(liked_by)::text, '1'
from home_feed
where id = '20000000-0000-0000-0000-000000000001';

insert into results
select 'CHECK5_redrop_branch_carries_original_liked_by',
  jsonb_array_length(liked_by)::text, '3'
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
