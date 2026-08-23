#!/usr/bin/env bash
# Regression test for WYN-033 (Share to Chat) -- proves the
# shared-content columns on messages behave correctly at the RLS/RPC
# layer, under the real `authenticated` role (not the Postgres
# superuser, which bypasses RLS entirely), mirroring
# wyn_031_chat_test.sh/wyn_032_message_request_test.sh's exact
# harness/role-switching convention.
#
#   1. Sending a shared drop/profile/club message succeeds with
#      text/image_url null -- messages_not_blank_unless_deleted treats
#      a non-null shared_content_id as satisfying "not blank" on its
#      own, same as an image message with no caption.
#   2. The recipient (a real conversation participant) can read the
#      shared-content message back through messages' own SELECT
#      policy -- no new privacy mechanism is needed because the actual
#      Drop/Profile/Club content is resolved client-side through its
#      own already-RLS-protected repository, not joined in here.
#   3. messages_not_blank_unless_deleted still rejects a message with
#      text, image_url, AND shared_content_id all null (regression --
#      the new column doesn't accidentally loosen the old guarantee).
#   4. The shared_content_type check constraint rejects a value outside
#      ('drop', 'profile', 'club').
#   5. delete_message() nulls shared_content_type/shared_content_id
#      alongside text/image_url (WYN-033 addition to the original
#      WYN-031 delete behavior).
#   6. get_message_for_moderation() returns the new shared_content_type/
#      shared_content_id columns correctly for a moderator, and still
#      returns zero rows for an ordinary non-moderator caller
#      (regression against the WYN-030 gate on this function).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_031_chat_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_033_share_to_chat_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway DB.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn033_share_to_chat_regression_test"
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
create table wyn033_ids (name text primary key, id uuid);

-- alice/bob: mutually follow each other, so their conversation starts
-- 'active' immediately (no WYN-032 gate to route around here -- this
-- test is about shared-content columns, not the request flow).
-- carol: moderator. dave: an ordinary user, unrelated to the
-- conversation -- used as the non-moderator negative case for
-- get_message_for_moderation().
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'moderator'),
  ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'user');

insert into public.follows (follower_id, following_id) values
  ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'),
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111');

-- The shared-content fixtures: a Drop authored by alice, a Club owned
-- by bob. Fixed ids so the seed/assert script can reference them
-- directly.
insert into public.drops (id, author_id, image_url) values
  ('77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', 'https://example.com/drop.jpg');

insert into public.clubs (id, name, privacy, owner_id) values
  ('88888888-8888-8888-8888-888888888888', 'ชมรมทดสอบ', 'public', '22222222-2222-2222-2222-222222222222');

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
  select 'CHECK0_conversation_starts_active', (case when status = 'active' then 1 else 0 end), 1
  from public.conversations where id = v_conv_id;
end
$$;

-- ------------------------------------------------------------
-- CHECK 1-3: sending each of the 3 shared-content types succeeds
-- with text/image_url null -- messages_not_blank_unless_deleted
-- treats a non-null shared_content_id as "not blank" on its own.
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
  v_drop_msg_id uuid;
  v_profile_msg_id uuid;
  v_club_msg_id uuid;
