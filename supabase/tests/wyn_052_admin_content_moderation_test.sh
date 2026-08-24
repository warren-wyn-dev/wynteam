#!/usr/bin/env bash
# Regression test for WYN-052 (WYN Admin Content Moderation -- Search
# Drop, Remove, Restore -- Drop only in V1) -- mirrors the harness of
# wyn_051_admin_user_management_test.sh.
#
#   1. admin_remove_drop() soft-deletes (deleted_at set, row still
#      exists) and records a moderation_actions row with
#      target_content_type='drop'/target_content_id=<drop>, report_id
#      NULL, and sends a moderation_content_removed notification.
#   2. THE CORE FIX: the Drop's own author calling restore_drop() on a
#      drop admin-removed in CHECK 1 is REJECTED.
#   3. admin_restore_drop() (moderator) then restores it -- deleted_at
#      cleared, the moderation_actions row marked overturned.
#   4. Regression: a self-deleted Drop (soft_delete_drop(), nothing to
#      do with moderation) still self-restores via restore_drop() exactly
#      as before this task (WYN-037 unaffected).
#   5. The pre-existing Report-driven path (apply_moderation_action()
#      'remove_content' on a 'drop' report) now ALSO soft-deletes
#      (instead of a hard DELETE) and records target_content_type/id.
#   6. The author of that report-driven-removed drop is also rejected by
#      restore_drop() (the fix applies uniformly to both remove paths).
#   7. admin_restore_drop() restores the report-driven-removed drop too.
#   8. Regression: apply_moderation_action() 'remove_content' against a
#      drop_comment report still hard-deletes exactly as before (V1 scope
#      is Drop only).
#   9. A caller with no profiles row, and an ordinary `user`-role account,
#      are both rejected by admin_remove_drop()/admin_restore_drop()/
#      admin_search_drops()/admin_get_drop() (the coalesce() class of bug,
#      WYN-050's lesson).
#  10. admin_search_drops()/admin_get_drop() bypass private-account
#      gating -- an Admin finds a Drop from a private account that an
#      ordinary querying-the-table-directly user could never see.
#  11. admin_user_moderation_history exposes target_content_id, filterable
#      per-Drop, same as it already does for target_user_id.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.
#
# Usage:
#   bash supabase/tests/wyn_052_admin_content_moderation_test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn052_admin_content_moderation_regression_test"
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
-- author1: owns drop_b (direct admin_remove_drop target) and drop_c
--   (self-delete/self-restore regression, untouched by moderation).
-- author2: owns drop_d (report-driven remove_content target), is_private.
-- reporter: ordinary user who files the report against drop_d.
-- normaluser: platform_role = 'user', must be rejected by every new RPC.
-- noprofile: an auth.users row with NO profiles row at all.
insert into auth.users (id, email) values
  ('90000000-0000-0000-0000-000000000001', 'admin@test.com'),
  ('90000000-0000-0000-0000-000000000002', 'moderator@test.com'),
  ('90000000-0000-0000-0000-000000000003', 'author1@test.com'),
  ('90000000-0000-0000-0000-000000000004', 'author2@test.com'),
  ('90000000-0000-0000-0000-000000000005', 'reporter@test.com'),
  ('90000000-0000-0000-0000-000000000006', 'normaluser@test.com'),
  ('90000000-0000-0000-0000-000000000007', 'noprofile@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('90000000-0000-0000-0000-000000000001', 'admin', 'admin', 'admin', false),
  ('90000000-0000-0000-0000-000000000002', 'moderator', 'moderator', 'moderator', false),
  ('90000000-0000-0000-0000-000000000003', 'author1', 'author1', 'user', false),
  ('90000000-0000-0000-0000-000000000004', 'author2', 'author2', 'user', true),
  ('90000000-0000-0000-0000-000000000005', 'reporter', 'reporter', 'user', false),
  ('90000000-0000-0000-0000-000000000006', 'normaluser', 'normaluser', 'user', false);
-- (deliberately no profiles row for 90000000-...-007)

insert into public.drops (id, author_id, image_url, caption) values
  ('d0000000-0000-0000-0000-00000000000b', '90000000-0000-0000-0000-000000000003', 'https://example.com/b.jpg', 'drop b'),
  ('d0000000-0000-0000-0000-00000000000c', '90000000-0000-0000-0000-000000000003', 'https://example.com/c.jpg', 'drop c'),
  ('d0000000-0000-0000-0000-00000000000d', '90000000-0000-0000-0000-000000000004', 'https://example.com/d.jpg', 'drop d, private author');

insert into public.drop_comments (id, drop_id, author_id, text_content) values
  ('c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-00000000000b', '90000000-0000-0000-0000-000000000005', 'a comment');

-- ------------------------------------------------------------
-- CHECK 1: admin_remove_drop() soft-deletes + records
-- target_content_type/id + report_id NULL + notifies.
-- ------------------------------------------------------------
do $$
declare
  v_deleted_at_set int;
  v_action_row record;
  v_notification_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.admin_remove_drop('d0000000-0000-0000-0000-00000000000b', 'ผิดกติกาชัดเจน');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select case when deleted_at is not null then 1 else 0 end into v_deleted_at_set
  from public.drops where id = 'd0000000-0000-0000-0000-00000000000b';

  select * into v_action_row from public.moderation_actions
  where target_content_type = 'drop' and target_content_id = 'd0000000-0000-0000-0000-00000000000b';

  select count(*) into v_notification_count from public.notifications
  where recipient_id = '90000000-0000-0000-0000-000000000003' and type = 'moderation_content_removed';

  insert into results select 'CHECK1a_soft_deleted_not_gone', v_deleted_at_set, 1;
  insert into results select 'CHECK1b_report_id_null', case when v_action_row.report_id is null then 1 else 0 end, 1;
  insert into results select 'CHECK1c_action_type_remove_content', case when v_action_row.action_type = 'remove_content' then 1 else 0 end, 1;
  insert into results select 'CHECK1d_notification_sent', v_notification_count, 1;
  insert into results select 'CHECK1e_row_still_exists', (select count(*) from public.drops where id = 'd0000000-0000-0000-0000-00000000000b'), 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 2 (THE CORE FIX): the Drop's own author cannot self-restore
-- a moderation-removed Drop via restore_drop().
-- ------------------------------------------------------------
do $$
declare
  v_rejected int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.restore_drop('d0000000-0000-0000-0000-00000000000b');
  exception when others then
    v_rejected := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK2_self_restore_of_moderated_drop_rejected', v_rejected, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 3: admin_restore_drop() (moderator) restores it -- deleted_at
-- cleared, moderation_actions row marked overturned.
-- ------------------------------------------------------------
do $$
declare
  v_still_deleted int;
  v_overturned int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  perform public.admin_restore_drop('d0000000-0000-0000-0000-00000000000b', 'อุทธรณ์สำเร็จ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select case when deleted_at is null then 0 else 1 end into v_still_deleted
  from public.drops where id = 'd0000000-0000-0000-0000-00000000000b';

  select count(*) into v_overturned from public.moderation_actions
  where target_content_type = 'drop' and target_content_id = 'd0000000-0000-0000-0000-00000000000b'
    and overturned_at is not null;

  insert into results select 'CHECK3a_admin_restore_clears_deleted_at', v_still_deleted, 0;
  insert into results select 'CHECK3b_admin_restore_marks_overturned', v_overturned, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 4 (regression): a self-deleted Drop -- nothing to do with
-- moderation -- still self-restores normally (WYN-037 unaffected).
-- ------------------------------------------------------------
do $$
declare
  v_restored int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  perform public.soft_delete_drop('d0000000-0000-0000-0000-00000000000c');
  perform public.restore_drop('d0000000-0000-0000-0000-00000000000c');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select case when deleted_at is null then 1 else 0 end into v_restored
  from public.drops where id = 'd0000000-0000-0000-0000-00000000000c';

  insert into results select 'CHECK4_self_delete_self_restore_unaffected', v_restored, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5: the Report-driven path -- apply_moderation_action()
-- 'remove_content' against a 'drop' report -- now soft-deletes (not a
-- hard DELETE) and records target_content_type/id too.
-- ------------------------------------------------------------
do $$
declare
  v_report_id uuid;
  v_deleted_at_set int;
  v_action_row record;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000005';
  set request.jwt.claim.role = 'authenticated';
  select public.submit_report('drop', 'd0000000-0000-0000-0000-00000000000d', 'spam', null)
    into v_report_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'remove_content', 'ยืนยันสแปม', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select case when deleted_at is not null then 1 else 0 end into v_deleted_at_set
  from public.drops where id = 'd0000000-0000-0000-0000-00000000000d';

  select * into v_action_row from public.moderation_actions
  where target_content_type = 'drop' and target_content_id = 'd0000000-0000-0000-0000-00000000000d';

  insert into results select 'CHECK5a_report_driven_soft_deletes', v_deleted_at_set, 1;
  insert into results select 'CHECK5b_report_driven_row_still_exists', (select count(*) from public.drops where id = 'd0000000-0000-0000-0000-00000000000d'), 1;
  insert into results select 'CHECK5c_report_driven_records_target_content', case when v_action_row.id is not null then 1 else 0 end, 1;
  insert into results select 'CHECK5d_report_driven_report_id_not_null', case when v_action_row.report_id = v_report_id then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: the fix applies uniformly -- the author of the
-- report-driven-removed drop is also rejected by restore_drop().
-- ------------------------------------------------------------
do $$
declare
  v_rejected int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.restore_drop('d0000000-0000-0000-0000-00000000000d');
  exception when others then
    v_rejected := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK6_report_driven_self_restore_also_rejected', v_rejected, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: admin_restore_drop() restores the report-driven-removed
-- drop too.
-- ------------------------------------------------------------
do $$
declare
  v_restored int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.admin_restore_drop('d0000000-0000-0000-0000-00000000000d', 'พิจารณาใหม่');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select case when deleted_at is null then 1 else 0 end into v_restored
  from public.drops where id = 'd0000000-0000-0000-0000-00000000000d';

  insert into results select 'CHECK7_report_driven_admin_restore_works', v_restored, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8 (regression): apply_moderation_action() 'remove_content'
-- against a drop_comment report still hard-deletes, V1 scope is Drop
-- only.
-- ------------------------------------------------------------
do $$
declare
  v_report_id uuid;
  v_still_exists int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  select public.submit_report('drop_comment', 'c0000000-0000-0000-0000-000000000001', 'spam', null)
    into v_report_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'remove_content', 'ยืนยันสแปม', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_still_exists from public.drop_comments where id = 'c0000000-0000-0000-0000-000000000001';

  insert into results select 'CHECK8_drop_comment_still_hard_deletes', v_still_exists, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9: no-profile and ordinary user-role callers are rejected by
-- all 4 new RPCs (coalesce() class of bug, WYN-050's lesson).
-- ------------------------------------------------------------
do $$
declare
  v_rejected_remove int := 0;
  v_rejected_restore int := 0;
  v_rejected_search int := 0;
  v_rejected_get int := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000007';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.admin_remove_drop('d0000000-0000-0000-0000-00000000000c', 'x');
  exception when others then v_rejected_remove := v_rejected_remove + 1; end;
  begin
    perform public.admin_restore_drop('d0000000-0000-0000-0000-00000000000c', 'x');
  exception when others then v_rejected_restore := v_rejected_restore + 1; end;
  begin
    perform public.admin_search_drops('drop');
  exception when others then v_rejected_search := v_rejected_search + 1; end;
  begin
    perform public.admin_get_drop('d0000000-0000-0000-0000-00000000000c');
  exception when others then v_rejected_get := v_rejected_get + 1; end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.admin_remove_drop('d0000000-0000-0000-0000-00000000000c', 'x');
  exception when others then v_rejected_remove := v_rejected_remove + 1; end;
  begin
    perform public.admin_restore_drop('d0000000-0000-0000-0000-00000000000c', 'x');
  exception when others then v_rejected_restore := v_rejected_restore + 1; end;
  begin
    perform public.admin_search_drops('drop');
  exception when others then v_rejected_search := v_rejected_search + 1; end;
  begin
    perform public.admin_get_drop('d0000000-0000-0000-0000-00000000000c');
  exception when others then v_rejected_get := v_rejected_get + 1; end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK9a_admin_remove_drop_rejected_both', v_rejected_remove, 2;
  insert into results select 'CHECK9b_admin_restore_drop_rejected_both', v_rejected_restore, 2;
  insert into results select 'CHECK9c_admin_search_drops_rejected_both', v_rejected_search, 2;
  insert into results select 'CHECK9d_admin_get_drop_rejected_both', v_rejected_get, 2;
end
$$;

-- ------------------------------------------------------------
-- CHECK 10: admin_search_drops()/admin_get_drop() bypass
-- private-account gating -- author2 is_private=true, yet Admin still
-- finds and fetches drop d.
-- ------------------------------------------------------------
do $$
declare
  v_found_in_search int;
  v_found_via_get int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_found_in_search from public.admin_search_drops('drop d')
  where id = 'd0000000-0000-0000-0000-00000000000d';
  select count(*) into v_found_via_get from public.admin_get_drop('d0000000-0000-0000-0000-00000000000d');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK10a_search_bypasses_private_account', v_found_in_search, 1;
  insert into results select 'CHECK10b_get_bypasses_private_account', v_found_via_get, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 11: admin_user_moderation_history exposes target_content_id,
-- filterable per-Drop.
-- ------------------------------------------------------------
do $$
declare
  v_history_rows int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '90000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_history_rows from public.admin_user_moderation_history
  where target_content_id = 'd0000000-0000-0000-0000-00000000000b';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK11_history_filterable_by_target_content_id', v_history_rows, 1;
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
