#!/usr/bin/env bash
# Regression test for WYN-116 (Club Re-engagement Notifications) -- proves
# the core guarantees at the database layer under the real `authenticated`
# role (not the Postgres superuser, which bypasses RLS entirely), mirroring
# wyn_044_notification_settings_test.sh's exact harness/role-switching
# convention.
#
#   1. A new club post notifies every OTHER approved member, never the
#      author.
#   2. A pending (not yet approved) member is never notified.
#   3. A banned (club-level) member is never notified.
#   4. A member who muted this specific club (club_notification_mutes) is
#      not notified of a new post.
#   5. A member with notification_settings.club = false is not notified.
#   6. Throttle: a 2nd new post in the same club within the 3-hour window
#      does NOT create a 2nd club_post_new row for the same recipient.
#   7. Throttle expiry: once the existing club_post_new row is backdated
#      past the 3-hour window, the next new post DOES notify again --
#      proves this is a rolling window, not a one-time-ever block.
#   8. Pinning a post notifies every OTHER approved member, INCLUDING the
#      post's own author (unlike new-post notifications, which exclude
#      the author -- being pinned is news to the author too).
#   9. Pinning never throttles -- two separate pins in quick succession
#      both notify.
#  10. A member who muted the club is also excluded from pinned-post
#      notifications.
#  11. Un-pinning then re-pinning the same post fires again (the trigger's
#      old/new transition guard, not a "pinned once ever" flag).
#  12. RLs on club_notification_mutes: a user can only see/insert/delete
#      their own mute row, never another user's.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_044_notification_settings_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_116_club_reengagement_notifications_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn116_club_reengagement_notifications_regression_test"
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

-- alice: club owner, posts/pins.
-- bob, carol, dave: approved members -- carol authors the post alice
-- pins in CHECK8, dave mutes the club in CHECK4/10, bob is the plain
-- "should always be notified" control recipient throughout.
-- erin: pending (unapproved) member -- must never be notified.
-- frank: banned (club-level) member -- must never be notified.
-- grace: approved member with notification_settings.club = false.
insert into auth.users (id, email) values
  ('77000000-0000-0000-0000-000000000001', 'alice@test.com'),
  ('77000000-0000-0000-0000-000000000002', 'bob@test.com'),
  ('77000000-0000-0000-0000-000000000003', 'carol@test.com'),
  ('77000000-0000-0000-0000-000000000004', 'dave@test.com'),
  ('77000000-0000-0000-0000-000000000005', 'erin@test.com'),
  ('77000000-0000-0000-0000-000000000006', 'frank@test.com'),
  ('77000000-0000-0000-0000-000000000007', 'grace@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('77000000-0000-0000-0000-000000000001', 'alice116', 'alice', 'user', false),
  ('77000000-0000-0000-0000-000000000002', 'bob116', 'bob', 'user', false),
  ('77000000-0000-0000-0000-000000000003', 'carol116', 'carol', 'user', false),
  ('77000000-0000-0000-0000-000000000004', 'dave116', 'dave', 'user', false),
  ('77000000-0000-0000-0000-000000000005', 'erin116', 'erin', 'user', false),
  ('77000000-0000-0000-0000-000000000006', 'frank116', 'frank', 'user', false),
  ('77000000-0000-0000-0000-000000000007', 'grace116', 'grace', 'user', false);

insert into public.clubs (id, name, privacy, owner_id) values
  ('77000000-0000-0000-0000-0000000000c1', 'Alice Club', 'public', '77000000-0000-0000-0000-000000000001');

-- alice's own (owner, approved) row is inserted automatically by the
-- clubs_add_owner_membership trigger above -- not seeded again here.
insert into public.club_members (club_id, user_id, role, status) values
  ('77000000-0000-0000-0000-0000000000c1', '77000000-0000-0000-0000-000000000002', 'member', 'approved'),
  ('77000000-0000-0000-0000-0000000000c1', '77000000-0000-0000-0000-000000000003', 'member', 'approved'),
  ('77000000-0000-0000-0000-0000000000c1', '77000000-0000-0000-0000-000000000004', 'member', 'approved'),
  ('77000000-0000-0000-0000-0000000000c1', '77000000-0000-0000-0000-000000000005', 'member', 'pending'),
  ('77000000-0000-0000-0000-0000000000c1', '77000000-0000-0000-0000-000000000006', 'member', 'banned'),
  ('77000000-0000-0000-0000-0000000000c1', '77000000-0000-0000-0000-000000000007', 'member', 'approved');

insert into public.notification_settings (user_id, club) values
  ('77000000-0000-0000-0000-000000000007', false);

-- dave mutes the club up front (used by CHECK4 and CHECK10).
insert into public.club_notification_mutes (club_id, user_id) values
  ('77000000-0000-0000-0000-0000000000c1', '77000000-0000-0000-0000-000000000004');

-- ------------------------------------------------------------
-- CHECK 1-5: alice posts a new club post. bob (plain approved member)
-- must be notified; alice (author) must not; erin (pending) must not;
-- frank (banned) must not; dave (muted) must not; grace (club off)
-- must not.
-- ------------------------------------------------------------
do $$
declare
  v_post_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '77000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_posts (id, club_id, author_id, content)
  values (
    '77000000-0000-0000-0000-0000000000d1',
    '77000000-0000-0000-0000-0000000000c1',
    '77000000-0000-0000-0000-000000000001',
    'First post'
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK1_other_approved_member_notified',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000002'
       and type = 'club_post_new' and club_post_id = '77000000-0000-0000-0000-0000000000d1'), 1;

  insert into results select 'CHECK2_author_never_notified_of_own_post',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000001'
       and type = 'club_post_new'), 0;

  insert into results select 'CHECK3_pending_member_not_notified',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000005'
       and type = 'club_post_new'), 0;

  insert into results select 'CHECK4_banned_member_not_notified',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000006'
       and type = 'club_post_new'), 0;

  insert into results select 'CHECK5_muted_member_not_notified',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000004'
       and type = 'club_post_new'), 0;

  insert into results select 'CHECK6_settings_club_off_member_not_notified',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000007'
       and type = 'club_post_new'), 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: a 2nd post in the same club, moments later, does NOT create
