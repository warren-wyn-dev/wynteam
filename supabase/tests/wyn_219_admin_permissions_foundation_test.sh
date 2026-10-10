#!/usr/bin/env bash
# WYN-219 Phase 2 step 1: per-system admin permissions foundation
# (supabase/migrations/20261010150000_wyn219_admin_permissions_foundation.sql).
#
#   1. Existing moderators are seeded with social:edit; admins and users get nothing.
#   2. internal.has_admin_permission(): super admin passes everything, edit
#      satisfies view, view does not satisfy edit, other systems and unknown
#      systems/levels are denied, no session is denied.
#   3. Only the super admin can grant, revoke and list; a platform admin,
#      a moderator with social:edit and a user are refused.
#   4. Grant/revoke write audit_log rows; re-granting the same level is a no-op.
#   5. Bad input is refused; the super admin cannot be granted rows.
#   6. App roles cannot write admin_permissions directly or read
#      internal.platform_super_admins, and read only their own permission rows.
#   7. admin_my_access() reports the caller's own access.
#   8. The migration is idempotent and keeps older audit event types.
#
# Requirements: a local PostgreSQL server reachable either as the
# current OS user or via `sudo -u postgres`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations/20261010150000_wyn219_admin_permissions_foundation.sql"
DB_NAME="wyn_219_admin_permissions_foundation_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

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
  email text,
  last_sign_in_at timestamptz
);

-- Supabase keeps one row per signed-in device; updated_at moves when the
-- app refreshes its session.
create table if not exists auth.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
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

cat > "$WORK_DIR/05_pre_seed.sql" <<'EOF'
\set ON_ERROR_STOP on
-- Accounts that exist before the migration runs.
--   sa    the Founder (super admin, seeded by the apply workflow)
--   adm   another platform admin
--   mod   a moderator
--   usr   a regular user
--   fd    a regular user who will be given food:view
insert into auth.users (id, email) values
  ('92190000-0000-0000-0000-000000000001', 'sa@test.invalid'),
  ('92190000-0000-0000-0000-000000000002', 'adm@test.invalid'),
  ('92190000-0000-0000-0000-000000000003', 'mod@test.invalid'),
  ('92190000-0000-0000-0000-000000000004', 'usr@test.invalid'),
  ('92190000-0000-0000-0000-000000000005', 'fd@test.invalid');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('92190000-0000-0000-0000-000000000001', 'p_sa', 'sa', 'admin', false),
  ('92190000-0000-0000-0000-000000000002', 'p_adm', 'adm', 'admin', false),
  ('92190000-0000-0000-0000-000000000003', 'p_mod', 'mod', 'moderator', false),
  ('92190000-0000-0000-0000-000000000004', 'p_usr', 'usr', 'user', false),
  ('92190000-0000-0000-0000-000000000005', 'p_fd', 'fd', 'user', false);

insert into public.audit_log (actor_id, event_type, detail)
values (null, 'system_notification_sent', '{}'::jsonb);

-- Production stores this constraint as `event_type = ANY ('{a,b,...}'::text[])`
-- (one array literal, values not individually quoted). Rewrite it to that
-- exact shape so the migration is tested against what it will really meet.
do $$
declare v_name text; v_values text;
begin
  select c.conname into v_name from pg_constraint c
  where c.conrelid = 'public.audit_log'::regclass and c.contype = 'c'
    and pg_get_constraintdef(c.oid) like '%event_type%';
  select string_agg(x.m[1], ',' order by x.m[1]) into v_values
  from pg_constraint c, regexp_matches(pg_get_constraintdef(c.oid), '''([a-z0-9_]+)''', 'g') as x(m)
  where c.conname = v_name;
  execute format('alter table public.audit_log drop constraint %I', v_name);
  execute format('alter table public.audit_log add constraint audit_log_event_type_check check (event_type = any (%L::text[]))', '{' || v_values || '}');
end
$$;
EOF

cat > "$WORK_DIR/10_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

create table results (check_name text primary key, actual int, expected int);
grant all on results to authenticated;

-- What the apply workflow does for the Founder.
insert into internal.platform_super_admins (user_id) values ('92190000-0000-0000-0000-000000000001');

