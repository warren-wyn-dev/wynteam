#!/usr/bin/env bash
# Regression test for WYN-051 (WYN Admin User Management -- direct
# Warn/Restrict/Suspend/Ban/Unban, not tied to a Report) -- mirrors the
# harness of wyn_050_admin_dashboard_test.sh.
#
#   1. admin_apply_user_action('warning', ...) inserts a moderation_actions
#      row with report_id NULL and sends a moderation_warning notification.
#   2. admin_apply_user_action('ban', ...) makes is_posting_blocked() true
#      immediately, with no Report anywhere involved.
#   3. admin_apply_user_action('restrict', ...) requires duration_days in
#      (1, 3, 7); an invalid value is rejected.
#   4. admin_unban_user() clears the block -- is_posting_blocked() goes
#      back to false, and the moderation_actions row is marked overturned.
#   5. A caller with no profiles row at all is rejected by both RPCs (the
#      exact NULL-role-bypass class WYN-050 found -- proving the coalesce()
#      fix here actually works, not just copy-pasted).
#   6. An ordinary `user`-role account is rejected by both RPCs.
#   7. A moderator (not just admin) can call both RPCs.
#   8. admin_user_moderation_history shows the reviewer's username (unlike
#      moderation_queue, which hides the reporter) and is invisible to a
#      `user`-role caller.
#   9. The pre-existing report-driven apply_moderation_action() path still
#      works unchanged (report_id going nullable didn't break it).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.
#
# Usage:
#   bash supabase/tests/wyn_051_admin_user_management_test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn051_admin_user_management_regression_test"
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