-- a 2nd club_post_new row for bob (3-hour throttle window).
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '77000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_posts (id, club_id, author_id, content)
  values (
    '77000000-0000-0000-0000-0000000000d2',
    '77000000-0000-0000-0000-0000000000c1',
    '77000000-0000-0000-0000-000000000001',
    'Second post, same window'
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK7_second_post_same_window_not_notified_again',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000002'
       and type = 'club_post_new'), 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8: backdate bob's existing club_post_new row past the 3-hour
-- window, then a 3rd post DOES notify again -- proves the throttle is a
-- rolling window, not a permanent one-time block.
-- ------------------------------------------------------------
update public.notifications
set created_at = now() - interval '4 hours'
where recipient_id = '77000000-0000-0000-0000-000000000002' and type = 'club_post_new';

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '77000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_posts (id, club_id, author_id, content)
  values (
    '77000000-0000-0000-0000-0000000000d3',
    '77000000-0000-0000-0000-0000000000c1',
    '77000000-0000-0000-0000-000000000001',
    'Third post, window expired'
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK8_window_expired_notifies_again',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000002'
       and type = 'club_post_new'), 2;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9-11: alice pins carol's post -- carol (the author) IS notified
-- (unlike new-post, pin notifies the author too), bob is notified,
-- dave (muted) is not, alice (who pinned it) is not.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '77000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_posts (id, club_id, author_id, content)
  values (
    '77000000-0000-0000-0000-0000000000d4',
    '77000000-0000-0000-0000-0000000000c1',
    '77000000-0000-0000-0000-000000000003',
    'Carol post to be pinned'
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '77000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  update public.club_posts set pinned = true
  where id = '77000000-0000-0000-0000-0000000000d4';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK9_pin_notifies_the_posts_own_author',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000003'
       and type = 'club_post_pinned' and club_post_id = '77000000-0000-0000-0000-0000000000d4'), 1;

  insert into results select 'CHECK10_pin_notifies_other_members_too',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000002'
       and type = 'club_post_pinned' and club_post_id = '77000000-0000-0000-0000-0000000000d4'), 1;

  insert into results select 'CHECK11_pinner_never_notified_of_own_action',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000001'
       and type = 'club_post_pinned'), 0;

  insert into results select 'CHECK12_muted_member_not_notified_of_pin',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000004'
       and type = 'club_post_pinned'), 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 13: pinning never throttles -- pin a 2nd (already-existing,
-- unpinned) post moments later, bob must be notified again (2 total
-- club_post_pinned rows now), unlike the new-post throttle above.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '77000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  update public.club_posts set pinned = true
  where id = '77000000-0000-0000-0000-0000000000d1';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK13_pinning_never_throttled',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000002'
       and type = 'club_post_pinned'), 2;
end
$$;

-- ------------------------------------------------------------
-- CHECK 14: un-pinning then re-pinning the SAME post fires again (the
-- old=false/new=true transition guard re-triggers, it isn't a "pinned
-- once ever" flag).
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '77000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  update public.club_posts set pinned = false where id = '77000000-0000-0000-0000-0000000000d1';
  update public.club_posts set pinned = true where id = '77000000-0000-0000-0000-0000000000d1';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK14_unpin_then_repin_notifies_again',
    (select count(*) from public.notifications
     where recipient_id = '77000000-0000-0000-0000-000000000002'
       and type = 'club_post_pinned'), 3;
end
$$;

-- ------------------------------------------------------------
-- CHECK 15-17: RLS on club_notification_mutes -- a user can insert/see
-- only their own mute row, and cannot see/delete another user's.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '77000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_notification_mutes (club_id, user_id) values
    ('77000000-0000-0000-0000-0000000000c1', '77000000-0000-0000-0000-000000000002');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
declare
  v_seen int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '77000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_seen from public.club_notification_mutes
  where user_id = '77000000-0000-0000-0000-000000000002';

  delete from public.club_notification_mutes
  where user_id = '77000000-0000-0000-0000-000000000002';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK15_user_a_cannot_see_user_bs_mute_row', v_seen, 0;
end
$$;

do $$
declare
  v_still_there int;
begin
  select count(*) into v_still_there from public.club_notification_mutes
  where user_id = '77000000-0000-0000-0000-000000000002';

  insert into results select 'CHECK16_user_a_cannot_delete_user_bs_mute_row', v_still_there, 1;
end
$$;

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '77000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  delete from public.club_notification_mutes
  where user_id = '77000000-0000-0000-0000-000000000002';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK17_user_can_unmute_their_own_row',
    (select count(*) from public.club_notification_mutes
     where user_id = '77000000-0000-0000-0000-000000000002'), 0;
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
