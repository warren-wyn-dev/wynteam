#!/usr/bin/env bash
# Regression test for WYN-047 (Data Rights -- Export + Account Deletion) --
# proves the core guarantees at the database layer under the real
# `authenticated` role (not the Postgres superuser, which bypasses RLS
# entirely), mirroring wyn_046_platform_documents_test.sh's exact
# harness/role-switching convention.
#
#   1. export_my_data(), called as alice, returns a JSON object
#      containing alice's own Drop, Pop, drop_comment, pop_comment,
#      club_post_comment, follow (both directions), save, club
#      membership, and notification_settings data.
#   2. export_my_data()'s "drops"/"pops" arrays contain exactly alice's
#      own content -- a Drop/Pop bob authored does not appear even
#      though alice liked/commented/saved it.
#   3. export_my_data()'s "sent_messages" contains only messages alice
#      sent -- a message bob sent in the same conversation is absent.
#   4. delete_my_account(), called for a user (carol) seeded with at
#      least one row in every major owned table (drops, pops, follows
#      both directions, saves, club_members, notification_settings, a
#      sent chat message), leaves zero rows across all of those tables
#      for carol's id, and carol's profiles row itself is gone.
#   5. delete_my_account() deleting carol does not touch dave's rows in
#      any of the same tables -- they survive untouched.
#   6. Neither export_my_data() nor delete_my_account() accepts a
#      parameter -- pg_get_function_arguments() confirms both
#      signatures are argument-less, so there is no way to target
#      another user via either RPC.
#   7. (QA round 1 finding, fast-followed) delete_my_account() refuses
#      a banned or actively-suspended user (ban-evasion-via-self-
#      deletion guard), but allows one whose suspend has already
#      expired -- reuses internal.is_posting_blocked().
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_046_platform_documents_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_047_data_rights_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn047_data_rights_regression_test"
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

