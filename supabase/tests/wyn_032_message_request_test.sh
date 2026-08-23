#!/usr/bin/env bash
# Regression test for WYN-032 (Message Request flow) -- proves the
# security-sensitive behavior actually works at the RLS/RPC layer,
# under the real `authenticated` role (not the Postgres superuser,
# which bypasses RLS entirely), mirroring wyn_031_chat_test.sh's exact
# harness/role-switching convention.
#
#   1. get_or_create_conversation(): 'active' immediately when the
#      recipient already follows the sender -- no gate at all, same as
#      WYN-031's original behavior (regression). 'pending' plus
#      requested_by/a message_request notification when they don't --
#      idempotent (a second call doesn't re-fire the notification or
#      change status/requested_by).
#   2. `chat_inbox` (WYN-031's view): a pending conversation shows up
#      only for the requester, never the recipient.
#   3. `message_requests` (new view): the inverse -- only the
#      recipient, never the requester -- and excludes a
#      blocked-either-way pair outright.
#   4. messages INSERT policy: the recipient of a pending request has
#      no INSERT path at all; the requester can keep sending while
#      pending.
#   5. accept_message_request(): the requester cannot accept their own
#      request, and neither can an unrelated third party who isn't
#      even a participant; the recipient can, flipping status to
#      'active' and unlocking a normal INSERT for the former recipient
#      too; accepting an already-active conversation is rejected.
#   6. delete_message_request(): the requester cannot delete their own
#      outgoing request this way, and neither can an unrelated third
#      party; the recipient can, and it discards the conversation and
#      every message in it (FK cascade) -- a fresh request can be
#      started afterward, not permanently stuck.
#   7. conversations_requested_by_is_participant check constraint
#      catches a requested_by that isn't actually one of the 2
#      participants, even from a direct table-owner insert.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_031_chat_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_032_message_request_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway DB.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn032_message_request_regression_test"
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
-- (regression, no gate). carol/dave: strangers, so carol -> dave
-- starts pending. eve: a stranger to carol too (used for the delete-
-- request checks, kept separate from carol<->dave). frank: a stranger
-- to alice, used for the message_requests-excludes-blocked check.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'eve@test.com'),
  ('66666666-6666-6666-6666-666666666666', 'frank@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'user'),
  ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'user'),
  ('55555555-5555-5555-5555-555555555555', 'eve', 'Eve', 'user'),
  ('66666666-6666-6666-6666-666666666666', 'frank', 'Frank', 'user');

-- bob already follows alice -- makes alice a "known" sender from
-- bob's perspective.
insert into public.follows (follower_id, following_id) values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111');

insert into storage.buckets (id, name, public) values ('chat-media', 'chat-media', false)
  on conflict (id) do nothing;

-- ------------------------------------------------------------
-- CHECK 1: alice -> bob starts 'active' immediately -- bob already
-- follows alice, so no gate at all (regression against WYN-031).
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
  v_status text;
  v_requested_by uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('22222222-2222-2222-2222-222222222222'::uuid) into v_conv_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select status, requested_by into v_status, v_requested_by from public.conversations where id = v_conv_id;
  insert into results values ('CHECK1a_known_recipient_starts_active', (case when v_status = 'active' then 1 else 0 end), 1);
  insert into results values ('CHECK1b_known_recipient_no_requested_by', (case when v_requested_by is null then 1 else 0 end), 1);
end
$$;

-- ------------------------------------------------------------
-- CHECK 2-4: carol -> dave starts 'pending' -- dave does not follow
-- carol -- plus the message_request notification and idempotency.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
  v_conv_id_2 uuid;
  v_status text;
  v_requested_by uuid;
  v_notif_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('44444444-4444-4444-4444-444444444444'::uuid) into v_conv_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select status, requested_by into v_status, v_requested_by from public.conversations where id = v_conv_id;
  insert into results values ('CHECK2a_unknown_recipient_starts_pending', (case when v_status = 'pending' then 1 else 0 end), 1);
  insert into results values ('CHECK2b_requested_by_is_sender', (case when v_requested_by = '33333333-3333-3333-3333-333333333333'::uuid then 1 else 0 end), 1);

  select count(*) into v_notif_count from public.notifications
  where recipient_id = '44444444-4444-4444-4444-444444444444'::uuid
    and actor_id = '33333333-3333-3333-3333-333333333333'::uuid
    and type = 'message_request'
    and conversation_id = v_conv_id;
  insert into results values ('CHECK3_message_request_notification_inserted', v_notif_count, 1);

  -- Idempotent second call -- same row, no second notification.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('44444444-4444-4444-4444-444444444444'::uuid) into v_conv_id_2;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK4a_idempotent_same_row', (case when v_conv_id = v_conv_id_2 then 1 else 0 end), 1);
  select count(*) into v_notif_count from public.notifications
  where recipient_id = '44444444-4444-4444-4444-444444444444'::uuid and type = 'message_request';
  insert into results values ('CHECK4b_idempotent_no_duplicate_notification', v_notif_count, 1);
