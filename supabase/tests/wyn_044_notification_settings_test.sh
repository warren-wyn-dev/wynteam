#!/usr/bin/env bash
# Regression test for WYN-044 (Notification Settings) -- proves the core
# guarantees at the database layer under the real `authenticated` role
# (not the Postgres superuser, which bypasses RLS entirely), mirroring
# wyn_043_notification_types_test.sh's exact harness/role-switching
# convention.
#
#   1. No row in `notification_settings` for a user -> every category
#      behaves as enabled (opt-out default).
#   2. Turning `comments` off blocks `comment_drop` but does not block
#      `like_pop` (a different category, `likes`, stays on).
#   3. Turning `comments` back on restores `comment_pop` -- proves the
#      gate is two-way, not a one-time switch.
#   4. Turning `likes` off blocks `like_drop` and `redrop`, but does not
#      block `comment_drop` (a different category, `comments`, stays on).
#   5. Turning `follows` off blocks `follow`.
#   6. Turning `club` off blocks `club_post_comment` -- proves the "every
#      Club sub-type shares one gate" mapping decision, not just the
#      plain Drop/Pop Like/Comment gates. Turning it back on restores it.
#   7. Turning `messages` off blocks `message_request`
#      (get_or_create_conversation()); turning it back on (for a fresh
#      conversation pair) restores it.
#   8. Turning `system` off blocks send_system_notification()'s insert;
#      turning it back on restores it.
#   9. A user with *every* category turned off still gets
#      `moderation_warning` (apply_moderation_action) and `appeal_approved`
#      (decide_appeal) inserted -- those code paths are never gated, by
#      design.
#  10. RLS: user A can neither SELECT nor UPDATE user B's
#      `notification_settings` row.
#  11. (WYN-044 debug fix) internal.notification_enabled() has no
#      EXECUTE grant to `authenticated` -- an ordinary user calling it
#      directly with someone else's user_id fails with a permission
#      error instead of leaking that user's real preference.
#  12. (WYN-044 debug fix) internal.notification_enabled() raises on an
#      unrecognized p_category instead of silently fail-opening.
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