-- Runs p_sql as p_user (null = no session) and reports whether it raised.
create or replace function pg_temp.refused(p_user uuid, p_sql text) returns int
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), true);
  perform set_config('role', 'authenticated', true);
  begin
    execute p_sql;
  exception when others then
    perform set_config('role', 'postgres', true);
    return 1;
  end;
  perform set_config('role', 'postgres', true);
  return 0;
end;
$$;

-- Evaluates a boolean expression as p_user and returns 1/0.
create or replace function pg_temp.as_user(p_user uuid, p_expr text) returns int
language plpgsql as $$
declare v boolean;
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), true);
  perform set_config('role', 'authenticated', true);
  execute 'select (' || p_expr || ')' into v;
  perform set_config('role', 'postgres', true);
  return case when v then 1 else 0 end;
end;
$$;

-- CHECK 1: seed.
insert into results
select 'CHECK1a_moderator_seeded_social_edit', count(*), 1 from public.admin_permissions
 where user_id = '92190000-0000-0000-0000-000000000003' and system = 'social' and level = 'edit' and granted_by is null;
insert into results
select 'CHECK1b_only_moderator_seeded', count(*), 1 from public.admin_permissions;

-- CHECK 2: has_admin_permission.
do $$
declare
  sa uuid := '92190000-0000-0000-0000-000000000001';
  adm uuid := '92190000-0000-0000-0000-000000000002';
  m uuid := '92190000-0000-0000-0000-000000000003';
  u uuid := '92190000-0000-0000-0000-000000000004';
begin
  insert into results values
    ('CHECK2a_super_admin_every_system_edit',
      pg_temp.as_user(sa, $q$internal.has_admin_permission('account','edit') and internal.has_admin_permission('social','edit')
        and internal.has_admin_permission('food','edit') and internal.has_admin_permission('merchant','edit')
        and internal.has_admin_permission('maps','edit')$q$), 1),
    ('CHECK2b_super_admin_unknown_system_denied', pg_temp.as_user(sa, $q$internal.has_admin_permission('billing','view')$q$), 0),
    ('CHECK2c_super_admin_unknown_level_denied', pg_temp.as_user(sa, $q$internal.has_admin_permission('food','owner')$q$), 0),
    ('CHECK2d_mod_social_view', pg_temp.as_user(m, $q$internal.has_admin_permission('social','view')$q$), 1),
    ('CHECK2e_mod_social_edit', pg_temp.as_user(m, $q$internal.has_admin_permission('social','edit')$q$), 1),
    ('CHECK2f_mod_food_view_denied', pg_temp.as_user(m, $q$internal.has_admin_permission('food','view')$q$), 0),
    ('CHECK2g_platform_admin_has_nothing', pg_temp.as_user(adm,
      $q$internal.has_admin_permission('account','view') or internal.has_admin_permission('social','view')
        or internal.has_admin_permission('food','view') or internal.has_admin_permission('merchant','view')
        or internal.has_admin_permission('maps','view')$q$), 0),
    ('CHECK2h_user_denied', pg_temp.as_user(u, $q$internal.has_admin_permission('social','view')$q$), 0),
    ('CHECK2i_no_session_denied', pg_temp.as_user(null, $q$coalesce(internal.has_admin_permission('social','view'), false)$q$), 0),
    ('CHECK2j_null_args_denied', pg_temp.as_user(sa, $q$coalesce(internal.has_admin_permission(null, null), false)$q$), 0);
end
$$;

-- CHECK 3: who may grant / revoke / list.
do $$
declare
  adm uuid := '92190000-0000-0000-0000-000000000002';
  m uuid := '92190000-0000-0000-0000-000000000003';
  u uuid := '92190000-0000-0000-0000-000000000004';
  fd text := '92190000-0000-0000-0000-000000000005';
