#!/usr/bin/env bash
# Regression test for WYN-130 (Club Members tab showing "ghost"
# accounts) -- proves club_member_profiles()'s authorization and
# ghost-account exclusion at the database layer under the real
# `authenticated` role (not the Postgres superuser, which bypasses RLS
# entirely), mirroring wyn_117_club_owner_insights_test.sh's exact
# harness.
#
#   1. An approved member sees every real (onboarded) approved member,
#      including themself.
#   2. An approved member does NOT see a ghost approved member (a
#      `profiles` row with no matching profile_private row at all --
#      exactly what AuthRepository.setDateOfBirth leaves behind when a
#      signup is abandoned before the Username step).
#   3. A ghost approved member is also excluded when the row's
#      profile_private DOES exist but onboarding_completed = false
#      (abandoned at a later onboarding step than CHECK2's fixture).
#   4. A non-member is denied entirely (status = 'approved').
#   5. The Owner (Admin-equivalent for this check) sees pending
#      requests, with the ghost pending requester excluded the same way
#      as CHECK2/CHECK3.
#   6. A plain (non-owner/admin) approved member is denied when asking
#      for status = 'pending'.
#   7. A non-member is denied for status = 'pending' too.
#   8. An invalid p_status value is rejected, even for the owner.
#   9. Pagination (p_limit/p_offset) is honoured -- a p_limit=1 call
#      returns only the oldest-joined real member.
#   10-13. club_event_attendee_profiles() (the Event attendee bottom
#      sheet's own second call site of the exact same bug): a real
#      attendee is visible, a ghost attendee (already an approved club
#      member, same fixture-shape as CHECK2) is excluded, a non-member
#      is denied, and an invalid p_status is rejected.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_117_club_owner_insights_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_130_club_members_ghost_accounts_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn130_club_ghost_members_regression_test"
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

create table results (check_name text primary key, actual text, expected text);

