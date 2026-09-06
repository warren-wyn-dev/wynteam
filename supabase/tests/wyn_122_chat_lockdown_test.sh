#!/usr/bin/env bash
# Regression test for WYN-122 (Founder: "ปิดระบบ แชทไม่ให้คนใช้ทั่วไป ยกเว้น
# @warren กับ @wynos_online จะเอาไว้ทดสอบ ก่อนเปิดใช้งานจริง") -- proves the
# chat lockdown allowlist mechanism enforces "both participants must be
# allowlisted" at the real RLS/RPC layer under the `authenticated` role
# (not the Postgres superuser, which bypasses RLS entirely), mirroring
# wyn_037_edit_delete_drop_test.sh/wyn_120_*_test.sh's exact
# harness/role-switching convention.
#
#   1. Lockdown OFF (default state before Founder's request): two
#      regular users can create a conversation and message each other
#      normally -- baseline, nothing broken by this feature's mere
#      existence.
#   2. Lockdown ON: two regular users (neither allowlisted) cannot
#      create a new conversation with each other -- get_or_create_
#      conversation() raises.
#   3. Lockdown ON: a regular user cannot start a conversation with an
#      *allowlisted* user either (warren) -- confirms the rule is
#      "both sides must be allowlisted", not "either side".
#   4. Lockdown ON: the two allowlisted users (warren, wynos_online)
#      can create a conversation and send messages to each other
#      completely normally.
#   5. Lockdown ON: a regular user's conversation that already existed
#      *before* lockdown was turned on (with another regular user)
#      disappears entirely from that user's own SELECT -- not just
#      blocked from new sends, matching the Founder's explicit "ซ่อน
#      ทั้งหมดระหว่างปิดระบบ" confirmation.
#   6. Lockdown ON: that same pre-existing conversation's messages are
#      also hidden from both participants.
#   7. Lockdown ON: neither participant can send a *new* message into
#      that pre-existing (now-hidden) conversation.
#   8. Lockdown ON: count_unread_conversations() (the Chat icon badge)
#      does not count messages from a hidden conversation -- proves
#      the SECURITY DEFINER badge function was updated too, not just
#      the RLS policies (a security definer function bypasses RLS by
#      default and needed its own explicit check).
#   9. Regression: no data was deleted or altered by turning lockdown
#      on -- the pre-existing conversation/message rows still
#      physically exist (superuser read, bypassing RLS).
#   10. Toggle lockdown back OFF: the regular users' old conversation
#       becomes visible and usable again -- full reversibility with
#       zero data loss, proving Acceptance Criteria #6/#7.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_037_edit_delete_drop_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_122_chat_lockdown_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn122_chat_lockdown_regression_test"
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

-- alice, bob: regular users. warren, wynos_online: the 2 testers that
-- stay allowlisted. carol: a 3rd regular user, for the "existing
-- conversation gets hidden" checks (alice<->carol conversation
-- predates lockdown).
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'warren@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'wynos_online@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'user'),
  ('44444444-4444-4444-4444-444444444444', 'warren', 'Warren', 'admin'),
  ('55555555-5555-5555-5555-555555555555', 'wynos_online', 'Wynos.online', 'user');

-- alice and carol already follow each other, and warren/bob too --
-- keeps every conversation created below 'active' immediately (not
-- 'pending'), so this test isn't also exercising WYN-032's Message
-- Request gate at the same time.
insert into public.follows (follower_id, following_id) values
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333'),
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111'),
  ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'),
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111'),
  ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444'),
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111'),
  ('44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555'),
  ('55555555-5555-5555-5555-555555555555', '44444444-4444-4444-4444-444444444444');

-- ------------------------------------------------------------
-- CHECK1: lockdown OFF (default) -- alice and bob, both regular
-- users, can create a conversation and message each other normally.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  v_conv_id := public.get_or_create_conversation('22222222-2222-2222-2222-222222222222');
  insert into public.messages (conversation_id, sender_id, text)
  values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'สวัสดี บ็อบ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK1_lockdown_off_regular_pair_can_chat', count(*), 1
  from public.messages where conversation_id = v_conv_id;

  perform set_config('wyn122.alice_bob_conv', v_conv_id::text, false);
end
$$;

