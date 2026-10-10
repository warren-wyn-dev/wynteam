-- WYN-219 Phase 2, step 1: per-system admin permissions foundation.
--
-- Founder decisions (2026-10-10, .wyn/company/DECISIONS.md):
--   * Admin permissions are split by system: account, social, food, merchant, maps.
--   * Each system has two levels: view and edit (edit includes view).
--   * The Founder is the only super admin. Super admins are managed by
--     migration/workflow only -- there is no API to add or remove one.
--   * Existing moderators get social only. Other existing admins get nothing;
--     the super admin grants access per person.
--   * The audit log is for the super admin only (applied in step 2).
--
-- Additive only. No existing RPC, policy or view changes behaviour here:
-- every current check still reads profiles.platform_role. Step 2 moves those
-- checks to internal.has_admin_permission() one system at a time.
--
-- Spec: .wyn/docs/engineering/wyn-219-phase2-admin-permissions-proposal.md
-- Test: supabase/tests/wyn_219_admin_permissions_foundation_test.sh
--
-- ROLLBACK (nothing reads these objects until step 2):
--   drop function public.admin_list_permissions(), public.admin_revoke_permission(uuid, text),
--     public.admin_grant_permission(uuid, text, text), public.admin_my_access(),
--     internal.has_admin_permission(text, text), internal.is_super_admin();
--   drop table public.admin_permissions, internal.platform_super_admins;
--   (the two extra audit_log event types are harmless and may stay)

create schema if not exists internal;

-- ------------------------------------------------------------
-- Tables
-- ------------------------------------------------------------

-- Not exposed through PostgREST (internal schema) and not granted to any
-- API role: only a migration or the service role can change it.
create table if not exists internal.platform_super_admins (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

revoke all on table internal.platform_super_admins from public, anon, authenticated;

create table if not exists public.admin_permissions (
  user_id uuid not null references public.profiles (id) on delete cascade,
  system text not null check (system in ('account', 'social', 'food', 'merchant', 'maps')),
  level text not null check (level in ('view', 'edit')),
  -- null = seeded by a migration rather than granted by a person.
  granted_by uuid references public.profiles (id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, system)
);

alter table public.admin_permissions enable row level security;

-- Deny by default. Writes only go through the security definer RPCs below,
-- so no API role keeps insert/update/delete (Supabase's default privileges
-- would otherwise grant them).
revoke all on table public.admin_permissions from public, anon, authenticated;
grant select on table public.admin_permissions to authenticated;

-- ------------------------------------------------------------
-- Check helpers
-- ------------------------------------------------------------

create or replace function internal.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from internal.platform_super_admins s
    where s.user_id = (select auth.uid())
  );
$$;

-- True when the caller may act on p_system at p_level. Super admins pass
-- every check; edit satisfies view. Unknown systems or levels, a missing
-- session or a missing row all return false (deny by default).
create or replace function internal.has_admin_permission(p_system text, p_level text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_system in ('account', 'social', 'food', 'merchant', 'maps')
    and p_level in ('view', 'edit')
    and (
      internal.is_super_admin()
      or exists (
        select 1 from public.admin_permissions ap
        where ap.user_id = (select auth.uid())
          and ap.system = p_system
          and (ap.level = 'edit' or p_level = 'view')
      )
    );
$$;

revoke all on function internal.is_super_admin() from public, anon;
revoke all on function internal.has_admin_permission(text, text) from public, anon;
grant execute on function internal.is_super_admin() to authenticated;
grant execute on function internal.has_admin_permission(text, text) to authenticated;

-- Own rows, or every row for the super admin.
drop policy if exists "admin_permissions_select_own_or_super" on public.admin_permissions;
create policy "admin_permissions_select_own_or_super"
  on public.admin_permissions
  for select
  to authenticated
  using (user_id = (select auth.uid()) or internal.is_super_admin());

-- ------------------------------------------------------------
-- Audit event types (additive; keeps every existing value)
-- ------------------------------------------------------------

do $$
declare
  v_name text;
  v_def text;
  v_values text[];
  v_new text[] := array['admin_permission_granted', 'admin_permission_revoked'];
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

  -- Two equivalent shapes exist: `event_type in ('a', 'b')` (each value
  -- quoted) and, after some rewrites, `event_type = ANY ('{a,b}'::text[])`
  -- (one quoted array literal, as in production on 2026-10-10).
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

-- The caller's own access, for the Admin app layout and sidebar.
create or replace function public.admin_my_access()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'super_admin', internal.is_super_admin(),
    'permissions', coalesce(
      (select jsonb_object_agg(ap.system, ap.level)
         from public.admin_permissions ap
        where ap.user_id = (select auth.uid())),
      '{}'::jsonb
    )
  );
