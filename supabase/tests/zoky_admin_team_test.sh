#!/usr/bin/env bash
# ZOKY-ADMIN-001: ZOKY Team Leads manage ZOKY Admin's food/merchant team
# (supabase/migrations/20261025100000_zoky_admin_team_v1.sql).
#
#   1. Only the super admin appoints/removes Leads; a Lead, a platform admin,
#      a food:edit member and a user are refused. The super admin cannot be
#      a Lead. Appoint/remove write audit rows; repeats are no-ops.
#   2. A Lead grants/upgrades/revokes food and merchant for a regular user;
#      every change is audited with via=zoky_team and gives real access
#      through internal.has_admin_permission().
#   3. Privilege escalation is refused: a Lead cannot grant account/social/
#      maps, change their own rows, change another Lead or the super admin,
#      or appoint a Lead; a member with food:edit cannot manage the team.
#   4. Leads and the super admin can list the team and look up one user by
#      exact username; nobody else can. Anon cannot execute any new RPC and
#      no API role can read or write internal.zoky_team_leads.
#   5. zoky_admin_my_access() reports super admin / Lead / food+merchant only.
#   6. The migration is idempotent; the rollback removes only the new objects
#      and keeps every admin_permissions row.
#
# Requirements: a local PostgreSQL server reachable either as the current OS
# user or via `sudo -u postgres`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
FOUNDATION_FILE="$SCRIPT_DIR/../migrations/20261010150000_wyn219_admin_permissions_foundation.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations/20261025100000_zoky_admin_team_v1.sql"
ROLLBACK_FILE="$SCRIPT_DIR/../rollbacks/20261025100000_zoky_admin_team_v1_rollback.sql"
DB_NAME="zoky_admin_team_test"
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
--   sa    the Founder (super admin)
--   lead  ZOKY Team Lead (food:edit from the super admin)
--   lead2 a second ZOKY Team Lead
--   adm   a platform admin with no permissions
--   fe    a member with food:edit (not a Lead)
--   usr   a regular user the Lead adds to the team
--   soc   a moderator (seeded social:edit by the foundation migration)
insert into auth.users (id, email) values
  ('2a000000-0000-0000-0000-000000000001', 'sa@test.invalid'),
  ('2a000000-0000-0000-0000-000000000002', 'lead@test.invalid'),
  ('2a000000-0000-0000-0000-000000000003', 'lead2@test.invalid'),
  ('2a000000-0000-0000-0000-000000000004', 'adm@test.invalid'),
  ('2a000000-0000-0000-0000-000000000005', 'fe@test.invalid'),
  ('2a000000-0000-0000-0000-000000000006', 'usr@test.invalid'),
  ('2a000000-0000-0000-0000-000000000007', 'soc@test.invalid');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('2a000000-0000-0000-0000-000000000001', 'z_sa', 'sa', 'admin', false),
  ('2a000000-0000-0000-0000-000000000002', 'z_lead', 'lead', 'user', false),
  ('2a000000-0000-0000-0000-000000000003', 'z_lead2', 'lead2', 'user', false),
  ('2a000000-0000-0000-0000-000000000004', 'z_adm', 'adm', 'admin', false),
  ('2a000000-0000-0000-0000-000000000005', 'z_fe', 'fe', 'user', false),
  ('2a000000-0000-0000-0000-000000000006', 'Z_Usr', 'usr', 'user', false),
  ('2a000000-0000-0000-0000-000000000007', 'z_soc', 'soc', 'moderator', false);
EOF

cat > "$WORK_DIR/10_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

create table results (check_name text primary key, actual int, expected int);
grant all on results to authenticated;

insert into internal.platform_super_admins (user_id) values ('2a000000-0000-0000-0000-000000000001');
insert into public.admin_permissions (user_id, system, level) values
  ('2a000000-0000-0000-0000-000000000002', 'food', 'edit'),
  ('2a000000-0000-0000-0000-000000000005', 'food', 'edit');

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

-- CHECK 1: appointing Leads.
do $$
declare
  sa uuid := '2a000000-0000-0000-0000-000000000001';
  lead text := '2a000000-0000-0000-0000-000000000002';
  lead2 text := '2a000000-0000-0000-0000-000000000003';
  adm uuid := '2a000000-0000-0000-0000-000000000004';
  fe uuid := '2a000000-0000-0000-0000-000000000005';
  usr uuid := '2a000000-0000-0000-0000-000000000006';
