#!/usr/bin/env bash
# Regression test for WYN-041 (Trending Engine v2's new SECURITY DEFINER
# RPC: authors_posting_blocked()) -- proves the core anti-manipulation/
# privacy guarantees at the database layer under the real `authenticated`
# role (not the Postgres superuser, which bypasses RLS entirely),
# mirroring wyn_040_discovery_test.sh's exact harness/role-switching
# convention.
#
#   1. An author with an active restrict (expires_at in the future, not
#      overturned) is returned.
#   2. An author with an active suspend (expires_at in the future, not
#      overturned) is returned.
#   3. An author with a permanent ban is returned.
#   4. An author whose restrict has already expired (expires_at in the
#      past) is NOT returned -- internal.is_posting_blocked()'s own
#      expiry check applies here exactly as it does everywhere else it's
#      used.
#   5. An author whose restrict was overturned by a successful appeal
#      (WYN-030's overturned_at, even though expires_at is still in the
#      future) is NOT returned.
#   6. An author with no moderation_actions row at all is NOT returned.
#   7. A completely unrelated third party (no relationship to any
#      candidate, not a moderator) still gets correct results back --
#      proves SECURITY DEFINER actually bypasses moderation_actions'
#      lack of a SELECT policy for ordinary users, rather than silently
#      seeing an empty result.
#   8. The result set contains exactly the 3 expected ids -- no extra
#      rows, no duplicates -- when all 6 candidates above are queried in
#      a single batched call.
#   9. The RPC's declared return type is exactly `TABLE(author_id uuid)`
#      -- proves no action_type/reason/reviewer_id/expires_at leaks
#      through the function signature itself (the anti-gaming return
#      shape Design decided on).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_040_discovery_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_041_trending_engine_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn041_trending_engine_regression_test"
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
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
grant select, insert on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
EOF

cat > "$WORK_DIR/10_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

create table results (check_name text primary key, actual int, expected int);

