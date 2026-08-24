#!/usr/bin/env bash
# Regression test for WYN-054 (Audit Log read screen) + WYN-055 (Official
# Announcement broadcast) -- mirrors the harness of
# wyn_051_admin_user_management_test.sh.
#
#   1. admin_audit_log VIEW returns rows written by earlier privileged
#      actions (apply_moderation_action, admin_apply_user_action) to an
#      admin/moderator caller, and nothing to a user-role caller.
#   2. A user-role/no-profile caller reading admin_audit_log directly
#      gets 0 rows (view-level gate holds).
#   3. admin_send_announcement('all', ...) reaches every profile that
#      has 'system' notifications enabled, and skips one that has opted
#      out.
#   4. audience='users' only reaches platform_role='user' accounts;
#      audience='staff' only reaches moderator/admin accounts.
#   5. admin_send_announcement() is rejected for a moderator (admin-only,
#      unlike every other Phase 7 RPC) -- this is the one most likely to
#      get miscopied from the other RPCs' `not in ('admin', 'moderator')`
#      shape.
#   6. admin_send_announcement() is rejected for a user-role/no-profile
#      caller.
#   7. Invalid category/audience/blank message are all rejected.
#   8. Every successful send writes exactly one admin_audit_log row with
#      the correct recipient_count in its detail, and it's readable back
#      through the same view (proving WYN-054's view sees WYN-055's own
#      writes, not just WYN-048/050/051/052's).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.
#
# Usage:
#   bash supabase/tests/wyn_054_055_audit_log_announcements_test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn054_055_audit_log_announcements_regression_test"
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