-- alice/bob: export_my_data() scoping checks (CHECK01-CHECK14).
-- carol/dave: delete_my_account() cascade + no-cross-user-impact
-- checks (CHECK15+). Two separate pairs so the export checks never
-- have to worry about carol's later deletion, and vice versa.
insert into auth.users (id, email) values
  ('67000000-0000-0000-0000-000000000001', 'alice047@test.com'),
  ('67000000-0000-0000-0000-000000000002', 'bob047@test.com'),
  ('67000000-0000-0000-0000-000000000003', 'carol047@test.com'),
  ('67000000-0000-0000-0000-000000000004', 'dave047@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('67000000-0000-0000-0000-000000000001', 'alice047', 'alice', 'user', false),
  ('67000000-0000-0000-0000-000000000002', 'bob047', 'bob', 'user', false),
  ('67000000-0000-0000-0000-000000000003', 'carol047', 'carol', 'user', false),
  ('67000000-0000-0000-0000-000000000004', 'dave047', 'dave', 'user', false);

-- ------------------------------------------------------------
-- Fixtures for the export_my_data() checks: alice's own content plus
-- bob's content that alice interacts with but does not own.
-- ------------------------------------------------------------
insert into public.drops (id, author_id, image_url) values
  ('67000000-0000-0000-0000-0000000000a1', '67000000-0000-0000-0000-000000000001', 'https://example.com/alice-drop.jpg'),
  ('67000000-0000-0000-0000-0000000000b1', '67000000-0000-0000-0000-000000000002', 'https://example.com/bob-drop.jpg');

insert into public.pops (id, author_id, video_url, duration_seconds) values
  ('67000000-0000-0000-0000-0000000000a2', '67000000-0000-0000-0000-000000000001', 'https://example.com/alice-pop.mp4', 10),
  ('67000000-0000-0000-0000-0000000000b2', '67000000-0000-0000-0000-000000000002', 'https://example.com/bob-pop.mp4', 15);

insert into public.clubs (id, name, privacy, owner_id) values
  ('67000000-0000-0000-0000-0000000000a3', 'Alice Club', 'public', '67000000-0000-0000-0000-000000000001');

-- clubs_add_owner_membership (trigger) already gave alice an approved
-- owner row -- bob needs his own approved membership to comment.
insert into public.club_members (club_id, user_id, role, status) values
  ('67000000-0000-0000-0000-0000000000a3', '67000000-0000-0000-0000-000000000002', 'member', 'approved');

insert into public.club_posts (id, club_id, author_id, content) values
  ('67000000-0000-0000-0000-0000000000a4', '67000000-0000-0000-0000-0000000000a3', '67000000-0000-0000-0000-000000000001', 'Hello Club');

-- alice's own comments (drop, pop, club post) -- targets bob's Drop/
-- Pop on purpose, to prove comments are scoped by *comment author*,
-- not by which content they were left on.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_comments (id, drop_id, author_id, text_content)
  values ('67000000-0000-0000-0000-0000000000c1', '67000000-0000-0000-0000-0000000000b1', '67000000-0000-0000-0000-000000000001', 'nice drop, bob');
  insert into public.pop_comments (id, pop_id, author_id, text_content)
  values ('67000000-0000-0000-0000-0000000000c2', '67000000-0000-0000-0000-0000000000b2', '67000000-0000-0000-0000-000000000001', 'nice pop, bob');
  insert into public.club_post_comments (id, club_post_id, author_id, text_content)
  values ('67000000-0000-0000-0000-0000000000c3', '67000000-0000-0000-0000-0000000000a4', '67000000-0000-0000-0000-000000000001', 'alice comment');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- bob also comments on his own club post, and on alice's Drop, to
-- prove bob's activity never leaks into alice's export.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_post_comments (id, club_post_id, author_id, text_content)
  values ('67000000-0000-0000-0000-0000000000c4', '67000000-0000-0000-0000-0000000000a4', '67000000-0000-0000-0000-000000000002', 'bob comment');
  insert into public.drop_comments (id, drop_id, author_id, text_content)
  values ('67000000-0000-0000-0000-0000000000c5', '67000000-0000-0000-0000-0000000000a1', '67000000-0000-0000-0000-000000000002', 'nice drop, alice');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- follows: alice follows bob, bob follows alice -- both directions
-- must show up in alice's export (following + followers).
insert into public.follows (follower_id, following_id) values
  ('67000000-0000-0000-0000-000000000001', '67000000-0000-0000-0000-000000000002'),
  ('67000000-0000-0000-0000-000000000002', '67000000-0000-0000-0000-000000000001');

-- alice saves bob's Drop -- her own action, belongs in her export,
-- even though the saved content itself is bob's (saves is what she
-- saved, not a copy of bob's Drop row).
insert into public.saves (user_id, content_type, content_id) values
  ('67000000-0000-0000-0000-000000000001', 'drop', '67000000-0000-0000-0000-0000000000b1');

insert into public.notification_settings (user_id, comments) values
  ('67000000-0000-0000-0000-000000000001', false);

-- Chat: alice starts a conversation with bob, both send a message --
-- alice's export must contain only her own sent message.
do $$
declare
  v_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('67000000-0000-0000-0000-000000000002') into v_conv_id;
  insert into public.messages (id, conversation_id, sender_id, text)
  values ('67000000-0000-0000-0000-0000000000d1', v_conv_id, '67000000-0000-0000-0000-000000000001', 'hi bob, from alice');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (id, conversation_id, sender_id, text)
  values ('67000000-0000-0000-0000-0000000000d2', v_conv_id, '67000000-0000-0000-0000-000000000002', 'hi alice, from bob');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 1-14: export_my_data(), called as alice.
-- ------------------------------------------------------------
do $$
declare
  v_export jsonb;
begin
  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select public.export_my_data() into v_export;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK01_profile_username_is_alice',
    case when v_export->'profile'->>'username' = 'alice047' then 1 else 0 end, 1;

  insert into results select 'CHECK02_drops_count_is_own_only', jsonb_array_length(v_export->'drops'), 1;
  insert into results select 'CHECK03_drops_contains_alice_drop',
    case when v_export->'drops'->0->>'id' = '67000000-0000-0000-0000-0000000000a1' then 1 else 0 end, 1;
  insert into results select 'CHECK04_drops_does_not_contain_bob_drop',
    case when v_export->'drops' @> jsonb_build_array(jsonb_build_object('id', '67000000-0000-0000-0000-0000000000b1')) then 1 else 0 end, 0;

  insert into results select 'CHECK05_pops_count_is_own_only', jsonb_array_length(v_export->'pops'), 1;
  insert into results select 'CHECK06_pops_does_not_contain_bob_pop',
    case when v_export->'pops' @> jsonb_build_array(jsonb_build_object('id', '67000000-0000-0000-0000-0000000000b2')) then 1 else 0 end, 0;

  insert into results select 'CHECK07_drop_comments_count_is_own_only', jsonb_array_length(v_export->'drop_comments'), 1;
  insert into results select 'CHECK08_pop_comments_count_is_own_only', jsonb_array_length(v_export->'pop_comments'), 1;
  insert into results select 'CHECK09_club_post_comments_count_is_own_only', jsonb_array_length(v_export->'club_post_comments'), 1;

  insert into results select 'CHECK10_following_contains_bob',
    case when v_export->'following' @> jsonb_build_array(jsonb_build_object('following_id', '67000000-0000-0000-0000-000000000002')) then 1 else 0 end, 1;
  insert into results select 'CHECK11_followers_contains_bob',
    case when v_export->'followers' @> jsonb_build_array(jsonb_build_object('follower_id', '67000000-0000-0000-0000-000000000002')) then 1 else 0 end, 1;

  insert into results select 'CHECK12_saves_count_is_own_only', jsonb_array_length(v_export->'saves'), 1;
  insert into results select 'CHECK13_club_memberships_contains_alice_own_row', jsonb_array_length(v_export->'club_memberships'), 1;
  insert into results select 'CHECK14_notification_settings_reflects_alice',
    case when (v_export->'notification_settings'->>'comments')::boolean = false then 1 else 0 end, 1;

  insert into results select 'CHECK15_sent_messages_count_is_own_only', jsonb_array_length(v_export->'sent_messages'), 1;
  insert into results select 'CHECK16_sent_messages_contains_alice_message',
    case when v_export->'sent_messages'->0->>'text' = 'hi bob, from alice' then 1 else 0 end, 1;
  insert into results select 'CHECK17_sent_messages_does_not_contain_bob_message',
    case when v_export->'sent_messages' @> jsonb_build_array(jsonb_build_object('id', '67000000-0000-0000-0000-0000000000d2')) then 1 else 0 end, 0;
end
$$;

-- ------------------------------------------------------------
-- Fixtures for the delete_my_account() checks: carol has at least one
-- row in every major owned table, including a follow relationship
-- with dave in both directions and a chat message she sent to dave.
-- ------------------------------------------------------------
insert into public.drops (id, author_id, image_url) values
  ('67000000-0000-0000-0000-0000000000e1', '67000000-0000-0000-0000-000000000003', 'https://example.com/carol-drop.jpg');

insert into public.pops (id, author_id, video_url, duration_seconds) values
  ('67000000-0000-0000-0000-0000000000e2', '67000000-0000-0000-0000-000000000003', 'https://example.com/carol-pop.mp4', 10);

insert into public.drops (id, author_id, image_url) values
  ('67000000-0000-0000-0000-0000000000f1', '67000000-0000-0000-0000-000000000004', 'https://example.com/dave-drop.jpg');

insert into public.follows (follower_id, following_id) values
  ('67000000-0000-0000-0000-000000000003', '67000000-0000-0000-0000-000000000004'),
  ('67000000-0000-0000-0000-000000000004', '67000000-0000-0000-0000-000000000003');

insert into public.saves (user_id, content_type, content_id) values
  ('67000000-0000-0000-0000-000000000003', 'drop', '67000000-0000-0000-0000-0000000000f1'),
  ('67000000-0000-0000-0000-000000000004', 'drop', '67000000-0000-0000-0000-0000000000e1');

insert into public.clubs (id, name, privacy, owner_id) values
  ('67000000-0000-0000-0000-0000000000e3', 'Carol Club', 'public', '67000000-0000-0000-0000-000000000003');

-- Dave's own club, owned by dave himself (unrelated to carol) --
-- clubs_add_owner_membership gives him an approved owner row here.
-- Deliberately NOT a membership in Carol Club: a club owned by carol
-- is itself carol's data (owner_id references profiles(id) on delete
-- cascade), so it -- and every club_members row scoped to it,
-- including a member who isn't carol -- is *correctly* deleted when
-- carol's account is deleted. That cascade is the club being deleted,
-- not carol's deletion reaching into dave's own data, so it would be
-- the wrong fixture to prove "dave's own club_members row survives"
-- against.
insert into public.clubs (id, name, privacy, owner_id) values
  ('67000000-0000-0000-0000-0000000000e6', 'Dave Club', 'public', '67000000-0000-0000-0000-000000000004');