begin
  insert into results values
    ('CHECK3a_admin_cannot_grant', pg_temp.refused(adm, format($q$select public.admin_grant_permission(%L, 'food', 'edit')$q$, fd)), 1),
    ('CHECK3b_moderator_cannot_grant', pg_temp.refused(m, format($q$select public.admin_grant_permission(%L, 'social', 'view')$q$, fd)), 1),
    ('CHECK3c_user_cannot_grant_self', pg_temp.refused(u, $q$select public.admin_grant_permission('92190000-0000-0000-0000-000000000004', 'account', 'edit')$q$), 1),
    ('CHECK3d_no_session_cannot_grant', pg_temp.refused(null, format($q$select public.admin_grant_permission(%L, 'food', 'edit')$q$, fd)), 1),
    ('CHECK3e_moderator_cannot_revoke', pg_temp.refused(m, $q$select public.admin_revoke_permission('92190000-0000-0000-0000-000000000003', 'social')$q$), 1),
    ('CHECK3f_admin_cannot_list', pg_temp.refused(adm, $q$select * from public.admin_list_permissions()$q$), 1),
    ('CHECK3g_moderator_cannot_list', pg_temp.refused(m, $q$select * from public.admin_list_permissions()$q$), 1);
end
$$;

-- CHECK 4: super admin grants, upgrades, re-grants and revokes.
do $$
declare
  sa uuid := '92190000-0000-0000-0000-000000000001';
  fd uuid := '92190000-0000-0000-0000-000000000005';
  v_listed int;
