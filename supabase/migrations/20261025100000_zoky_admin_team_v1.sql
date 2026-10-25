-- ZOKY-ADMIN-001: ZOKY team leads manage ZOKY Admin's food/merchant team.
--
-- Founder approval (2026-10-25, .wyn/company/APPROVALS.md):
--   * ZOKY Admin is a separate app for ZOKY Food and ZOKY Merchant.
--   * A ZOKY Team Lead may grant and revoke the WYN-219 `food` and `merchant`
--     permissions (view/edit) without the super admin, and nothing else.
--   * Only the super admin appoints or removes Team Leads; a Lead cannot
--     appoint another Lead.
--
-- Additive only. public.admin_permissions stays the single source of truth
-- and every Food/Merchant RPC keeps checking internal.has_admin_permission()
-- exactly as before. A Lead can never:
--   * grant or revoke account, social or maps;
--   * change their own rows, another Lead's rows or the super admin;
--   * appoint or remove a Lead.
-- Leads' own food/merchant permissions are granted by the super admin.
--
-- Requires: 20261010150000_wyn219_admin_permissions_foundation.sql applied.
-- Spec: .wyn/docs/product/zoky-admin-001-split-proposal.md
-- Test: supabase/tests/zoky_admin_team_test.sh
-- Rollback: supabase/rollbacks/20261025100000_zoky_admin_team_v1_rollback.sql

create schema if not exists internal;

-- ------------------------------------------------------------
-- Table
-- ------------------------------------------------------------

-- Not exposed through PostgREST (internal schema) and not granted to any API
-- role: changed only through admin_set_zoky_team_lead() below.
create table if not exists internal.zoky_team_leads (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  appointed_by uuid references public.profiles (id) on delete set null,
  appointed_at timestamptz not null default now()
);

revoke all on table internal.zoky_team_leads from public, anon, authenticated;

-- ------------------------------------------------------------
-- Check helpers
-- ------------------------------------------------------------

create or replace function internal.is_zoky_team_lead()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from internal.zoky_team_leads l
    where l.user_id = (select auth.uid())
  );
$$;

