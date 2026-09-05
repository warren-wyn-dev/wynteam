#!/usr/bin/env bash
# Regression test for WYN-040 (Discovery Page's 2 new SECURITY DEFINER
# RPCs: rising_profiles()/suggested_users()) -- proves the core
# security/product guarantees at the database layer under the real
# `authenticated` role (not the Postgres superuser, which bypasses RLS
# entirely), mirroring wyn_039_private_account_test.sh's exact
# harness/role-switching convention.
#
#   1.  rising_profiles() excludes the caller themself.
#   2.  rising_profiles() excludes an account the caller already follows,
#       even if it has more recent growth than everyone else.
#   3.  rising_profiles() excludes an account blocked either-way with the
#       caller.
#   4.  rising_profiles() respects p_min_followers -- an account with
#       recent growth but too few total followers is excluded by the
#       default (5), and included once p_min_followers is lowered.
#   5.  rising_profiles() only counts follows.created_at within the
#       p_days window -- an account whose followers are all older than
#       the window never appears.
#   6.  rising_profiles() ranks by in-window growth count, most first
#       (proven via p_limit=1: the higher-growth candidate wins the one
#       slot over a lower-growth one).
#   7.  A completely unrelated third party (no relationship to any
#       candidate) still gets correct ranked results from
#       rising_profiles() -- proves SECURITY DEFINER actually bypasses
#       follows' own restrictive SELECT policy (WYN-039) rather than
#       silently seeing an empty/undercounted result.
#   8.  rising_profiles() does NOT filter by mute (Product spec: Rising's
#       exclusion list is self/followed/blocked only, unlike Suggested
#       Users) -- a muted-but-otherwise-eligible account still appears.
#   9.  suggested_users() excludes the caller themself.
#   10. suggested_users() excludes an account already followed.
#   11. suggested_users() excludes an account blocked either-way.
#   12. suggested_users() excludes an account the caller has muted
#       (WYN-028) -- unlike rising_profiles() (CHECK8 above).
#   13. suggested_users() ranks by total follower count, most first
#       (proven via p_limit=1).
#   14. A third party with no relationship to any candidate still gets
#       correct ranked results from suggested_users() -- same
#       SECURITY DEFINER proof as CHECK7, for the second RPC.
#   15. Neither RPC leaks the raw ranking signal to the client -- each
#       function's declared return type is exactly `TABLE(profile_id
#       uuid)`, a single column, never a follower-growth/follower-count
#       number.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_039_private_account_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_040_discovery_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn040_discovery_regression_test"
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

