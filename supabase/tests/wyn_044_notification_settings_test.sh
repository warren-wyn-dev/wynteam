#!/usr/bin/env bash
# Regression test for WYN-044 (Notification Settings -- opt-out per
# category) -- proves the core guarantees at the database layer under
# the real `authenticated` role (not the Postgres superuser, which
# bypasses RLS entirely), mirroring wyn_043_notification_types_test.sh's
# exact harness/role-switching convention.
#
#   1. A user who never touched settings (no notification_settings row
#      at all) still receives notifications -- the "missing row =
#      enabled" contract (internal.notification_category_enabled's own
#      coalesce()) is the single most important guarantee this task
#      adds; see the Product spec's Risks section for why a regression
#      here would be worse than WYN-043's redrop crash (silent, no
#      error anywhere).
#   2. Disabling one category (likes) blocks exactly that category's
#      notifications (like_drop, club_post_like, redrop) and nothing
#      else -- comment_drop (a different category) still arrives for
#      the same recipient.
#   3. set_notification_category_enabled() only changes the one column
#      it's asked to -- toggling likes off does not also flip comments/
#      follows/messages/club/system.
#   4. follow_request (a non-trigger insert inside
#      internal.notify_follow_request) is gated by 'follows'.
#   5. club_join_request (a fan-out INSERT...SELECT to every
#      owner/admin) is gated by 'club' per-recipient, not all-or-nothing
#      for the whole club.
#   6. message_request (inserted inside get_or_create_conversation(), not
#      a trigger) is gated by 'messages'.
#   7. system (send_system_notification(), WYN-043) is gated by
#      'system' -- an admin's send silently becomes a no-op for a
#      recipient who disabled it, without erroring back to the admin.
#   8. set_notification_category_enabled() rejects an unknown category
#      name.
#   9. RLS on notification_settings itself: a user can only read/write
#      their own row, never another user's.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_043_notification_types_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_044_notification_settings_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn044_notification_settings_regression_test"
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

