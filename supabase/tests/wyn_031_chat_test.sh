#!/usr/bin/env bash
# Regression test for WYN-031 (1:1 Chat) -- proves the security-sensitive
# behavior actually works at the RLS/RPC layer, under the real
# `authenticated` role (not the Postgres superuser, which bypasses RLS
# entirely), mirroring wyn_029_moderation_queue_test.sh/
# wyn_030_appeal_system_test.sh's exact harness/role-switching convention.
#
#   1. get_or_create_conversation(): rejects self-chat and a
#      blocked-either-way pair, normalizes to canonical (user_a_id <
#      user_b_id) order regardless of caller/callee order, and is
#      idempotent (a second call returns the same row, not a duplicate).
#   2. RLS on `conversations`: only the 2 participants can see a
#      conversation row; a third user gets zero rows.
#   3. messages INSERT policy: a participant can send in an active
#      conversation; a non-participant cannot; a block created *after*
#      the conversation exists blocks further sends; a Restricted
#      (posting-blocked) participant cannot send even into their own
#      conversation.
#   4. RLS on `messages` SELECT: a non-participant gets zero rows.
#   5. prevent_cross_conversation_reply trigger: replying with a
#      message id that belongs to a different conversation is rejected;
#      a same-conversation reply succeeds.
#   6. delete_message(): only the sender can delete their own message,
#      and it nulls text/image_url rather than just flagging a column
#      (deleted_at set, text/image_url both null afterward).
#   7. conversations_canonical_order check constraint catches a
#      reversed-order row even from a direct insert (not just
#      get_or_create_conversation()'s own normalization).
#   8. submit_report()'s `message` branch: a participant can report the
#      other side's message; reporting your own message is rejected;
#      reporting a message from a conversation you're not part of is
#      rejected.
#   9. get_message_for_moderation(): a moderator gets the row, an
#      ordinary user (even a participant) gets zero rows.
#   10. RLS on `conversation_mutes`: a user can only insert/view/delete
#       their own mute row, never another user's.
#   11. RLS on the `chat-media` storage bucket: a participant can
#       INSERT under their conversation's folder, a non-participant
#       cannot.
#   12. mark_conversation_read()/count_unread_conversations(): unread
#       count is 1 right after the other side sends, and drops to 0
#       after the caller marks the conversation read -- and
#       mark_conversation_read() only ever touches the caller's own
#       read-timestamp column.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_030_appeal_system_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_031_chat_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway DB.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn031_chat_regression_test"
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

-- Real Supabase projects ship storage.objects with RLS already enabled
-- by the platform -- schema.sql only ever adds policies to it, never
-- enables RLS itself. This stub has to do that one platform-level step
-- itself for the chat-media policies below to mean anything.
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

-- alice/bob: the 1:1 conversation's 2 participants. carol: moderator.
-- dave: an uninvolved third user (never a participant, never a
-- moderator). eve: gets blocked by alice mid-conversation, to prove a
-- block created *after* the conversation exists still cuts off sends.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'eve@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'moderator'),
  ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'user'),
  ('55555555-5555-5555-5555-555555555555', 'eve', 'Eve', 'user');

insert into storage.buckets (id, name, public) values ('chat-media', 'chat-media', false)
  on conflict (id) do nothing;

-- ------------------------------------------------------------
-- CHECK 1-4: get_or_create_conversation() validation + canonical
-- ordering + idempotency.
-- ------------------------------------------------------------

