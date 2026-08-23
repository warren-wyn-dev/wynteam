#!/usr/bin/env bash
# Regression test for WYN-045 (Settings -- Interaction Privacy Controls:
# DM/Mention/Comment Permission) -- proves the core security/product
# guarantees at the database layer under the real `authenticated` role
# (not the Postgres superuser, which bypasses RLS entirely), mirroring
# wyn_039_private_account_test.sh's/wyn_044_notification_settings_test.sh's
# exact harness/role-switching convention.
#
#   DM Permission (get_or_create_conversation()):
#   1.  `people_i_follow` rejects a new conversation from someone the
#       recipient does not follow (raises, no `conversations` row).
#   2.  `people_i_follow` allows a new conversation from someone the
#       recipient DOES follow -- status `active`, same as today.
#   3.  `no_one` rejects a new conversation even from someone the
#       recipient follows -- no exception carve-out.
#   4.  An existing conversation (created while the recipient's setting
#       was still `everyone`, ending up `pending`) is unaffected when the
#       recipient later switches to `no_one` -- get_or_create_conversation()
#       still returns the same row instead of raising, and no second row
#       is created for the same pair.
#
#   Mention Permission (drop_mentions RLS INSERT policy + create_poll_drop()):
#   5.  `no_one` denies a direct `drop_mentions` INSERT (the plain,
#       non-poll Drop creation path -- client inserts into `drops`, then
#       separately into `drop_mentions`) -- but the Drop itself, inserted
#       as its own separate statement, is unaffected/still exists.
#   6.  `no_one` does NOT error `create_poll_drop()` when the mentioned
#       user disallows it -- the Poll Drop is still created successfully,
#       it just silently produces no `drop_mentions` row for that user
#       (mirrors the existing block-exclusion posture, not turned into a
#       hard error).
#   7.  Default (`everyone`, untouched) -- mentioning still works exactly
#       as before this task.
#
#   Comment Permission (drop_comments/pop_comments RLS INSERT policies):
#   8.  `people_i_follow` denies a `drop_comments` INSERT from someone the
#       Drop author does not follow.
#   9.  `people_i_follow` denies a `pop_comments` INSERT from someone the
#       Pop author does not follow.
#   10. `people_i_follow` allows a `drop_comments` INSERT from someone the
#       Drop author DOES follow.
#   11. `people_i_follow` allows a `pop_comments` INSERT from someone the
#       Pop author DOES follow.
#   12. `club_post_comments` is completely unaffected by comment_permission
#       -- the SAME pair of users that CHECK08/09 proved is blocked on
#       Drop/Pop can still comment on that same owner's Club post via
#       approved membership (regression proof Club stays independent).
#   13. Default (`everyone`, untouched) -- commenting still works exactly
#       as before this task.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_039_private_account_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_045_privacy_controls_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn045_privacy_controls_regression_test"
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

