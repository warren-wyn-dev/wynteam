-- ROLLBACK for WYN-219 Phase 2, step 2 (Merchant): merchant application review checks -> merchant:view|edit
--
-- Generated from the production definitions dumped by
-- wyn219-dump-admin-check-definitions.yml (run 38059388028, 2026-10-10). Each
-- definition is copied verbatim; only its role-check expression changes:
--   staff check (admin or moderator) -> view (or edit where noted)
--   admin check                      -> edit
-- Data uses of profiles.platform_role (e.g. announcement audiences, the user
-- directory's role column) are unchanged.
--
-- Effect (Founder decisions 2026-10-10): the super admin keeps full access;
-- everyone else needs the matching permission from the Team Permissions page.
-- Requires: 20261010150000_wyn219_admin_permissions_foundation.sql applied.
-- Test: supabase/tests/wyn_219_step2_remaining_systems_test.sh
-- ROLLBACK: supabase/rollbacks/20261010170000_wyn219_step2_merchant_permissions_rollback.sql

-- public.admin_merchant_applications(p_status text, p_limit integer): restore production definition
CREATE OR REPLACE FUNCTION public.admin_merchant_applications(p_status text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, user_id uuid, applicant_username text, applicant_display_name text, business_name text, business_type text, contact_name text, phone text, address text, note text, status text, rejection_reason text, reviewed_at timestamp with time zone, reviewer_username text, created_at timestamp with time zone, updated_at timestamp with time zone, food_store_id uuid, merchant_access_enabled boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;
  if p_status is not null and p_status not in ('pending', 'approved', 'rejected') then
    raise exception 'Invalid merchant application status: %', p_status;
  end if;

  return query
  select
    ma.id,
    ma.user_id,
    applicant.username,
    applicant.display_name,
    ma.business_name,
    ma.business_type,
    ma.contact_name,
    ma.phone,
    ma.address,
    ma.note,
    ma.status,
    ma.rejection_reason,
    ma.reviewed_at,
    reviewer.username,
    ma.created_at,
    ma.updated_at,
    ma.food_store_id,
    (
      ma.food_store_id is not null
      and exists (
        select 1
        from public.merchant_memberships mm
        where mm.merchant_account_id = ma.merchant_account_id
          and mm.active
      )
    ) as merchant_access_enabled
  from public.merchant_applications ma
  left join public.profiles applicant on applicant.id = ma.user_id
  left join public.profiles reviewer on reviewer.id = ma.reviewed_by
  where p_status is null or ma.status = p_status
  order by
    case ma.status when 'pending' then 0 when 'rejected' then 1 else 2 end,
    ma.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
end;
$function$;

-- public.admin_review_merchant_application(p_application_id uuid, p_decision text, p_reason text): restore production definition
CREATE OR REPLACE FUNCTION public.admin_review_merchant_application(p_application_id uuid, p_decision text, p_reason text DEFAULT NULL::text)
 RETURNS TABLE(status text, food_store_id uuid, merchant_access_enabled boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_admin uuid := auth.uid();
  v_application public.merchant_applications%rowtype;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_store_id uuid;
  v_account_id uuid;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can review merchant applications';
  end if;
  if p_decision not in ('approved', 'rejected') then
    raise exception 'Invalid merchant decision: %', p_decision;
  end if;

  select * into v_application
  from public.merchant_applications
  where id = p_application_id
  for update;

  if not found then raise exception 'Merchant application not found'; end if;
  if v_application.status = 'approved' then raise exception 'Approved merchant applications are final'; end if;
  if p_decision = 'rejected' and v_reason is null then raise exception 'Rejection reason is required'; end if;

  v_account_id := v_application.merchant_account_id;
  if v_account_id is null then
    insert into public.merchant_accounts(business_name, business_type, status)
    values (v_application.business_name, v_application.business_type, 'pending')
    returning id into v_account_id;

    insert into public.merchant_memberships(merchant_account_id, user_id, role, active)
    values (v_account_id, v_application.user_id, 'owner', true)
    on conflict (merchant_account_id, user_id)
    do update set role='owner', active=true, updated_at=now();

    update public.merchant_applications
    set merchant_account_id=v_account_id
    where id=v_application.id;
  end if;

  if p_decision = 'approved' then
    v_store_id := v_application.food_store_id;

    update public.merchant_accounts
    set business_name=v_application.business_name,
        business_type=v_application.business_type,
        status='approved',
        updated_at=now()
    where id=v_account_id;

    if v_application.business_type = 'food' then
      if v_store_id is null then
        insert into public.food_stores(
          merchant_account_id, slug, name, description, phone, address, is_open, is_published
        ) values (
          v_account_id,
          'merchant-' || replace(v_application.id::text, '-', ''),
          left(v_application.business_name, 100),
          case when v_application.note is null then null else left(v_application.note, 1000) end,
          left(v_application.phone, 50),
          left(v_application.address, 500),
          false,
          false
        )
        returning id into v_store_id;
      else
        update public.food_stores
        set merchant_account_id = coalesce(merchant_account_id, v_account_id)
        where id = v_store_id;

        if exists (
          select 1 from public.food_stores
          where id=v_store_id and merchant_account_id <> v_account_id
        ) then
          raise exception 'Food store belongs to another merchant account';
        end if;
      end if;
    end if;

    update public.merchant_applications
    set status='approved',
        rejection_reason=null,
        reviewed_at=now(),
        reviewed_by=v_admin,
        food_store_id=v_store_id,
        merchant_account_id=v_account_id,
        updated_at=now()
    where id=v_application.id;

    insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
    select v_account_id, mm.user_id, 'system',
      case
        when v_application.business_type='food'
          then 'คำขอ WYNOS Merchant ได้รับการอนุมัติแล้ว คุณสามารถเข้า Merchant Dashboard ได้'
        else 'คำขอ WYNOS Merchant ได้รับการอนุมัติแล้ว'
      end
    from public.merchant_memberships mm
    where mm.merchant_account_id=v_account_id and mm.active;

    if exists (select 1 from public.profiles where id=v_application.user_id) then
      insert into public.notifications(recipient_id, actor_id, type, reason)
      values (
        v_application.user_id, null, 'system',
        case
          when v_application.business_type='food'
            then 'คำขอ WYNOS Merchant ของคุณได้รับการอนุมัติแล้ว คุณสามารถเข้า Merchant Dashboard ได้'
          else 'คำขอ WYNOS Merchant ของคุณได้รับการอนุมัติแล้ว'
        end
      );
    end if;

    perform internal.log_audit_event(
      v_admin,
      'admin_merchant_application_approved',
      v_application.user_id,
      jsonb_build_object(
        'application_id', v_application.id,
        'merchant_account_id', v_account_id,
        'business_name', v_application.business_name,
        'business_type', v_application.business_type,
        'food_store_id', v_store_id
      )
    );
  else
    update public.merchant_accounts
    set status='pending', updated_at=now()
    where id=v_account_id;

    update public.merchant_applications
    set status='rejected',
        rejection_reason=v_reason,
        reviewed_at=now(),
        reviewed_by=v_admin,
        merchant_account_id=v_account_id,
        updated_at=now()
    where id=v_application.id;

    insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
    select v_account_id, mm.user_id, 'system',
      'คำขอ WYNOS Merchant ยังไม่ผ่านการอนุมัติ: ' || v_reason
    from public.merchant_memberships mm
    where mm.merchant_account_id=v_account_id and mm.active;

    if exists (select 1 from public.profiles where id=v_application.user_id) then
      insert into public.notifications(recipient_id, actor_id, type, reason)
      values (v_application.user_id, null, 'system', 'คำขอ WYNOS Merchant ของคุณยังไม่ผ่านการอนุมัติ: ' || v_reason);
    end if;

    perform internal.log_audit_event(
      v_admin,
      'admin_merchant_application_rejected',
      v_application.user_id,
      jsonb_build_object(
        'application_id', v_application.id,
        'merchant_account_id', v_account_id,
        'business_name', v_application.business_name,
        'business_type', v_application.business_type,
        'reason', v_reason
      )
    );
  end if;

  return query
  select
    ma.status,
    ma.food_store_id,
    (
      ma.food_store_id is not null
      and exists (
        select 1 from public.merchant_memberships mm
        where mm.merchant_account_id=ma.merchant_account_id and mm.active
      )
    )
  from public.merchant_applications ma
  where ma.id=v_application.id;
end;
$function$;