$$;

create or replace function public.admin_grant_permission(p_user_id uuid, p_system text, p_level text)
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
  if not internal.is_super_admin() then
    raise exception 'Only the super admin can grant admin permissions' using errcode = '42501';
  end if;
  if p_system is null or p_system not in ('account', 'social', 'food', 'merchant', 'maps') then
    raise exception 'Invalid system: %', p_system using errcode = '22023';
  end if;
  if p_level is null or p_level not in ('view', 'edit') then
    raise exception 'Invalid level: %', p_level using errcode = '22023';
  end if;
  if p_user_id is null or not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'User not found' using errcode = 'P0002';
  end if;
  if exists (select 1 from internal.platform_super_admins where user_id = p_user_id) then
    raise exception 'The super admin already has every permission' using errcode = '22023';
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
    jsonb_build_object('system', p_system, 'level', p_level, 'previous_level', v_previous)
  );
end;
$$;

create or replace function public.admin_revoke_permission(p_user_id uuid, p_system text)
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
  if not internal.is_super_admin() then
    raise exception 'Only the super admin can revoke admin permissions' using errcode = '42501';
  end if;
  if p_system is null or p_system not in ('account', 'social', 'food', 'merchant', 'maps') then
    raise exception 'Invalid system: %', p_system using errcode = '22023';
  end if;

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
    jsonb_build_object('system', p_system, 'previous_level', v_previous)
  );
  return true;
end;
$$;

create or replace function public.admin_list_permissions()
returns table (
  user_id uuid,
  username text,
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
  if not internal.is_super_admin() then
    raise exception 'Only the super admin can list admin permissions' using errcode = '42501';
  end if;

  return query
  select ap.user_id, p.username, ap.system, ap.level, ap.granted_by, g.username, ap.granted_at
  from public.admin_permissions ap
  join public.profiles p on p.id = ap.user_id
  left join public.profiles g on g.id = ap.granted_by
  order by p.username nulls last, ap.system;
end;
$$;

revoke all on function public.admin_my_access() from public, anon;
revoke all on function public.admin_grant_permission(uuid, text, text) from public, anon;
revoke all on function public.admin_revoke_permission(uuid, text) from public, anon;
revoke all on function public.admin_list_permissions() from public, anon;
grant execute on function public.admin_my_access() to authenticated;
grant execute on function public.admin_grant_permission(uuid, text, text) to authenticated;
grant execute on function public.admin_revoke_permission(uuid, text) to authenticated;
grant execute on function public.admin_list_permissions() to authenticated;

-- ------------------------------------------------------------
-- Seed: existing moderators -> social:edit (Founder decision 2026-10-10)
-- ------------------------------------------------------------
-- Moderators today can review reports, moderate content, decide appeals and
-- ban/suspend users; the Founder placed user sanctions under Social. The
-- super admin is seeded separately by the apply workflow (it names the
-- account at apply time instead of committing it here).

insert into public.admin_permissions (user_id, system, level, granted_by)
select p.id, 'social', 'edit', null
from public.profiles p
where p.platform_role = 'moderator'
on conflict (user_id, system) do nothing;
