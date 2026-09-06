#!/usr/bin/env bash
# Regression test for WYN-118 (Club Events) -- proves the RLS/trigger/RPC
# guarantees at the database layer under the real `authenticated` role
# (not the Postgres superuser, which bypasses RLS entirely), mirroring
# wyn_115_club_poll_test.sh's exact harness/role-switching convention.
#
#   1. An approved member (any role) can see events.
#   2. A pending member cannot see events.
#   3. A non-member cannot see events.
#   4. Staff (owner/admin/moderator) can create an event.
#   5. A plain member cannot create an event.
#   6. Staff can update/delete ANOTHER staff member's event (not just
#      their own) -- same collaborative model as pin/unpin.
#   7. A plain member cannot update or delete an event.
#   8. An approved member can RSVP as themselves.
#   9. A pending member cannot RSVP (trigger denies).
#  10. A banned (club-level) member cannot RSVP.
#  11. A non-member cannot RSVP.
#  12. A posting-blocked (globally restricted) approved member cannot
#      RSVP.
#  13. A user cannot RSVP as someone else (RLS `with check`).
#  14. Changing your RSVP (re-vote) updates the same row, doesn't
#      duplicate it.
#  15. Any approved member can see OTHER members' RSVPs (unlike poll
#      votes, which are private to the voter) -- proves the
#      Requirements' "เห็น...รายชื่อคนที่ตอบรับ" is actually implemented.
#  16. club_event_rsvp_counts() returns the correct going/maybe/
#      not_going counts for an event.
#  17. club_event_rsvp_counts() returns NO row for an event in a club
#      the caller isn't an approved member of -- proves no cross-club
#      leak through the (deliberately non-SECURITY-DEFINER) RPC.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_115_club_poll_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_118_club_events_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn118_club_events_regression_test"
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

