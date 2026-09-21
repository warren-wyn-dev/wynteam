#!/usr/bin/env bash
# Regression test for WYN-186 (WYNOS Web Beta1, item 8): Activity sheet's
# unique-viewer count and ghost-account-filtered Likes/Reposts/Comments
# lists, plus the new profiles.username non-empty constraint. Mirrors
# wyn_130_club_members_ghost_accounts_test.sh's harness: loads schema.sql,
# then this feature's own migration file, then asserts under `set role
# authenticated` + a JWT sub claim.
#
#   1. drop_unique_viewer_count() counts distinct viewers, not raw view
#      events -- 3 repeat views from the same person count as 1.
#   2. drop_activity_profiles('like') excludes a ghost liker (no
#      profile_private row at all).
#   3. drop_activity_profiles('redrop') excludes a redrop from someone the
#      caller has blocked.
#   4. drop_activity_profiles('comment') returns one row per commenter
#      (deduped), not one row per comment.
#   5. drop_activity_profiles('comment') excludes a ghost commenter.
#   6. profiles.username = '' (empty string) is rejected by the new
#      constraint.
#   7. profiles.username = NULL is still allowed (legitimate
#      not-yet-onboarded state, untouched by this migration).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_130_club_members_ghost_accounts_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_186_activity_unique_views_ghost_fix_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations_wyn186_activity_unique_views_ghost_fix.sql"
DB_NAME="wyn186_activity_ghost_fix_regression_test"
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

-- alice: drop author. bob: real liker/commenter/redropper. carol: GHOST
-- liker/commenter (profiles row, no profile_private row at all -- exactly
-- what setDateOfBirth leaves behind). dave: redropper alice has blocked.
insert into auth.users (id, email) values
  ('97000000-0000-0000-0000-000000000001', 'alice@test.com'),
  ('97000000-0000-0000-0000-000000000002', 'bob@test.com'),
  ('97000000-0000-0000-0000-000000000003', 'carol@test.com'),
  ('97000000-0000-0000-0000-000000000004', 'dave@test.com');

insert into public.profiles (id, username, display_name, is_private) values
  ('97000000-0000-0000-0000-000000000001', 'alice186', 'alice', false),
  ('97000000-0000-0000-0000-000000000002', 'bob186', 'bob', false),
  ('97000000-0000-0000-0000-000000000003', null, null, false),
  ('97000000-0000-0000-0000-000000000004', 'dave186', 'dave', false);

insert into public.profile_private (id, onboarding_completed) values
  ('97000000-0000-0000-0000-000000000001', true),
  ('97000000-0000-0000-0000-000000000002', true),
  ('97000000-0000-0000-0000-000000000004', true);
-- Deliberately no row for carol (000003).

insert into public.drops (id, author_id, image_url, caption) values
  ('97000000-0000-0000-0000-0000000000d1', '97000000-0000-0000-0000-000000000001', 'https://example.com/x.jpg', 'Hello');

insert into public.blocks (blocker_id, blocked_id) values
  ('97000000-0000-0000-0000-000000000001', '97000000-0000-0000-0000-000000000004');

-- CHECK1 fixture: bob views the drop 3 times.
insert into public.drop_views (drop_id, viewer_id) values
  ('97000000-0000-0000-0000-0000000000d1', '97000000-0000-0000-0000-000000000002'),
  ('97000000-0000-0000-0000-0000000000d1', '97000000-0000-0000-0000-000000000002'),
  ('97000000-0000-0000-0000-0000000000d1', '97000000-0000-0000-0000-000000000002');

-- CHECK2 fixture: bob (real) and carol (ghost) both like the drop.
insert into public.drop_likes (drop_id, user_id) values
  ('97000000-0000-0000-0000-0000000000d1', '97000000-0000-0000-0000-000000000002'),
  ('97000000-0000-0000-0000-0000000000d1', '97000000-0000-0000-0000-000000000003');

-- CHECK3 fixture: bob (not blocked) and dave (blocked by alice) both redrop.
insert into public.redrops (drop_id, redropper_id) values
  ('97000000-0000-0000-0000-0000000000d1', '97000000-0000-0000-0000-000000000002'),
  ('97000000-0000-0000-0000-0000000000d1', '97000000-0000-0000-0000-000000000004');

