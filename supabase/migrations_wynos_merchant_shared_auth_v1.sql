-- WYNOS Merchant shared WYNOS authentication.
-- One WYNOS user identity can own/join Merchant Accounts; stores remain separate tenants.

alter table public.merchant_users
  drop constraint if exists merchant_users_identity_mode_check;

alter table public.merchant_users
  add constraint merchant_users_identity_mode_check
  check (identity_mode in ('merchant', 'legacy_social', 'shared_wynos'));

update public.merchant_users
set identity_mode = 'shared_wynos',
    updated_at = now()
where identity_mode <> 'shared_wynos';

drop trigger if exists wynos_merchant_auth_user_created on auth.users;
drop function if exists internal.bootstrap_merchant_auth_user();

drop policy if exists "Merchant applicants can view own application" on public.merchant_applications;
create policy "Merchant applicants can view own application"
on public.merchant_applications
for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Merchant applicants can create own application" on public.merchant_applications;
create policy "Merchant applicants can create own application"
on public.merchant_applications
for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and status = 'pending'
);

drop policy if exists "Merchant applicants can edit pending or rejected application" on public.merchant_applications;
create policy "Merchant applicants can edit pending or rejected application"
on public.merchant_applications
for update to authenticated
using (
  (select auth.uid()) = user_id
  and status in ('pending', 'rejected')
)
with check (
  (select auth.uid()) = user_id
  and status = 'pending'
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
  v_application_id uuid;
  v_business_name text := left(trim(coalesce(p_business_name, '')), 120);
  v_contact_name text := left(trim(coalesce(p_contact_name, '')), 120);
  v_phone text := left(trim(coalesce(p_phone, '')), 50);
  v_address text := left(trim(coalesce(p_address, '')), 800);
  v_note text := nullif(left(trim(coalesce(p_note, '')), 1200), '');
begin
  if v_user is null then
    raise exception 'WYNOS authentication required';
  end if;
  if v_business_name = '' then raise exception 'business name required'; end if;
  if p_business_type not in ('food', 'retail', 'service', 'other') then
    raise exception 'invalid business type';
  end if;
  if v_contact_name = '' or v_phone = '' or v_address = '' then
    raise exception 'merchant contact information required';
  end if;

  insert into public.merchant_users(user_id, identity_mode, active)
  values (v_user, 'shared_wynos', true)
  on conflict (user_id) do update
    set identity_mode = 'shared_wynos',
        active = true,
        updated_at = now();

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
  returning id into v_application_id;

  return v_application_id;
end;
$$;

revoke all on function public.merchant_submit_application(text,text,text,text,text,text) from public, anon;
grant execute on function public.merchant_submit_application(text,text,text,text,text,text) to authenticated;