-- admin/moderator: platform_role set, issue actions.
-- target: the ordinary user being acted on.
-- normaluser: platform_role = 'user', must be rejected.
-- noprofile: an auth.users row with NO profiles row at all.
insert into auth.users (id, email) values
  ('90000000-0000-0000-0000-000000000001', 'admin@test.com'),
  ('90000000-0000-0000-0000-000000000002', 'moderator@test.com'),
  ('90000000-0000-0000-0000-000000000003', 'target@test.com'),
  ('90000000-0000-0000-0000-000000000004', 'normaluser@test.com'),
  ('90000000-0000-0000-0000-000000000005', 'noprofile@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('90000000-0000-0000-0000-000000000001', 'admin', 'admin', 'admin', false),
  ('90000000-0000-0000-0000-000000000002', 'moderator', 'moderator', 'moderator', false),
  ('90000000-0000-0000-0000-000000000003', 'target', 'target', 'user', false),
  ('90000000-0000-0000-0000-000000000004', 'normaluser', 'normaluser', 'user', false);
-- (deliberately no profiles row for 90000000-...-005)

-- ------------------------------------------------------------
-- CHECK 1: admin warns the target -- row inserted with report_id
-- NULL, notification sent.
-- ------------------------------------------------------------
do $$
declare
  v_report_id_is_null int;
  v_notification_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.admin_apply_user_action(
    '90000000-0000-0000-0000-000000000003', 'warning', 'be nice', null
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select case when report_id is null then 1 else 0 end into v_report_id_is_null
  from public.moderation_actions
  where target_user_id = '90000000-0000-0000-0000-000000000003' and action_type = 'warning';

  select count(*) into v_notification_count from public.notifications
  where recipient_id = '90000000-0000-0000-0000-000000000003' and type = 'moderation_warning';

  insert into results select 'CHECK1a_warning_report_id_null', v_report_id_is_null, 1;
  insert into results select 'CHECK1b_warning_notification_sent', v_notification_count, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 2: admin bans the target -- is_posting_blocked() true
-- immediately, no Report anywhere.
-- ------------------------------------------------------------
do $$
declare
  v_blocked boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.admin_apply_user_action(
    '90000000-0000-0000-0000-000000000003', 'ban', 'repeated abuse', null
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  v_blocked := internal.is_posting_blocked('90000000-0000-0000-0000-000000000003');
  insert into results select 'CHECK2_ban_blocks_posting', case when v_blocked then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 3: invalid duration_days for restrict is rejected.
-- ------------------------------------------------------------
do $$
declare
  v_rejected int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.admin_apply_user_action(
      '90000000-0000-0000-0000-000000000004', 'restrict', 'test', 2
    );
  exception when others then
    v_rejected := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK3_invalid_duration_rejected', v_rejected, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 4: admin_unban_user() clears the ban from CHECK2 --
-- is_posting_blocked() goes back to false, row marked overturned.
-- ------------------------------------------------------------
do $$
declare
  v_blocked boolean;
  v_overturned int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.admin_unban_user('90000000-0000-0000-0000-000000000003', 'appealed successfully offline');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  v_blocked := internal.is_posting_blocked('90000000-0000-0000-0000-000000000003');
  select count(*) into v_overturned from public.moderation_actions
  where target_user_id = '90000000-0000-0000-0000-000000000003'
    and action_type = 'ban' and overturned_at is not null;

  insert into results select 'CHECK4a_unban_clears_block', case when v_blocked then 0 else 1 end, 1;
  insert into results select 'CHECK4b_unban_marks_overturned', v_overturned, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5: a caller with no profiles row at all is rejected by
-- both RPCs -- proves the coalesce() fix actually works here too.
-- ------------------------------------------------------------
do $$
declare
  v_rejected_apply int := 0;
  v_rejected_unban int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.admin_apply_user_action('90000000-0000-0000-0000-000000000004', 'warning', 'x', null);
  exception when others then
    v_rejected_apply := 1;
  end;
  begin
    perform public.admin_unban_user('90000000-0000-0000-0000-000000000004', 'x');
  exception when others then
    v_rejected_unban := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK5a_no_profile_rejected_apply', v_rejected_apply, 1;
  insert into results select 'CHECK5b_no_profile_rejected_unban', v_rejected_unban, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: an ordinary user-role account is rejected by both RPCs.
-- ------------------------------------------------------------
do $$
declare
  v_rejected_apply int := 0;
  v_rejected_unban int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.admin_apply_user_action('90000000-0000-0000-0000-000000000003', 'warning', 'x', null);
  exception when others then
    v_rejected_apply := 1;
  end;
  begin
    perform public.admin_unban_user('90000000-0000-0000-0000-000000000003', 'x');
  exception when others then
    v_rejected_unban := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK6a_ordinary_user_rejected_apply', v_rejected_apply, 1;
  insert into results select 'CHECK6b_ordinary_user_rejected_unban', v_rejected_unban, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: a moderator (not just admin) can call both RPCs.
-- ------------------------------------------------------------
do $$
declare
  v_ok int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  perform public.admin_apply_user_action('90000000-0000-0000-0000-000000000004', 'suspend', 'test', 1);
  perform public.admin_unban_user('90000000-0000-0000-0000-000000000004', 'undo test');
  v_ok := 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK7_moderator_allowed', v_ok, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8: admin_user_moderation_history shows reviewer_username,
-- and is invisible to a user-role caller.
-- ------------------------------------------------------------
do $$
declare
  v_reviewer_username text;
  v_user_role_row_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select reviewer_username into v_reviewer_username
  from public.admin_user_moderation_history
  where target_user_id = '90000000-0000-0000-0000-000000000003' and action_type = 'warning';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_user_role_row_count from public.admin_user_moderation_history;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK8a_reviewer_username_visible',
    case when v_reviewer_username = 'admin' then 1 else 0 end, 1;
  insert into results select 'CHECK8b_hidden_from_user_role', v_user_role_row_count, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9: the pre-existing report-driven apply_moderation_action()
-- path still works unchanged after report_id went nullable.
-- ------------------------------------------------------------
do $$
declare
  v_report_id uuid;
  v_blocked boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  select public.submit_report('user', '90000000-0000-0000-0000-000000000003', 'spam', null)
    into v_report_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'suspend', 'confirmed spam', 3);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  v_blocked := internal.is_posting_blocked('90000000-0000-0000-0000-000000000003');
  insert into results select 'CHECK9_report_driven_path_unaffected', case when v_blocked then 1 else 0 end, 1;
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