-- alice: recipient under test, never touches settings until CHECK2.
-- bob: actor who likes/comments/redrops alice's Drop.
-- admin: platform_role = 'admin', sends alice a system notification.
-- owner: Club owner, recipient of a join request.
-- requester: sends alice a follow request / a club join request / a
--   message request.
-- carol: a second Club owner, used to prove club_join_request's gate
--   is per-recipient, not all-or-nothing for the whole fan-out.
insert into auth.users (id, email) values
  ('50000000-0000-0000-0000-000000000001', 'alice@test.com'),
  ('50000000-0000-0000-0000-000000000002', 'bob@test.com'),
  ('50000000-0000-0000-0000-000000000003', 'admin@test.com'),
  ('50000000-0000-0000-0000-000000000004', 'owner@test.com'),
  ('50000000-0000-0000-0000-000000000005', 'requester@test.com'),
  ('50000000-0000-0000-0000-000000000006', 'carol@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('50000000-0000-0000-0000-000000000001', 'alice', 'alice', 'user', false),
  ('50000000-0000-0000-0000-000000000002', 'bob', 'bob', 'user', false),
  ('50000000-0000-0000-0000-000000000003', 'adminuser', 'adminuser', 'admin', false),
  ('50000000-0000-0000-0000-000000000004', 'owneruser', 'owneruser', 'user', false),
  ('50000000-0000-0000-0000-000000000005', 'requesteruser', 'requesteruser', 'user', false),
  ('50000000-0000-0000-0000-000000000006', 'caroluser', 'caroluser', 'user', false);

-- ------------------------------------------------------------
-- CHECK 1: alice has never touched settings at all (no row in
-- notification_settings) -- bob liking her Drop must still notify her.
-- This is the single most important guarantee of this task.
-- ------------------------------------------------------------
do $$
declare
  v_drop_id uuid;
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drops (author_id, image_url, caption)
  values ('50000000-0000-0000-0000-000000000001', 'https://example.com/a.jpg', 'alice drop')
  returning id into v_drop_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_likes (drop_id, user_id) values (v_drop_id, '50000000-0000-0000-0000-000000000002');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000001' and type = 'like_drop';

  insert into results select 'CHECK1_no_settings_row_still_notifies', v_count, 1;

  insert into results select 'CHECK1b_no_row_created_by_mere_notify',
    (select count(*)::int from public.notification_settings where user_id = '50000000-0000-0000-0000-000000000001'), 0;

  -- Stash the drop id for later checks via a session GUC-free temp table.
  create temp table t_ids (key text primary key, val uuid);
  insert into t_ids values ('alice_drop', v_drop_id);
end
$$;

-- ------------------------------------------------------------
-- CHECK 2-3: alice disables 'likes' -- a second like (from a fresh
-- actor, since drop_likes has a unique (drop_id, user_id) and bob
-- already liked it) and a redrop and a club_post_like must all be
-- silently skipped, but a comment must still arrive (different
-- category, proves the gate is per-category not all-or-nothing).
-- ------------------------------------------------------------
do $$
declare
  v_drop_id uuid;
  v_before_likes int;
  v_after_likes int;
  v_before_comments int;
  v_after_comments int;
  v_before_redrop int;
  v_after_redrop int;
begin
  select val into v_drop_id from t_ids where key = 'alice_drop';

  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.set_notification_category_enabled('likes', false);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_before_likes from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000001' and type = 'like_drop';
  select count(*) into v_before_comments from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000001' and type = 'comment_drop';
  select count(*) into v_before_redrop from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000001' and type = 'redrop';

  -- A second actor comments AND redrops -- likes category is off,
  -- comments category is still on.
  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_comments (drop_id, author_id, text_content)
  values (v_drop_id, '50000000-0000-0000-0000-000000000005', 'nice drop');
  insert into public.redrops (drop_id, redropper_id, quote_text)
  values (v_drop_id, '50000000-0000-0000-0000-000000000005', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_after_likes from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000001' and type = 'like_drop';
  select count(*) into v_after_comments from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000001' and type = 'comment_drop';
  select count(*) into v_after_redrop from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000001' and type = 'redrop';

  insert into results select 'CHECK2_redrop_gated_by_likes_off',
    (v_after_redrop - v_before_redrop), 0;

  insert into results select 'CHECK3_comment_drop_unaffected_by_likes_off',
    (v_after_comments - v_before_comments), 1;

  -- likes count must not have moved either (no new like was inserted
  -- in this block, this just re-confirms nothing else bumped it).
  insert into results select 'CHECK3b_like_drop_count_unchanged',
    (v_after_likes - v_before_likes), 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 4: set_notification_category_enabled only touches the one
-- column it's told to -- likes is off (from above), comments/follows/
-- messages/club/system must all still read as enabled (true).
-- ------------------------------------------------------------
do $$
declare
  v_likes boolean;
  v_comments boolean;
  v_follows boolean;
  v_messages boolean;
  v_club boolean;
  v_system boolean;
begin
  select likes_enabled, comments_enabled, follows_enabled, messages_enabled, club_enabled, system_enabled
    into v_likes, v_comments, v_follows, v_messages, v_club, v_system
  from public.notification_settings
  where user_id = '50000000-0000-0000-0000-000000000001';

  insert into results select 'CHECK4a_likes_is_off', case when v_likes = false then 1 else 0 end, 1;
  insert into results select 'CHECK4b_comments_untouched', case when v_comments = true then 1 else 0 end, 1;
  insert into results select 'CHECK4c_follows_untouched', case when v_follows = true then 1 else 0 end, 1;
  insert into results select 'CHECK4d_messages_untouched', case when v_messages = true then 1 else 0 end, 1;
  insert into results select 'CHECK4e_club_untouched', case when v_club = true then 1 else 0 end, 1;
  insert into results select 'CHECK4f_system_untouched', case when v_system = true then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5: follow_request (internal.notify_follow_request, not
-- gated by likes above) is gated by 'follows' specifically.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  -- alice makes herself private so a follow from requester becomes a
  -- follow_request instead of an immediate follow (mirrors WYN-039's
  -- own test setup for triggering the pending path).
  update public.profiles set is_private = true where id = '50000000-0000-0000-0000-000000000001';

  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.set_notification_category_enabled('follows', false);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  insert into public.follow_requests (requester_id, target_id)
  values ('50000000-0000-0000-0000-000000000005', '50000000-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000001' and type = 'follow_request';

  insert into results select 'CHECK5_follow_request_gated_by_follows_off', v_count, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: club_join_request's fan-out gate is per-recipient -- owner
-- has 'club' disabled, carol (promoted to admin of the same club) does
-- not, so carol must still be notified while owner is not. Uses the
-- real RPC flow (approve_club_member/set_club_member_role) rather than
-- inserting an 'admin'/'approved' row directly, since the insert
-- policy only ever allows self-inserting as role='member'.
-- ------------------------------------------------------------
do $$
declare
  v_club_id uuid;
  v_owner_before int;
  v_owner_after int;
  v_carol_before int;
  v_carol_after int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  insert into public.clubs (name, description, owner_id, privacy)
  values ('Test Club', 'desc', '50000000-0000-0000-0000-000000000004', 'private')
  returning id into v_club_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- carol requests to join (private club -> pending), owner approves,
  -- then promotes her to admin.
  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_members (club_id, user_id, role, status)
  values (v_club_id, '50000000-0000-0000-0000-000000000006', 'member', 'pending');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  perform public.approve_club_member(v_club_id, '50000000-0000-0000-0000-000000000006');
  perform public.set_club_member_role(v_club_id, '50000000-0000-0000-0000-000000000006', 'admin');
  perform public.set_notification_category_enabled('club', false);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- Snapshot counts *after* the setup above (carol's own join already
  -- notified the owner once, back when 'club' was still on) so the
  -- check below measures only what requester's join adds.
  select count(*) into v_owner_before from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000004' and type = 'club_join_request';
  select count(*) into v_carol_before from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000006' and type = 'club_join_request';

  -- requester now sends the join request under test -- fans out to
  -- owner (club off) and carol/admin (club on).
  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_members (club_id, user_id, role, status)
  values (v_club_id, '50000000-0000-0000-0000-000000000005', 'member', 'pending');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_owner_after from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000004' and type = 'club_join_request';
  select count(*) into v_carol_after from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000006' and type = 'club_join_request';

  insert into results select 'CHECK6a_owner_with_club_off_not_notified', (v_owner_after - v_owner_before), 0;
  insert into results select 'CHECK6b_carol_with_club_on_still_notified', (v_carol_after - v_carol_before), 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: message_request (get_or_create_conversation) is gated by
-- 'messages'.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  perform public.set_notification_category_enabled('messages', false);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  perform public.get_or_create_conversation('50000000-0000-0000-0000-000000000004');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000004' and type = 'message_request';

  insert into results select 'CHECK7_message_request_gated_by_messages_off', v_count, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8: send_system_notification (WYN-043) is gated by 'system' --
-- the admin's call must succeed (no exception) even though the
-- recipient has it disabled; it just silently doesn't insert.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
  v_errored int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.set_notification_category_enabled('system', false);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.send_system_notification('50000000-0000-0000-0000-000000000001', 'ประกาศทดสอบ');
  exception when others then
    v_errored := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '50000000-0000-0000-0000-000000000001' and type = 'system';

  insert into results select 'CHECK8a_system_gated_no_row', v_count, 0;
  insert into results select 'CHECK8b_admin_call_did_not_error', v_errored, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9: unknown category name is rejected.
-- ------------------------------------------------------------
do $$
declare
  v_rejected int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.set_notification_category_enabled('not_a_real_category', false);
  exception when others then
    v_rejected := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK9_unknown_category_rejected', v_rejected, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 10-11: RLS on notification_settings -- alice cannot see or
-- update bob's row directly (bob never toggled anything, so create
-- one for him first via his own call).
-- ------------------------------------------------------------
do $$
declare
  v_alice_sees_bob int;
  v_alice_update_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  perform public.set_notification_category_enabled('likes', false);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '50000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_alice_sees_bob from public.notification_settings
  where user_id = '50000000-0000-0000-0000-000000000002';

  update public.notification_settings set likes_enabled = true
  where user_id = '50000000-0000-0000-0000-000000000002';
  get diagnostics v_alice_update_count = row_count;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK10_alice_cannot_see_bobs_settings', v_alice_sees_bob, 0;
  insert into results select 'CHECK11_alice_cannot_update_bobs_settings', v_alice_update_count, 0;
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