-- ------------------------------------------------------------
-- Fixtures
-- ------------------------------------------------------------
-- DM: alice (people_i_follow) / bob (alice follows him) / carol
-- (stranger to alice) / dave (no_one) / eve (dave follows her) / frank
-- (default) / grace (stranger to frank, messages him first while he's
-- still default, then he switches to no_one).
--
-- Mention: mona (no_one) / hank (actor, creates Drops directly and via
-- create_poll_drop()) / nancy (default, regression baseline).
--
-- Comment: olivia (people_i_follow, owns a Drop/Pop/Club) / peter
-- (olivia follows him) / quinn (stranger to olivia, but an approved
-- member of olivia's Club -- proves Club stays independent) / tara
-- (default, owns a Drop) / ursula (stranger to tara, regression
-- baseline actor).
insert into auth.users (id, email) values
  ('65000000-0000-0000-0000-000000000001', 'alice045@test.com'),
  ('65000000-0000-0000-0000-000000000002', 'bob045@test.com'),
  ('65000000-0000-0000-0000-000000000003', 'carol045@test.com'),
  ('65000000-0000-0000-0000-000000000004', 'dave045@test.com'),
  ('65000000-0000-0000-0000-000000000005', 'eve045@test.com'),
  ('65000000-0000-0000-0000-000000000006', 'frank045@test.com'),
  ('65000000-0000-0000-0000-000000000007', 'grace045@test.com'),
  ('65000000-0000-0000-0000-000000000008', 'mona045@test.com'),
  ('65000000-0000-0000-0000-000000000009', 'hank045@test.com'),
  ('65000000-0000-0000-0000-000000000010', 'nancy045@test.com'),
  ('65000000-0000-0000-0000-000000000011', 'olivia045@test.com'),
  ('65000000-0000-0000-0000-000000000012', 'peter045@test.com'),
  ('65000000-0000-0000-0000-000000000013', 'quinn045@test.com'),
  ('65000000-0000-0000-0000-000000000014', 'tara045@test.com'),
  ('65000000-0000-0000-0000-000000000015', 'ursula045@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private, dm_permission, mention_permission, comment_permission) values
  ('65000000-0000-0000-0000-000000000001', 'alice045', 'Alice', 'user', false, 'people_i_follow', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000002', 'bob045', 'Bob', 'user', false, 'everyone', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000003', 'carol045', 'Carol', 'user', false, 'everyone', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000004', 'dave045', 'Dave', 'user', false, 'no_one', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000005', 'eve045', 'Eve', 'user', false, 'everyone', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000006', 'frank045', 'Frank', 'user', false, 'everyone', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000007', 'grace045', 'Grace', 'user', false, 'everyone', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000008', 'mona045', 'Mona', 'user', false, 'everyone', 'no_one', 'everyone'),
  ('65000000-0000-0000-0000-000000000009', 'hank045', 'Hank', 'user', false, 'everyone', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000010', 'nancy045', 'Nancy', 'user', false, 'everyone', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000011', 'olivia045', 'Olivia', 'user', false, 'everyone', 'everyone', 'people_i_follow'),
  ('65000000-0000-0000-0000-000000000012', 'peter045', 'Peter', 'user', false, 'everyone', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000013', 'quinn045', 'Quinn', 'user', false, 'everyone', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000014', 'tara045', 'Tara', 'user', false, 'everyone', 'everyone', 'everyone'),
  ('65000000-0000-0000-0000-000000000015', 'ursula045', 'Ursula', 'user', false, 'everyone', 'everyone', 'everyone');

-- alice follows bob (needed for DM CHECK02) -- direction matters: the
-- recipient (alice)'s own follow list decides who is allowed in,
-- mirroring the existing `active` condition exactly.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  insert into public.follows (follower_id, following_id) values
    ('65000000-0000-0000-0000-000000000001', '65000000-0000-0000-0000-000000000002');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- dave follows eve (needed for DM CHECK03 -- no_one rejects even this).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  insert into public.follows (follower_id, following_id) values
    ('65000000-0000-0000-0000-000000000004', '65000000-0000-0000-0000-000000000005');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- olivia follows peter (needed for Comment CHECK10/11).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000011';
  set request.jwt.claim.role = 'authenticated';
  insert into public.follows (follower_id, following_id) values
    ('65000000-0000-0000-0000-000000000011', '65000000-0000-0000-0000-000000000012');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- Content fixtures (inserted directly, table-owner bypasses RLS -- same
-- convention wyn_044's own test uses).
insert into public.drops (id, author_id, image_url, caption) values
  ('65100000-0000-0000-0000-000000000001', '65000000-0000-0000-0000-000000000011', 'https://example.com/olivia.jpg', 'olivia drop'),
  ('65100000-0000-0000-0000-000000000002', '65000000-0000-0000-0000-000000000014', 'https://example.com/tara.jpg', 'tara drop');

insert into public.pops (id, author_id, video_url, duration_seconds) values
  ('65100000-0000-0000-0000-0000000000a1', '65000000-0000-0000-0000-000000000011', 'https://example.com/olivia.mp4', 15);

insert into public.clubs (id, name, privacy, owner_id) values
  ('65200000-0000-0000-0000-000000000001', 'Olivia Club', 'public', '65000000-0000-0000-0000-000000000011');

-- clubs_add_owner_membership (trigger) already gave olivia an approved
-- owner row -- quinn needs her own approved membership to comment.
insert into public.club_members (club_id, user_id, role, status) values
  ('65200000-0000-0000-0000-000000000001', '65000000-0000-0000-0000-000000000013', 'member', 'approved');

insert into public.club_posts (id, club_id, author_id, content) values
  ('65200000-0000-0000-0000-000000000002', '65200000-0000-0000-0000-000000000001', '65000000-0000-0000-0000-000000000011', 'Hello from Olivia Club');

-- ------------------------------------------------------------
-- DM Permission
-- ------------------------------------------------------------

-- CHECK01: carol (stranger to alice) cannot open a new conversation
-- with alice (dm_permission = people_i_follow).
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.get_or_create_conversation('65000000-0000-0000-0000-000000000001');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK01_dm_people_i_follow_blocks_non_follower', case when v_failed then 1 else 0 end, 1;

  insert into results select 'CHECK01b_dm_people_i_follow_blocked_creates_no_row',
    (select count(*) from public.conversations
     where user_a_id = least('65000000-0000-0000-0000-000000000001'::uuid, '65000000-0000-0000-0000-000000000003'::uuid)
       and user_b_id = greatest('65000000-0000-0000-0000-000000000001'::uuid, '65000000-0000-0000-0000-000000000003'::uuid))::int, 0;
end
$$;

-- CHECK02: bob (alice already follows him) CAN open a new conversation
-- with alice -- status active, same as today's condition.
do $$
declare
  v_id uuid;
  v_status text;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('65000000-0000-0000-0000-000000000001') into v_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select status into v_status from public.conversations where id = v_id;

  insert into results select 'CHECK02_dm_people_i_follow_allows_followed_actor', case when v_status = 'active' then 1 else 0 end, 1;
end
$$;

-- CHECK03: eve cannot open a new conversation with dave (dm_permission
-- = no_one), even though dave follows her -- no exception carve-out.
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.get_or_create_conversation('65000000-0000-0000-0000-000000000004');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK03_dm_no_one_blocks_even_followed_actor', case when v_failed then 1 else 0 end, 1;
end
$$;

-- CHECK04a: grace opens a conversation with frank while he is still
-- default (everyone) -- succeeds, status pending (regression baseline,
-- unchanged from before this task).
do $$
declare
  v_id uuid;
  v_status text;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000007';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('65000000-0000-0000-0000-000000000006') into v_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select status into v_status from public.conversations where id = v_id;

  insert into results select 'CHECK04a_dm_default_everyone_allows_pending_request', case when v_status = 'pending' then 1 else 0 end, 1;
end
$$;

-- frank now locks down to no_one -- the conversation from CHECK04a
-- already exists.
update public.profiles set dm_permission = 'no_one' where id = '65000000-0000-0000-0000-000000000006';

-- CHECK04b/c: grace re-fetching the same conversation does NOT raise
-- (existing conversation, returned as-is before any permission check
-- runs), and no second row is created for the same pair.
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000007';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.get_or_create_conversation('65000000-0000-0000-0000-000000000006');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK04b_dm_existing_conversation_unaffected_by_later_no_one', case when v_failed then 0 else 1 end, 1;

  insert into results select 'CHECK04c_dm_existing_conversation_still_single_row',
    (select count(*) from public.conversations
     where user_a_id = least('65000000-0000-0000-0000-000000000006'::uuid, '65000000-0000-0000-0000-000000000007'::uuid)
       and user_b_id = greatest('65000000-0000-0000-0000-000000000006'::uuid, '65000000-0000-0000-0000-000000000007'::uuid))::int, 1;
end
$$;

-- ------------------------------------------------------------
-- Mention Permission
-- ------------------------------------------------------------

-- hank creates a Drop directly (the plain, non-poll path -- client
-- inserts into drops, then separately into drop_mentions).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000009';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drops (id, author_id, image_url, caption) values
    ('65100000-0000-0000-0000-0000000000d1', '65000000-0000-0000-0000-000000000009', 'https://example.com/hank1.jpg', 'hello @mona045');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK05: hank's direct drop_mentions insert against mona
-- (mention_permission = no_one) is denied by RLS -- but the Drop
-- itself (a separate statement, already committed above) is
-- unaffected.
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000009';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drop_mentions (drop_id, mentioned_user_id) values
      ('65100000-0000-0000-0000-0000000000d1', '65000000-0000-0000-0000-000000000008');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK05a_mention_no_one_blocks_direct_insert', case when v_failed then 1 else 0 end, 1;

  insert into results select 'CHECK05b_mention_no_one_creates_no_row',
    (select count(*) from public.drop_mentions
     where drop_id = '65100000-0000-0000-0000-0000000000d1'
       and mentioned_user_id = '65000000-0000-0000-0000-000000000008')::int, 0;

  insert into results select 'CHECK05c_mention_no_one_drop_itself_still_created',
    (select count(*) from public.drops where id = '65100000-0000-0000-0000-0000000000d1')::int, 1;
end
$$;

-- CHECK06: create_poll_drop() with mona in p_mentioned_user_ids does
-- NOT error -- the Poll Drop is created successfully, just with no
-- drop_mentions row for mona (same non-error posture as block).
do $$
declare
  v_failed boolean := false;
  v_poll_drop_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000009';
  set request.jwt.claim.role = 'authenticated';
  begin
    select public.create_poll_drop(
      'สีที่คุณชอบ', array['แดง', 'น้ำเงิน'], 1,
      array['65000000-0000-0000-0000-000000000008']::uuid[]
    ) into v_poll_drop_id;
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK06a_poll_drop_mention_no_one_does_not_error', case when v_failed then 0 else 1 end, 1;

  insert into results select 'CHECK06b_poll_drop_mention_no_one_drop_created',
    (select count(*) from public.drops where id = v_poll_drop_id)::int, 1;

  insert into results select 'CHECK06c_poll_drop_mention_no_one_creates_no_row',
    (select count(*) from public.drop_mentions
     where drop_id = v_poll_drop_id and mentioned_user_id = '65000000-0000-0000-0000-000000000008')::int, 0;
end
$$;

-- CHECK07: default (everyone, untouched) -- mentioning nancy still
-- works exactly as before this task.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000009';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drops (id, author_id, image_url, caption) values
    ('65100000-0000-0000-0000-0000000000d2', '65000000-0000-0000-0000-000000000009', 'https://example.com/hank2.jpg', 'hello @nancy045');
  insert into public.drop_mentions (drop_id, mentioned_user_id) values
    ('65100000-0000-0000-0000-0000000000d2', '65000000-0000-0000-0000-000000000010');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK07_mention_default_everyone_unchanged',
    (select count(*) from public.drop_mentions
     where drop_id = '65100000-0000-0000-0000-0000000000d2'
       and mentioned_user_id = '65000000-0000-0000-0000-000000000010')::int, 1;
end
$$;

-- ------------------------------------------------------------
-- Comment Permission
-- ------------------------------------------------------------

-- CHECK08: quinn (stranger to olivia) cannot comment on olivia's Drop
-- (comment_permission = people_i_follow).
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000013';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drop_comments (drop_id, author_id, text_content) values
      ('65100000-0000-0000-0000-000000000001', '65000000-0000-0000-0000-000000000013', 'nice drop');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK08_comment_people_i_follow_blocks_non_follower_drop', case when v_failed then 1 else 0 end, 1;
end
$$;

-- CHECK09: quinn cannot comment on olivia's Pop either.
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000013';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.pop_comments (pop_id, author_id, text_content) values
      ('65100000-0000-0000-0000-0000000000a1', '65000000-0000-0000-0000-000000000013', 'nice pop');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK09_comment_people_i_follow_blocks_non_follower_pop', case when v_failed then 1 else 0 end, 1;
end
$$;

-- CHECK10: peter (olivia follows him) CAN comment on olivia's Drop.
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000012';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drop_comments (drop_id, author_id, text_content) values
      ('65100000-0000-0000-0000-000000000001', '65000000-0000-0000-0000-000000000012', 'nice drop');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK10_comment_people_i_follow_allows_followed_actor_drop', case when v_failed then 0 else 1 end, 1;
end
$$;

-- CHECK11: peter CAN comment on olivia's Pop too.
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000012';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.pop_comments (pop_id, author_id, text_content) values
      ('65100000-0000-0000-0000-0000000000a1', '65000000-0000-0000-0000-000000000012', 'nice pop');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK11_comment_people_i_follow_allows_followed_actor_pop', case when v_failed then 0 else 1 end, 1;
end
$$;

-- CHECK12: the SAME pair (olivia/quinn) that CHECK08/09 proved is
-- blocked on Drop/Pop -- quinn, as an approved Club member, can still
-- comment on olivia's Club post. club_post_comments is a completely
-- separate policy that never gained a comment_allowed() check --
-- regression proof Club stays independent.
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000013';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_post_comments (club_post_id, author_id, text_content) values
      ('65200000-0000-0000-0000-000000000002', '65000000-0000-0000-0000-000000000013', 'nice club post');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK12_club_post_comments_unaffected_by_comment_permission', case when v_failed then 0 else 1 end, 1;
end
$$;

-- CHECK13: default (everyone, untouched) -- ursula (a stranger tara
-- does not follow) can still comment on tara's Drop, same as before
-- this task.
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '65000000-0000-0000-0000-000000000015';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drop_comments (drop_id, author_id, text_content) values
      ('65100000-0000-0000-0000-000000000002', '65000000-0000-0000-0000-000000000015', 'nice drop');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK13_comment_default_everyone_unchanged', case when v_failed then 0 else 1 end, 1;
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