-- admin/moderator: platform_role set.
-- user1/user2: platform_role = 'user' -- user2 opts out of 'system'.
-- noprofile: an auth.users row with NO profiles row at all.
insert into auth.users (id, email) values
  ('90000000-0000-0000-0000-000000000001', 'admin@test.com'),
  ('90000000-0000-0000-0000-000000000002', 'moderator@test.com'),
  ('90000000-0000-0000-0000-000000000003', 'user1@test.com'),
  ('90000000-0000-0000-0000-000000000004', 'user2@test.com'),
  ('90000000-0000-0000-0000-000000000005', 'noprofile@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('90000000-0000-0000-0000-000000000001', 'admin', 'admin', 'admin', false),
  ('90000000-0000-0000-0000-000000000002', 'moderator', 'moderator', 'moderator', false),
  ('90000000-0000-0000-0000-000000000003', 'user1', 'user1', 'user', false),
  ('90000000-0000-0000-0000-000000000004', 'user2', 'user2', 'user', false);
-- (deliberately no profiles row for 90000000-...-005)

insert into public.notification_settings (user_id, system) values
  ('90000000-0000-0000-0000-000000000004', false);

-- ------------------------------------------------------------
-- Seed one audit_log row via an already-existing RPC
-- (admin_apply_user_action, WYN-051) so CHECK1/2 have something real
-- to read back through the new view -- not a raw INSERT, since
-- internal.log_audit_event() isn't grantable to authenticated at all.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.admin_apply_user_action(
    '90000000-0000-0000-0000-000000000003', 'warning', 'seed row for WYN-054 test', null
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 1: admin_audit_log is visible to admin/moderator, and shows
-- the seeded row.
-- ------------------------------------------------------------
do $$
declare
  v_admin_rows int;
  v_moderator_rows int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_admin_rows from public.admin_audit_log
  where event_type = 'admin_user_action_applied';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_moderator_rows from public.admin_audit_log
  where event_type = 'admin_user_action_applied';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK1a_admin_sees_seeded_row', v_admin_rows, 1;
  insert into results select 'CHECK1b_moderator_sees_seeded_row', v_moderator_rows, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 2: a user-role/no-profile caller reading admin_audit_log
-- directly gets 0 rows.
-- ------------------------------------------------------------
do $$
declare
  v_user_rows int;
  v_noprofile_rows int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_user_rows from public.admin_audit_log;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_noprofile_rows from public.admin_audit_log;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK2a_user_role_sees_nothing', v_user_rows, 0;
  insert into results select 'CHECK2b_no_profile_sees_nothing', v_noprofile_rows, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 3: admin_send_announcement('all', ...) reaches user1 (opted
-- in) but skips user2 (opted out of 'system').
-- ------------------------------------------------------------
do $$
declare
  v_count int;
  v_user1_notified int;
  v_user2_notified int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select public.admin_send_announcement('important', 'ประกาศทดสอบ ALL', 'all') into v_count;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_user1_notified from public.notifications
  where recipient_id = '90000000-0000-0000-0000-000000000003'
    and type = 'system' and reason = 'ประกาศทดสอบ ALL';
  select count(*) into v_user2_notified from public.notifications
  where recipient_id = '90000000-0000-0000-0000-000000000004'
    and type = 'system' and reason = 'ประกาศทดสอบ ALL';

  -- admin + moderator + user1 all opted in = 3, user2 opted out excluded.
  insert into results select 'CHECK3a_all_audience_recipient_count', v_count, 3;
  insert into results select 'CHECK3b_opted_in_user_notified', v_user1_notified, 1;
  insert into results select 'CHECK3c_opted_out_user_skipped', v_user2_notified, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 4: audience='users' only reaches platform_role='user';
-- audience='staff' only reaches moderator/admin.
-- ------------------------------------------------------------
do $$
declare
  v_users_count int;
  v_staff_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select public.admin_send_announcement('maintenance', 'ประกาศทดสอบ USERS', 'users') into v_users_count;
  select public.admin_send_announcement('maintenance', 'ประกาศทดสอบ STAFF', 'staff') into v_staff_count;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- users: user1 only (user2 opted out) = 1. staff: admin + moderator = 2.
  insert into results select 'CHECK4a_users_audience_count', v_users_count, 1;
  insert into results select 'CHECK4b_staff_audience_count', v_staff_count, 2;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5: a moderator is rejected (admin-only, unlike every other
-- Phase 7 RPC).
-- ------------------------------------------------------------
do $$
declare
  v_rejected int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.admin_send_announcement('important', 'x', 'all');
  exception when others then
    v_rejected := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK5_moderator_rejected', v_rejected, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: user-role/no-profile callers are rejected.
-- ------------------------------------------------------------
do $$
declare
  v_rejected_user int := 0;
  v_rejected_noprofile int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.admin_send_announcement('important', 'x', 'all');
  exception when others then
    v_rejected_user := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.admin_send_announcement('important', 'x', 'all');
  exception when others then
    v_rejected_noprofile := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK6a_user_role_rejected', v_rejected_user, 1;
  insert into results select 'CHECK6b_no_profile_rejected', v_rejected_noprofile, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: invalid category/audience/blank message are all rejected.
-- ------------------------------------------------------------
do $$
declare
  v_rejected_category int := 0;
  v_rejected_audience int := 0;
  v_rejected_blank int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.admin_send_announcement('not_a_real_category', 'x', 'all');
  exception when others then
    v_rejected_category := 1;
  end;
  begin
    perform public.admin_send_announcement('important', 'x', 'not_a_real_audience');
  exception when others then
    v_rejected_audience := 1;
  end;
  begin
    perform public.admin_send_announcement('important', '   ', 'all');
  exception when others then
    v_rejected_blank := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK7a_invalid_category_rejected', v_rejected_category, 1;
  insert into results select 'CHECK7b_invalid_audience_rejected', v_rejected_audience, 1;
  insert into results select 'CHECK7c_blank_message_rejected', v_rejected_blank, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8: every successful send (3 so far -- CHECK3/4a/4b) wrote
-- exactly one admin_audit_log row each with the right recipient_count,
-- readable back through the view.
-- ------------------------------------------------------------
do $$
declare
  v_announcement_rows int;
  v_all_detail_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_announcement_rows from public.admin_audit_log
  where event_type = 'admin_announcement_sent';
  select (detail->>'recipient_count')::int into v_all_detail_count
  from public.admin_audit_log
  where event_type = 'admin_announcement_sent'
    and detail->>'audience' = 'all';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK8a_one_audit_row_per_send', v_announcement_rows, 3;
  insert into results select 'CHECK8b_detail_recipient_count_correct', v_all_detail_count, 3;
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