-- alice: club owner (auto-approved by clubs_add_owner_membership).
-- bob: real approved member, joined 2 days ago.
-- gApproved: GHOST approved member -- a `profiles` row with NO
--   profile_private row at all, exactly what AuthRepository.
--   setDateOfBirth leaves behind when a signup is abandoned before the
--   Username step ever runs (see schema.sql's own comment on this).
-- gApproved2: a second-flavour ghost -- profile_private DOES exist but
--   onboarding_completed = false (abandoned at a later onboarding step).
-- gPending: GHOST pending join requester, same no-profile_private-row
--   shape as gApproved.
-- erin: non-member.
insert into auth.users (id, email) values
  ('99000000-0000-0000-0000-000000000001', 'alice@test.com'),
  ('99000000-0000-0000-0000-000000000002', 'bob@test.com'),
  ('99000000-0000-0000-0000-000000000003', 'gapproved@test.com'),
  ('99000000-0000-0000-0000-000000000004', 'gapproved2@test.com'),
  ('99000000-0000-0000-0000-000000000005', 'gpending@test.com'),
  ('99000000-0000-0000-0000-000000000006', 'erin@test.com');

-- Ghost rows deliberately have NO username/display_name/avatar_url --
-- exactly the bare `profiles` row shape a first-onboarding-step upsert
-- leaves behind.
insert into public.profiles (id, username, display_name, is_private) values
  ('99000000-0000-0000-0000-000000000001', 'alice130', 'alice', false),
  ('99000000-0000-0000-0000-000000000002', 'bob130', 'bob', false),
  ('99000000-0000-0000-0000-000000000003', null, null, false),
  ('99000000-0000-0000-0000-000000000004', null, null, false),
  ('99000000-0000-0000-0000-000000000005', null, null, false),
  ('99000000-0000-0000-0000-000000000006', 'erin130', 'erin', false);

insert into public.profile_private (id, onboarding_completed) values
  ('99000000-0000-0000-0000-000000000001', true),
  ('99000000-0000-0000-0000-000000000002', true),
  ('99000000-0000-0000-0000-000000000004', false),
  ('99000000-0000-0000-0000-000000000006', true);
-- Deliberately no rows for gApproved/gPending (000003/000005).

insert into public.clubs (id, name, privacy, owner_id) values
  ('99000000-0000-0000-0000-0000000000c1', 'Ghost Club', 'public', '99000000-0000-0000-0000-000000000001');

-- alice's own (owner, approved) row is inserted automatically by the
-- clubs_add_owner_membership trigger above.
insert into public.club_members (club_id, user_id, role, status, created_at) values
  ('99000000-0000-0000-0000-0000000000c1', '99000000-0000-0000-0000-000000000002', 'member', 'approved', now() - interval '2 days'),
  ('99000000-0000-0000-0000-0000000000c1', '99000000-0000-0000-0000-000000000003', 'member', 'approved', now() - interval '1 day'),
  ('99000000-0000-0000-0000-0000000000c1', '99000000-0000-0000-0000-000000000004', 'member', 'approved', now() - interval '1 day'),
  ('99000000-0000-0000-0000-0000000000c1', '99000000-0000-0000-0000-000000000005', 'member', 'pending', now());

-- WYN-130 (continued): club_event_attendee_profiles() fixtures. One
-- Event in Ghost Club; bob (real) and gApproved (ghost, already an
-- approved club member -- 000003 above) both RSVP 'going'.
insert into public.club_events (id, club_id, creator_id, title, starts_at, location_type, location) values
  ('99000000-0000-0000-0000-0000000000e1', '99000000-0000-0000-0000-0000000000c1', '99000000-0000-0000-0000-000000000001', 'Ghost Meetup', now() + interval '3 days', 'online', 'https://example.com');

insert into public.club_event_rsvps (event_id, user_id, status) values
  ('99000000-0000-0000-0000-0000000000e1', '99000000-0000-0000-0000-000000000002', 'going'),
  ('99000000-0000-0000-0000-0000000000e1', '99000000-0000-0000-0000-000000000003', 'going');

-- ------------------------------------------------------------
-- CHECK 1-3: an approved member (bob) sees the real approved members
-- (alice + himself) and neither ghost flavour.
-- ------------------------------------------------------------
do $$
declare
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  select array_agg(user_id order by user_id) into v_ids
  from public.club_member_profiles('99000000-0000-0000-0000-0000000000c1', 'approved', 50, 0);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK1_real_members_present',
    (('99000000-0000-0000-0000-000000000001' = any(v_ids)) and ('99000000-0000-0000-0000-000000000002' = any(v_ids)))::text,
    'true';
  insert into results select 'CHECK2_ghost_no_profile_private_excluded',
    (not ('99000000-0000-0000-0000-000000000003' = any(v_ids)))::text, 'true';
  insert into results select 'CHECK3_ghost_onboarding_incomplete_excluded',
    (not ('99000000-0000-0000-0000-000000000004' = any(v_ids)))::text, 'true';
end
$$;

-- ------------------------------------------------------------
-- CHECK 4: a non-member (erin) is denied for status = 'approved'.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform * from public.club_member_profiles('99000000-0000-0000-0000-0000000000c1', 'approved', 50, 0);
    insert into results values ('CHECK4_non_member_denied_approved', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK4_non_member_denied_approved', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5: the Owner (alice) sees the pending request list with the
-- ghost pending requester excluded.
-- ------------------------------------------------------------
do $$
declare
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select array_agg(user_id order by user_id) into v_ids
  from public.club_member_profiles('99000000-0000-0000-0000-0000000000c1', 'pending', 50, 0);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK5_ghost_pending_excluded',
    coalesce(('99000000-0000-0000-0000-000000000005' = any(v_ids))::text, 'false'), 'false';
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: a plain approved member (bob) is denied for status =
-- 'pending' (not owner/admin).
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform * from public.club_member_profiles('99000000-0000-0000-0000-0000000000c1', 'pending', 50, 0);
    insert into results values ('CHECK6_member_denied_pending', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK6_member_denied_pending', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: a non-member (erin) is denied for status = 'pending' too.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform * from public.club_member_profiles('99000000-0000-0000-0000-0000000000c1', 'pending', 50, 0);
    insert into results values ('CHECK7_non_member_denied_pending', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK7_non_member_denied_pending', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8: an invalid p_status value is rejected, even for the owner.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform * from public.club_member_profiles('99000000-0000-0000-0000-0000000000c1', 'banned', 50, 0);
    insert into results values ('CHECK8_invalid_status_rejected', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK8_invalid_status_rejected', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9: pagination -- p_limit=1 for the approved list returns
-- exactly the oldest-joined real member. bob's row is explicitly
-- backdated 2 days (see the club_members insert above), so he is older
-- than alice's owner row (created_at = the moment `clubs` was inserted,
-- i.e. "now()" at fixture-setup time) despite being inserted second.
-- ------------------------------------------------------------
do $$
declare
  v_row record;
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count
  from public.club_member_profiles('99000000-0000-0000-0000-0000000000c1', 'approved', 1, 0);
  select * into v_row
  from public.club_member_profiles('99000000-0000-0000-0000-0000000000c1', 'approved', 1, 0);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK9a_limit_returns_one_row', v_count::text, '1';
  insert into results select 'CHECK9b_limit_returns_oldest_real_member',
    v_row.user_id::text, '99000000-0000-0000-0000-000000000002';
end
$$;

-- ------------------------------------------------------------
-- CHECK 10-13: club_event_attendee_profiles() -- same ghost exclusion
-- and permission mirroring, for the Event attendee bottom sheet.
-- ------------------------------------------------------------
do $$
declare
  v_ids uuid[];
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  select array_agg(user_id order by user_id) into v_ids
  from public.club_event_attendee_profiles('99000000-0000-0000-0000-0000000000e1', 'going');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK10_event_real_attendee_present',
    coalesce(('99000000-0000-0000-0000-000000000002' = any(v_ids))::text, 'false'), 'true';
  insert into results select 'CHECK11_event_ghost_attendee_excluded',
    (not coalesce('99000000-0000-0000-0000-000000000003' = any(v_ids), false))::text, 'true';
end
$$;

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform * from public.club_event_attendee_profiles('99000000-0000-0000-0000-0000000000e1', 'going');
    insert into results values ('CHECK12_event_non_member_denied', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK12_event_non_member_denied', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform * from public.club_event_attendee_profiles('99000000-0000-0000-0000-0000000000e1', 'bogus');
    insert into results values ('CHECK13_event_invalid_status_rejected', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK13_event_invalid_status_rejected', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
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