begin
  insert into results values
    ('CHECK4a_grant_food_view_ok', 1 - pg_temp.refused(sa, format($q$select public.admin_grant_permission(%L, 'food', 'view')$q$, fd)), 1),
    ('CHECK4b_fd_food_view', pg_temp.as_user(fd, $q$internal.has_admin_permission('food','view')$q$), 1),
    ('CHECK4c_fd_food_edit_denied', pg_temp.as_user(fd, $q$internal.has_admin_permission('food','edit')$q$), 0),
    ('CHECK4d_fd_maps_view_denied', pg_temp.as_user(fd, $q$internal.has_admin_permission('maps','view')$q$), 0);

  perform pg_temp.refused(sa, format($q$select public.admin_grant_permission(%L, 'food', 'view')$q$, fd)); -- same level: no-op
  perform pg_temp.refused(sa, format($q$select public.admin_grant_permission(%L, 'food', 'edit')$q$, fd)); -- upgrade
  insert into results values
    ('CHECK4e_fd_food_edit_after_upgrade', pg_temp.as_user(fd, $q$internal.has_admin_permission('food','edit')$q$), 1);

  perform set_config('request.jwt.claim.sub', sa::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into v_listed from public.admin_list_permissions();
  perform set_config('role', 'postgres', true);
  insert into results values ('CHECK4f_super_admin_lists_all', v_listed, 2);

  insert into results values
    ('CHECK4g_revoke_ok', pg_temp.as_user(sa, format($q$public.admin_revoke_permission(%L, 'food')$q$, fd)), 1),
    ('CHECK4h_fd_food_view_gone', pg_temp.as_user(fd, $q$internal.has_admin_permission('food','view')$q$), 0),
    ('CHECK4i_revoke_missing_returns_false', pg_temp.as_user(sa, format($q$public.admin_revoke_permission(%L, 'food')$q$, fd)), 0);
end
$$;

insert into results
select 'CHECK4j_audit_granted_rows', count(*), 2 from public.audit_log
 where event_type = 'admin_permission_granted'
   and target_id = '92190000-0000-0000-0000-000000000005'
   and actor_id = '92190000-0000-0000-0000-000000000001';
insert into results
select 'CHECK4k_audit_upgrade_keeps_previous_level', count(*), 1 from public.audit_log
 where event_type = 'admin_permission_granted' and detail->>'level' = 'edit' and detail->>'previous_level' = 'view';
insert into results
select 'CHECK4l_audit_revoked_rows', count(*), 1 from public.audit_log
 where event_type = 'admin_permission_revoked' and detail->>'previous_level' = 'edit';

-- CHECK 5: bad input.
do $$
declare sa uuid := '92190000-0000-0000-0000-000000000001';
begin
  insert into results values
    ('CHECK5a_bad_system', pg_temp.refused(sa, $q$select public.admin_grant_permission('92190000-0000-0000-0000-000000000005', 'billing', 'view')$q$), 1),
    ('CHECK5b_bad_level', pg_temp.refused(sa, $q$select public.admin_grant_permission('92190000-0000-0000-0000-000000000005', 'food', 'owner')$q$), 1),
    ('CHECK5c_unknown_user', pg_temp.refused(sa, $q$select public.admin_grant_permission('92190000-0000-0000-0000-0000000000ff', 'food', 'view')$q$), 1),
    ('CHECK5d_super_admin_not_grantable', pg_temp.refused(sa, $q$select public.admin_grant_permission('92190000-0000-0000-0000-000000000001', 'food', 'view')$q$), 1),
    ('CHECK5e_revoke_bad_system', pg_temp.refused(sa, $q$select public.admin_revoke_permission('92190000-0000-0000-0000-000000000003', 'billing')$q$), 1);
end
$$;

-- CHECK 6: direct table access.
do $$
declare
  m uuid := '92190000-0000-0000-0000-000000000003';
  u uuid := '92190000-0000-0000-0000-000000000004';
  v_seen int;
begin
  insert into results values
    ('CHECK6a_user_cannot_insert', pg_temp.refused(u, $q$insert into public.admin_permissions (user_id, system, level) values ('92190000-0000-0000-0000-000000000004', 'food', 'edit')$q$), 1),
    ('CHECK6b_moderator_cannot_update', pg_temp.refused(m, $q$update public.admin_permissions set system = 'food' where user_id = '92190000-0000-0000-0000-000000000003'$q$), 1),
    ('CHECK6c_moderator_cannot_delete', pg_temp.refused(m, $q$delete from public.admin_permissions where user_id = '92190000-0000-0000-0000-000000000003'$q$), 1),
    ('CHECK6d_user_cannot_read_super_admins', pg_temp.refused(u, $q$select * from internal.platform_super_admins$q$), 1),
    ('CHECK6e_user_cannot_insert_super_admin', pg_temp.refused(u, $q$insert into internal.platform_super_admins values ('92190000-0000-0000-0000-000000000004')$q$), 1),
    ('CHECK6f_anon_cannot_call_grant', case when has_function_privilege('anon', 'public.admin_grant_permission(uuid,text,text)', 'execute') then 0 else 1 end, 1),
    ('CHECK6g_anon_cannot_call_helper', case when has_function_privilege('anon', 'internal.has_admin_permission(text,text)', 'execute') then 0 else 1 end, 1);

  -- The user sees no rows; the moderator sees only their own.
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into v_seen from public.admin_permissions;
  perform set_config('role', 'postgres', true);
  insert into results values ('CHECK6h_user_sees_no_rows', v_seen, 0);

  perform set_config('request.jwt.claim.sub', m::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into v_seen from public.admin_permissions;
  perform set_config('role', 'postgres', true);
  insert into results values ('CHECK6i_moderator_sees_own_row_only', v_seen, 1);
end
$$;

-- CHECK 7: admin_my_access.
do $$
begin
  insert into results values
    ('CHECK7a_super_admin_flag', pg_temp.as_user('92190000-0000-0000-0000-000000000001', $q$(public.admin_my_access()->>'super_admin')::boolean$q$), 1),
    ('CHECK7b_moderator_social_edit', pg_temp.as_user('92190000-0000-0000-0000-000000000003', $q$public.admin_my_access() = '{"super_admin": false, "permissions": {"social": "edit"}}'::jsonb$q$), 1),
    ('CHECK7c_user_empty', pg_temp.as_user('92190000-0000-0000-0000-000000000004', $q$public.admin_my_access() = '{"super_admin": false, "permissions": {}}'::jsonb$q$), 1);
end
$$;

-- CHECK 8: an older audit event type is still accepted after the constraint rewrite.
insert into public.audit_log (actor_id, event_type, detail) values (null, 'system_notification_sent', '{}'::jsonb);
insert into results
select 'CHECK8a_older_event_type_kept', count(*), 2 from public.audit_log where event_type = 'system_notification_sent';

select check_name, actual, expected from results order by check_name;
EOF

dropdb_any "$DB_NAME"
if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi

# The migration runs twice: it must be idempotent (and must not re-seed or
# duplicate anything the first run created).
for step in "$WORK_DIR/00_stub.sql" "$SCHEMA_FILE" "$WORK_DIR/05_pre_seed.sql" "$MIGRATION_FILE" "$MIGRATION_FILE" "$WORK_DIR/10_assert.sql"; do
  if ! run_psql "$DB_NAME" "$step"; then
    echo "FAIL: $step errored" >&2
    dropdb_any "$DB_NAME"
    exit 1
  fi
done
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
