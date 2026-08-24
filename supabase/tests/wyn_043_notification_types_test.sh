#!/usr/bin/env bash
# Regression test for WYN-043 (Notification Types -- new SECURITY DEFINER
# RPC: send_system_notification()) -- proves the core guarantees at the
# database layer under the real `authenticated` role (not the Postgres
# superuser, which bypasses RLS entirely), mirroring
# wyn_041_trending_engine_test.sh's exact harness/role-switching
# convention.
#
#   1. An admin (platform_role = 'admin') can send a system notification
#      to another user.
#   2. The inserted row has type = 'system', actor_id = NULL, and
#      reason = the message text passed in.
#   3. An ordinary user (platform_role = 'user') is rejected.
#   4. A moderator (platform_role = 'moderator') is rejected too -- this
#      RPC is admin-only, not moderator-or-admin like decide_appeal().
#   5. A blank/whitespace-only message is rejected.
#   6. A NULL message is rejected.
#   7. The recipient can see their own system notification (ordinary
#      notifications SELECT policy, unchanged by this task).
#   8. A third party (not the recipient) cannot see that notification --
#      confirms this RPC didn't accidentally loosen notifications' own
#      RLS.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_041_trending_engine_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_043_notification_types_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn043_notification_types_regression_test"
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

-- admin: platform_role = 'admin', sends the notifications below.
-- moderator: platform_role = 'moderator', must also be rejected.
-- normalUser: platform_role = 'user', must be rejected.
-- recipient: the target of the admin's successful send.
-- stranger: unrelated third party, used to prove RLS still hides the
-- notification from anyone but the recipient.
insert into auth.users (id, email) values
  ('40000000-0000-0000-0000-000000000001', 'admin@test.com'),
  ('40000000-0000-0000-0000-000000000002', 'moderator@test.com'),
  ('40000000-0000-0000-0000-000000000003', 'normaluser@test.com'),
  ('40000000-0000-0000-0000-000000000004', 'recipient@test.com'),
  ('40000000-0000-0000-0000-000000000005', 'stranger@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('40000000-0000-0000-0000-000000000001', 'admin', 'admin', 'admin', false),
  ('40000000-0000-0000-0000-000000000002', 'moderator', 'moderator', 'moderator', false),
  ('40000000-0000-0000-0000-000000000003', 'normaluser', 'normaluser', 'user', false),
  ('40000000-0000-0000-0000-000000000004', 'recipient', 'recipient', 'user', false),
  ('40000000-0000-0000-0000-000000000005', 'stranger', 'stranger', 'user', false);

-- ------------------------------------------------------------
-- CHECK 1-2: admin sends successfully -- row shape is correct.
-- ------------------------------------------------------------
do $$
declare
  v_id uuid;
  v_actor_id uuid;
  v_type text;
  v_reason text;
begin
  set role authenticated;
  set request.jwt.claim.sub = '40000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.send_system_notification(
    '40000000-0000-0000-0000-000000000004',
    'ระบบจะปิดปรับปรุงคืนนี้'
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select id, actor_id, type, reason into v_id, v_actor_id, v_type, v_reason
  from public.notifications
  where recipient_id = '40000000-0000-0000-0000-000000000004'
    and type = 'system';

  insert into results select 'CHECK1_admin_send_succeeds',
    case when v_id is not null then 1 else 0 end, 1;

  insert into results select 'CHECK2a_type_is_system',
    case when v_type = 'system' then 1 else 0 end, 1;

  insert into results select 'CHECK2b_actor_id_is_null',
    case when v_actor_id is null then 1 else 0 end, 1;

  insert into results select 'CHECK2c_reason_matches_message',
    case when v_reason = 'ระบบจะปิดปรับปรุงคืนนี้' then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 3-4: non-admin callers are rejected.
-- ------------------------------------------------------------
do $$
declare
  v_rejected int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '40000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.send_system_notification(
      '40000000-0000-0000-0000-000000000004', 'should not work'
    );
  exception when others then
    v_rejected := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK3_normal_user_rejected', v_rejected, 1;
end
$$;

do $$
declare
  v_rejected int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '40000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.send_system_notification(
      '40000000-0000-0000-0000-000000000004', 'should not work either'
    );
  exception when others then
    v_rejected := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK4_moderator_rejected', v_rejected, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5-6: blank/NULL message is rejected, even for a real admin.
-- ------------------------------------------------------------
do $$
declare
  v_rejected_blank int := 0;
  v_rejected_null int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '40000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';

  begin
    perform public.send_system_notification(
      '40000000-0000-0000-0000-000000000004', '   '
    );
  exception when others then
    v_rejected_blank := 1;
  end;

  begin
    perform public.send_system_notification(
      '40000000-0000-0000-0000-000000000004', null
    );
  exception when others then
    v_rejected_null := 1;
  end;

  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK5_blank_message_rejected', v_rejected_blank, 1;
  insert into results select 'CHECK6_null_message_rejected', v_rejected_null, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7-8: RLS still applies normally -- recipient sees it, a
-- stranger doesn't.
-- ------------------------------------------------------------
do $$
declare
  v_recipient_count int;
  v_stranger_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '40000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_recipient_count from public.notifications where type = 'system';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '40000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_stranger_count from public.notifications where type = 'system';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK7_recipient_sees_own_notification',
    case when v_recipient_count >= 1 then 1 else 0 end, 1;

  insert into results select 'CHECK8_stranger_sees_nothing',
    v_stranger_count, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9: a caller with an auth.users row but NO profiles row at
-- all must be rejected too -- internal.current_platform_role()
-- returns NULL for them, and a bare `<> 'admin'` check silently lets
-- NULL through (PL/pgSQL's `if` treats NULL like false). Found during
-- WYN-051's Independent QA (same NULL-role-bypass class WYN-050 hit).
-- See .wyn/tasks/bugs/WYN-043-send-system-notification-null-role-bypass.md.
-- ------------------------------------------------------------
do $$
declare
  v_rejected int := 0;
begin
  insert into auth.users (id, email)
  values ('40000000-0000-0000-0000-000000000006', 'noprofile@test.com');

  set role authenticated;
  set request.jwt.claim.sub = '40000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.send_system_notification(
      '40000000-0000-0000-0000-000000000004', 'should not work'
    );
  exception when others then
    v_rejected := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK9_caller_with_no_profile_row_rejected', v_rejected, 1;
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