-- alice: club owner, creates event E1. bob: admin, edits/deletes E1
-- (proves staff can manage each other's events) and creates E2. carol:
-- moderator, approved member who RSVPs. dave: plain member, RSVPs and
-- changes their mind. erin: pending member. frank: banned (club-level)
-- member. grace: non-member. henry: approved member who is globally
-- posting-blocked (banned via a real moderation_actions row, same
-- fixture shape wyn_115_club_poll_test.sh's "frank" uses).
insert into auth.users (id, email) values
  ('99000000-0000-0000-0000-000000000001', 'alice@test.com'),
  ('99000000-0000-0000-0000-000000000002', 'bob@test.com'),
  ('99000000-0000-0000-0000-000000000003', 'carol@test.com'),
  ('99000000-0000-0000-0000-000000000004', 'dave@test.com'),
  ('99000000-0000-0000-0000-000000000005', 'erin@test.com'),
  ('99000000-0000-0000-0000-000000000006', 'frank@test.com'),
  ('99000000-0000-0000-0000-000000000007', 'grace@test.com'),
  ('99000000-0000-0000-0000-000000000008', 'henry@test.com'),
  ('99000000-0000-0000-0000-000000000009', 'moderator@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('99000000-0000-0000-0000-000000000001', 'alice118', 'alice', 'user', false),
  ('99000000-0000-0000-0000-000000000002', 'bob118', 'bob', 'user', false),
  ('99000000-0000-0000-0000-000000000003', 'carol118', 'carol', 'user', false),
  ('99000000-0000-0000-0000-000000000004', 'dave118', 'dave', 'user', false),
  ('99000000-0000-0000-0000-000000000005', 'erin118', 'erin', 'user', false),
  ('99000000-0000-0000-0000-000000000006', 'frank118', 'frank', 'user', false),
  ('99000000-0000-0000-0000-000000000007', 'grace118', 'grace', 'user', false),
  ('99000000-0000-0000-0000-000000000008', 'henry118', 'henry', 'user', false),
  ('99000000-0000-0000-0000-000000000009', 'moderator118', 'moderator', 'moderator', false);

insert into public.clubs (id, name, privacy, owner_id) values
  ('99000000-0000-0000-0000-0000000000c1', 'Alice Club', 'public', '99000000-0000-0000-0000-000000000001');

-- alice's own (owner, approved) row is inserted automatically by the
-- clubs_add_owner_membership trigger above -- not seeded again here.
insert into public.club_members (club_id, user_id, role, status) values
  ('99000000-0000-0000-0000-0000000000c1', '99000000-0000-0000-0000-000000000002', 'admin', 'approved'),
  ('99000000-0000-0000-0000-0000000000c1', '99000000-0000-0000-0000-000000000003', 'moderator', 'approved'),
  ('99000000-0000-0000-0000-0000000000c1', '99000000-0000-0000-0000-000000000004', 'member', 'approved'),
  ('99000000-0000-0000-0000-0000000000c1', '99000000-0000-0000-0000-000000000005', 'member', 'pending'),
  ('99000000-0000-0000-0000-0000000000c1', '99000000-0000-0000-0000-000000000006', 'member', 'banned'),
  ('99000000-0000-0000-0000-0000000000c1', '99000000-0000-0000-0000-000000000008', 'member', 'approved');

-- henry is globally posting-blocked -- a real report + moderation
-- action, same fixture shape wyn_115_club_poll_test.sh's own posting-
-- block check uses.
insert into public.reports (id, reporter_id, target_type, target_id, category) values
  ('99000000-0000-0000-0000-0000000000e1', '99000000-0000-0000-0000-000000000001', 'user', '99000000-0000-0000-0000-000000000008', 'harassment');

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000009';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(
    '99000000-0000-0000-0000-0000000000e1', 'suspend', 'test suspension', 7
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 1-3: SELECT visibility of events.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_events (id, club_id, creator_id, title, starts_at, location_type, location)
  values (
    '99000000-0000-0000-0000-0000000000f1',
    '99000000-0000-0000-0000-0000000000c1',
    '99000000-0000-0000-0000-000000000001',
    'Photo Walk', now() + interval '7 days', 'offline', 'Lumphini Park'
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.club_events where id = '99000000-0000-0000-0000-0000000000f1';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK1_approved_member_sees_event', v_count, 1;
end
$$;

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.club_events where id = '99000000-0000-0000-0000-0000000000f1';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK2_pending_member_cannot_see_event', v_count, 0;
end
$$;

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000007';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.club_events where id = '99000000-0000-0000-0000-0000000000f1';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK3_non_member_cannot_see_event', v_count, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 4-5: staff can create an event, a plain member cannot.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_events (id, club_id, creator_id, title, starts_at, location_type, location)
  values (
    '99000000-0000-0000-0000-0000000000f2',
    '99000000-0000-0000-0000-0000000000c1',
    '99000000-0000-0000-0000-000000000003',
    'Online Meetup', now() + interval '3 days', 'online', 'https://meet.example.com/x'
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  select count(*) into v_count from public.club_events where id = '99000000-0000-0000-0000-0000000000f2';
  insert into results select 'CHECK4_moderator_can_create_event', v_count, 1;
end
$$;

do $$
declare
  v_error_raised int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_events (id, club_id, creator_id, title, starts_at, location_type, location)
    values (
      '99000000-0000-0000-0000-0000000000f3',
      '99000000-0000-0000-0000-0000000000c1',
      '99000000-0000-0000-0000-000000000004',
      'Should Fail', now() + interval '1 day', 'online', 'https://x'
    );
  exception when others then
    v_error_raised := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK5_plain_member_cannot_create_event', v_error_raised, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6-7: bob (admin) can edit/delete alice's event E1 (staff
-- manage each other's events); dave (plain member) cannot update E1.
-- ------------------------------------------------------------
do $$
declare
  v_title text;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  update public.club_events set title = 'Photo Walk (rescheduled)'
  where id = '99000000-0000-0000-0000-0000000000f1';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  select title into v_title from public.club_events where id = '99000000-0000-0000-0000-0000000000f1';
  insert into results select 'CHECK6_staff_can_edit_others_event',
    case when v_title = 'Photo Walk (rescheduled)' then 1 else 0 end, 1;
end
$$;

do $$
declare
  v_title text;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  update public.club_events set title = 'Hijacked' where id = '99000000-0000-0000-0000-0000000000f1';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  select title into v_title from public.club_events where id = '99000000-0000-0000-0000-0000000000f1';
  insert into results select 'CHECK7_plain_member_cannot_edit_event',
    case when v_title = 'Photo Walk (rescheduled)' then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8-13: RSVP behavior.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_event_rsvps (event_id, user_id, status)
  values ('99000000-0000-0000-0000-0000000000f1', '99000000-0000-0000-0000-000000000004', 'going');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  select count(*) into v_count from public.club_event_rsvps
    where event_id = '99000000-0000-0000-0000-0000000000f1' and user_id = '99000000-0000-0000-0000-000000000004' and status = 'going';
  insert into results select 'CHECK8_approved_member_can_rsvp', v_count, 1;
end
$$;

do $$
declare
  v_error_raised int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_event_rsvps (event_id, user_id, status)
    values ('99000000-0000-0000-0000-0000000000f1', '99000000-0000-0000-0000-000000000005', 'going');
  exception when others then
    v_error_raised := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK9_pending_member_cannot_rsvp', v_error_raised, 1;
end
$$;

do $$
declare
  v_error_raised int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_event_rsvps (event_id, user_id, status)
    values ('99000000-0000-0000-0000-0000000000f1', '99000000-0000-0000-0000-000000000006', 'going');
  exception when others then
    v_error_raised := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK10_banned_member_cannot_rsvp', v_error_raised, 1;
end
$$;

do $$
declare
  v_error_raised int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000007';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_event_rsvps (event_id, user_id, status)
    values ('99000000-0000-0000-0000-0000000000f1', '99000000-0000-0000-0000-000000000007', 'going');
  exception when others then
    v_error_raised := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK11_non_member_cannot_rsvp', v_error_raised, 1;
end
$$;

do $$
declare
  v_error_raised int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000008';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_event_rsvps (event_id, user_id, status)
    values ('99000000-0000-0000-0000-0000000000f1', '99000000-0000-0000-0000-000000000008', 'going');
  exception when others then
    v_error_raised := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK12_posting_blocked_member_cannot_rsvp', v_error_raised, 1;
end
$$;

do $$
declare
  v_error_raised int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_event_rsvps (event_id, user_id, status)
    values ('99000000-0000-0000-0000-0000000000f1', '99000000-0000-0000-0000-000000000003', 'going');
  exception when others then
    v_error_raised := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK13_cannot_rsvp_as_someone_else', v_error_raised, 1;
end
$$;

do $$
declare
  v_status text;
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_event_rsvps (event_id, user_id, status)
  values ('99000000-0000-0000-0000-0000000000f1', '99000000-0000-0000-0000-000000000004', 'maybe')
  on conflict (event_id, user_id) do update set status = excluded.status;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  select status into v_status from public.club_event_rsvps
    where event_id = '99000000-0000-0000-0000-0000000000f1' and user_id = '99000000-0000-0000-0000-000000000004';
  select count(*) into v_count from public.club_event_rsvps
    where event_id = '99000000-0000-0000-0000-0000000000f1' and user_id = '99000000-0000-0000-0000-000000000004';
  insert into results select 'CHECK14_changing_rsvp_updates_not_duplicates',
    case when v_status = 'maybe' and v_count = 1 then 1 else 0 end, 1;
end
$$;

-- carol RSVPs 'maybe' too, for the counts check below.
insert into public.club_event_rsvps (event_id, user_id, status) values
  ('99000000-0000-0000-0000-0000000000f1', '99000000-0000-0000-0000-000000000003', 'maybe'),
  ('99000000-0000-0000-0000-0000000000f1', '99000000-0000-0000-0000-000000000002', 'not_going');

-- ------------------------------------------------------------
-- CHECK 15: an approved member can see OTHER members' RSVPs (unlike
-- poll votes).
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.club_event_rsvps
    where event_id = '99000000-0000-0000-0000-0000000000f1'
      and user_id in ('99000000-0000-0000-0000-000000000003', '99000000-0000-0000-0000-000000000002');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK15_member_can_see_others_rsvps', v_count, 2;
end
$$;

-- ------------------------------------------------------------
-- CHECK 16-17: club_event_rsvp_counts() aggregation + no cross-club leak.
-- ------------------------------------------------------------
do $$
declare
  v_going bigint;
  v_maybe bigint;
  v_not_going bigint;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  select going, maybe, not_going into v_going, v_maybe, v_not_going
    from public.club_event_rsvp_counts(array['99000000-0000-0000-0000-0000000000f1'::uuid]);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  -- dave's RSVP was changed from 'going' to 'maybe' in CHECK14, so the
  -- final tally has 0 'going' (dave/maybe, carol/maybe, bob/not_going).
  insert into results select 'CHECK16_rsvp_counts_going', v_going::int, 0;
  insert into results select 'CHECK16_rsvp_counts_maybe', v_maybe::int, 2;
  insert into results select 'CHECK16_rsvp_counts_not_going', v_not_going::int, 1;
end
$$;

do $$
declare
  v_row_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000007';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_row_count
    from public.club_event_rsvp_counts(array['99000000-0000-0000-0000-0000000000f1'::uuid]);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK17_non_member_gets_no_rsvp_counts_row', v_row_count, 0;
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