begin
  insert into results values
    ('CHECK1a_admin_cannot_appoint', pg_temp.refused(adm, format($q$select public.admin_set_zoky_team_lead(%L, true)$q$, lead)), 1),
    ('CHECK1b_food_edit_cannot_appoint', pg_temp.refused(fe, format($q$select public.admin_set_zoky_team_lead(%L, true)$q$, lead)), 1),
    ('CHECK1c_user_cannot_appoint_self', pg_temp.refused(usr, format($q$select public.admin_set_zoky_team_lead(%L, true)$q$, usr)), 1),
    ('CHECK1d_no_session_cannot_appoint', pg_temp.refused(null, format($q$select public.admin_set_zoky_team_lead(%L, true)$q$, lead)), 1),
    ('CHECK1e_super_admin_appoints', pg_temp.as_user(sa, format($q$public.admin_set_zoky_team_lead(%L, true)$q$, lead)), 1),
    ('CHECK1f_repeat_appoint_noop', pg_temp.as_user(sa, format($q$public.admin_set_zoky_team_lead(%L, true)$q$, lead)), 0),
    ('CHECK1g_super_admin_appoints_second', pg_temp.as_user(sa, format($q$public.admin_set_zoky_team_lead(%L, true)$q$, lead2)), 1),
    ('CHECK1h_super_admin_not_a_lead', pg_temp.refused(sa, format($q$select public.admin_set_zoky_team_lead(%L, true)$q$, sa)), 1),
    ('CHECK1i_unknown_user', pg_temp.refused(sa, $q$select public.admin_set_zoky_team_lead('2a000000-0000-0000-0000-0000000000ff', true)$q$), 1),
    ('CHECK1j_lead_cannot_appoint', pg_temp.refused(lead::uuid, format($q$select public.admin_set_zoky_team_lead(%L, true)$q$, usr)), 1),
    ('CHECK1k_lead_cannot_remove_other_lead', pg_temp.refused(lead::uuid, format($q$select public.admin_set_zoky_team_lead(%L, false)$q$, lead2)), 1),
    ('CHECK1l_lead_flag', pg_temp.as_user(lead::uuid, $q$internal.is_zoky_team_lead()$q$), 1),
    ('CHECK1m_user_not_lead', pg_temp.as_user(usr, $q$internal.is_zoky_team_lead()$q$), 0);
end
$$;

insert into results
select 'CHECK1n_audit_appointed', count(*), 2 from public.audit_log
 where event_type = 'zoky_team_lead_appointed' and actor_id = '2a000000-0000-0000-0000-000000000001';

-- CHECK 2: a Lead manages a regular user's food/merchant access.
do $$
declare
  lead uuid := '2a000000-0000-0000-0000-000000000002';
  usr text := '2a000000-0000-0000-0000-000000000006';
begin
  insert into results values
    ('CHECK2a_lead_grants_food_view', 1 - pg_temp.refused(lead, format($q$select public.admin_zoky_grant_permission(%L, 'food', 'view')$q$, usr)), 1),
    ('CHECK2b_usr_food_view', pg_temp.as_user(usr::uuid, $q$internal.has_admin_permission('food','view')$q$), 1),
    ('CHECK2c_usr_food_edit_denied', pg_temp.as_user(usr::uuid, $q$internal.has_admin_permission('food','edit')$q$), 0),
    ('CHECK2d_lead_upgrades_food_edit', 1 - pg_temp.refused(lead, format($q$select public.admin_zoky_grant_permission(%L, 'food', 'edit')$q$, usr)), 1),
    ('CHECK2e_usr_food_edit', pg_temp.as_user(usr::uuid, $q$internal.has_admin_permission('food','edit')$q$), 1),
    ('CHECK2f_lead_grants_merchant_view', 1 - pg_temp.refused(lead, format($q$select public.admin_zoky_grant_permission(%L, 'merchant', 'view')$q$, usr)), 1),
    ('CHECK2g_same_level_noop', 1 - pg_temp.refused(lead, format($q$select public.admin_zoky_grant_permission(%L, 'merchant', 'view')$q$, usr)), 1),
    ('CHECK2h_lead_revokes_merchant', pg_temp.as_user(lead, format($q$public.admin_zoky_revoke_permission(%L, 'merchant')$q$, usr)), 1),
    ('CHECK2i_revoke_missing_false', pg_temp.as_user(lead, format($q$public.admin_zoky_revoke_permission(%L, 'merchant')$q$, usr)), 0),
    ('CHECK2j_usr_merchant_gone', pg_temp.as_user(usr::uuid, $q$internal.has_admin_permission('merchant','view')$q$), 0),
    ('CHECK2k_bad_level', pg_temp.refused(lead, format($q$select public.admin_zoky_grant_permission(%L, 'food', 'owner')$q$, usr)), 1),
    ('CHECK2l_unknown_user', pg_temp.refused(lead, $q$select public.admin_zoky_grant_permission('2a000000-0000-0000-0000-0000000000ff', 'food', 'view')$q$), 1);
