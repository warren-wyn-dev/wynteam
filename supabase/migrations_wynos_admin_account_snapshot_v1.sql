-- WYNOS Account Phase 1: read-only, admin-only service evidence.
-- Canonical account ID is auth.users.id shared by WYNOS applications.
-- Requires staging security review before production application.
-- Evidence is NOT proof of service sign-in or activation.

create or replace function public.admin_wynos_account_snapshot(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_snapshot jsonb;
begin
  if (select auth.uid()) is null
     or coalesce((select p.platform_role
                  from public.profiles p
                  where p.id = (select auth.uid())), '') <> 'admin' then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'account_id', u.id,
    'created_at', u.created_at,
    'signals', jsonb_build_object(
      'social_profile', exists (
        select 1 from public.profiles p where p.id = u.id
      ),
      'food_activity', exists (
        select 1 from public.food_orders o where o.buyer_id = u.id
      ) or exists (
        select 1 from public.food_customer_addresses a where a.user_id = u.id
      ),
      'merchant_record', exists (
        select 1 from public.merchant_users mu where mu.user_id = u.id
      ) or exists (
        select 1 from public.merchant_applications ma where ma.user_id = u.id
      ) or exists (
        select 1 from public.merchant_memberships mm where mm.user_id = u.id
      ),
      'maps_activity', exists (
        select 1 from public.wynos_saved_places sp where sp.user_id = u.id
      ) or exists (
        select 1 from public.wynos_place_suggestions sg where sg.user_id = u.id
      ) or exists (
        select 1 from public.wynos_place_photos ph where ph.user_id = u.id
      )
    )
  ) into v_snapshot
  from auth.users u
  where u.id = p_user_id;

  return v_snapshot;
end;
$$;

revoke all on function public.admin_wynos_account_snapshot(uuid)
  from public, anon, authenticated;
grant execute on function public.admin_wynos_account_snapshot(uuid)
  to authenticated;
comment on function public.admin_wynos_account_snapshot(uuid) is
  'Admin-only service-record evidence for a shared WYNOS account; not a definitive activation or SSO state.';
