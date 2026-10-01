-- WYNOS Merchant application review from WYN Admin.
-- Keeps applicant-owned RLS intact; cross-user review is exposed only
-- through role-checked SECURITY DEFINER RPCs with explicit EXECUTE grants.

alter table public.merchant_applications
  add column if not exists food_store_id uuid
  references public.food_stores(id) on delete set null;

create index if not exists merchant_applications_food_store_idx
  on public.merchant_applications (food_store_id)
  where food_store_id is not null;

alter table public.audit_log
  drop constraint if exists audit_log_event_type_check;

alter table public.audit_log
  add constraint audit_log_event_type_check
  check (event_type in (
    'moderation_action_applied',
    'appeal_decided',
    'system_notification_sent',
    'account_deleted',
    'data_exported',
    'admin_user_action_applied',
    'admin_user_unbanned',
    'admin_content_removed',
    'admin_content_restored',
    'admin_announcement_sent',
    'admin_merchant_application_approved',
    'admin_merchant_application_rejected'
  ));

create or replace function public.admin_merchant_applications(
  p_status text default null,
  p_limit integer default 100
)
returns table(
  id uuid,
  user_id uuid,
  applicant_username text,
  applicant_display_name text,
  business_name text,
  business_type text,
  contact_name text,
  phone text,
  address text,
  note text,
  status text,
  rejection_reason text,
  reviewed_at timestamptz,
  reviewer_username text,
  created_at timestamptz,
  updated_at timestamptz,
  food_store_id uuid,
  merchant_access_enabled boolean
)
language plpgsql
security definer
set search_path = public
as $$
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
    exists (
      select 1
      from public.food_staff fs
      where fs.user_id = ma.user_id
        and fs.active
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
$$;

revoke all on function public.admin_merchant_applications(text, integer) from public;
revoke all on function public.admin_merchant_applications(text, integer) from anon;
grant execute on function public.admin_merchant_applications(text, integer) to authenticated;

create or replace function public.admin_review_merchant_application(
  p_application_id uuid,
  p_decision text,
  p_reason text default null
)
returns table(
  status text,
  food_store_id uuid,
  merchant_access_enabled boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_application public.merchant_applications%rowtype;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_store_id uuid;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can review merchant applications';
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'Invalid merchant decision: %', p_decision;
  end if;

  select *
  into v_application
  from public.merchant_applications
  where id = p_application_id
  for update;

  if not found then
    raise exception 'Merchant application not found';
  end if;

  if v_application.status = 'approved' then
    raise exception 'Approved merchant applications are final';
  end if;

  if p_decision = 'rejected' and v_reason is null then
    raise exception 'Rejection reason is required';
  end if;

  if not exists (select 1 from public.profiles where id = v_application.user_id) then
    raise exception 'Applicant profile not found';
  end if;

  if p_decision = 'approved' then
    v_store_id := v_application.food_store_id;

    -- The current production Merchant dashboard is the WYNOS Food
    -- merchant surface. Food applications are provisioned immediately.
    -- Other business types are approved at application level and remain
    -- ready for their future domain-specific Merchant surface.
    if v_application.business_type = 'food' then
      if v_store_id is null then
        insert into public.food_stores (
          slug,
          name,
          description,
          phone,
          address,
          is_open,
          is_published
        ) values (
          'merchant-' || replace(v_application.id::text, '-', ''),
          left(v_application.business_name, 100),
          case when v_application.note is null then null else left(v_application.note, 1000) end,
          left(v_application.phone, 50),
          left(v_application.address, 500),
          false,
          false
        )
        returning id into v_store_id;
      end if;

      insert into public.food_staff (store_id, user_id, role, active)
      values (v_store_id, v_application.user_id, 'owner', true)
      on conflict (store_id, user_id)
      do update set role = 'owner', active = true;
    end if;

    update public.merchant_applications
    set status = 'approved',
        rejection_reason = null,
        reviewed_at = now(),
        reviewed_by = v_admin,
        food_store_id = v_store_id,
        updated_at = now()
    where id = v_application.id;

    insert into public.notifications (recipient_id, actor_id, type, reason)
    values (
      v_application.user_id,
      null,
      'system',
      case
        when v_application.business_type = 'food'
          then 'คำขอ WYNOS Merchant ของคุณได้รับการอนุมัติแล้ว คุณสามารถเข้า Merchant Dashboard ได้'
        else 'คำขอ WYNOS Merchant ของคุณได้รับการอนุมัติแล้ว ระบบสำหรับประเภทธุรกิจนี้จะเปิดใช้งานตามความพร้อม'
      end
    );

    perform internal.log_audit_event(
      v_admin,
      'admin_merchant_application_approved',
      v_application.user_id,
      jsonb_build_object(
        'application_id', v_application.id,
        'business_name', v_application.business_name,
        'business_type', v_application.business_type,
        'food_store_id', v_store_id
      )
    );
  else
    update public.merchant_applications
    set status = 'rejected',
        rejection_reason = v_reason,
        reviewed_at = now(),
        reviewed_by = v_admin,
        updated_at = now()
    where id = v_application.id;

    insert into public.notifications (recipient_id, actor_id, type, reason)
    values (
      v_application.user_id,
      null,
      'system',
      'คำขอ WYNOS Merchant ของคุณยังไม่ผ่านการอนุมัติ: ' || v_reason
    );

    perform internal.log_audit_event(
      v_admin,
      'admin_merchant_application_rejected',
      v_application.user_id,
      jsonb_build_object(
        'application_id', v_application.id,
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
    exists (
      select 1 from public.food_staff fs
      where fs.user_id = ma.user_id and fs.active
    )
  from public.merchant_applications ma
  where ma.id = v_application.id;
end;
$$;

revoke all on function public.admin_review_merchant_application(uuid, text, text) from public;
revoke all on function public.admin_review_merchant_application(uuid, text, text) from anon;
grant execute on function public.admin_review_merchant_application(uuid, text, text) to authenticated;