end
$$;

insert into results
select 'CHECK2m_audit_granted_via_zoky', count(*), 3 from public.audit_log
 where event_type = 'admin_permission_granted' and detail->>'via' = 'zoky_team'
   and actor_id = '2a000000-0000-0000-0000-000000000002' and target_id = '2a000000-0000-0000-0000-000000000006';
insert into results
select 'CHECK2n_audit_upgrade_previous', count(*), 1 from public.audit_log
 where event_type = 'admin_permission_granted' and detail->>'via' = 'zoky_team'
   and detail->>'level' = 'edit' and detail->>'previous_level' = 'view';
insert into results
select 'CHECK2o_audit_revoked_via_zoky', count(*), 1 from public.audit_log
 where event_type = 'admin_permission_revoked' and detail->>'via' = 'zoky_team' and detail->>'previous_level' = 'view';

-- CHECK 3: privilege escalation is refused.
do $$
declare
  sa text := '2a000000-0000-0000-0000-000000000001';
  lead uuid := '2a000000-0000-0000-0000-000000000002';
  lead2 text := '2a000000-0000-0000-0000-000000000003';
  fe uuid := '2a000000-0000-0000-0000-000000000005';
  usr text := '2a000000-0000-0000-0000-000000000006';
  soc text := '2a000000-0000-0000-0000-000000000007';
begin
  insert into results values
    ('CHECK3a_lead_cannot_grant_account', pg_temp.refused(lead, format($q$select public.admin_zoky_grant_permission(%L, 'account', 'edit')$q$, usr)), 1),
    ('CHECK3b_lead_cannot_grant_social', pg_temp.refused(lead, format($q$select public.admin_zoky_grant_permission(%L, 'social', 'view')$q$, usr)), 1),
    ('CHECK3c_lead_cannot_grant_maps', pg_temp.refused(lead, format($q$select public.admin_zoky_grant_permission(%L, 'maps', 'view')$q$, usr)), 1),
    ('CHECK3d_lead_cannot_revoke_social', pg_temp.refused(lead, format($q$select public.admin_zoky_revoke_permission(%L, 'social')$q$, soc)), 1),
    ('CHECK3e_lead_cannot_grant_self_merchant', pg_temp.refused(lead, format($q$select public.admin_zoky_grant_permission(%L, 'merchant', 'edit')$q$, lead)), 1),
    ('CHECK3f_lead_cannot_revoke_self', pg_temp.refused(lead, format($q$select public.admin_zoky_revoke_permission(%L, 'food')$q$, lead)), 1),
    ('CHECK3g_lead_cannot_grant_other_lead', pg_temp.refused(lead, format($q$select public.admin_zoky_grant_permission(%L, 'food', 'edit')$q$, lead2)), 1),
    ('CHECK3h_lead_cannot_touch_super_admin', pg_temp.refused(lead, format($q$select public.admin_zoky_revoke_permission(%L, 'food')$q$, sa)), 1),
    ('CHECK3i_lead_cannot_use_wyn219_grant', pg_temp.refused(lead, format($q$select public.admin_grant_permission(%L, 'food', 'edit')$q$, usr)), 1),
    ('CHECK3j_food_edit_cannot_manage_team', pg_temp.refused(fe, format($q$select public.admin_zoky_grant_permission(%L, 'food', 'view')$q$, usr)), 1),
    ('CHECK3k_food_edit_cannot_grant_self_merchant', pg_temp.refused(fe, format($q$select public.admin_zoky_grant_permission(%L, 'merchant', 'view')$q$, fe)), 1),
    ('CHECK3l_lead_cannot_write_table', pg_temp.refused(lead, format($q$insert into public.admin_permissions (user_id, system, level) values (%L, 'merchant', 'edit')$q$, lead)), 1),
    ('CHECK3m_lead_cannot_read_leads_table', pg_temp.refused(lead, $q$select * from internal.zoky_team_leads$q$), 1),
    ('CHECK3n_user_cannot_insert_lead', pg_temp.refused(usr::uuid, format($q$insert into internal.zoky_team_leads (user_id) values (%L)$q$, usr)), 1),
    ('CHECK3o_cannot_call_assert_helper', pg_temp.refused(lead, format($q$select internal.zoky_assert_can_manage(%L, 'food')$q$, usr)), 1),
    ('CHECK3p_lead_still_no_merchant', pg_temp.as_user(lead, $q$internal.has_admin_permission('merchant','view')$q$), 0),
    ('CHECK3q_soc_still_social_edit', pg_temp.as_user(soc::uuid, $q$internal.has_admin_permission('social','edit')$q$), 1);