insert into public.notification_settings (user_id, comments) values
  ('67000000-0000-0000-0000-000000000003', false),
  ('67000000-0000-0000-0000-000000000004', false);

-- carol's own sent message, to dave -- deleted alongside her account
-- (the conversation itself is carol's data too, since she is one of
-- its two participants).
do $$
declare
  v_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('67000000-0000-0000-0000-000000000004') into v_conv_id;
  insert into public.messages (id, conversation_id, sender_id, text)
  values ('67000000-0000-0000-0000-0000000000e4', v_conv_id, '67000000-0000-0000-0000-000000000003', 'hi dave, from carol');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- dave's own sent message, in a conversation with alice -- unrelated
-- to carol entirely, the correct fixture to prove dave's own sent
-- messages survive carol's deletion untouched.
do $$
declare
  v_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('67000000-0000-0000-0000-000000000001') into v_conv_id;
  insert into public.messages (id, conversation_id, sender_id, text)
  values ('67000000-0000-0000-0000-0000000000e5', v_conv_id, '67000000-0000-0000-0000-000000000004', 'hi alice, from dave');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 18: delete_my_account(), called as carol.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  perform public.delete_my_account();
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK 18-27: zero rows remain for carol across every owned table,
-- and her profiles row (and auth.users row) are gone entirely.
insert into results select 'CHECK18_carol_profile_row_gone',
  (select count(*) from public.profiles where id = '67000000-0000-0000-0000-000000000003')::int, 0;
