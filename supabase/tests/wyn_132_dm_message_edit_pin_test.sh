#!/usr/bin/env bash
# QA regression test for WYN-132 (DM Edit + Pin Message) -- written
# independently by AI QA & Security to verify the RPC/RLS layer
# directly, mirroring wyn_134_dm_new_message_notification_test.sh's
# harness/role-switching convention. Covers:
#   1. edit_message(): own text-only message can be edited (edited_at
#      set); someone else's message, an image message, a deleted
#      message, and an empty-text edit are all rejected.
#   2. pin_message(): capped at exactly 3 pinned messages per
#      conversation -- a 4th pin attempt is rejected; either
#      participant may pin/unpin (no DM hierarchy).
#   3. delete_message() auto-unpins a pinned message (soft-delete via
#      UPDATE, not a real DELETE, so FK cascade alone can't do this).
#   4. A non-participant cannot pin a message in someone else's DM.
#   5. No client-side UPDATE policy exists on `messages` at all -- the
#      RPCs above are the only mutation path (confirmed via
#      pg_policies, not just code inspection).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.
#
# Usage: bash supabase/tests/wyn_132_dm_message_edit_pin_test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn132_qa_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

run_psql() {
  local db="$1"; local file="$2"
  if psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  elif sudo -u postgres psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  else
    cat "$WORK_DIR/psql.out" >&2
    return 1
  fi
}
createdb_any() { local db="$1"; createdb "$db" >/dev/null 2>&1 || sudo -u postgres createdb "$db" >/dev/null 2>&1; }
dropdb_any() { local db="$1"; dropdb --if-exists "$db" >/dev/null 2>&1 || sudo -u postgres dropdb --if-exists "$db" >/dev/null 2>&1 || true; }

cat > "$WORK_DIR/00_stub.sql" <<'EOF'
create extension if not exists pgcrypto;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key default gen_random_uuid(), email text);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create or replace function auth.role() returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role', true), '')
$$;
create schema if not exists storage;
create table if not exists storage.buckets (id text primary key, name text not null, public boolean not null default false);
create table if not exists storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets (id), name text, owner uuid);
create or replace function storage.foldername(name text) returns text[] language sql immutable as $$ select string_to_array(name, '/') $$;
alter table storage.objects enable row level security;
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
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
create table results (check_name text primary key, actual text, expected text);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'user');

insert into public.follows (follower_id, following_id) values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111');

do $$
declare v_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.get_or_create_conversation('22222222-2222-2222-2222-222222222222'::uuid) into v_conv_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ============ EDIT MESSAGE TESTS ============

-- CHECK1: alice can edit her own text message
do $$
declare v_conv_id uuid; v_msg_id uuid; v_text text; v_edited_at timestamptz;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'ข้อความเดิม') returning id into v_msg_id;
  perform public.edit_message(v_msg_id, 'ข้อความที่แก้ไขแล้ว');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select text, edited_at into v_text, v_edited_at from public.messages where id = v_msg_id;
  insert into results values ('CHECK1_own_text_message_edit_succeeds', v_text, 'ข้อความที่แก้ไขแล้ว');
  insert into results values ('CHECK1b_edited_at_set', (case when v_edited_at is not null then 'set' else 'null' end), 'set');
end
$$;

-- CHECK2: bob CANNOT edit alice's message (someone else's message)
do $$
declare v_conv_id uuid; v_msg_id uuid; v_failed boolean := false;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  select id into v_msg_id from public.messages where conversation_id = v_conv_id and sender_id = '11111111-1111-1111-1111-111111111111'::uuid order by created_at asc limit 1;

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.edit_message(v_msg_id, 'บ๊อบพยายามแก้ของอลิซ');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK2_cannot_edit_others_message', v_failed::text, 'true');
end
$$;

-- CHECK3: cannot edit an image message
do $$
declare v_conv_id uuid; v_msg_id uuid; v_failed boolean := false;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, image_url) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'https://example.com/img.jpg') returning id into v_msg_id;
  begin
    perform public.edit_message(v_msg_id, 'พยายามแก้ข้อความรูปภาพ');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK3_cannot_edit_image_message', v_failed::text, 'true');
end
$$;

-- CHECK4: cannot edit a deleted message
do $$
declare v_conv_id uuid; v_msg_id uuid; v_failed boolean := false;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'จะถูกลบ') returning id into v_msg_id;
  perform public.delete_message(v_msg_id);
  begin
    perform public.edit_message(v_msg_id, 'พยายามแก้ข้อความที่ถูกลบ');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK4_cannot_edit_deleted_message', v_failed::text, 'true');
end
$$;

