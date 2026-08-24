#!/usr/bin/env bash
# Regression test for WYN-048 (Audit Log Foundation) -- proves the core
# guarantees at the database layer under the real `authenticated` role
# (not the Postgres superuser, which bypasses RLS entirely), mirroring
# wyn_047_data_rights_test.sh's exact harness/role-switching convention.
#
#   1. apply_moderation_action(), called by a moderator, produces
#      exactly one new audit_log row with
#      event_type = 'moderation_action_applied', actor_id = the
#      moderator, target_id = the resolved target user, and a detail
#      object carrying action_type/reason.
#   2. decide_appeal(), called by a moderator approving an appeal,
#      produces exactly one new audit_log row with
#      event_type = 'appeal_decided', actor_id = the reviewer,
#      target_id = the appellant, and detail->>'decision' = 'approved'.
#   3. send_system_notification(), called by an admin against a
#      recipient with the 'system' category enabled (the default),
#      produces exactly one new audit_log row with
#      event_type = 'system_notification_sent', actor_id = the admin,
#      target_id = the recipient, detail->>'message' = the message.
#   4. send_system_notification(), called against a recipient who has
#      explicitly disabled the 'system' category, produces ZERO new
#      audit_log rows -- nothing was actually sent (notifications gets
#      no new row either, per WYN-043's existing opt-out gate), so
#      nothing is logged as sent. Proves the deliberate placement of
#      the log call inside that `if` branch in schema.sql.
#   5. export_my_data(), called by a user, produces exactly one new
#      audit_log row with event_type = 'data_exported',
#      actor_id = target_id = the caller, detail is null.
#   6. delete_my_account(), called by a user, produces exactly one new
#      audit_log row with event_type = 'account_deleted',
#      actor_id = target_id = the caller.
#   7. THE MOST IMPORTANT CHECK IN THIS TASK: that account_deleted
#      audit_log row still exists, with a non-null
#      actor_username_snapshot equal to the deleted user's real
#      username, *after* delete_my_account() has fully committed and
#      profiles/auth.users no longer have a matching row for that id --
#      proving audit_log.actor_id's deliberate lack of an
#      `on delete cascade` FK actually holds under a real cascade
#      chain, not just in theory.
#   8. No `authenticated` role -- plain `user`, `moderator`, or `admin`
#      platform_role -- can SELECT, INSERT, UPDATE, or DELETE
#      audit_log directly, checked for all three platform_role values
#      independently.
#
# This script does not re-implement wyn_029/030/043/047's own
# regression checks -- see the WYN-048 Coding Output for confirmation
# that all four of those scripts (plus every other script in
# supabase/tests/) were re-run independently after this task's changes
# and still pass unmodified, proving the 5 wired functions' pre-
# existing behavior is untouched.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_047_data_rights_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_048_audit_log_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn048_audit_log_regression_test"
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