insert into results select 'CHECK19_carol_auth_users_row_gone',
  (select count(*) from auth.users where id = '67000000-0000-0000-0000-000000000003')::int, 0;
insert into results select 'CHECK20_carol_drops_gone',
  (select count(*) from public.drops where author_id = '67000000-0000-0000-0000-000000000003')::int, 0;
insert into results select 'CHECK21_carol_pops_gone',
  (select count(*) from public.pops where author_id = '67000000-0000-0000-0000-000000000003')::int, 0;
insert into results select 'CHECK22_carol_follows_gone',
  (select count(*) from public.follows
   where follower_id = '67000000-0000-0000-0000-000000000003'
      or following_id = '67000000-0000-0000-0000-000000000003')::int, 0;
insert into results select 'CHECK23_carol_saves_gone',
  (select count(*) from public.saves where user_id = '67000000-0000-0000-0000-000000000003')::int, 0;
insert into results select 'CHECK24_carol_club_members_gone',
  (select count(*) from public.club_members where user_id = '67000000-0000-0000-0000-000000000003')::int, 0;
insert into results select 'CHECK25_carol_notification_settings_gone',
  (select count(*) from public.notification_settings where user_id = '67000000-0000-0000-0000-000000000003')::int, 0;
insert into results select 'CHECK26_carol_sent_messages_gone',
  (select count(*) from public.messages where sender_id = '67000000-0000-0000-0000-000000000003')::int, 0;
-- Carol owned Carol Club -- clubs.owner_id also cascades.
insert into results select 'CHECK27_carol_owned_club_gone',
  (select count(*) from public.clubs where owner_id = '67000000-0000-0000-0000-000000000003')::int, 0;

-- CHECK 28-35: dave's rows in every one of the same tables survive
-- completely untouched by carol's deletion.
insert into results select 'CHECK28_dave_profile_row_survives',
  (select count(*) from public.profiles where id = '67000000-0000-0000-0000-000000000004')::int, 1;
insert into results select 'CHECK29_dave_drops_survive',
  (select count(*) from public.drops where author_id = '67000000-0000-0000-0000-000000000004')::int, 1;