-- CHECK1: alice can't start a conversation with herself.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.get_or_create_conversation('11111111-1111-1111-1111-111111111111'::uuid);
    insert into results values ('CHECK1_self_chat_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK1_self_chat_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- alice blocks eve (used by CHECK2 and CHECK8 below).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.block_user('55555555-5555-5555-5555-555555555555'::uuid);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK2: eve (the blocked side) can't start a conversation with alice
-- either -- is_blocked_either_way() is direction-agnostic.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.get_or_create_conversation('11111111-1111-1111-1111-111111111111'::uuid);
    insert into results values ('CHECK2_blocked_either_way_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK2_blocked_either_way_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK3: alice starts a conversation with bob -- must succeed and
-- normalize to canonical order (alice's uuid < bob's uuid already, but
-- assert it explicitly rather than assuming).
do $$
declare
  v_conv_id uuid;
  v_a uuid;
  v_b uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('22222222-2222-2222-2222-222222222222'::uuid) into v_conv_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select user_a_id, user_b_id into v_a, v_b from public.conversations where id = v_conv_id;
  insert into results values ('CHECK3_conversation_created_canonical_order', (case when v_a < v_b then 1 else 0 end), 1);
end
$$;

-- CHECK4: bob starting the *same* conversation (callee/caller
-- reversed) must return the same row, not a second one.
do $$
declare
  v_conv_id_bob uuid;
  v_conv_id_alice uuid;
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('11111111-1111-1111-1111-111111111111'::uuid) into v_conv_id_bob;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select id into v_conv_id_alice from public.conversations
  where user_a_id = '11111111-1111-1111-1111-111111111111'::uuid
    and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid;

  select count(*) into v_count from public.conversations
  where user_a_id = '11111111-1111-1111-1111-111111111111'::uuid
    and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid;

  insert into results values ('CHECK4a_idempotent_same_row', (case when v_conv_id_bob = v_conv_id_alice then 1 else 0 end), 1);
  insert into results values ('CHECK4b_idempotent_no_duplicate_row', v_count, 1);
end
$$;

-- ------------------------------------------------------------
-- CHECK 5: RLS on `conversations` -- only alice/bob see their
-- conversation; dave (uninvolved) sees zero rows for it.
-- ------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK5_unrelated_user_sees_no_conversation', count(*), 0
from public.conversations
where user_a_id = '11111111-1111-1111-1111-111111111111'::uuid
  and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 6-9: messages INSERT policy.
-- ------------------------------------------------------------

-- CHECK6: alice (a real participant) can send in her active conversation.
do $$
declare
  v_conv_id uuid;
  v_msg_id uuid;
begin
  select id into v_conv_id from public.conversations
  where user_a_id = '11111111-1111-1111-1111-111111111111'::uuid
    and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid;

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (id, conversation_id, sender_id, text)
  values ('b0000000-0000-0000-0000-000000000001', v_conv_id, '11111111-1111-1111-1111-111111111111', 'สวัสดีบ๊อบ')
  returning id into v_msg_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK6_participant_can_send', (case when v_msg_id is not null then 1 else 0 end), 1);
end
$$;

-- CHECK7: dave (not a participant) cannot insert into alice/bob's
-- conversation, even claiming to be the sender himself.
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where user_a_id = '11111111-1111-1111-1111-111111111111'::uuid
    and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid;

  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.messages (conversation_id, sender_id, text)
    values (v_conv_id, '44444444-4444-4444-4444-444444444444', 'แอบส่ง');
    insert into results values ('CHECK7_non_participant_send_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK7_non_participant_send_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- alice and bob start a second conversation (with carol acting only as
-- moderator elsewhere -- this is bob<->carol is NOT needed; instead
-- reuse eve for the block-after-conversation-exists case: eve creates
-- a fresh conversation with dave first (unblocked), then alice's block
-- on eve is irrelevant here -- so instead: dave and eve start a
-- conversation while unblocked, then dave blocks eve, then eve's send
-- must fail).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  perform public.get_or_create_conversation('55555555-5555-5555-5555-555555555555'::uuid);
  perform public.block_user('55555555-5555-5555-5555-555555555555'::uuid);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK8: eve tries to send into the dave<->eve conversation after
-- dave blocked her -- the conversation row still exists, but the
-- block (created after the fact) must still cut off sending.
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '44444444-4444-4444-4444-444444444444'::uuid and user_b_id = '55555555-5555-5555-5555-555555555555'::uuid)
     or (user_a_id = '55555555-5555-5555-5555-555555555555'::uuid and user_b_id = '44444444-4444-4444-4444-444444444444'::uuid);

  set role authenticated;
  set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.messages (conversation_id, sender_id, text)
    values (v_conv_id, '55555555-5555-5555-5555-555555555555', 'ขอคุยหน่อย');
    insert into results values ('CHECK8_send_after_block_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK8_send_after_block_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- Restrict carol (a moderator, but posting-block applies to anyone) so
-- CHECK9 can prove a posting-blocked participant can't send.
insert into public.reports (id, reporter_id, target_type, target_id, category, status) values
  ('30000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'user', '33333333-3333-3333-3333-333333333333', 'spam', 'actioned');
insert into public.moderation_actions (id, report_id, target_user_id, reviewer_id, action_type, reason, duration_days, expires_at) values
  ('a0000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'restrict', 'spam', 3, now() + interval '3 days');

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.get_or_create_conversation('33333333-3333-3333-3333-333333333333'::uuid);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK9: carol (Restricted, i.e. posting-blocked) cannot send even
-- though she's a real participant in an active, unblocked conversation.
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '11111111-1111-1111-1111-111111111111'::uuid and user_b_id = '33333333-3333-3333-3333-333333333333'::uuid)
     or (user_a_id = '33333333-3333-3333-3333-333333333333'::uuid and user_b_id = '11111111-1111-1111-1111-111111111111'::uuid);

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.messages (conversation_id, sender_id, text)
    values (v_conv_id, '33333333-3333-3333-3333-333333333333', 'ฉันโดนจำกัดอยู่');
    insert into results values ('CHECK9_posting_blocked_participant_send_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK9_posting_blocked_participant_send_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 10: RLS on `messages` SELECT -- dave (not a participant of
-- alice/bob's conversation) gets zero rows.
-- ------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK10_non_participant_sees_no_messages', count(*), 0
from public.messages where id = 'b0000000-0000-0000-0000-000000000001'::uuid;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 11-12: prevent_cross_conversation_reply trigger.
-- ------------------------------------------------------------

-- bob replies within the same conversation to alice's message -- must
-- succeed.
do $$
declare
  v_conv_id uuid;
  v_reply_id uuid;
begin
  select id into v_conv_id from public.conversations
  where user_a_id = '11111111-1111-1111-1111-111111111111'::uuid
    and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid;

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text, reply_to_message_id)
  values (v_conv_id, '22222222-2222-2222-2222-222222222222', 'สวัสดีอลิซ', 'b0000000-0000-0000-0000-000000000001')
  returning id into v_reply_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK11_same_conversation_reply_succeeds', (case when v_reply_id is not null then 1 else 0 end), 1);
end
$$;

-- CHECK12: alice tries to reply, inside the dave<->eve conversation,
-- to a message that actually lives in the alice<->bob conversation --
-- the trigger must reject the cross-conversation reference regardless
-- of who's sending.
do $$
declare
  v_dave_eve_conv_id uuid;
begin
  select id into v_dave_eve_conv_id from public.conversations
  where (user_a_id = '44444444-4444-4444-4444-444444444444'::uuid and user_b_id = '55555555-5555-5555-5555-555555555555'::uuid)
     or (user_a_id = '55555555-5555-5555-5555-555555555555'::uuid and user_b_id = '44444444-4444-4444-4444-444444444444'::uuid);

  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.messages (conversation_id, sender_id, text, reply_to_message_id)
    values (v_dave_eve_conv_id, '44444444-4444-4444-4444-444444444444', 'ข้ามบทสนทนา', 'b0000000-0000-0000-0000-000000000001');
    insert into results values ('CHECK12_cross_conversation_reply_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK12_cross_conversation_reply_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 13-15: delete_message() -- only the sender, and it nulls
-- content rather than just flagging a column.
-- ------------------------------------------------------------

-- CHECK13: bob (not the sender) can't delete alice's message.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.delete_message('b0000000-0000-0000-0000-000000000001'::uuid);
    insert into results values ('CHECK13_non_sender_delete_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK13_non_sender_delete_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK14/15: alice (the sender) deletes her own message -- content
-- nulled, deleted_at set.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.delete_message('b0000000-0000-0000-0000-000000000001'::uuid);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;
insert into results
select 'CHECK14_deleted_message_text_nulled',
  (case when text is null and image_url is null then 1 else 0 end), 1
from public.messages where id = 'b0000000-0000-0000-0000-000000000001'::uuid;
insert into results
select 'CHECK15_deleted_message_deleted_at_set',
  (case when deleted_at is not null then 1 else 0 end), 1
from public.messages where id = 'b0000000-0000-0000-0000-000000000001'::uuid;

-- ------------------------------------------------------------
-- CHECK 16: conversations_canonical_order check constraint catches a
-- reversed-order row even from a direct table-owner insert (proves
-- it's a real DB-level guarantee, not just get_or_create_conversation()
-- remembering to normalize).
-- ------------------------------------------------------------
do $$
begin
  begin
    insert into public.conversations (user_a_id, user_b_id)
    values ('22222222-2222-2222-2222-222222222222'::uuid, '11111111-1111-1111-1111-111111111111'::uuid);
    insert into results values ('CHECK16_reversed_order_constraint_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK16_reversed_order_constraint_rejected', 1, 1);
  end;
end
$$;

-- ------------------------------------------------------------
-- CHECK 17-19: submit_report()'s `message` branch.
-- ------------------------------------------------------------

-- bob sends a fresh, non-deleted message for these checks to target.
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where user_a_id = '11111111-1111-1111-1111-111111111111'::uuid
    and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid;

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (id, conversation_id, sender_id, text)
  values ('b0000000-0000-0000-0000-000000000002', v_conv_id, '22222222-2222-2222-2222-222222222222', 'ข้อความที่จะโดนรายงาน');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK17: alice (a real participant, not the sender) reports bob's
-- message -- must succeed.
do $$
declare
  v_report_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.submit_report('message', 'b0000000-0000-0000-0000-000000000002'::uuid, 'harassment', 'ข้อความไม่เหมาะสม') into v_report_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK17_participant_report_message_succeeds', (case when v_report_id is not null then 1 else 0 end), 1);
end
$$;

-- CHECK18: bob (the sender) can't report his own message.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_report('message', 'b0000000-0000-0000-0000-000000000002'::uuid, 'harassment', 'ข้อความของตัวเอง');
    insert into results values ('CHECK18_report_own_message_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK18_report_own_message_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK19: dave (not a participant of the alice<->bob conversation)
-- can't report a message from it.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_report('message', 'b0000000-0000-0000-0000-000000000002'::uuid, 'harassment', 'ฉันไม่เกี่ยว');
    insert into results values ('CHECK19_non_participant_report_message_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK19_non_participant_report_message_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 20-21: get_message_for_moderation() -- moderator-only gate.
-- ------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK20_moderator_can_read_message_for_moderation', count(*), 1
from public.get_message_for_moderation('b0000000-0000-0000-0000-000000000002'::uuid);
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- alice is a real participant of the conversation this message lives
-- in, but is NOT a moderator -- must still get zero rows.
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK21_non_moderator_participant_gets_no_rows', count(*), 0
from public.get_message_for_moderation('b0000000-0000-0000-0000-000000000002'::uuid);
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 22-24: RLS on `conversation_mutes`.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where user_a_id = '11111111-1111-1111-1111-111111111111'::uuid
    and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid;

  -- CHECK22: alice can mute the conversation for herself.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.conversation_mutes (conversation_id, user_id)
  values (v_conv_id, '11111111-1111-1111-1111-111111111111');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK23: alice can't insert a mute row on bob's behalf.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.conversation_mutes (conversation_id, user_id)
    values (v_conv_id, '22222222-2222-2222-2222-222222222222');
    insert into results values ('CHECK23_mute_on_behalf_of_another_user_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK23_mute_on_behalf_of_another_user_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;
insert into results values ('CHECK22_mute_own_conversation_succeeds', 1, 1);

-- CHECK24: bob (didn't mute anything) sees zero rows querying
-- conversation_mutes directly -- alice's mute row is invisible to him.
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK24_mute_row_invisible_to_other_participant', count(*), 0
from public.conversation_mutes;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 25-26: RLS on the `chat-media` storage bucket.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where user_a_id = '11111111-1111-1111-1111-111111111111'::uuid
    and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid;

  -- CHECK25: alice (a real participant) can upload into her
  -- conversation's folder.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('chat-media', v_conv_id::text || '/alice-1.jpg', '11111111-1111-1111-1111-111111111111');
    insert into results values ('CHECK25_participant_upload_accepted', 1, 1);
  exception when others then
    insert into results values ('CHECK25_participant_upload_accepted', 0, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK26: dave (not a participant of this conversation) cannot
  -- upload into its folder.
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('chat-media', v_conv_id::text || '/sneaky.jpg', '44444444-4444-4444-4444-444444444444');
    insert into results values ('CHECK26_non_participant_upload_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK26_non_participant_upload_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 27-29: mark_conversation_read()/count_unread_conversations().
-- ------------------------------------------------------------

-- alice's count_unread_conversations() sees bob's earlier reply
-- ('สวัสดีอลิซ') as unread (she's never marked this conversation read).
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK27_unread_before_mark_read', public.count_unread_conversations(), 1;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where user_a_id = '11111111-1111-1111-1111-111111111111'::uuid
    and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid;

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.mark_conversation_read(v_conv_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK28_unread_zero_after_mark_read', public.count_unread_conversations(), 0;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK29: mark_conversation_read() only touched alice's own column --
-- bob's own last-read column is still null.
insert into results
select 'CHECK29_mark_read_only_touches_callers_own_column',
  (case when user_b_last_read_at is null then 1 else 0 end), 1
from public.conversations
where user_a_id = '11111111-1111-1111-1111-111111111111'::uuid
  and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid;

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

echo "== Seeding fixtures and running RLS/RPC checks =="
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