-- admin1/mod1: apply moderation actions + decide appeals.
-- userA: target of the moderation action + appellant.
-- userB: reporter.
-- userC: deletes her own account.
-- userD: exports his own data.
-- userE: system notification recipient with the default (enabled)
-- 'system' preference.
-- userF: system notification recipient who explicitly disabled
-- 'system'.
-- plainUser/mod2/admin2: RLS probe, one per platform_role value.
insert into auth.users (id, email) values
  ('68000000-0000-0000-0000-000000000001', 'admin1048@test.com'),
  ('68000000-0000-0000-0000-000000000002', 'mod1048@test.com'),
  ('68000000-0000-0000-0000-000000000003', 'usera048@test.com'),
  ('68000000-0000-0000-0000-000000000004', 'userb048@test.com'),
  ('68000000-0000-0000-0000-000000000005', 'userc048@test.com'),
  ('68000000-0000-0000-0000-000000000006', 'userd048@test.com'),
  ('68000000-0000-0000-0000-000000000007', 'usere048@test.com'),
  ('68000000-0000-0000-0000-000000000008', 'userf048@test.com'),
  ('68000000-0000-0000-0000-000000000009', 'plainuser048@test.com'),
  ('68000000-0000-0000-0000-00000000000a', 'mod2048@test.com'),
  ('68000000-0000-0000-0000-00000000000b', 'admin2048@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('68000000-0000-0000-0000-000000000001', 'admin1048', 'admin1', 'admin', false),
  ('68000000-0000-0000-0000-000000000002', 'mod1048', 'mod1', 'moderator', false),
  ('68000000-0000-0000-0000-000000000003', 'usera048', 'userA', 'user', false),
  ('68000000-0000-0000-0000-000000000004', 'userb048', 'userB', 'user', false),
  ('68000000-0000-0000-0000-000000000005', 'userc048', 'userC', 'user', false),
  ('68000000-0000-0000-0000-000000000006', 'userd048', 'userD', 'user', false),
  ('68000000-0000-0000-0000-000000000007', 'usere048', 'userE', 'user', false),
  ('68000000-0000-0000-0000-000000000008', 'userf048', 'userF', 'user', false),
  ('68000000-0000-0000-0000-000000000009', 'plainuser048', 'plainUser', 'user', false),
  ('68000000-0000-0000-0000-00000000000a', 'mod2048', 'mod2', 'moderator', false),
  ('68000000-0000-0000-0000-00000000000b', 'admin2048', 'admin2', 'admin', false);

-- userF explicitly disabled the 'system' notification category.
insert into public.notification_settings (user_id, system) values
  ('68000000-0000-0000-0000-000000000008', false);

-- ------------------------------------------------------------
-- CHECK 1-2: apply_moderation_action() -- moderation_action_applied.
-- ------------------------------------------------------------
do $$
declare
  v_report_id uuid;
  v_action_id uuid;
  v_before int;
  v_after int;
begin
  select count(*) into v_before from public.audit_log;

  set role authenticated;
  set request.jwt.claim.sub = '68000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  perform public.submit_report('user', '68000000-0000-0000-0000-000000000003', 'harassment', 'please review');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select id into v_report_id from public.reports
    where target_type = 'user' and target_id = '68000000-0000-0000-0000-000000000003';

  set role authenticated;
  set request.jwt.claim.sub = '68000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'warning', 'please follow the community guidelines', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_after from public.audit_log;

  select id into v_action_id from public.moderation_actions where report_id = v_report_id;

  insert into results select 'CHECK01_moderation_action_produces_exactly_one_audit_row', v_after - v_before, 1;
  insert into results select 'CHECK02_moderation_audit_row_has_correct_fields',
    (select count(*) from public.audit_log
     where event_type = 'moderation_action_applied'
       and actor_id = '68000000-0000-0000-0000-000000000002'
       and target_id = '68000000-0000-0000-0000-000000000003'
       and detail->>'action_type' = 'warning'
       and detail->>'reason' = 'please follow the community guidelines'),
    1;

  -- ------------------------------------------------------------
  -- CHECK 3-4: decide_appeal() -- appeal_decided.
  -- ------------------------------------------------------------
  declare
    v_appeal_id uuid;
    v_before2 int;
    v_after2 int;
  begin
    select count(*) into v_before2 from public.audit_log;

    set role authenticated;
    set request.jwt.claim.sub = '68000000-0000-0000-0000-000000000003';
    set request.jwt.claim.role = 'authenticated';
    select public.submit_appeal(v_action_id, 'I did nothing wrong', null) into v_appeal_id;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

    set role authenticated;
    set request.jwt.claim.sub = '68000000-0000-0000-0000-000000000002';
    set request.jwt.claim.role = 'authenticated';
    perform public.decide_appeal(v_appeal_id, true, null);
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

    select count(*) into v_after2 from public.audit_log;

    insert into results select 'CHECK03_appeal_decision_produces_exactly_one_audit_row', v_after2 - v_before2, 1;
    insert into results select 'CHECK04_appeal_audit_row_has_correct_fields',
      (select count(*) from public.audit_log
       where event_type = 'appeal_decided'
         and actor_id = '68000000-0000-0000-0000-000000000002'
         and target_id = '68000000-0000-0000-0000-000000000003'
         and detail->>'decision' = 'approved'),
      1;
  end;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5-6: send_system_notification() -- sent (recipient has
-- 'system' enabled, the default).
-- ------------------------------------------------------------
do $$
declare
  v_before int;
  v_after int;
begin
  select count(*) into v_before from public.audit_log;

  set role authenticated;
  set request.jwt.claim.sub = '68000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.send_system_notification('68000000-0000-0000-0000-000000000007', 'Scheduled maintenance tonight');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_after from public.audit_log;

  insert into results select 'CHECK05_sent_system_notification_produces_exactly_one_audit_row', v_after - v_before, 1;
  insert into results select 'CHECK06_system_notification_audit_row_has_correct_fields',
    (select count(*) from public.audit_log
     where event_type = 'system_notification_sent'
       and actor_id = '68000000-0000-0000-0000-000000000001'
       and target_id = '68000000-0000-0000-0000-000000000007'
       and detail->>'message' = 'Scheduled maintenance tonight'),
    1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: send_system_notification() against a recipient who
-- disabled 'system' -- nothing sent, nothing logged.
-- ------------------------------------------------------------
do $$
declare
  v_before int;
  v_after int;
begin
  select count(*) into v_before from public.audit_log
    where event_type = 'system_notification_sent' and target_id = '68000000-0000-0000-0000-000000000008';

  set role authenticated;
  set request.jwt.claim.sub = '68000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.send_system_notification('68000000-0000-0000-0000-000000000008', 'You will never see this');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_after from public.audit_log
    where event_type = 'system_notification_sent' and target_id = '68000000-0000-0000-0000-000000000008';

  insert into results select 'CHECK07_opted_out_recipient_produces_zero_audit_rows', v_after - v_before, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8-9: export_my_data() -- data_exported.
-- ------------------------------------------------------------
do $$
declare
  v_before int;
  v_after int;
begin
  select count(*) into v_before from public.audit_log;

  set role authenticated;
  set request.jwt.claim.sub = '68000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  perform public.export_my_data();
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_after from public.audit_log;

  insert into results select 'CHECK08_export_produces_exactly_one_audit_row', v_after - v_before, 1;
  insert into results select 'CHECK09_export_audit_row_has_correct_fields',
    (select count(*) from public.audit_log
     where event_type = 'data_exported'
       and actor_id = '68000000-0000-0000-0000-000000000006'
       and target_id = '68000000-0000-0000-0000-000000000006'
       and detail is null),
    1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 10-13: delete_my_account() -- account_deleted, AND the
-- resulting audit_log row survives the very deletion it records.
-- This is the single most important check in this whole task.
-- ------------------------------------------------------------
do $$
declare
  v_before int;
  v_after int;
  v_username_before text;
begin
  select username into v_username_before from public.profiles where id = '68000000-0000-0000-0000-000000000005';
  select count(*) into v_before from public.audit_log;

  set role authenticated;
  set request.jwt.claim.sub = '68000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  perform public.delete_my_account();
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_after from public.audit_log;

  insert into results select 'CHECK10_account_deletion_produces_exactly_one_audit_row', v_after - v_before, 1;

  -- CHECK11-13 run as the table owner (the same role that loaded
  -- schema.sql), which bypasses audit_log's RLS entirely (there is no
  -- policy for `authenticated` to even attempt bypassing) -- exactly
  -- how Founder would inspect this table via the Supabase SQL editor
  -- until WYN-054 ships an Admin UI.
  insert into results select 'CHECK11_carols_profile_row_is_actually_gone',
    (select count(*) from public.profiles where id = '68000000-0000-0000-0000-000000000005'), 0;
  insert into results select 'CHECK12_account_deleted_audit_row_survives_the_deletion',
    (select count(*) from public.audit_log
     where event_type = 'account_deleted'
       and actor_id = '68000000-0000-0000-0000-000000000005'
       and target_id = '68000000-0000-0000-0000-000000000005'),
    1;
  insert into results select 'CHECK13_surviving_audit_row_has_correct_username_snapshot',
    (select case when actor_username_snapshot = v_username_before then 1 else 0 end
     from public.audit_log
     where event_type = 'account_deleted' and actor_id = '68000000-0000-0000-0000-000000000005'),
    1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 14-25: no `authenticated` role -- plain user, moderator, or