-- moderator: reviewer of every moderation_actions row below. reporter:
-- filer of every reports row below (neither identity matters for this
-- RPC -- just FK targets moderation_actions/reports require).
-- aRestricted: active restrict (expires in 3 days). aSuspended: active
-- suspend (expires in 7 days). aBanned: permanent ban. aExpired: restrict
-- whose expires_at is already in the past. aOverturned: restrict whose
-- expires_at is still in the future but overturned_at is set (WYN-030
-- successful appeal) -- must NOT be blocked despite the still-future
-- expiry. aNormal: no moderation_actions row at all. stranger: has no
-- relationship to any account above -- proves SECURITY DEFINER.
insert into auth.users (id, email) values
  ('20000000-0000-0000-0000-000000000001', 'moderator@test.com'),
  ('20000000-0000-0000-0000-000000000002', 'reporter@test.com'),
  ('20000000-0000-0000-0000-00000000000a', 'arestricted@test.com'),
  ('20000000-0000-0000-0000-00000000000b', 'asuspended@test.com'),
  ('20000000-0000-0000-0000-00000000000c', 'abanned@test.com'),
  ('20000000-0000-0000-0000-00000000000d', 'aexpired@test.com'),
  ('20000000-0000-0000-0000-00000000000e', 'aoverturned@test.com'),
  ('20000000-0000-0000-0000-00000000000f', 'anormal@test.com'),
  ('20000000-0000-0000-0000-000000000010', 'stranger@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private)
select id, split_part(email, '@', 1), split_part(email, '@', 1), 'user', false
from auth.users;

insert into public.reports (id, reporter_id, target_type, target_id, category, status) values
  ('21000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', 'user', '20000000-0000-0000-0000-00000000000a', 'spam', 'actioned'),
  ('21000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'user', '20000000-0000-0000-0000-00000000000b', 'harassment', 'actioned'),
  ('21000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 'user', '20000000-0000-0000-0000-00000000000c', 'hate', 'actioned'),
  ('21000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000002', 'user', '20000000-0000-0000-0000-00000000000d', 'spam', 'actioned'),
  ('21000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000002', 'user', '20000000-0000-0000-0000-00000000000e', 'spam', 'actioned');

insert into public.moderation_actions (id, report_id, target_user_id, reviewer_id, action_type, reason, duration_days, expires_at) values
  ('22000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-00000000000a', '20000000-0000-0000-0000-000000000001', 'restrict', 'active restrict fixture', 3, now() + interval '3 days'),
  ('22000000-0000-0000-0000-000000000002', '21000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-00000000000b', '20000000-0000-0000-0000-000000000001', 'suspend', 'active suspend fixture', 7, now() + interval '7 days'),
  ('22000000-0000-0000-0000-000000000003', '21000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-00000000000c', '20000000-0000-0000-0000-000000000001', 'ban', 'permanent ban fixture', null, null),
  ('22000000-0000-0000-0000-000000000004', '21000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-00000000000d', '20000000-0000-0000-0000-000000000001', 'restrict', 'expired restrict fixture', 1, now() - interval '1 day'),
  ('22000000-0000-0000-0000-000000000005', '21000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-00000000000e', '20000000-0000-0000-0000-000000000001', 'restrict', 'overturned restrict fixture', 3, now() + interval '3 days');

update public.moderation_actions
set overturned_at = now()
where id = '22000000-0000-0000-0000-000000000005';

-- ------------------------------------------------------------
-- CHECK 1-6, 8: authors_posting_blocked() as an ordinary authenticated
-- caller with no special relationship to any candidate (not the
-- moderator, not a target) -- proves this works for any regular user,
-- not just moderators.
-- ------------------------------------------------------------
do $$
declare
  v_ids uuid[];
  v_candidates uuid[] := array[
    '20000000-0000-0000-0000-00000000000a',
    '20000000-0000-0000-0000-00000000000b',
    '20000000-0000-0000-0000-00000000000c',
    '20000000-0000-0000-0000-00000000000d',
    '20000000-0000-0000-0000-00000000000e',
    '20000000-0000-0000-0000-00000000000f'
  ];
begin
  set role authenticated;
  set request.jwt.claim.sub = '20000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  select array_agg(author_id) into v_ids from public.authors_posting_blocked(v_candidates);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK1_active_restrict_is_blocked',
    case when '20000000-0000-0000-0000-00000000000a' = any(v_ids) then 1 else 0 end, 1;

  insert into results select 'CHECK2_active_suspend_is_blocked',
    case when '20000000-0000-0000-0000-00000000000b' = any(v_ids) then 1 else 0 end, 1;

  insert into results select 'CHECK3_permanent_ban_is_blocked',
    case when '20000000-0000-0000-0000-00000000000c' = any(v_ids) then 1 else 0 end, 1;

  insert into results select 'CHECK4_expired_restrict_is_not_blocked',
    case when '20000000-0000-0000-0000-00000000000d' = any(v_ids) then 1 else 0 end, 0;

  insert into results select 'CHECK5_overturned_restrict_is_not_blocked',
    case when '20000000-0000-0000-0000-00000000000e' = any(v_ids) then 1 else 0 end, 0;

  insert into results select 'CHECK6_normal_author_is_not_blocked',
    case when '20000000-0000-0000-0000-00000000000f' = any(v_ids) then 1 else 0 end, 0;

  insert into results select 'CHECK8_batch_result_has_exactly_3_ids',
    coalesce(array_length(v_ids, 1), 0), 3;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: a completely unrelated third party ("stranger" -- not the
-- moderator, not a target, no relationship to any candidate at all)
-- still gets the same 3 ids back -- proves SECURITY DEFINER bypasses
-- moderation_actions' lack of a SELECT policy for ordinary users.
-- ------------------------------------------------------------
do $$
declare
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '20000000-0000-0000-0000-000000000010';
  set request.jwt.claim.role = 'authenticated';
  select array_agg(author_id) into v_ids from public.authors_posting_blocked(array[
    '20000000-0000-0000-0000-00000000000a',
    '20000000-0000-0000-0000-00000000000f'
  ]::uuid[]);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK7_stranger_sees_correct_result_via_security_definer',
    case
      when '20000000-0000-0000-0000-00000000000a' = any(v_ids)
       and not ('20000000-0000-0000-0000-00000000000f' = any(v_ids))
      then 1 else 0
    end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9: declared return type exposes nothing beyond author_id -- no
-- action_type/reason/reviewer_id/expires_at leaks through the function
-- signature itself.
-- ------------------------------------------------------------
do $$
declare
  v_result text;
begin
  select pg_get_function_result('public.authors_posting_blocked(uuid[])'::regprocedure)
    into v_result;

  insert into results select 'CHECK9_returns_only_author_id',
    case when v_result = 'TABLE(author_id uuid)' then 1 else 0 end, 1;
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
