-- WYNOS Merchant business accounts v2.
-- Merchant authentication uses its own browser session and business tenancy.
-- New Merchant auth users are marked at signup; approval remains an Admin action.

create table if not exists public.merchant_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  identity_mode text not null default 'merchant'
    check (identity_mode in ('merchant', 'legacy_social')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.merchant_accounts (
  id uuid primary key default gen_random_uuid(),
  business_name text not null check (char_length(business_name) between 1 and 120),
  business_type text not null default 'food'
    check (business_type in ('food', 'retail', 'service', 'other')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'suspended', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.merchant_memberships (
  merchant_account_id uuid not null references public.merchant_accounts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null
    check (role in ('owner', 'admin', 'manager', 'orders', 'support', 'delivery')),
  active boolean not null default true,
  invited_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (merchant_account_id, user_id)
);

create index if not exists merchant_memberships_user_idx
  on public.merchant_memberships(user_id)
  where active;

alter table public.merchant_applications
  add column if not exists merchant_account_id uuid
  references public.merchant_accounts(id) on delete set null;

create unique index if not exists merchant_applications_account_uq
  on public.merchant_applications(merchant_account_id)
  where merchant_account_id is not null;

alter table public.food_stores
  add column if not exists merchant_account_id uuid
  references public.merchant_accounts(id) on delete restrict;

create index if not exists food_stores_merchant_account_idx
  on public.food_stores(merchant_account_id)
  where merchant_account_id is not null;

create table if not exists public.merchant_notifications (
  id uuid primary key default gen_random_uuid(),
  merchant_account_id uuid not null references public.merchant_accounts(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  type text not null default 'system'
    check (type in ('system', 'order', 'payment', 'staff')),
  reason text not null check (char_length(reason) between 1 and 1000),
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists merchant_notifications_recipient_created_idx
  on public.merchant_notifications(recipient_user_id, created_at desc);

alter table public.merchant_users enable row level security;
alter table public.merchant_accounts enable row level security;
alter table public.merchant_memberships enable row level security;
alter table public.merchant_notifications enable row level security;

drop policy if exists "Merchant users can view own identity" on public.merchant_users;
create policy "Merchant users can view own identity"
on public.merchant_users for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Merchant members can view account" on public.merchant_accounts;
create policy "Merchant members can view account"
on public.merchant_accounts for select to authenticated
using (
  exists (
    select 1
    from public.merchant_memberships mm
    where mm.merchant_account_id = merchant_accounts.id
      and mm.user_id = (select auth.uid())
      and mm.active
  )
);

drop policy if exists "Merchant members can view own membership" on public.merchant_memberships;
create policy "Merchant members can view own membership"
on public.merchant_memberships for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Merchant users can view own notifications" on public.merchant_notifications;
create policy "Merchant users can view own notifications"
on public.merchant_notifications for select to authenticated
using (recipient_user_id = (select auth.uid()));

drop policy if exists "Merchant users can mark own notifications read" on public.merchant_notifications;
create policy "Merchant users can mark own notifications read"
on public.merchant_notifications for update to authenticated
using (recipient_user_id = (select auth.uid()))
with check (recipient_user_id = (select auth.uid()));

revoke all on public.merchant_users from anon, authenticated;
revoke all on public.merchant_accounts from anon, authenticated;
revoke all on public.merchant_memberships from anon, authenticated;
revoke all on public.merchant_notifications from anon, authenticated;
grant select on public.merchant_users to authenticated;
grant select on public.merchant_accounts to authenticated;
grant select on public.merchant_memberships to authenticated;
grant select, update(read_at) on public.merchant_notifications to authenticated;

create or replace function internal.bootstrap_merchant_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, internal
as $$
begin
  if lower(coalesce(new.raw_user_meta_data ->> 'wynos_account_type', '')) = 'merchant' then
    insert into public.merchant_users(user_id, identity_mode, active)
    values (new.id, 'merchant', true)
    on conflict (user_id) do update
      set active = true,
          updated_at = now();
  end if;
  return new;
end;
$$;

revoke all on function internal.bootstrap_merchant_auth_user() from public, anon, authenticated;

drop trigger if exists wynos_merchant_auth_user_created on auth.users;
create trigger wynos_merchant_auth_user_created
after insert on auth.users
for each row execute function internal.bootstrap_merchant_auth_user();

-- Existing Merchant applicants are kept in compatibility mode so their current
-- store is not orphaned. New signups use identity_mode='merchant'.
do $$
declare
  r record;
  v_account_id uuid;
begin
  for r in
    select ma.*
    from public.merchant_applications ma
    where ma.merchant_account_id is null
    order by ma.created_at
  loop
    insert into public.merchant_users(user_id, identity_mode, active)
    values (r.user_id, 'legacy_social', true)
    on conflict (user_id) do nothing;

    insert into public.merchant_accounts(
      business_name, business_type, status, created_at, updated_at
    ) values (
      r.business_name,
      r.business_type,
      case when r.status = 'approved' then 'approved' else 'pending' end,
      r.created_at,
      r.updated_at
    )
    returning id into v_account_id;

    insert into public.merchant_memberships(
      merchant_account_id, user_id, role, active
    ) values (
      v_account_id, r.user_id, 'owner', true
    )
    on conflict (merchant_account_id, user_id)
    do update set role='owner', active=true, updated_at=now();

    update public.merchant_applications
    set merchant_account_id = v_account_id
    where id = r.id;

    if r.food_store_id is not null then
      update public.food_stores
      set merchant_account_id = coalesce(merchant_account_id, v_account_id)
      where id = r.food_store_id;
    end if;
  end loop;
end;
$$;

drop policy if exists "Merchant applicants can view own application" on public.merchant_applications;
create policy "Merchant applicants can view own application"
on public.merchant_applications
for select to authenticated
using (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.merchant_users mu
    where mu.user_id = (select auth.uid()) and mu.active
  )
);

drop policy if exists "Merchant applicants can create own application" on public.merchant_applications;
create policy "Merchant applicants can create own application"
on public.merchant_applications
for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and status = 'pending'
  and exists (
    select 1 from public.merchant_users mu
    where mu.user_id = (select auth.uid()) and mu.active
  )
);

drop policy if exists "Merchant applicants can edit pending or rejected application" on public.merchant_applications;
create policy "Merchant applicants can edit pending or rejected application"
on public.merchant_applications
for update to authenticated
using (
  (select auth.uid()) = user_id
  and status in ('pending', 'rejected')
  and exists (
    select 1 from public.merchant_users mu
    where mu.user_id = (select auth.uid()) and mu.active
  )
)
with check (
  (select auth.uid()) = user_id
  and status = 'pending'
  and exists (
    select 1 from public.merchant_users mu
    where mu.user_id = (select auth.uid()) and mu.active
  )
);

create or replace function public.merchant_submit_application(
  p_business_name text,
  p_business_type text,
  p_contact_name text,
  p_phone text,
  p_address text,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_application public.merchant_applications%rowtype;
  v_account_id uuid;
  v_business_name text := left(trim(coalesce(p_business_name, '')), 120);
  v_contact_name text := left(trim(coalesce(p_contact_name, '')), 120);
  v_phone text := left(trim(coalesce(p_phone, '')), 50);
  v_address text := left(trim(coalesce(p_address, '')), 800);
  v_note text := nullif(left(trim(coalesce(p_note, '')), 1200), '');
begin
  if v_user is null then raise exception 'merchant authentication required'; end if;
  if not exists (
    select 1 from public.merchant_users mu
    where mu.user_id = v_user and mu.active
  ) then
    raise exception 'merchant account required';
  end if;
  if v_business_name = '' then raise exception 'business name required'; end if;
  if p_business_type not in ('food', 'retail', 'service', 'other') then raise exception 'invalid business type'; end if;
  if v_contact_name = '' or v_phone = '' or v_address = '' then
    raise exception 'merchant contact information required';
  end if;

  select * into v_application
  from public.merchant_applications
  where user_id = v_user
  for update;

  if found then
    if v_application.status = 'approved' then
      raise exception 'approved merchant applications are final';
    end if;

    v_account_id := v_application.merchant_account_id;
    if v_account_id is null then
      insert into public.merchant_accounts(business_name, business_type, status)
      values (v_business_name, p_business_type, 'pending')
      returning id into v_account_id;

      update public.merchant_applications
      set merchant_account_id = v_account_id
      where id = v_application.id;
    end if;

    insert into public.merchant_memberships(merchant_account_id, user_id, role, active)
    values (v_account_id, v_user, 'owner', true)
    on conflict (merchant_account_id, user_id)
    do update set role='owner', active=true, updated_at=now();

    update public.merchant_accounts
    set business_name=v_business_name,
        business_type=p_business_type,
        status='pending',
        updated_at=now()
    where id=v_account_id;

    update public.merchant_applications
    set business_name=v_business_name,
        business_type=p_business_type,
        contact_name=v_contact_name,
        phone=v_phone,
        address=v_address,
        note=v_note,
        status='pending',
        rejection_reason=null,
        reviewed_at=null,
        reviewed_by=null,
        updated_at=now()
    where id=v_application.id;

    return v_application.id;
  end if;

  insert into public.merchant_accounts(business_name, business_type, status)
  values (v_business_name, p_business_type, 'pending')
  returning id into v_account_id;

  insert into public.merchant_memberships(merchant_account_id, user_id, role, active)
  values (v_account_id, v_user, 'owner', true);

  insert into public.merchant_applications(
    user_id, merchant_account_id, business_name, business_type,
    contact_name, phone, address, note
  ) values (
    v_user, v_account_id, v_business_name, p_business_type,
    v_contact_name, v_phone, v_address, v_note
  )
  returning id into v_account_id;

  return v_account_id;
end;
$$;

revoke all on function public.merchant_submit_application(text,text,text,text,text,text) from public, anon;
grant execute on function public.merchant_submit_application(text,text,text,text,text,text) to authenticated;

create or replace function public.food_has_merchant_access(p_store_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and (
      exists (
        select 1
        from public.developer_accounts d
        where d.user_id = auth.uid()
      )
      or exists (
        select 1
        from public.food_stores s
        join public.merchant_memberships mm
          on mm.merchant_account_id = s.merchant_account_id
        where mm.user_id = auth.uid()
          and mm.active
          and (p_store_id is null or s.id = p_store_id)
      )
      or exists (
        select 1
        from public.food_staff fs
        where fs.user_id = auth.uid()
          and fs.active
          and (p_store_id is null or fs.store_id = p_store_id)
      )
    );
$$;

revoke all on function public.food_has_merchant_access(uuid) from public, anon;
grant execute on function public.food_has_merchant_access(uuid) to authenticated;

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
      from public.merchant_memberships mm
      where mm.merchant_account_id = ma.merchant_account_id
        and mm.active
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

revoke all on function public.admin_merchant_applications(text, integer) from public, anon;
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
    exists (
      select 1 from public.merchant_memberships mm
      where mm.merchant_account_id=ma.merchant_account_id and mm.active
    )
  from public.merchant_applications ma
  where ma.id=v_application.id;
end;
$$;

revoke all on function public.admin_review_merchant_application(uuid,text,text) from public, anon;
grant execute on function public.admin_review_merchant_application(uuid,text,text) to authenticated;

create or replace function internal.food_order_notify()
returns trigger
language plpgsql
security definer
set search_path = public, internal
as $$
declare
  v_reason text;
  v_account_id uuid;
begin
  select s.merchant_account_id into v_account_id
  from public.food_stores s
  where s.id = new.store_id;

  if tg_op = 'INSERT' and new.source in ('app','social') then
    v_reason := 'WYNOS Merchant · ออเดอร์ใหม่ #' || new.order_number || ' · ฿' || trim(to_char(new.total, 'FM999999990.00'));

    if v_account_id is not null then
      insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
      select v_account_id, mm.user_id, 'order', v_reason
      from public.merchant_memberships mm
      where mm.merchant_account_id=v_account_id and mm.active;
    end if;

    insert into public.notifications(recipient_id, actor_id, type, reason)
    select fs.user_id, null, 'system', v_reason
    from public.food_staff fs
    where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
  elsif tg_op = 'UPDATE' and new.payment_status is distinct from old.payment_status then
    if new.payment_status = 'submitted' then
      v_reason := 'WYNOS Merchant · ลูกค้าส่งสลิป #' || new.order_number;
      if v_account_id is not null then
        insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
        select v_account_id, mm.user_id, 'payment', v_reason
        from public.merchant_memberships mm
        where mm.merchant_account_id=v_account_id and mm.active;
      end if;
      insert into public.notifications(recipient_id, actor_id, type, reason)
      select fs.user_id, null, 'system', v_reason
      from public.food_staff fs
      where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
    elsif new.payment_status = 'paid' then
      if new.buyer_id is not null then
        insert into public.notifications(recipient_id, actor_id, type, reason)
        values (new.buyer_id, null, 'system', 'ชำระเงินออเดอร์ #' || new.order_number || ' สำเร็จแล้ว');
      end if;
      v_reason := 'WYNOS Merchant · ชำระเงินแล้ว #' || new.order_number;
      if v_account_id is not null then
        insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
        select v_account_id, mm.user_id, 'payment', v_reason
        from public.merchant_memberships mm
        where mm.merchant_account_id=v_account_id and mm.active;
      end if;
      insert into public.notifications(recipient_id, actor_id, type, reason)
      select fs.user_id, null, 'system', v_reason
      from public.food_staff fs
      where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
    elsif new.payment_status = 'issue' and new.buyer_id is not null then
      insert into public.notifications(recipient_id, actor_id, type, reason)
      values (
        new.buyer_id, null, 'system',
        coalesce(new.payment_verification_note, new.payment_note, 'สลิปออเดอร์ #' || new.order_number || ' ต้องตรวจสอบอีกครั้ง')
      );
    end if;
  end if;

  return new;
end;
$$;

revoke all on function internal.food_order_notify() from public, anon, authenticated;