-- Raises unless the caller may manage the ZOKY team's permission on
-- p_user_id: the super admin may change anyone but themselves (they already
-- hold every permission); a Lead may change only accounts that are neither
-- a Lead (themselves included) nor the super admin.
create or replace function internal.zoky_assert_can_manage(p_user_id uuid, p_system text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_super boolean := internal.is_super_admin();
begin
  if not v_super and not internal.is_zoky_team_lead() then
    raise exception 'Only the super admin or a ZOKY Team Lead can manage the ZOKY team' using errcode = '42501';
  end if;
  if p_system is null or p_system not in ('food', 'merchant') then
    raise exception 'The ZOKY team can only hold food or merchant permissions' using errcode = '22023';
  end if;
  if p_user_id is null or not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'User not found' using errcode = 'P0002';
  end if;
  if exists (select 1 from internal.platform_super_admins where user_id = p_user_id) then
    raise exception 'The super admin already has every permission' using errcode = '22023';
  end if;
  if not v_super and exists (select 1 from internal.zoky_team_leads where user_id = p_user_id) then
    raise exception 'Only the super admin can change a ZOKY Team Lead''s permissions' using errcode = '42501';
  end if;
end;
$$;

revoke all on function internal.is_zoky_team_lead() from public, anon;
revoke all on function internal.zoky_assert_can_manage(uuid, text) from public, anon, authenticated;
grant execute on function internal.is_zoky_team_lead() to authenticated;

-- ------------------------------------------------------------
-- Audit event types (additive; keeps every existing value)
-- ------------------------------------------------------------

do $$
declare
  v_name text;
  v_def text;
  v_values text[];
  v_new text[] := array['zoky_team_lead_appointed', 'zoky_team_lead_removed'];
begin
  select c.conname, pg_get_constraintdef(c.oid)
    into v_name, v_def
  from pg_constraint c
  where c.conrelid = 'public.audit_log'::regclass
    and c.contype = 'c'
    and pg_get_constraintdef(c.oid) like '%event_type%'
  limit 1;

  if v_def is null then
    raise exception 'audit_log event_type check constraint not found';
  end if;

  -- Same two constraint shapes as the WYN-219 foundation migration handles.
  select array_agg(distinct x.m[1] order by x.m[1])
    into v_values
  from regexp_matches(v_def, '''([a-z0-9_]+)''', 'g') as x(m);

  if v_values is null then
    select array_agg(distinct btrim(v) order by btrim(v))
      into v_values
    from regexp_matches(v_def, '''\{([^}]*)\}''') as x(m),
         unnest(string_to_array(x.m[1], ',')) as v;
  end if;

  if v_values is null or cardinality(v_values) < 2
     or exists (select 1 from unnest(v_values) as v where v !~ '^[a-z0-9_]+$') then
    raise exception 'Could not read the audit_log event types from: %', v_def;
  end if;

  if v_new <@ v_values then
    return;
  end if;

  select array_agg(distinct v order by v) into v_values
  from unnest(v_values || v_new) as v;

  execute format('alter table public.audit_log drop constraint %I', v_name);
  execute format(
    'alter table public.audit_log add constraint audit_log_event_type_check check (event_type in (%s))',
    (select string_agg(quote_literal(v), ', ') from unnest(v_values) as v)
  );
end
$$;

-- ------------------------------------------------------------
-- RPCs
-- ------------------------------------------------------------

-- The caller's own ZOKY Admin access: super admin, Team Lead and their
-- food/merchant levels only.
create or replace function public.zoky_admin_my_access()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'super_admin', internal.is_super_admin(),
    'team_lead', internal.is_zoky_team_lead(),
    'permissions', coalesce(
      (select jsonb_object_agg(ap.system, ap.level)
         from public.admin_permissions ap
        where ap.user_id = (select auth.uid())
          and ap.system in ('food', 'merchant')),
      '{}'::jsonb
    )
  );
$$;

-- Super admin only: appoint (p_enabled = true) or remove a Team Lead.
-- Returns whether anything changed.
create or replace function public.admin_set_zoky_team_lead(p_user_id uuid, p_enabled boolean)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_changed int;
begin
  if not internal.is_super_admin() then
    raise exception 'Only the super admin can appoint or remove ZOKY Team Leads' using errcode = '42501';
  end if;
  if p_enabled is null then
    raise exception 'p_enabled is required' using errcode = '22023';
  end if;
  if p_user_id is null or not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'User not found' using errcode = 'P0002';
  end if;
  if exists (select 1 from internal.platform_super_admins where user_id = p_user_id) then
    raise exception 'The super admin cannot be a ZOKY Team Lead' using errcode = '22023';
  end if;

  if p_enabled then
    insert into internal.zoky_team_leads (user_id, appointed_by, appointed_at)
    values (p_user_id, v_actor, now())
    on conflict (user_id) do nothing;
  else
    delete from internal.zoky_team_leads where user_id = p_user_id;
  end if;
  get diagnostics v_changed = row_count;

  if v_changed = 0 then
    return false;
  end if;

  perform internal.log_audit_event(
    v_actor,
    case when p_enabled then 'zoky_team_lead_appointed' else 'zoky_team_lead_removed' end,
    p_user_id,
    '{}'::jsonb
  );
  return true;
end;
$$;

