#!/usr/bin/env bash
# Regression test for WYN-063 (WYNOS Unified Home Feed Algorithm V1.0's
# new SQL ranking function: get_wynos_ranked_feed()), mirroring
# wyn_041_trending_engine_test.sh's exact harness/role-switching
# convention.
#
#   1. As "me", get_wynos_ranked_feed() excludes a Drop "me" hid via
#      feed_signals (signal_type='hide') -- returns exactly the 2
#      non-hidden Drops in scope, and the hidden id never appears.
#   2. A Drop from an author "me" follows is marked is_following=true.
#   3. A Drop from a stranger author "me" never interacted with is
#      marked is_following=false and is_discovery=true.
#   4. The followed-and-liked author's Drop outranks the stranger's
#      (higher Personalized Interest + Following weight, same age).
#   5. wynos_score is never null and never negative for any row.
#   6. content_save_count() returns the true total across all users,
#      bypassing saves' own per-user RLS.
#   7. feed_signals RLS -- "me" cannot see another user's rows.
#   8. A brand-new user with zero Drops in the system gets an empty
#      result, not an error (empty candidate set).
#   9. If feed_ranking_config is emptied out entirely, the function
#      still returns a non-null wynos_score via its coalesce(...,
#      default) fallback, rather than erroring or nulling out.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_041_trending_engine_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_063_unified_home_feed_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn063_unified_home_feed_regression_test"
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
-- get_wynos_ranked_feed() and content_save_count() are plain (invoker-
-- rights) SQL functions, unlike authors_posting_blocked()'s SECURITY
-- DEFINER -- so the authenticated/anon roles need direct grants on
-- auth.uid()/auth.role()/auth.users to call them at all.
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

-- Seed 3 users: me (the viewer), followed-author, stranger-author.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'me@test.local'),
  ('00000000-0000-0000-0000-000000000002', 'followed@test.local'),
  ('00000000-0000-0000-0000-000000000003', 'stranger@test.local');

insert into profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001', 'me'),
  ('00000000-0000-0000-0000-000000000002', 'followed_author'),
  ('00000000-0000-0000-0000-000000000003', 'stranger_author');

-- "me" follows "followed_author" but not "stranger_author".
insert into follows (follower_id, following_id) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');

-- One Drop from each author, both recent.
insert into drops (id, author_id, image_url, caption, created_at) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'https://x/img1.jpg', 'from followed author', now() - interval '2 hours'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'https://x/img2.jpg', 'from stranger author', now() - interval '2 hours'),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 'https://x/img3.jpg', 'to be hidden', now() - interval '1 hour');

-- "me" likes the followed author's drop (boosts affinity + engagement).
insert into drop_likes (drop_id, user_id) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');

-- "me" hides the 3rd drop.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
insert into feed_signals (user_id, signal_type, target_type, target_id) values
  ('00000000-0000-0000-0000-000000000001', 'hide', 'drop', '10000000-0000-0000-0000-000000000003');
reset role;
reset request.jwt.claim.sub;

create table results (check_name text primary key, actual int, expected int);

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';

insert into results
select 'CHECK1_row_count_excludes_hidden', count(*), 2
from get_wynos_ranked_feed();

insert into results
select 'CHECK1_hidden_drop_absent', count(*), 0
from get_wynos_ranked_feed()
where row_data->>'id' = '10000000-0000-0000-0000-000000000003';

insert into results
select 'CHECK2_followed_author_is_following', count(*), 1
from get_wynos_ranked_feed()
where row_data->>'id' = '10000000-0000-0000-0000-000000000001'
  and is_following = true;

insert into results
select 'CHECK3_stranger_is_discovery', count(*), 1
from get_wynos_ranked_feed()
where row_data->>'id' = '10000000-0000-0000-0000-000000000002'
  and is_following = false
  and is_discovery = true;

insert into results
select 'CHECK4_followed_outranks_stranger',
  (select case when
    (select wynos_score from get_wynos_ranked_feed() where row_data->>'id' = '10000000-0000-0000-0000-000000000001')
    >
    (select wynos_score from get_wynos_ranked_feed() where row_data->>'id' = '10000000-0000-0000-0000-000000000002')
  then 1 else 0 end),
  1;

insert into results
select 'CHECK5_scores_always_valid', count(*), 0
from get_wynos_ranked_feed()
where wynos_score is null or wynos_score < 0;

reset role;
reset request.jwt.claim.sub;

insert into saves (user_id, content_type, content_id) values
  ('00000000-0000-0000-0000-000000000001', 'drop', '10000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000003', 'drop', '10000000-0000-0000-0000-000000000001');

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
insert into results
select 'CHECK6_save_count_total_not_per_user',
  (select content_save_count('10000000-0000-0000-0000-000000000001'::uuid))::int,
  2;
reset role;
reset request.jwt.claim.sub;

insert into feed_signals (user_id, signal_type, target_type, target_id) values
  ('00000000-0000-0000-0000-000000000002', 'hide', 'drop', '10000000-0000-0000-0000-000000000001');

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
insert into results
select 'CHECK7_feed_signals_rls_own_rows_only', count(*), 1
from feed_signals;
reset role;
reset request.jwt.claim.sub;

-- ===== CHECK 8: a brand-new user with zero Drops anywhere in the
-- system -- must return an empty set, not error. =====
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000099', 'lonely@test.local');
insert into profiles (id, username) values
  ('00000000-0000-0000-0000-000000000099', 'lonely_user');
delete from drops;
delete from feed_signals;

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000099';
insert into results
select 'CHECK8_empty_candidate_set_no_error', count(*), 0
from get_wynos_ranked_feed();
reset role;
reset request.jwt.claim.sub;

-- ===== CHECK 9: feed_ranking_config emptied out entirely -- must fall
-- back to the documented V1.0 defaults, not error or null out. =====
insert into drops (id, author_id, image_url, caption, created_at) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'https://x/e.jpg', 'edge case drop', now());
delete from feed_ranking_config;

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000099';
insert into results
select 'CHECK9_empty_config_falls_back', count(*), 1
from get_wynos_ranked_feed()
where wynos_score is not null;
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