end
$$;

-- CHECK 4: the super admin may manage a Lead's permissions.
do $$
declare
  sa uuid := '2a000000-0000-0000-0000-000000000001';
  lead2 text := '2a000000-0000-0000-0000-000000000003';
begin
  insert into results values
    ('CHECK4a_super_admin_grants_lead', 1 - pg_temp.refused(sa, format($q$select public.admin_zoky_grant_permission(%L, 'merchant', 'view')$q$, lead2)), 1),
    ('CHECK4b_super_admin_cannot_target_self', pg_temp.refused(sa, format($q$select public.admin_zoky_grant_permission(%L, 'food', 'view')$q$, sa)), 1);
end
$$;

-- CHECK 5: listing and lookup.
do $$
declare
  sa uuid := '2a000000-0000-0000-0000-000000000001';
  lead uuid := '2a000000-0000-0000-0000-000000000002';
  adm uuid := '2a000000-0000-0000-0000-000000000004';
  fe uuid := '2a000000-0000-0000-0000-000000000005';
  v int;
begin
  insert into results values
    ('CHECK5a_admin_cannot_list', pg_temp.refused(adm, $q$select * from public.admin_zoky_list_team()$q$), 1),
    ('CHECK5b_food_edit_cannot_list', pg_temp.refused(fe, $q$select * from public.admin_zoky_list_team()$q$), 1),
    ('CHECK5c_food_edit_cannot_find', pg_temp.refused(fe, $q$select * from public.admin_zoky_find_user('z_usr')$q$), 1),
    ('CHECK5d_lead_finds_case_insensitive_with_at', pg_temp.as_user(lead, $q$(select count(*) from public.admin_zoky_find_user(' @z_usr ')) = 1$q$), 1),
    ('CHECK5e_find_is_exact', pg_temp.as_user(lead, $q$(select count(*) from public.admin_zoky_find_user('z_')) = 0$q$), 1),
    ('CHECK5f_find_null', pg_temp.as_user(lead, $q$(select count(*) from public.admin_zoky_find_user(null)) = 0$q$), 1);

  -- lead food:edit, lead2 merchant:view, fe food:edit, usr food:edit; social rows excluded.
  perform set_config('request.jwt.claim.sub', lead::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into v from public.admin_zoky_list_team();
  perform set_config('role', 'postgres', true);
  insert into results values ('CHECK5g_lead_lists_food_merchant_rows', v, 4);

  perform set_config('request.jwt.claim.sub', lead::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into v from public.admin_zoky_list_team() where is_team_lead;
  perform set_config('role', 'postgres', true);
  insert into results values ('CHECK5h_leads_flagged', v, 2);
end
$$;

-- A Lead without any food/merchant row still appears (once, with no system).
insert into auth.users (id, email) values ('2a000000-0000-0000-0000-000000000008', 'lead3@test.invalid');
insert into public.profiles (id, username, display_name, platform_role, is_private)
values ('2a000000-0000-0000-0000-000000000008', 'z_lead3', 'lead3', 'user', false);
do $$
declare
  sa uuid := '2a000000-0000-0000-0000-000000000001';
  v int;
begin
  perform pg_temp.as_user(sa, $q$public.admin_set_zoky_team_lead('2a000000-0000-0000-0000-000000000008', true)$q$);
  perform set_config('request.jwt.claim.sub', sa::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into v from public.admin_zoky_list_team() where user_id = '2a000000-0000-0000-0000-000000000008' and system is null;
  perform set_config('role', 'postgres', true);
  insert into results values ('CHECK5i_lead_without_rows_listed', v, 1);
  insert into results values
    ('CHECK5j_super_admin_removes_lead', pg_temp.as_user(sa, $q$public.admin_set_zoky_team_lead('2a000000-0000-0000-0000-000000000008', false)$q$), 1),
    ('CHECK5k_repeat_remove_noop', pg_temp.as_user(sa, $q$public.admin_set_zoky_team_lead('2a000000-0000-0000-0000-000000000008', false)$q$), 0);
end
$$;
insert into results
select 'CHECK5l_audit_removed', count(*), 1 from public.audit_log where event_type = 'zoky_team_lead_removed';

-- CHECK 6: anon / privileges.
insert into results values
  ('CHECK6a_anon_my_access', case when has_function_privilege('anon', 'public.zoky_admin_my_access()', 'execute') then 1 else 0 end, 0),
  ('CHECK6b_anon_set_lead', case when has_function_privilege('anon', 'public.admin_set_zoky_team_lead(uuid,boolean)', 'execute') then 1 else 0 end, 0),
  ('CHECK6c_anon_find', case when has_function_privilege('anon', 'public.admin_zoky_find_user(text)', 'execute') then 1 else 0 end, 0),
  ('CHECK6d_anon_list', case when has_function_privilege('anon', 'public.admin_zoky_list_team()', 'execute') then 1 else 0 end, 0),
  ('CHECK6e_anon_grant', case when has_function_privilege('anon', 'public.admin_zoky_grant_permission(uuid,text,text)', 'execute') then 1 else 0 end, 0),
  ('CHECK6f_anon_revoke', case when has_function_privilege('anon', 'public.admin_zoky_revoke_permission(uuid,text)', 'execute') then 1 else 0 end, 0),
  ('CHECK6g_authenticated_assert_helper', case when has_function_privilege('authenticated', 'internal.zoky_assert_can_manage(uuid,text)', 'execute') then 1 else 0 end, 0);

-- CHECK 7: zoky_admin_my_access.
do $$
begin
  insert into results values
    ('CHECK7a_lead_access', pg_temp.as_user('2a000000-0000-0000-0000-000000000002',
      $q$public.zoky_admin_my_access() = '{"super_admin": false, "team_lead": true, "permissions": {"food": "edit"}}'::jsonb$q$), 1),
    ('CHECK7b_moderator_social_hidden', pg_temp.as_user('2a000000-0000-0000-0000-000000000007',
      $q$public.zoky_admin_my_access() = '{"super_admin": false, "team_lead": false, "permissions": {}}'::jsonb$q$), 1),
    ('CHECK7c_super_admin', pg_temp.as_user('2a000000-0000-0000-0000-000000000001',
      $q$(public.zoky_admin_my_access()->>'super_admin')::boolean$q$), 1);
end
$$;

insert into results
select 'CHECK8a_permission_rows_before_rollback', count(*), 5 from public.admin_permissions;
EOF

cat > "$WORK_DIR/20_after_rollback.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on
insert into results
select 'CHECK8b_rollback_keeps_permissions', count(*), 5 from public.admin_permissions;
insert into results
select 'CHECK8c_rollback_drops_table', count(*), 0 from pg_tables where schemaname = 'internal' and tablename = 'zoky_team_leads';
insert into results
select 'CHECK8d_rollback_drops_rpcs', count(*), 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where (n.nspname = 'public' and p.proname in ('zoky_admin_my_access', 'admin_set_zoky_team_lead', 'admin_zoky_find_user',
          'admin_zoky_list_team', 'admin_zoky_grant_permission', 'admin_zoky_revoke_permission'))
    or (n.nspname = 'internal' and p.proname in ('is_zoky_team_lead', 'zoky_assert_can_manage'));
insert into results
select 'CHECK8e_foundation_untouched', count(*), 1 from pg_proc where proname = 'admin_grant_permission';
select check_name, actual, expected from results order by check_name;
EOF

dropdb_any "$DB_NAME"
if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi

for step in "$WORK_DIR/00_stub.sql" "$SCHEMA_FILE" "$WORK_DIR/05_pre_seed.sql" "$FOUNDATION_FILE" "$MIGRATION_FILE" "$MIGRATION_FILE" "$WORK_DIR/10_assert.sql" "$ROLLBACK_FILE" "$WORK_DIR/20_after_rollback.sql"; do
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