-- viewer: the caller for most checks. rA: high recent growth (6 new
-- followers in-window), 6 total followers -- the expected Rising #1.
-- rB: lower recent growth (2 new followers in-window), 2 total
-- followers -- below the default p_min_followers (5). rFollowed:
-- already followed by viewer, huge in-window growth (would otherwise
-- rank #1) -- must still be excluded. rBlocked: blocked by viewer,
-- huge in-window growth -- must still be excluded. rOld: 6 followers,
-- but every single one gained 30 days ago (outside the default 7-day
-- window) -- must never appear. rMuted: muted by viewer, eligible
-- in-window growth -- proves rising_profiles() does NOT filter by mute
-- (only suggested_users() does). stranger: unrelated third party, no
-- relationship to viewer or any rX account -- proves SECURITY DEFINER.
-- sHigh/sLow: two Suggested Users candidates with different total
-- follower counts, to prove ranking order.
insert into auth.users (id, email) values
  ('10000000-0000-0000-0000-000000000001', 'viewer@test.com'),
  ('10000000-0000-0000-0000-00000000000a', 'ra@test.com'),
  ('10000000-0000-0000-0000-00000000000b', 'rb@test.com'),
  ('10000000-0000-0000-0000-00000000000c', 'rfollowed@test.com'),
  ('10000000-0000-0000-0000-00000000000d', 'rblocked@test.com'),
  ('10000000-0000-0000-0000-00000000000e', 'rold@test.com'),
  ('10000000-0000-0000-0000-00000000000f', 'rmuted@test.com'),
  ('10000000-0000-0000-0000-000000000010', 'stranger@test.com'),
  ('10000000-0000-0000-0000-000000000011', 'shigh@test.com'),
  ('10000000-0000-0000-0000-000000000012', 'slow@test.com'),
  ('10000000-0000-0000-0000-000000000013', 'sghost@test.com');

-- 6 filler followers for rA/rFollowed/rBlocked/rOld/rMuted, all created
-- "now" (within any window) unless noted otherwise -- gives every one
-- of them a real backing follower row, not just synthetic auth users.
insert into auth.users (id, email)
select gen_random_uuid(), 'filler' || gs || '@test.com'
from generate_series(1, 12) as gs;

insert into public.profiles (id, username, display_name, platform_role, is_private)
select id, split_part(email, '@', 1), split_part(email, '@', 1), 'user', false
from auth.users;

-- ------------------------------------------------------------
-- Fixture: rA -- 6 new followers, all within the 7-day window.
-- ------------------------------------------------------------
insert into public.follows (follower_id, following_id, created_at)
select id, '10000000-0000-0000-0000-00000000000a', now() - interval '1 day'
from public.profiles
where username like 'filler%'
limit 6;

-- rB -- 2 new followers, within the window (below default min_followers).
insert into public.follows (follower_id, following_id, created_at)
select id, '10000000-0000-0000-0000-00000000000b', now() - interval '1 day'
from public.profiles
where username like 'filler%'
limit 2;

-- rFollowed -- 8 new followers within the window (more than rA), but
-- viewer already follows this account.
insert into public.follows (follower_id, following_id, created_at)
select id, '10000000-0000-0000-0000-00000000000c', now() - interval '1 day'
from public.profiles
where username like 'filler%'
limit 8;
insert into public.follows (follower_id, following_id) values
  ('10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000c');

-- rBlocked -- 8 new followers within the window, but blocked by viewer.
insert into public.follows (follower_id, following_id, created_at)
select id, '10000000-0000-0000-0000-00000000000d', now() - interval '1 day'
from public.profiles
where username like 'filler%'
limit 8;
insert into public.blocks (blocker_id, blocked_id) values
  ('10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000d');

-- rOld -- 6 total followers, but every one gained 30 days ago (outside
-- the default 7-day window).
insert into public.follows (follower_id, following_id, created_at)
select id, '10000000-0000-0000-0000-00000000000e', now() - interval '30 days'
from public.profiles
where username like 'filler%'
limit 6;

-- rMuted -- 3 new followers within the window (deliberately fewer than
-- rA's 6, so CHECK6's ranking assertion has a single unambiguous
-- winner -- rMuted is only meant to prove "still appears despite being
-- muted" (CHECK8), not to compete for the top rank), and muted by
-- viewer.
insert into public.follows (follower_id, following_id, created_at)
select id, '10000000-0000-0000-0000-00000000000f', now() - interval '1 day'
from public.profiles
where username like 'filler%'
limit 3;
insert into public.mutes (muter_id, muted_id) values
  ('10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000f');

-- Suggested Users fixtures: sHigh has 9 total followers -- deliberately
-- more than every other candidate viewer is still eligible to see
-- (rA/rOld both have 6), so CHECK13's ranking assertion also has a
-- single unambiguous winner. Backdated outside the 7-day window (like
-- rOld) so sHigh's own follower count doesn't *also* make it eligible
-- for rising_profiles() -- suggested_users() ranks by total followers
-- regardless of when they were gained, so this doesn't affect CHECK13
-- at all, but keeps the two RPCs' fixtures from bleeding into each
-- other. sLow has 1 (recent, but still far below sHigh either way).
insert into public.follows (follower_id, following_id, created_at)
select id, '10000000-0000-0000-0000-000000000011', now() - interval '30 days'
from public.profiles
where username like 'filler%'
limit 9;
insert into public.follows (follower_id, following_id, created_at)
select id, '10000000-0000-0000-0000-000000000012', now() - interval '1 day'
from public.profiles
where username like 'filler%'
limit 1;

-- suggested_users() now excludes an incomplete-onboarding account (a
-- `profiles` row with no matching profile_private.onboarding_completed
-- = true -- see schema.sql's appended fix, 2026-09-05). sHigh/sLow
-- stand in for real, fully-onboarded accounts for CHECK13/CHECK14, so
-- they need that row same as any account past the Username step really
-- would; every rising_profiles()-only fixture above (rA/rB/rFollowed/
-- rBlocked/rOld/rMuted/stranger) is untouched by that filter and
-- deliberately left without one.
insert into public.profile_private (id, onboarding_completed) values
  ('10000000-0000-0000-0000-000000000011', true),
  ('10000000-0000-0000-0000-000000000012', true);

-- sGhost -- the regression fixture for the 2026-09-05 fix itself: a
-- `profiles` row exactly like one AuthRepository.setDateOfBirth creates
-- on the very first onboarding step, abandoned before Username ever
-- ran -- no profile_private row at all (not even one with
-- onboarding_completed = false; a real abandoned signup never reaches
-- the point of creating that row either, since Birthday is the step
-- that upserts `profiles` and Username is what runs after). Given all
-- 12 available filler followers -- deliberately more than sHigh's 9 --
-- so CHECK16 actually proves exclusion, not just "wasn't ranked #1
-- anyway". Backdated outside the 7-day window, same reasoning and same
-- pattern as sHigh's own fixture comment above: suggested_users() ranks
-- by total followers regardless of when gained, so this doesn't blunt
-- CHECK16 at all, but it keeps sGhost's 12 followers from also reading
-- as this month's single biggest *rising* profile and stealing CHECK6's
-- #1 growth spot out from under rA.
insert into public.follows (follower_id, following_id, created_at)
select id, '10000000-0000-0000-0000-000000000013', now() - interval '30 days'
from public.profiles
where username like 'filler%'
limit 12;

-- ------------------------------------------------------------
-- CHECK 1-3, 5, 8: rising_profiles(), default params, as viewer.
-- ------------------------------------------------------------
do $$
declare
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '10000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select array_agg(profile_id) into v_ids from public.rising_profiles(20, 7, 1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK1_rising_excludes_self',
    case when '10000000-0000-0000-0000-000000000001' = any(v_ids) then 1 else 0 end, 0;

  insert into results select 'CHECK2_rising_excludes_already_followed',
    case when '10000000-0000-0000-0000-00000000000c' = any(v_ids) then 1 else 0 end, 0;

  insert into results select 'CHECK3_rising_excludes_blocked',
    case when '10000000-0000-0000-0000-00000000000d' = any(v_ids) then 1 else 0 end, 0;

  insert into results select 'CHECK5_rising_excludes_growth_outside_window',
    case when '10000000-0000-0000-0000-00000000000e' = any(v_ids) then 1 else 0 end, 0;

  insert into results select 'CHECK8_rising_does_not_exclude_muted',
    case when '10000000-0000-0000-0000-00000000000f' = any(v_ids) then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 4: p_min_followers filtering.
-- ------------------------------------------------------------
do $$
declare
  v_ids_default uuid[];
  v_ids_lowered uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '10000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  -- Default p_min_followers (5) -- rB has only 2 total followers.
  select array_agg(profile_id) into v_ids_default from public.rising_profiles();
  select array_agg(profile_id) into v_ids_lowered from public.rising_profiles(20, 7, 1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK4a_min_followers_excludes_below_default',
    case when '10000000-0000-0000-0000-00000000000b' = any(v_ids_default) then 1 else 0 end, 0;

  insert into results select 'CHECK4b_min_followers_includes_once_lowered',
    case when '10000000-0000-0000-0000-00000000000b' = any(v_ids_lowered) then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: ranking order -- p_limit=1 must return rA (6 in-window
-- followers), not rB (2), since rFollowed/rBlocked (higher growth) are
-- excluded from viewer's own results by CHECK2/CHECK3 above.
-- ------------------------------------------------------------
do $$
declare
  v_top uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '10000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select profile_id into v_top from public.rising_profiles(1, 7, 1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK6_rising_ranks_by_growth_desc',
    case when v_top = '10000000-0000-0000-0000-00000000000a' then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: a completely unrelated third party ("stranger") still gets
-- rA back from rising_profiles() -- proves SECURITY DEFINER bypasses
-- follows' own restrictive SELECT policy (WYN-039) rather than seeing
-- an empty/undercounted result. stranger has no relationship to rA or
-- any of rA's followers at all.
-- ------------------------------------------------------------
do $$
declare
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '10000000-0000-0000-0000-000000000010';
  set request.jwt.claim.role = 'authenticated';
  select array_agg(profile_id) into v_ids from public.rising_profiles(20, 7, 1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK7_stranger_sees_rising_via_security_definer',
    case when '10000000-0000-0000-0000-00000000000a' = any(v_ids) then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9-12: suggested_users(), as viewer.
-- ------------------------------------------------------------
do $$
declare
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '10000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select array_agg(profile_id) into v_ids from public.suggested_users(50);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK9_suggested_excludes_self',
    case when '10000000-0000-0000-0000-000000000001' = any(v_ids) then 1 else 0 end, 0;

  insert into results select 'CHECK10_suggested_excludes_already_followed',
    case when '10000000-0000-0000-0000-00000000000c' = any(v_ids) then 1 else 0 end, 0;

  insert into results select 'CHECK11_suggested_excludes_blocked',
    case when '10000000-0000-0000-0000-00000000000d' = any(v_ids) then 1 else 0 end, 0;

  insert into results select 'CHECK12_suggested_excludes_muted',
    case when '10000000-0000-0000-0000-00000000000f' = any(v_ids) then 1 else 0 end, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 13: ranking order -- p_limit=1 must return sHigh (5 followers)
-- over sLow (1 follower).
-- ------------------------------------------------------------
do $$
declare
  v_top uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '10000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select profile_id into v_top from public.suggested_users(1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK13_suggested_ranks_by_follower_count_desc',
    case when v_top = '10000000-0000-0000-0000-000000000011' then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 14: stranger (unrelated third party) still gets sHigh back from
-- suggested_users() -- same SECURITY DEFINER proof as CHECK7.
-- ------------------------------------------------------------
do $$
declare
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '10000000-0000-0000-0000-000000000010';
  set request.jwt.claim.role = 'authenticated';
  select array_agg(profile_id) into v_ids from public.suggested_users(50);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK14_stranger_sees_suggested_via_security_definer',
    case when '10000000-0000-0000-0000-000000000011' = any(v_ids) then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 16 (2026-09-05 fix): sGhost has more followers than every
-- other suggested_users() candidate here (12, vs. sHigh's 9) and would
-- win p_limit=1 outright if the fix didn't exclude it -- proves the fix
-- by ranking, not just by presence/absence in a big list.
-- ------------------------------------------------------------
do $$
declare
  v_top uuid;
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '10000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select profile_id into v_top from public.suggested_users(1);
  select array_agg(profile_id) into v_ids from public.suggested_users(50);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK16a_suggested_excludes_incomplete_onboarding_from_top',
    case when v_top = '10000000-0000-0000-0000-000000000013' then 1 else 0 end, 0;

  insert into results select 'CHECK16b_suggested_excludes_incomplete_onboarding_entirely',
    case when '10000000-0000-0000-0000-000000000013' = any(v_ids) then 1 else 0 end, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 15: neither RPC's declared return type exposes anything beyond
-- profile_id -- no raw follower-growth/follower-count number leaks
-- through the function signature itself.
-- ------------------------------------------------------------
do $$
declare
  v_rising_result text;
  v_suggested_result text;
begin
  select pg_get_function_result('public.rising_profiles(int,int,int)'::regprocedure)
    into v_rising_result;
  select pg_get_function_result('public.suggested_users(int)'::regprocedure)
    into v_suggested_result;

  insert into results select 'CHECK15a_rising_profiles_returns_only_profile_id',
    case when v_rising_result = 'TABLE(profile_id uuid)' then 1 else 0 end, 1;

  insert into results select 'CHECK15b_suggested_users_returns_only_profile_id',
    case when v_suggested_result = 'TABLE(profile_id uuid)' then 1 else 0 end, 1;
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