-- Super admin or Team Lead: exact (case-insensitive) username lookup so a
-- Lead can add a member without the Account permission. Exact match only,
-- one row at most -- no browsing of accounts.
create or replace function public.admin_zoky_find_user(p_username text)
returns table (user_id uuid, username text, display_name text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not internal.is_super_admin() and not internal.is_zoky_team_lead() then
    raise exception 'Only the super admin or a ZOKY Team Lead can manage the ZOKY team' using errcode = '42501';
  end if;

  return query
  select p.id, p.username, p.display_name
  from public.profiles p
  where p_username is not null
    and lower(p.username) = lower(btrim(ltrim(btrim(p_username), '@')))
  limit 1;
end;
$$;

-- Super admin or Team Lead: everyone on the ZOKY team -- food/merchant
-- permission rows (system/level set) and Leads without such rows (system
-- and level null).
create or replace function public.admin_zoky_list_team()
returns table (
  user_id uuid,
  username text,
  display_name text,
  is_team_lead boolean,
  system text,
  level text,
  granted_by uuid,
  granted_by_username text,
  granted_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not internal.is_super_admin() and not internal.is_zoky_team_lead() then
    raise exception 'Only the super admin or a ZOKY Team Lead can manage the ZOKY team' using errcode = '42501';
  end if;

  return query
  select p.id, p.username, p.display_name, (l.user_id is not null),
         ap.system, ap.level, ap.granted_by, g.username, ap.granted_at
  from public.admin_permissions ap
  join public.profiles p on p.id = ap.user_id
  left join internal.zoky_team_leads l on l.user_id = ap.user_id
  left join public.profiles g on g.id = ap.granted_by
  where ap.system in ('food', 'merchant')
  union all
  select p.id, p.username, p.display_name, true,
         null::text, null::text, null::uuid, null::text, null::timestamptz
  from internal.zoky_team_leads l
  join public.profiles p on p.id = l.user_id
  where not exists (
    select 1 from public.admin_permissions ap
    where ap.user_id = l.user_id and ap.system in ('food', 'merchant')
  )
  order by 2 nulls last, 5 nulls first;
end;
$$;

create or replace function public.admin_zoky_grant_permission(p_user_id uuid, p_system text, p_level text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_previous text;
begin
  perform internal.zoky_assert_can_manage(p_user_id, p_system);
  if p_level is null or p_level not in ('view', 'edit') then
    raise exception 'Invalid level: %', p_level using errcode = '22023';
  end if;

  select level into v_previous
  from public.admin_permissions
  where user_id = p_user_id and system = p_system;

  if v_previous is not distinct from p_level then
    return;
  end if;

  insert into public.admin_permissions (user_id, system, level, granted_by, granted_at)
  values (p_user_id, p_system, p_level, v_actor, now())
  on conflict (user_id, system)
  do update set level = excluded.level, granted_by = excluded.granted_by, granted_at = excluded.granted_at;

  perform internal.log_audit_event(
    v_actor,
    'admin_permission_granted',
    p_user_id,
    jsonb_build_object('system', p_system, 'level', p_level, 'previous_level', v_previous, 'via', 'zoky_team')
  );
end;
$$;

create or replace function public.admin_zoky_revoke_permission(p_user_id uuid, p_system text)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_previous text;
begin
  perform internal.zoky_assert_can_manage(p_user_id, p_system);

  delete from public.admin_permissions
  where user_id = p_user_id and system = p_system
  returning level into v_previous;

  if v_previous is null then
    return false;
  end if;

  perform internal.log_audit_event(
    v_actor,
    'admin_permission_revoked',
    p_user_id,
    jsonb_build_object('system', p_system, 'previous_level', v_previous, 'via', 'zoky_team')
  );
  return true;
end;
$$;

revoke all on function public.zoky_admin_my_access() from public, anon;
revoke all on function public.admin_set_zoky_team_lead(uuid, boolean) from public, anon;
revoke all on function public.admin_zoky_find_user(text) from public, anon;
revoke all on function public.admin_zoky_list_team() from public, anon;
revoke all on function public.admin_zoky_grant_permission(uuid, text, text) from public, anon;
revoke all on function public.admin_zoky_revoke_permission(uuid, text) from public, anon;
grant execute on function public.zoky_admin_my_access() to authenticated;
grant execute on function public.admin_set_zoky_team_lead(uuid, boolean) to authenticated;
grant execute on function public.admin_zoky_find_user(text) to authenticated;
grant execute on function public.admin_zoky_list_team() to authenticated;
grant execute on function public.admin_zoky_grant_permission(uuid, text, text) to authenticated;
grant execute on function public.admin_zoky_revoke_permission(uuid, text) to authenticated;
