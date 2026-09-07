#!/usr/bin/env bash
# Regression test for WYN-134 (DM "New Message" Notification) -- proves
# the security-sensitive behavior actually works at the RLS/RPC/trigger
# layer, under the real `authenticated` role (not the Postgres
# superuser, which bypasses RLS entirely), mirroring
# wyn_032_message_request_test.sh's exact harness/role-switching
# convention.
#
#   1. notify_new_message(): fires exactly once per new message in an
#      'active' conversation, recipient computed correctly regardless
#      of which side sent it (least/greatest user_a/user_b ordering).
#   2. Respects conversation_mutes -- a muted recipient gets no
#      new_message notification at all while muted, resumes once
#      unmuted.
#   3. Respects notification_settings.messages -- disabled means no
#      new_message notification, same as WYN-032's message_request
#      already does via the same internal.notification_enabled() gate.
#   4. Never fires for a 'pending' conversation, even when the
#      requester keeps sending while waiting (message_request already
#      covers that conversation once, at creation -- see
#      wyn_032_message_request_test.sh's own CHECK3/CHECK4b).
#   5. mark_conversation_read() clears is_read on every unread
#      new_message notification for that conversation/recipient in the
#      same call, and this doesn't regress its original WYN-031
#      behavior (still updates the caller's own last_read_at column,
#      still rejects a non-participant).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_032_message_request_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_134_dm_new_message_notification_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway DB.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn134_new_message_notification_regression_test"
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

-- alice/bob: bob already follows alice, so alice -> bob starts active
-- immediately (WYN-031/032 regression, no gate). carol/dave: strangers
-- to each other, so carol -> dave starts pending.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'user'),
  ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'user');

-- bob already follows alice -- makes alice a "known" sender from bob's
-- perspective, so alice -> bob starts 'active' immediately.
insert into public.follows (follower_id, following_id) values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111');

-- ------------------------------------------------------------
-- Setup: alice <-> bob active conversation; carol -> dave pending.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('22222222-2222-2222-2222-222222222222'::uuid) into v_conv_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'SETUP_alice_bob_active', (case when status = 'active' then 1 else 0 end), 1
  from public.conversations where id = v_conv_id;

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.get_or_create_conversation('44444444-4444-4444-4444-444444444444'::uuid);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK1: alice sends the first real message in the active
-- conversation -- bob gets exactly one new_message notification,
-- unread, with the right actor/conversation.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '11111111-1111-1111-1111-111111111111'::uuid and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid)
     or (user_a_id = '22222222-2222-2222-2222-222222222222'::uuid and user_b_id = '11111111-1111-1111-1111-111111111111'::uuid);

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'สวัสดีบ๊อบ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK1_bob_gets_one_unread_new_message_notification', count(*), 1
  from public.notifications
  where recipient_id = '22222222-2222-2222-2222-222222222222'::uuid
    and actor_id = '11111111-1111-1111-1111-111111111111'::uuid
    and type = 'new_message'
    and conversation_id = v_conv_id
    and is_read = false;
end
$$;

-- ------------------------------------------------------------
-- CHECK2: bob mutes the conversation -- alice's next message creates
-- no new new_message notification (total stays at 1).
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
  v_count int;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '11111111-1111-1111-1111-111111111111'::uuid and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid)
     or (user_a_id = '22222222-2222-2222-2222-222222222222'::uuid and user_b_id = '11111111-1111-1111-1111-111111111111'::uuid);

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.conversation_mutes (conversation_id, user_id) values (v_conv_id, '22222222-2222-2222-2222-222222222222');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'ข้อความตอนถูกปิดแจ้งเตือน');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '22222222-2222-2222-2222-222222222222'::uuid and type = 'new_message';
  insert into results values ('CHECK2_muted_conversation_gets_no_new_notification', v_count, 1);
end
$$;

-- ------------------------------------------------------------
-- CHECK3: bob unmutes, then disables the 'messages' notification
-- category entirely -- alice's next message still creates no new
-- new_message notification (total still 1), same
-- internal.notification_enabled() gate message_request already uses.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
  v_count int;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '11111111-1111-1111-1111-111111111111'::uuid and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid)
     or (user_a_id = '22222222-2222-2222-2222-222222222222'::uuid and user_b_id = '11111111-1111-1111-1111-111111111111'::uuid);

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  delete from public.conversation_mutes where conversation_id = v_conv_id and user_id = '22222222-2222-2222-2222-222222222222';
  insert into public.notification_settings (user_id, messages) values ('22222222-2222-2222-2222-222222222222', false)
    on conflict (user_id) do update set messages = false;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'ข้อความตอนปิดแจ้งเตือนข้อความ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '22222222-2222-2222-2222-222222222222'::uuid and type = 'new_message';
  insert into results values ('CHECK3_disabled_messages_category_gets_no_new_notification', v_count, 1);