end
$$;

-- ------------------------------------------------------------
-- CHECK 5-8: chat_inbox / message_requests visibility split.
-- ------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK5_requester_sees_it_in_chat_inbox', count(*), 1
from public.chat_inbox
where other_user_id = '44444444-4444-4444-4444-444444444444'::uuid;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK6_recipient_does_not_see_it_in_chat_inbox', count(*), 0
from public.chat_inbox
where other_user_id = '33333333-3333-3333-3333-333333333333'::uuid;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK7_recipient_sees_it_in_message_requests', count(*), 1
from public.message_requests
where other_user_id = '33333333-3333-3333-3333-333333333333'::uuid;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK8_requester_does_not_see_it_in_message_requests', count(*), 0
from public.message_requests
where other_user_id = '44444444-4444-4444-4444-444444444444'::uuid;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 9-10: messages INSERT policy while pending.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '33333333-3333-3333-3333-333333333333'::uuid and user_b_id = '44444444-4444-4444-4444-444444444444'::uuid)
     or (user_a_id = '44444444-4444-4444-4444-444444444444'::uuid and user_b_id = '33333333-3333-3333-3333-333333333333'::uuid);

  -- CHECK9: dave (the recipient) cannot send at all while pending.
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.messages (conversation_id, sender_id, text)
    values (v_conv_id, '44444444-4444-4444-4444-444444444444', 'ตอบก่อนรับคำขอ');
    insert into results values ('CHECK9_recipient_cannot_send_while_pending', 0, 1);
  exception when others then
    insert into results values ('CHECK9_recipient_cannot_send_while_pending', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK10: carol (the requester) can send while still pending --
  -- her insert succeeds even though dave's (CHECK9, just above) was
  -- rejected, so exactly 1 message exists at this point (carol's).
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text)
  values (v_conv_id, '33333333-3333-3333-3333-333333333333', 'ข้อความระหว่างรอ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK10_requester_can_keep_sending_while_pending', count(*), 1
  from public.messages where conversation_id = v_conv_id;
end
$$;

-- ------------------------------------------------------------
-- CHECK 10b-10c: chat-media storage upload policy while pending --
-- must mirror the messages INSERT policy exactly (an image message
-- uploads to storage *before* its messages row is inserted, so this
-- is a distinct policy that would silently break image sends during
-- the pending phase if left at WYN-031's original "active only" check).
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '33333333-3333-3333-3333-333333333333'::uuid and user_b_id = '44444444-4444-4444-4444-444444444444'::uuid)
     or (user_a_id = '44444444-4444-4444-4444-444444444444'::uuid and user_b_id = '33333333-3333-3333-3333-333333333333'::uuid);

  -- CHECK10b: carol (the requester) can upload an image while pending.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('chat-media', v_conv_id::text || '/carol-1.jpg', '33333333-3333-3333-3333-333333333333');
    insert into results values ('CHECK10b_requester_can_upload_image_while_pending', 1, 1);
  exception when others then
    insert into results values ('CHECK10b_requester_can_upload_image_while_pending', 0, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK10c: dave (the recipient) still cannot upload while pending
  -- (mirrors CHECK9's message-send rejection).
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('chat-media', v_conv_id::text || '/dave-1.jpg', '44444444-4444-4444-4444-444444444444');
    insert into results values ('CHECK10c_recipient_cannot_upload_image_while_pending', 0, 1);
  exception when others then
    insert into results values ('CHECK10c_recipient_cannot_upload_image_while_pending', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 11-14: accept_message_request().
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '33333333-3333-3333-3333-333333333333'::uuid and user_b_id = '44444444-4444-4444-4444-444444444444'::uuid)
     or (user_a_id = '44444444-4444-4444-4444-444444444444'::uuid and user_b_id = '33333333-3333-3333-3333-333333333333'::uuid);

  -- CHECK11: carol (the requester) cannot accept her own request.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.accept_message_request(v_conv_id);
    insert into results values ('CHECK11_requester_cannot_accept_own_request', 0, 1);
  exception when others then
    insert into results values ('CHECK11_requester_cannot_accept_own_request', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK11b: an unrelated third party (frank, not even a participant)
  -- cannot accept it either -- status must still be 'pending'
  -- afterward.
  set role authenticated;
  set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.accept_message_request(v_conv_id);
    insert into results values ('CHECK11b_unrelated_third_party_cannot_accept', 0, 1);
  exception when others then
    insert into results values ('CHECK11b_unrelated_third_party_cannot_accept', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK11c_status_still_pending_after_rejected_accepts', (case when status = 'pending' then 1 else 0 end), 1
  from public.conversations where id = v_conv_id;

  -- CHECK12: dave (the recipient) accepts -- status flips to active.
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  perform public.accept_message_request(v_conv_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK12_recipient_accept_flips_status_active', (case when status = 'active' then 1 else 0 end), 1
  from public.conversations where id = v_conv_id;

  -- CHECK13: dave can now send normally (was blocked before accept).
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text)
  values (v_conv_id, '44444444-4444-4444-4444-444444444444', 'ตอบหลังรับคำขอแล้ว');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK13_recipient_can_send_after_accept', count(*), 1
  from public.messages where conversation_id = v_conv_id and sender_id = '44444444-4444-4444-4444-444444444444'::uuid;

  -- CHECK14: accepting again (already active) is rejected.
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.accept_message_request(v_conv_id);
    insert into results values ('CHECK14_accept_already_active_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK14_accept_already_active_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 15-18: delete_message_request().
-- ------------------------------------------------------------

-- eve -> carol: a fresh pending request, kept separate from
-- carol<->dave above. eve also sends a real message into it, so the
-- cascade check below has something real to prove got deleted.
do $$
declare
  v_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('33333333-3333-3333-3333-333333333333'::uuid) into v_conv_id;
  insert into public.messages (conversation_id, sender_id, text)
  values (v_conv_id, '55555555-5555-5555-5555-555555555555', 'สวัสดีคาโรล');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
declare
  v_conv_id uuid;
  v_message_count_before int;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '33333333-3333-3333-3333-333333333333'::uuid and user_b_id = '55555555-5555-5555-5555-555555555555'::uuid)
     or (user_a_id = '55555555-5555-5555-5555-555555555555'::uuid and user_b_id = '33333333-3333-3333-3333-333333333333'::uuid);

  select count(*) into v_message_count_before from public.messages where conversation_id = v_conv_id;
  insert into results values ('CHECK15z_fixture_has_a_real_message_before_delete', (case when v_message_count_before > 0 then 1 else 0 end), 1);

  -- CHECK15: eve (the requester) cannot delete her own outgoing
  -- request this way -- row must still exist afterward.
  set role authenticated;
  set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.delete_message_request(v_conv_id);
    insert into results values ('CHECK15_requester_cannot_delete_own_request', 0, 1);
  exception when others then
    insert into results values ('CHECK15_requester_cannot_delete_own_request', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK15b: an unrelated third party (frank) cannot delete it
  -- either -- the row must still exist afterward.
  set role authenticated;
  set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.delete_message_request(v_conv_id);
    insert into results values ('CHECK15b_unrelated_third_party_cannot_delete', 0, 1);
  exception when others then
    insert into results values ('CHECK15b_unrelated_third_party_cannot_delete', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK15c_conversation_still_exists_after_rejected_deletes', count(*), 1
  from public.conversations where id = v_conv_id;

  -- CHECK16: carol (the recipient) deletes it -- conversation gone.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.delete_message_request(v_conv_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK16_recipient_delete_removes_conversation', count(*), 0
  from public.conversations where id = v_conv_id;

  -- CHECK17: its message(s) cascaded away too (v_message_count_before
  -- was asserted > 0 by CHECK15z above, so this is a real deletion,
  -- not a vacuous 0 == 0).
  insert into results
  select 'CHECK17_delete_cascades_to_messages', count(*), 0
  from public.messages where conversation_id = v_conv_id;
end
$$;

-- CHECK18: eve can start a fresh request to carol again -- not
-- permanently stuck after being declined.
do $$
declare
  v_new_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('33333333-3333-3333-3333-333333333333'::uuid) into v_new_conv_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK18_can_start_fresh_request_after_delete', (case when v_new_conv_id is not null then 1 else 0 end), 1);
end
$$;

-- ------------------------------------------------------------
-- CHECK 19: conversations_requested_by_is_participant catches a
-- requested_by that isn't one of the 2 participants, even from a
-- direct table-owner insert.
-- ------------------------------------------------------------
do $$
begin
  begin
    insert into public.conversations (user_a_id, user_b_id, status, requested_by)
    values (
      '11111111-1111-1111-1111-111111111111'::uuid,
      '66666666-6666-6666-6666-666666666666'::uuid,
      'pending',
      '22222222-2222-2222-2222-222222222222'::uuid
    );
    insert into results values ('CHECK19_requested_by_non_participant_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK19_requested_by_non_participant_rejected', 1, 1);
  end;
end
$$;

-- ------------------------------------------------------------
-- CHECK 20: message_requests excludes a blocked-either-way pair --
-- frank -> alice starts pending, alice blocks frank, the request
-- disappears from alice's message_requests.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
  set request.jwt.claim.role = 'authenticated';
  perform public.get_or_create_conversation('11111111-1111-1111-1111-111111111111'::uuid);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.block_user('66666666-6666-6666-6666-666666666666'::uuid);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK20_message_requests_excludes_blocked_pair', count(*), 0
from public.message_requests
where other_user_id = '66666666-6666-6666-6666-666666666666'::uuid;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

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