-- CHECK5: cannot edit to empty text
do $$
declare v_conv_id uuid; v_msg_id uuid; v_failed boolean := false;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'ข้อความ') returning id into v_msg_id;
  begin
    perform public.edit_message(v_msg_id, '   ');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK5_cannot_edit_to_empty_text', v_failed::text, 'true');
end
$$;

-- ============ PIN MESSAGE TESTS ============

-- CHECK6: pin up to 3 messages succeeds, 4th fails (cap enforced)
do $$
declare v_conv_id uuid; v_msg_id1 uuid; v_msg_id2 uuid; v_msg_id3 uuid; v_msg_id4 uuid; v_failed boolean := false; v_count int;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'ปักหมุด1') returning id into v_msg_id1;
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'ปักหมุด2') returning id into v_msg_id2;
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'ปักหมุด3') returning id into v_msg_id3;
  insert into public.messages (conversation_id, sender_id, text) values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'ปักหมุด4') returning id into v_msg_id4;
  perform public.pin_message(v_msg_id1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- bob pins the second one (either participant can pin)
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  perform public.pin_message(v_msg_id2);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.pin_message(v_msg_id3);
  begin
    perform public.pin_message(v_msg_id4);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.message_pins where conversation_id = v_conv_id;
  insert into results values ('CHECK6a_pin_cap_enforced_4th_fails', v_failed::text, 'true');
  insert into results values ('CHECK6b_only_3_pinned', v_count::text, '3');
end
$$;

-- CHECK7: deleting a pinned message auto-unpins it
do $$
declare v_conv_id uuid; v_msg_id uuid; v_count_before int; v_count_after int;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  select message_id into v_msg_id from public.message_pins where conversation_id = v_conv_id limit 1;
  select count(*) into v_count_before from public.message_pins where message_id = v_msg_id;

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  -- need to know sender of that message to delete as them; find sender
  perform public.delete_message(v_msg_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count_after from public.message_pins where message_id = v_msg_id;
  insert into results values ('CHECK7a_pin_existed_before_delete', v_count_before::text, '1');
  insert into results values ('CHECK7b_auto_unpinned_after_delete', v_count_after::text, '0');
end
$$;

-- CHECK8: unpin works and either participant can unpin (bob unpins alice-pinned msg)
do $$
declare v_conv_id uuid; v_msg_id uuid; v_count int;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  select message_id into v_msg_id from public.message_pins where conversation_id = v_conv_id limit 1;

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  perform public.unpin_message(v_msg_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.message_pins where message_id = v_msg_id;
  insert into results values ('CHECK8_either_participant_can_unpin', v_count::text, '0');
end
$$;

-- CHECK9: a non-participant (carol) cannot pin a message in alice/bob's conversation
do $$
declare v_conv_id uuid; v_msg_id uuid; v_failed boolean := false;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  select id into v_msg_id from public.messages where conversation_id = v_conv_id and deleted_at is null limit 1;

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.pin_message(v_msg_id);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK9_non_participant_cannot_pin', v_failed::text, 'true');
end
$$;

-- CHECK10: no client-side UPDATE policy exists on messages (only RPC path)
do $$
declare v_has_update_policy boolean;
begin
  select exists (
    select 1 from pg_policies where schemaname='public' and tablename='messages' and cmd = 'UPDATE'
  ) into v_has_update_policy;
  insert into results values ('CHECK10_no_client_update_policy_on_messages', v_has_update_policy::text, 'false');
end
$$;

select check_name, actual, expected from results order by check_name;
EOF

if ! createdb_any "$DB_NAME"; then echo "FAIL: could not create test database $DB_NAME" >&2; exit 1; fi
if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then echo "FAIL: stub setup failed" >&2; dropdb_any "$DB_NAME"; exit 1; fi
if ! run_psql "$DB_NAME" "$SCHEMA_FILE"; then echo "FAIL: schema.sql failed to load cleanly" >&2; dropdb_any "$DB_NAME"; exit 1; fi
echo "== Seeding fixtures and running RLS/RPC checks (WYN-132) =="
if ! run_psql "$DB_NAME" "$WORK_DIR/10_seed_and_assert.sql"; then echo "FAIL: seed/assert script errored" >&2; cat "$WORK_DIR/psql.out" >&2; dropdb_any "$DB_NAME"; exit 1; fi
cat "$WORK_DIR/psql.out"

FAILURES=0
while IFS='|' read -r name actual expected; do
  name="$(echo "$name" | xargs)"; actual="$(echo "$actual" | xargs)"; expected="$(echo "$expected" | xargs)"
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
if [ "$FAILURES" -gt 0 ]; then echo "FAIL: $FAILURES check(s) failed"; exit 1; fi
echo "ALL CHECKS PASSED"