end
$$;

-- ------------------------------------------------------------
-- CHECK4: bob re-enables messages -- alice's next message creates a
-- second new_message notification (total becomes 2).
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
  v_count int;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '11111111-1111-1111-1111-111111111111'::uuid and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid)
     or (user_a_id = '22222222-2222-2222-2222-222222222222'::uuid and user_b_id = '11111111-1111-1111-1111-111111111111'::uuid);

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  update public.notification_settings set messages = true where user_id = '22222222-2222-2222-2222-222222222222';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'เปิดแจ้งเตือนแล้ว');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '22222222-2222-2222-2222-222222222222'::uuid and type = 'new_message';
  insert into results values ('CHECK4_reenabled_messages_gets_second_notification', v_count, 2);
end
$$;

-- ------------------------------------------------------------
-- CHECK5: the reverse direction also works -- bob sending to alice
-- notifies alice (recipient is computed correctly regardless of
-- which side is user_a/user_b).
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
  v_count int;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '11111111-1111-1111-1111-111111111111'::uuid and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid)
     or (user_a_id = '22222222-2222-2222-2222-222222222222'::uuid and user_b_id = '11111111-1111-1111-1111-111111111111'::uuid);

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '22222222-2222-2222-2222-222222222222', 'ตอบกลับอลิซ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '11111111-1111-1111-1111-111111111111'::uuid
    and actor_id = '22222222-2222-2222-2222-222222222222'::uuid
    and type = 'new_message';
  insert into results values ('CHECK5_reverse_direction_notifies_alice', v_count, 1);
end
$$;

-- ------------------------------------------------------------
-- CHECK6-7: mark_conversation_read() clears every unread new_message
-- notification for that conversation/recipient, and still updates the
-- caller's own last_read_at column (WYN-031 regression).
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
  v_unread_count int;
  v_last_read timestamptz;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '11111111-1111-1111-1111-111111111111'::uuid and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid)
     or (user_a_id = '22222222-2222-2222-2222-222222222222'::uuid and user_b_id = '11111111-1111-1111-1111-111111111111'::uuid);

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  perform public.mark_conversation_read(v_conv_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_unread_count from public.notifications
  where recipient_id = '22222222-2222-2222-2222-222222222222'::uuid
    and conversation_id = v_conv_id
    and type = 'new_message'
    and is_read = false;
  insert into results values ('CHECK6_mark_conversation_read_clears_unread_new_message', v_unread_count, 0);

  select user_b_last_read_at into v_last_read from public.conversations where id = v_conv_id;
  insert into results values ('CHECK7_mark_conversation_read_still_updates_last_read_at', (case when v_last_read is not null then 1 else 0 end), 1);
end
$$;

-- ------------------------------------------------------------
-- CHECK8: mark_conversation_read() still rejects a non-participant
-- (WYN-031 regression).
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '11111111-1111-1111-1111-111111111111'::uuid and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid)
     or (user_a_id = '22222222-2222-2222-2222-222222222222'::uuid and user_b_id = '11111111-1111-1111-1111-111111111111'::uuid);

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.mark_conversation_read(v_conv_id);
    insert into results values ('CHECK8_non_participant_cannot_mark_read', 0, 1);
  exception when others then
    insert into results values ('CHECK8_non_participant_cannot_mark_read', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK9: a still-'pending' conversation never gets a new_message
-- notification, even when the requester (carol) keeps sending while
-- dave hasn't decided yet -- message_request already covered this
-- conversation once, at creation (see
-- wyn_032_message_request_test.sh's own CHECK3/CHECK4b).
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
  v_count int;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '33333333-3333-3333-3333-333333333333'::uuid and user_b_id = '44444444-4444-4444-4444-444444444444'::uuid)
     or (user_a_id = '44444444-4444-4444-4444-444444444444'::uuid and user_b_id = '33333333-3333-3333-3333-333333333333'::uuid);

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '33333333-3333-3333-3333-333333333333', 'ยังรอเดฟตอบรับอยู่');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.notifications
  where recipient_id = '44444444-4444-4444-4444-444444444444'::uuid and type = 'new_message';
  insert into results values ('CHECK9_pending_conversation_never_gets_new_message', v_count, 0);
end
$$;

select check_name, actual, expected from results order by check_name;
EOF

if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME" >&2
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then
  echo "FAIL: stub setup failed" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$SCHEMA_FILE"; then
  echo "FAIL: schema.sql failed to load cleanly" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

echo "== Seeding fixtures and running RLS/RPC/trigger checks =="
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
    CHECK*|SETUP*)
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