-- CHECK4/5 fixture: bob comments twice (dedup to 1 row), carol (ghost)
-- comments once (excluded).
insert into public.drop_comments (drop_id, author_id, text_content) values
  ('97000000-0000-0000-0000-0000000000d1', '97000000-0000-0000-0000-000000000002', 'first'),
  ('97000000-0000-0000-0000-0000000000d1', '97000000-0000-0000-0000-000000000002', 'second'),
  ('97000000-0000-0000-0000-0000000000d1', '97000000-0000-0000-0000-000000000003', 'ghost comment');

-- ------------------------------------------------------------
-- CHECK 1: drop_unique_viewer_count() counts distinct viewers (1), not
-- raw view events (3).
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '97000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select public.drop_unique_viewer_count('97000000-0000-0000-0000-0000000000d1') into v_count;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK1_unique_viewer_count_dedupes_repeat_views', v_count::text, '1');
end
$$;

-- ------------------------------------------------------------
-- CHECK 2: drop_activity_profiles('like') excludes the ghost liker.
-- ------------------------------------------------------------
do $$
declare
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '97000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select array_agg(user_id) into v_ids
  from public.drop_activity_profiles('97000000-0000-0000-0000-0000000000d1', 'like', 100);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK2a_real_liker_present',
    ('97000000-0000-0000-0000-000000000002' = any(v_ids))::text, 'true';
  insert into results select 'CHECK2b_ghost_liker_excluded',
    coalesce(('97000000-0000-0000-0000-000000000003' = any(v_ids))::text, 'false'), 'false';
end
$$;

-- ------------------------------------------------------------
-- CHECK 3: drop_activity_profiles('redrop') excludes a blocked redropper.
-- ------------------------------------------------------------
do $$
declare
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '97000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select array_agg(user_id) into v_ids
  from public.drop_activity_profiles('97000000-0000-0000-0000-0000000000d1', 'redrop', 100);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK3a_real_redropper_present',
    ('97000000-0000-0000-0000-000000000002' = any(v_ids))::text, 'true';
  insert into results select 'CHECK3b_blocked_redropper_excluded',
    coalesce(('97000000-0000-0000-0000-000000000004' = any(v_ids))::text, 'false'), 'false';
end
$$;

-- ------------------------------------------------------------
-- CHECK 4/5: drop_activity_profiles('comment') dedupes to one row per
-- commenter and excludes the ghost commenter.
-- ------------------------------------------------------------
do $$
declare
  v_rows int;
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '97000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select count(*), array_agg(user_id) into v_rows, v_ids
  from public.drop_activity_profiles('97000000-0000-0000-0000-0000000000d1', 'comment', 100);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK4_comment_rows_deduped_per_commenter', v_rows::text, '1');
  insert into results select 'CHECK5_ghost_commenter_excluded',
    coalesce(('97000000-0000-0000-0000-000000000003' = any(v_ids))::text, 'false'), 'false';
end
$$;

-- ------------------------------------------------------------
-- CHECK 6/7: profiles.username = '' rejected, NULL still allowed.
-- ------------------------------------------------------------
insert into auth.users (id, email) values
  ('97000000-0000-0000-0000-000000000099', 'empty-username@test.com'),
  ('97000000-0000-0000-0000-000000000098', 'null-username@test.com');

do $$
begin
  begin
    insert into public.profiles (id, username) values ('97000000-0000-0000-0000-000000000099', '');
    insert into results values ('CHECK6_empty_username_rejected', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK6_empty_username_rejected', 'denied', 'denied');
  end;

  begin
    insert into public.profiles (id, username) values ('97000000-0000-0000-0000-000000000098', null);
    insert into results values ('CHECK7_null_username_still_allowed', 'allowed', 'allowed');
  exception when others then
    insert into results values ('CHECK7_null_username_still_allowed', 'denied', 'allowed');
  end;
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
  echo "FAIL: migrations_wyn186_activity_unique_views_ghost_fix.sql errored while loading" >&2
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