begin
  select id into v_conv_id from public.conversations
  where (user_a_id = '11111111-1111-1111-1111-111111111111'::uuid and user_b_id = '22222222-2222-2222-2222-222222222222'::uuid)
     or (user_a_id = '22222222-2222-2222-2222-222222222222'::uuid and user_b_id = '11111111-1111-1111-1111-111111111111'::uuid);

  -- alice shares her own drop to bob.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, shared_content_type, shared_content_id)
  values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'drop', '77777777-7777-7777-7777-777777777777')
  returning id into v_drop_msg_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK1_shared_drop_message_inserted', count(*), 1
  from public.messages
  where id = v_drop_msg_id and text is null and image_url is null
    and shared_content_type = 'drop' and shared_content_id = '77777777-7777-7777-7777-777777777777'::uuid;

  -- bob shares alice's own profile back to her.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, shared_content_type, shared_content_id)
  values (v_conv_id, '22222222-2222-2222-2222-222222222222', 'profile', '11111111-1111-1111-1111-111111111111')
  returning id into v_profile_msg_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK2_shared_profile_message_inserted', count(*), 1
  from public.messages
  where id = v_profile_msg_id and shared_content_type = 'profile'
    and shared_content_id = '11111111-1111-1111-1111-111111111111'::uuid;

  -- alice shares bob's club.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.messages (conversation_id, sender_id, shared_content_type, shared_content_id)
  values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'club', '88888888-8888-8888-8888-888888888888')
  returning id into v_club_msg_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK3_shared_club_message_inserted', count(*), 1
  from public.messages
  where id = v_club_msg_id and shared_content_type = 'club'
    and shared_content_id = '88888888-8888-8888-8888-888888888888'::uuid;

  -- CHECK4: bob (the recipient/participant) can read alice's shared
  -- drop message back through messages' own SELECT policy.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK4_recipient_can_read_shared_message', count(*), 1
  from public.messages where id = v_drop_msg_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- Stash ids for the checks below, in later do blocks (do blocks
  -- don't share variables with each other).
  insert into wyn033_ids values ('drop_msg', v_drop_msg_id), ('club_msg', v_club_msg_id), ('conv', v_conv_id);
end
$$;

-- ------------------------------------------------------------
-- CHECK 5: messages_not_blank_unless_deleted still rejects a message
-- with text, image_url, AND shared_content_id all null (regression --
-- the new column doesn't loosen the old guarantee).
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from wyn033_ids where name = 'conv';

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.messages (conversation_id, sender_id)
    values (v_conv_id, '11111111-1111-1111-1111-111111111111');
    insert into results values ('CHECK5_fully_blank_message_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK5_fully_blank_message_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: shared_content_type check constraint rejects a value
-- outside ('drop', 'profile', 'club').
-- ------------------------------------------------------------
do $$
declare
  v_conv_id uuid;
begin
  select id into v_conv_id from wyn033_ids where name = 'conv';

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.messages (conversation_id, sender_id, shared_content_type, shared_content_id)
    values (v_conv_id, '11111111-1111-1111-1111-111111111111', 'pop', '77777777-7777-7777-7777-777777777777');
    insert into results values ('CHECK6_invalid_shared_content_type_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK6_invalid_shared_content_type_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7-8: delete_message() nulls shared_content_type/
-- shared_content_id alongside text/image_url.
-- ------------------------------------------------------------
do $$
declare
  v_drop_msg_id uuid;
begin
  select id into v_drop_msg_id from wyn033_ids where name = 'drop_msg';

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.delete_message(v_drop_msg_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK7_delete_message_nulls_shared_content_type', (case when shared_content_type is null then 1 else 0 end), 1
  from public.messages where id = v_drop_msg_id;
  insert into results
  select 'CHECK8_delete_message_nulls_shared_content_id', (case when shared_content_id is null then 1 else 0 end), 1
  from public.messages where id = v_drop_msg_id;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9-10: get_message_for_moderation() returns the new
-- shared_content_type/shared_content_id columns correctly for a
-- moderator (using the still-live shared club message), and still
-- returns zero rows for an ordinary non-moderator caller
-- (regression against the WYN-030 gate on this function).
-- ------------------------------------------------------------
do $$
declare
  v_club_msg_id uuid;
  v_shared_type text;
  v_shared_id uuid;
  v_row_count int;
begin
  select id into v_club_msg_id from wyn033_ids where name = 'club_msg';

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  select shared_content_type, shared_content_id into v_shared_type, v_shared_id
  from public.get_message_for_moderation(v_club_msg_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values (
    'CHECK9a_moderator_sees_shared_content_type',
    (case when v_shared_type = 'club' then 1 else 0 end), 1
  );
  insert into results values (
    'CHECK9b_moderator_sees_shared_content_id',
    (case when v_shared_id = '88888888-8888-8888-8888-888888888888'::uuid then 1 else 0 end), 1
  );

  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_row_count from public.get_message_for_moderation(v_club_msg_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results values ('CHECK10_non_moderator_gets_zero_rows', v_row_count, 0);
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