-- alice: recipient/subject whose notification_settings we toggle.
-- bob: actor for likes/comments/redrop on alice's Drop/Pop content.
-- carol: club member who comments on alice's club post.
-- dave: messages actor whose conversation-start is blocked (messages off).
-- erin: messages actor whose conversation-start is allowed (messages on).
-- frank: follows actor whose follow is blocked (follows off).
-- moderator: platform_role = 'moderator', runs apply_moderation_action/decide_appeal.
-- admin: platform_role = 'admin', runs send_system_notification.
-- stranger: owns her own notification_settings row, used for the RLS probe.
insert into auth.users (id, email) values
  ('61000000-0000-0000-0000-000000000001', 'alice@test.com'),
  ('61000000-0000-0000-0000-000000000002', 'bob@test.com'),
  ('61000000-0000-0000-0000-000000000003', 'carol@test.com'),
  ('61000000-0000-0000-0000-000000000004', 'dave@test.com'),
  ('61000000-0000-0000-0000-000000000005', 'erin@test.com'),
  ('61000000-0000-0000-0000-000000000006', 'frank@test.com'),
  ('61000000-0000-0000-0000-000000000007', 'moderator@test.com'),
  ('61000000-0000-0000-0000-000000000008', 'admin@test.com'),
  ('61000000-0000-0000-0000-000000000009', 'stranger@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('61000000-0000-0000-0000-000000000001', 'alice044', 'alice', 'user', false),
  ('61000000-0000-0000-0000-000000000002', 'bob044', 'bob', 'user', false),
  ('61000000-0000-0000-0000-000000000003', 'carol044', 'carol', 'user', false),
  ('61000000-0000-0000-0000-000000000004', 'dave044', 'dave', 'user', false),
  ('61000000-0000-0000-0000-000000000005', 'erin044', 'erin', 'user', false),
  ('61000000-0000-0000-0000-000000000006', 'frank044', 'frank', 'user', false),
  ('61000000-0000-0000-0000-000000000007', 'moderator044', 'moderator', 'moderator', false),
  ('61000000-0000-0000-0000-000000000008', 'admin044', 'admin', 'admin', false),
  ('61000000-0000-0000-0000-000000000009', 'stranger044', 'stranger', 'user', false);

-- Content fixtures (inserted directly, same convention
-- wyn_034_redrop_test.sh uses for Drop fixtures -- only the actions
-- under test go through role-switched, RLS-checked inserts below).
insert into public.drops (id, author_id, image_url) values
  ('61000000-0000-0000-0000-0000000000d1', '61000000-0000-0000-0000-000000000001', 'https://example.com/alice-drop1.jpg'),
  ('61000000-0000-0000-0000-0000000000d2', '61000000-0000-0000-0000-000000000001', 'https://example.com/alice-drop2.jpg');

insert into public.pops (id, author_id, video_url, duration_seconds) values
  ('61000000-0000-0000-0000-0000000000a1', '61000000-0000-0000-0000-000000000001', 'https://example.com/alice-pop1.mp4', 10);

insert into public.clubs (id, name, privacy, owner_id) values
  ('61000000-0000-0000-0000-0000000000c1', 'Alice Club', 'public', '61000000-0000-0000-0000-000000000001');

-- clubs_add_owner_membership (trigger) already gave alice an approved
-- owner row -- carol needs her own approved membership to comment.
insert into public.club_members (club_id, user_id, role, status) values
  ('61000000-0000-0000-0000-0000000000c1', '61000000-0000-0000-0000-000000000003', 'member', 'approved');

insert into public.club_posts (id, club_id, author_id, content) values
  ('61000000-0000-0000-0000-0000000000c2', '61000000-0000-0000-0000-0000000000c1', '61000000-0000-0000-0000-000000000001', 'Hello Club');

-- ------------------------------------------------------------
-- CHECK 1: no row in notification_settings for alice yet -- every
-- category behaves as enabled. Bob likes alice's first Drop.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_likes (drop_id, user_id)
  values ('61000000-0000-0000-0000-0000000000d1', '61000000-0000-0000-0000-000000000002');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001'
    and type = 'like_drop' and drop_id = '61000000-0000-0000-0000-0000000000d1';

  insert into results select 'CHECK01_no_row_defaults_to_enabled_like_drop', v_count, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 2-3: turning `comments` off blocks comment_drop, but a
-- different category (`likes`, still true/default) is unaffected.
-- ------------------------------------------------------------
insert into public.notification_settings (user_id, comments) values
  ('61000000-0000-0000-0000-000000000001', false);

do $$
declare
  v_comment_count int;
  v_like_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_comments (drop_id, author_id, text_content)
  values ('61000000-0000-0000-0000-0000000000d1', '61000000-0000-0000-0000-000000000002', 'nice drop');
  insert into public.pop_likes (pop_id, user_id)
  values ('61000000-0000-0000-0000-0000000000a1', '61000000-0000-0000-0000-000000000002');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_comment_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'comment_drop';
  select count(*) into v_like_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'like_pop';

  insert into results select 'CHECK02_comments_off_blocks_comment_drop', v_comment_count, 0;
  insert into results select 'CHECK03_comments_off_does_not_block_like_pop', v_like_count, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 4: turning `comments` back on restores the insert (two-way,
-- not just one-way).
-- ------------------------------------------------------------
update public.notification_settings set comments = true
where user_id = '61000000-0000-0000-0000-000000000001';

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  insert into public.pop_comments (pop_id, author_id, text_content)
  values ('61000000-0000-0000-0000-0000000000a1', '61000000-0000-0000-0000-000000000002', 'nice pop');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'comment_pop';

  insert into results select 'CHECK04_comments_back_on_restores_comment_pop', v_count, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5-7: turning `likes` off blocks like_drop and redrop, but a
-- different category (`comments`, still on) is unaffected.
-- ------------------------------------------------------------
update public.notification_settings set likes = false
where user_id = '61000000-0000-0000-0000-000000000001';

do $$
declare
  v_like_count int;
  v_redrop_count int;
  v_comment_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_likes (drop_id, user_id)
  values ('61000000-0000-0000-0000-0000000000d2', '61000000-0000-0000-0000-000000000002');
  insert into public.redrops (drop_id, redropper_id)
  values ('61000000-0000-0000-0000-0000000000d2', '61000000-0000-0000-0000-000000000002');
  insert into public.drop_comments (drop_id, author_id, text_content)
  values ('61000000-0000-0000-0000-0000000000d2', '61000000-0000-0000-0000-000000000002', 'nice drop 2');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_like_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'like_drop'
    and drop_id = '61000000-0000-0000-0000-0000000000d2';
  select count(*) into v_redrop_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'redrop';
  select count(*) into v_comment_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'comment_drop'
    and drop_id = '61000000-0000-0000-0000-0000000000d2';

  insert into results select 'CHECK05_likes_off_blocks_like_drop', v_like_count, 0;
  insert into results select 'CHECK06_likes_off_blocks_redrop', v_redrop_count, 0;
  insert into results select 'CHECK07_likes_off_does_not_block_comment_drop', v_comment_count, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8: turning `follows` off blocks the follow notification.
-- ------------------------------------------------------------
update public.notification_settings set follows = false
where user_id = '61000000-0000-0000-0000-000000000001';

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  insert into public.follows (follower_id, following_id)
  values ('61000000-0000-0000-0000-000000000006', '61000000-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'follow';

  insert into results select 'CHECK08_follows_off_blocks_follow', v_count, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9-10: `club` off blocks club_post_comment (proves the
-- "every Club sub-type shares one gate" mapping decision); turning it
-- back on restores it.
-- ------------------------------------------------------------
update public.notification_settings set club = false
where user_id = '61000000-0000-0000-0000-000000000001';

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_post_comments (club_post_id, author_id, text_content)
  values ('61000000-0000-0000-0000-0000000000c2', '61000000-0000-0000-0000-000000000003', 'first comment');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'club_post_comment';

  insert into results select 'CHECK09_club_off_blocks_club_post_comment', v_count, 0;
end
$$;

update public.notification_settings set club = true
where user_id = '61000000-0000-0000-0000-000000000001';

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_post_comments (club_post_id, author_id, text_content)
  values ('61000000-0000-0000-0000-0000000000c2', '61000000-0000-0000-0000-000000000003', 'second comment');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'club_post_comment';

  insert into results select 'CHECK10_club_back_on_restores_club_post_comment', v_count, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 11-12: `messages` off blocks message_request
-- (get_or_create_conversation()); turning it back on restores it for
-- a fresh conversation pair (a conversation is only ever a pending
-- Message Request, and therefore only ever notifies, once).
-- ------------------------------------------------------------
update public.notification_settings set messages = false
where user_id = '61000000-0000-0000-0000-000000000001';

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  perform public.get_or_create_conversation('61000000-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'message_request'
    and actor_id = '61000000-0000-0000-0000-000000000004';

  insert into results select 'CHECK11_messages_off_blocks_message_request', v_count, 0;
end
$$;

update public.notification_settings set messages = true
where user_id = '61000000-0000-0000-0000-000000000001';

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  perform public.get_or_create_conversation('61000000-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'message_request'
    and actor_id = '61000000-0000-0000-0000-000000000005';

  insert into results select 'CHECK12_messages_back_on_restores_message_request', v_count, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 13-14: `system` off blocks send_system_notification()'s
-- insert; turning it back on restores it.
-- ------------------------------------------------------------
update public.notification_settings set system = false
where user_id = '61000000-0000-0000-0000-000000000001';

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000008';
  set request.jwt.claim.role = 'authenticated';
  perform public.send_system_notification('61000000-0000-0000-0000-000000000001', 'system off test');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'system'
    and reason = 'system off test';

  insert into results select 'CHECK13_system_off_blocks_send_system_notification', v_count, 0;
end
$$;

update public.notification_settings set system = true
where user_id = '61000000-0000-0000-0000-000000000001';

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000008';
  set request.jwt.claim.role = 'authenticated';
  perform public.send_system_notification('61000000-0000-0000-0000-000000000001', 'system on test');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'system'
    and reason = 'system on test';

  insert into results select 'CHECK14_system_back_on_restores_send_system_notification', v_count, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 15-16: alice now has EVERY category turned off -- prove
-- moderation_warning/appeal_approved are still inserted
-- unconditionally, exactly as before this task (never gated, by
-- design).
-- ------------------------------------------------------------
update public.notification_settings
set likes = false, comments = false, follows = false, messages = false,
    club = false, trending = false, system = false
where user_id = '61000000-0000-0000-0000-000000000001';

-- Report fixtures (bob and carol each report alice as a user once, for
-- two separate moderation actions -- two different reporters because
-- reports_reporter_target_open_unique only allows one open report per
-- reporter/target pair at a time. reports/moderation_actions are not
-- under test here, just the plumbing apply_moderation_action() and
-- decide_appeal() need).
insert into public.reports (id, reporter_id, target_type, target_id, category) values
  ('61000000-0000-0000-0000-0000000000e1', '61000000-0000-0000-0000-000000000002', 'user', '61000000-0000-0000-0000-000000000001', 'harassment'),
  ('61000000-0000-0000-0000-0000000000e2', '61000000-0000-0000-0000-000000000003', 'user', '61000000-0000-0000-0000-000000000001', 'harassment');

do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000007';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(
    '61000000-0000-0000-0000-0000000000e1', 'warning', 'first warning'
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'moderation_warning';

  insert into results select 'CHECK15_moderation_warning_never_gated', v_count, 1;
end
$$;

do $$
declare
  v_action_id uuid;
  v_appeal_id uuid;
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000007';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(
    '61000000-0000-0000-0000-0000000000e2', 'restrict', 'restricted for a bit', 1
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select id into v_action_id from public.moderation_actions where report_id = '61000000-0000-0000-0000-0000000000e2';

  insert into public.appeals (moderation_action_id, appellant_id, reason)
  values (v_action_id, '61000000-0000-0000-0000-000000000001', 'it was a mistake')
  returning id into v_appeal_id;

  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000007';
  set request.jwt.claim.role = 'authenticated';
  perform public.decide_appeal(v_appeal_id, true);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '61000000-0000-0000-0000-000000000001' and type = 'appeal_approved';

  insert into results select 'CHECK16_appeal_approved_never_gated', v_count, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 18-19: RLS -- alice cannot see or update stranger's
-- notification_settings row.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000009';
  set request.jwt.claim.role = 'authenticated';
  insert into public.notification_settings (user_id, likes) values
    ('61000000-0000-0000-0000-000000000009', false);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
declare
  v_seen int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_seen from public.notification_settings
  where user_id = '61000000-0000-0000-0000-000000000009';

  update public.notification_settings set likes = true
  where user_id = '61000000-0000-0000-0000-000000000009';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK18_user_a_cannot_select_user_b_settings', v_seen, 0;
end
$$;

do $$
declare
  v_likes boolean;
begin
  select likes into v_likes from public.notification_settings
  where user_id = '61000000-0000-0000-0000-000000000009';

  insert into results select 'CHECK19_user_a_cannot_update_user_b_settings',
    case when v_likes = false then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 20: internal.notification_enabled() has no `grant execute ...
-- to authenticated` (WYN-044 debug fix for the Low security finding
-- -- an ordinary authenticated user could otherwise call this
-- security-definer helper directly with someone *else's* user_id and
-- read that user's real per-category preference, bypassing
-- notification_settings' own RLS). Bob calling it directly with
-- stranger's user_id must fail with a permission error.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '61000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform internal.notification_enabled(
      '61000000-0000-0000-0000-000000000009', 'likes'
    );
    insert into results values
      ('CHECK20_direct_call_with_other_users_id_denied', 0, 1);
  exception when insufficient_privilege or others then
    insert into results values
      ('CHECK20_direct_call_with_other_users_id_denied', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 21: an unrecognized p_category raises an exception instead of
-- silently falling through the CASE to NULL -> coalesce(..., true) ->
-- fail-open with no signal (WYN-044 debug fix for the Minor finding).
-- Called as the function owner (not role authenticated), since
-- CHECK 20 above already proved an ordinary authenticated user cannot
-- call this function directly at all anymore.
-- ------------------------------------------------------------
do $$
begin
  begin
    perform internal.notification_enabled(
      '61000000-0000-0000-0000-000000000001', 'not_a_real_category'
    );
    insert into results values
      ('CHECK21_invalid_category_raises_instead_of_fail_open', 0, 1);
  exception when others then
    insert into results values
      ('CHECK21_invalid_category_raises_instead_of_fail_open', 1, 1);
  end;
end
$$;

-- ------------------------------------------------------------
-- CHECK 22 (QA round 2 finding, WYN-044 debug fix follow-up): a NULL
-- p_category specifically must also raise, not just an unrecognized
-- string -- `NULL not in (...)` is NULL (neither true nor false) under
-- 3-valued logic, so `p_category not in (...)` alone let a NULL
-- category slip through to the old fail-open coalesce(...,true)
-- behavior even after CHECK21's fix for bogus non-null strings.
-- ------------------------------------------------------------
do $$
begin
  begin
    perform internal.notification_enabled(
      '61000000-0000-0000-0000-000000000001', null
    );
    insert into results values
      ('CHECK22_null_category_raises_instead_of_fail_open', 0, 1);
  exception when others then
    insert into results values
      ('CHECK22_null_category_raises_instead_of_fail_open', 1, 1);
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