-- alice<->carol conversation, created *before* lockdown is turned on
-- -- used below to prove pre-existing conversations get hidden, not
-- just newly-attempted ones.
do $$
declare
  v_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  v_conv_id := public.get_or_create_conversation('33333333-3333-3333-3333-333333333333');
  insert into public.messages (conversation_id, sender_id, text)
  values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'แคโรล จำข้อความนี้ไว้นะ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- carol replies, so there's an unread message from carol's side for
  -- CHECK8's badge-count assertion below.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text)
  values (v_conv_id, '33333333-3333-3333-3333-333333333333', 'ได้ค่ะ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  perform set_config('wyn122.alice_carol_conv', v_conv_id::text, false);
end
$$;

-- ------------------------------------------------------------
-- Turn lockdown ON, allowlist only warren + wynos_online -- table-
-- owner writes, bypassing RLS (mirrors how every other test fixture
-- in this suite seeds data directly).
-- ------------------------------------------------------------
update public.chat_lockdown set enabled = true where id;
insert into public.chat_lockdown_allowlist (user_id) values
  ('44444444-4444-4444-4444-444444444444'),
  ('55555555-5555-5555-5555-555555555555');

-- ------------------------------------------------------------
-- CHECK2: lockdown ON -- bob (regular, not allowlisted) tries to
-- start a NEW conversation with alice (also regular) -- must raise.
-- ------------------------------------------------------------
do $$
declare
  v_failed boolean := false;
begin
  begin
    set role authenticated;
    set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
    set request.jwt.claim.role = 'authenticated';
    perform public.get_or_create_conversation('33333333-3333-3333-3333-333333333333');
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;
  insert into results select 'CHECK2_lockdown_on_regular_pair_new_conv_raises', case when v_failed then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK3: lockdown ON -- alice (regular) tries to start a conversation
-- with warren (allowlisted) -- still must raise, because BOTH sides
-- must be allowlisted, not just one. This is the exact rule the
-- Founder confirmed ("ไม่ได้เลย -- เอแชทกับใครไม่ได้ทั้งนั้นช่วงปิดระบบ").
-- ------------------------------------------------------------
do $$
declare
  v_failed boolean := false;
begin
  begin
    set role authenticated;
    set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
    set request.jwt.claim.role = 'authenticated';
    perform public.get_or_create_conversation('44444444-4444-4444-4444-444444444444');
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;
  insert into results select 'CHECK3_lockdown_on_regular_to_allowlisted_raises', case when v_failed then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK4: lockdown ON -- warren and wynos_online (both allowlisted)
-- can create a conversation and message each other completely
-- normally.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  v_conv_id := public.get_or_create_conversation('55555555-5555-5555-5555-555555555555');
  insert into public.messages (conversation_id, sender_id, text)
  values (v_conv_id, '44444444-4444-4444-4444-444444444444', 'ทดสอบระบบแชทกันนะ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK4_lockdown_on_allowlisted_pair_can_chat', count(*), 1
  from public.messages where conversation_id = v_conv_id;
end
$$;

-- ------------------------------------------------------------
-- CHECK5-6: lockdown ON -- alice<->carol's pre-existing conversation
-- (created before lockdown) is now fully hidden from BOTH of them --
-- not just blocked from new sends.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid := current_setting('wyn122.alice_carol_conv')::uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK5_old_conversation_hidden_from_alice',
    (select count(*) from public.conversations where id = v_conv_id), 0;
  insert into results
  select 'CHECK6_old_messages_hidden_from_alice',
    (select count(*) from public.messages where conversation_id = v_conv_id), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK6b_old_messages_hidden_from_carol',
    (select count(*) from public.messages where conversation_id = v_conv_id), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK7: lockdown ON -- alice cannot send a NEW message into that
-- now-hidden pre-existing conversation either.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid := current_setting('wyn122.alice_carol_conv')::uuid;
  v_failed boolean := false;
begin
  begin
    set role authenticated;
    set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
    set request.jwt.claim.role = 'authenticated';
    insert into public.messages (conversation_id, sender_id, text)
    values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'ยังส่งได้อยู่ไหม');
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;
  insert into results select 'CHECK7_cannot_send_into_hidden_conversation', case when v_failed then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK8: lockdown ON -- alice's unread badge count no longer counts
-- carol's unread reply sitting in the now-hidden conversation.
-- count_unread_conversations() is SECURITY DEFINER and bypasses RLS
-- entirely, so this proves the badge function's own explicit check
-- was added, not just the RLS policies.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK8_unread_badge_excludes_hidden_conversation',
    public.count_unread_conversations(), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK9: regression -- no data was deleted/altered by turning
-- lockdown on. The alice<->carol conversation and both its messages
-- still physically exist (table-owner read, bypassing RLS).
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid := current_setting('wyn122.alice_carol_conv')::uuid;
begin
  insert into results
  select 'CHECK9_old_conversation_row_still_exists', count(*), 1
  from public.conversations where id = v_conv_id;
  insert into results
  select 'CHECK9b_old_messages_still_exist', count(*), 2
  from public.messages where conversation_id = v_conv_id;
end
$$;

-- ------------------------------------------------------------
-- CHECK10: toggle lockdown back OFF -- alice<->carol's conversation
-- and messages become visible and usable again, with zero data loss.
-- ------------------------------------------------------------
update public.chat_lockdown set enabled = false where id;

do $$
declare
  v_conv_id uuid := current_setting('wyn122.alice_carol_conv')::uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK10_conversation_visible_again_after_toggle_off',
    (select count(*) from public.conversations where id = v_conv_id), 1;
  insert into results
  select 'CHECK10b_old_messages_visible_again',
    (select count(*) from public.messages where conversation_id = v_conv_id), 2;

  -- can send again, too.
  insert into public.messages (conversation_id, sender_id, text)
  values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'กลับมาแชทได้แล้ว');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK10c_can_send_again_after_toggle_off', count(*), 3
  from public.messages where conversation_id = v_conv_id;
end
$$;

-- ------------------------------------------------------------
-- CHECK11: regression -- bob (regular, blocked from a NEW conversation
-- at CHECK2 while lockdown was on) can now start one normally too,
-- proving the toggle-off restores *everyone*, not just the pair that
-- already had a conversation.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  v_conv_id := public.get_or_create_conversation('33333333-3333-3333-3333-333333333333');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK11_regular_pair_can_create_new_conv_after_toggle_off', count(*), 1
  from public.conversations where id = v_conv_id;
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
