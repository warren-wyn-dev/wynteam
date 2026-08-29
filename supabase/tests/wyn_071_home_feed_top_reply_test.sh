#!/usr/bin/env bash
# Regression test for the WYNOS Home reference spec 4.10 addition of
# `top_reply` to `public.home_feed`: the single top-level comment with
# the most likes (ties broken by most recent). Mirrors
# wyn_071_home_feed_liked_by_test.sh's exact harness.
#
#   1. A Drop with one top-level comment surfaces it as top_reply.
#   2. Among several top-level comments, the one with the most likes
#      wins, not the most recent.
#   3. A reply-to-a-reply (parent_comment_id set) is never surfaced,
#      even if it has more likes than every top-level comment.
#   4. A Drop with zero comments reports top_reply as null.
#   5. A Pop's top_reply uses pop_comments/pop_comment_likes,
#      independent of drop_comments.
#   6. A ReDrop of a Drop with a top reply carries the *original*
#      Drop's top_reply through the redrop branch too.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.
#
# Usage:
#   bash supabase/tests/wyn_071_home_feed_top_reply_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn071_home_feed_top_reply_regression_test"
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
  ('00000000-0000-0000-0000-000000000002', 'otphichay@test.local'),
  ('00000000-0000-0000-0000-000000000003', 'worraa@test.local'),
  ('00000000-0000-0000-0000-000000000004', 'liker@test.local'),
  ('00000000-0000-0000-0000-000000000005', 'redropper@test.local');

insert into profiles (id, username, display_name) values
  ('00000000-0000-0000-0000-000000000001', 'author', null),
  ('00000000-0000-0000-0000-000000000002', 'otphichay', null),
  ('00000000-0000-0000-0000-000000000003', 'worraa', null),
  ('00000000-0000-0000-0000-000000000004', 'liker', null),
  ('00000000-0000-0000-0000-000000000005', 'redropper', null);

-- Drop A: 2 top-level comments (worraa's has more likes than
-- otphichay's, despite otphichay's being posted later) + 1
-- reply-to-a-reply on worraa's comment with even more likes than
-- either top-level comment. Drop B: zero comments.
insert into drops (id, author_id, image_url, caption) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000001', 'https://x/a1.jpg', 'has replies'),
  ('10000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000001', 'https://x/b1.jpg', 'no replies');

insert into pops (id, author_id, video_url, duration_seconds, view_count) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'https://x/clip.mp4', 10, 0);

insert into drop_comments (id, drop_id, author_id, text_content, created_at, parent_comment_id) values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000003', 'อยากไปด้วยยย', now() - interval '10 minutes', null),
  ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000002', 'น่ารักมาก', now() - interval '1 minute', null),
  ('40000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000004', 'a reply to a reply, should never surface', now(), '40000000-0000-0000-0000-000000000001');

insert into drop_comment_likes (comment_id, user_id) values
  ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002'),
  ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004'),
  ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005'),
  ('40000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'),
  -- The reply-to-a-reply has more likes than either top-level comment,
  -- but must never be surfaced regardless (CHECK3).
  ('40000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002'),
  ('40000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003'),
  ('40000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000005');

insert into pop_comments (id, pop_id, author_id, text_content, parent_comment_id) values
  ('50000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'pop comment', null);

-- redropper ReDrops Drop A.
insert into redrops (id, drop_id, redropper_id) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000005');

create table results (check_name text primary key, actual text, expected text);
grant select, insert on results to authenticated;

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000005';

insert into results
select 'CHECK1_has_a_top_reply', (top_reply is not null)::text, 'true'
from home_feed
where id = '10000000-0000-0000-0000-00000000000a' and redrop_id is null;

insert into results
select 'CHECK2_most_liked_top_level_comment_wins',
  top_reply->>'author_username', 'worraa'
from home_feed
where id = '10000000-0000-0000-0000-00000000000a' and redrop_id is null;

insert into results
select 'CHECK2b_top_reply_text_matches',
  top_reply->>'text', 'อยากไปด้วยยย'
from home_feed
where id = '10000000-0000-0000-0000-00000000000a' and redrop_id is null;

-- CHECK3 is implicit in CHECK2: if the reply-to-a-reply (liker's
-- account, most-liked overall) had leaked through, author_username
-- would be 'liker', not 'worraa'.
insert into results
select 'CHECK3_reply_to_reply_never_wins',
  (top_reply->>'author_username' <> 'liker')::text, 'true'
from home_feed
where id = '10000000-0000-0000-0000-00000000000a' and redrop_id is null;

insert into results
select 'CHECK4_zero_comments_reports_null', (top_reply is null)::text, 'true'
from home_feed
where id = '10000000-0000-0000-0000-00000000000b';

insert into results
select 'CHECK5_pop_top_reply_from_pop_comments',
  top_reply->>'author_username', 'otphichay'
from home_feed
where id = '20000000-0000-0000-0000-000000000001';

insert into results
select 'CHECK6_redrop_branch_carries_original_top_reply',
  top_reply->>'author_username', 'worraa'
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