-- Carol<->Dave's mutual follow rows are gone via cascade (carol no
-- longer exists to be followed/following) -- prove dave's account
-- itself is otherwise fully functional (not left in some broken
-- half-cascaded state) by having him, as `authenticated` dave, create
-- a brand new follow row targeting alice.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  insert into public.follows (follower_id, following_id) values
    ('67000000-0000-0000-0000-000000000004', '67000000-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;
insert into results select 'CHECK30_dave_follows_survive',
  (select count(*) from public.follows
   where follower_id = '67000000-0000-0000-0000-000000000004'
     and following_id = '67000000-0000-0000-0000-000000000001')::int, 1;
insert into results select 'CHECK31_dave_saves_survive',
  (select count(*) from public.saves where user_id = '67000000-0000-0000-0000-000000000004')::int, 1;
insert into results select 'CHECK32_dave_club_members_survive',
  (select count(*) from public.club_members where user_id = '67000000-0000-0000-0000-000000000004')::int, 1;
insert into results select 'CHECK33_dave_notification_settings_survive',
  (select count(*) from public.notification_settings where user_id = '67000000-0000-0000-0000-000000000004')::int, 1;
insert into results select 'CHECK34_dave_sent_messages_survive',
  (select count(*) from public.messages where sender_id = '67000000-0000-0000-0000-000000000004')::int, 1;
insert into results select 'CHECK35_alice_and_bob_untouched_by_carol_deletion',
  (select count(*) from public.profiles
   where id in ('67000000-0000-0000-0000-000000000001', '67000000-0000-0000-0000-000000000002'))::int, 2;

-- ------------------------------------------------------------
-- CHECK 36-37: neither RPC accepts a parameter -- there is no way to
-- target another user's data/account via either function.
-- ------------------------------------------------------------
insert into results select 'CHECK36_export_my_data_is_argument_less',
  (select case when pg_get_function_arguments(oid) = '' then 1 else 0 end
   from pg_proc
   where proname = 'export_my_data'
     and pronamespace = 'public'::regnamespace)::int,
  1;
insert into results select 'CHECK37_delete_my_account_is_argument_less',
  (select case when pg_get_function_arguments(oid) = '' then 1 else 0 end
   from pg_proc
   where proname = 'delete_my_account'
     and pronamespace = 'public'::regnamespace)::int,
  1;

-- ------------------------------------------------------------
-- CHECK 38-42 (QA round 1 finding, fast-followed): delete_my_account()
-- must refuse a Restricted/Suspended/Banned account -- otherwise a
-- sanctioned user could erase moderation_actions/appeals (both
-- `on delete cascade` from public.profiles) via self-deletion and
-- sign up again with a clean slate, evading the sanction entirely.
-- Reuses internal.is_posting_blocked(), the same check already gating
-- content creation elsewhere.
-- ------------------------------------------------------------
insert into auth.users (id, email) values
  ('67000000-0000-0000-0000-000000000005', 'erin047@test.com'),
  ('67000000-0000-0000-0000-000000000006', 'frank047@test.com'),
  ('67000000-0000-0000-0000-000000000007', 'grace047@test.com'),
  ('67000000-0000-0000-0000-000000000008', 'modx047@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('67000000-0000-0000-0000-000000000005', 'erin047', 'erin', 'user', false),
  ('67000000-0000-0000-0000-000000000006', 'frank047', 'frank', 'user', false),
  ('67000000-0000-0000-0000-000000000007', 'grace047', 'grace', 'user', false),
  ('67000000-0000-0000-0000-000000000008', 'modx047', 'modx', 'moderator', false);

insert into public.reports (id, reporter_id, target_type, target_id, category, status) values
  ('67100000-0000-0000-0000-0000000000e1', '67000000-0000-0000-0000-000000000008', 'user', '67000000-0000-0000-0000-000000000005', 'harassment', 'actioned'),
  ('67100000-0000-0000-0000-0000000000e2', '67000000-0000-0000-0000-000000000008', 'user', '67000000-0000-0000-0000-000000000006', 'harassment', 'actioned'),
  ('67100000-0000-0000-0000-0000000000e3', '67000000-0000-0000-0000-000000000008', 'user', '67000000-0000-0000-0000-000000000007', 'harassment', 'actioned');

-- erin: permanent ban.
insert into public.moderation_actions (report_id, target_user_id, action_type, reason, reviewer_id) values
  ('67100000-0000-0000-0000-0000000000e1', '67000000-0000-0000-0000-000000000005', 'ban', 'test ban', '67000000-0000-0000-0000-000000000008');
-- frank: active suspend (expires in the future).
insert into public.moderation_actions (report_id, target_user_id, action_type, reason, duration_days, expires_at, reviewer_id) values
  ('67100000-0000-0000-0000-0000000000e2', '67000000-0000-0000-0000-000000000006', 'suspend', 'test suspend', 7, now() + interval '7 days', '67000000-0000-0000-0000-000000000008');
-- grace: suspend that already expired -- must NOT block deletion
-- (is_posting_blocked() only counts restrict/suspend while
-- expires_at > now()).
insert into public.moderation_actions (report_id, target_user_id, action_type, reason, duration_days, expires_at, reviewer_id) values
  ('67100000-0000-0000-0000-0000000000e3', '67000000-0000-0000-0000-000000000007', 'suspend', 'test suspend, expired', 1, now() - interval '1 day', '67000000-0000-0000-0000-000000000008');

do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.delete_my_account();
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK38_banned_user_cannot_delete_account', case when v_failed then 1 else 0 end, 1;
  insert into results select 'CHECK39_banned_users_profile_row_survives_failed_attempt',
    (select count(*) from public.profiles where id = '67000000-0000-0000-0000-000000000005')::int, 1;
end
$$;

do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.delete_my_account();
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK40_actively_suspended_user_cannot_delete_account', case when v_failed then 1 else 0 end, 1;
end
$$;

do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '67000000-0000-0000-0000-000000000007';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.delete_my_account();
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK41_user_with_expired_suspend_can_delete_account', case when v_failed then 0 else 1 end, 1;
  insert into results select 'CHECK42_grace_profile_row_gone_after_successful_deletion',
    (select count(*) from public.profiles where id = '67000000-0000-0000-0000-000000000007')::int, 0;
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