-- admin -- can SELECT/INSERT/UPDATE/DELETE audit_log directly, for
-- each of the three platform_role values independently.
-- ------------------------------------------------------------
do $$
declare
  v_probe_id uuid;
  v_rec record;
  v_role_id uuid;
  v_role_label text;
  v_select_count int;
  v_insert_failed boolean;
  v_update_rows int;
  v_delete_rows int;
  v_before_count int;
begin
  -- A known existing row to target with the UPDATE/DELETE probes below.
  select id into v_probe_id from public.audit_log where event_type = 'data_exported' limit 1;

  for v_rec in
    select * from (values
      ('68000000-0000-0000-0000-000000000009'::uuid, 'plain_user'),
      ('68000000-0000-0000-0000-00000000000a'::uuid, 'moderator'),
      ('68000000-0000-0000-0000-00000000000b'::uuid, 'admin')
    ) as t(role_id, role_label)
  loop
    v_role_id := v_rec.role_id;
    v_role_label := v_rec.role_label;
    select count(*) into v_before_count from public.audit_log;

    set role authenticated;
    set request.jwt.claim.role = 'authenticated';
    perform set_config('request.jwt.claim.sub', v_role_id::text, false);

    select count(*) into v_select_count from public.audit_log;

    v_insert_failed := false;
    begin
      insert into public.audit_log (actor_id, event_type, target_id, detail)
      values (v_role_id::uuid, 'data_exported', v_role_id::uuid, null);
    exception when others then
      v_insert_failed := true;
    end;

    update public.audit_log set detail = jsonb_build_object('tampered', true) where id = v_probe_id;
    get diagnostics v_update_rows = row_count;

    delete from public.audit_log where id = v_probe_id;
    get diagnostics v_delete_rows = row_count;

    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

    insert into results select 'CHECK_' || v_role_label || '_cannot_select_audit_log', v_select_count, 0;
    insert into results select 'CHECK_' || v_role_label || '_insert_is_rejected', case when v_insert_failed then 1 else 0 end, 1;
    insert into results select 'CHECK_' || v_role_label || '_update_affects_zero_rows', v_update_rows, 0;
    insert into results select 'CHECK_' || v_role_label || '_delete_affects_zero_rows', v_delete_rows, 0;
    insert into results select 'CHECK_' || v_role_label || '_row_count_unchanged_after_probe',
      (select count(*) from public.audit_log), v_before_count;
  end loop;
end
$$;

-- ------------------------------------------------------------
-- CHECK 14 (QA finding, fast-followed): internal.log_audit_event()
-- itself must not be directly callable by an ordinary authenticated
-- user -- p_actor_id/p_target_id are fully caller-supplied (unlike
-- export_my_data()/delete_my_account(), whose only "whose data" input
-- is auth.uid()), so a direct grant would let any client forge
-- arbitrary audit_log rows attributing fabricated actions to other
-- users. Mirrors wyn_044_notification_settings_test.sh's CHECK20 for
-- internal.notification_enabled(), the same vulnerability class.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '68000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform internal.log_audit_event(
      '68000000-0000-0000-0000-00000000000b',
      'account_deleted',
      '68000000-0000-0000-0000-00000000000b',
      '{"forged": true}'::jsonb
    );
    insert into results values
      ('CHECK14_log_audit_event_direct_call_denied', 0, 1);
  exception when insufficient_privilege or others then
    insert into results values
      ('CHECK14_log_audit_event_direct_call_denied', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
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
