-- WYNOS Merchant legacy Food Store compatibility backfill v1.
-- Normalizes stores created before Merchant Accounts existed so Merchant Core
-- features (notifications, staff, activity and tests) use the same tenancy model.

do $$
declare
  r record;
  v_account_id uuid;
begin
  for r in
    select s.*
    from public.food_stores s
    where s.merchant_account_id is null
      and exists (
        select 1
        from public.food_staff fs
        where fs.store_id = s.id
          and fs.role = 'owner'
          and fs.active
      )
    order by s.created_at
  loop
    insert into public.merchant_accounts(
      business_name,
      business_type,
      status,
      created_at,
      updated_at
    )
    values (
      left(coalesce(nullif(trim(r.name), ''), 'WYNOS Food'), 120),
      'food',
      'approved',
      coalesce(r.created_at, now()),
      now()
    )
    returning id into v_account_id;

    update public.food_stores
    set merchant_account_id = v_account_id,
        updated_at = now()
    where id = r.id
      and merchant_account_id is null;

    if not found then
      raise exception 'legacy_food_store_backfill_conflict';
    end if;

    insert into public.merchant_users(
      user_id,
      identity_mode,
      active,
      created_at,
      updated_at
    )
    select
      fs.user_id,
      'legacy_social',
      bool_or(fs.active),
      min(fs.created_at),
      now()
    from public.food_staff fs
    where fs.store_id = r.id
    group by fs.user_id
    on conflict (user_id) do update
      set active = public.merchant_users.active or excluded.active,
          updated_at = now();

    insert into public.merchant_memberships(
      merchant_account_id,
      user_id,
      role,
      active,
      invited_by,
      created_at,
      updated_at
    )
    select
      v_account_id,
      fs.user_id,
      case fs.role
        when 'owner' then 'owner'
        when 'delivery' then 'delivery'
        else 'manager'
      end,
      fs.active,
      null,
      fs.created_at,
      now()
    from public.food_staff fs
    where fs.store_id = r.id
    on conflict (merchant_account_id, user_id) do update
      set role = excluded.role,
          active = excluded.active,
          updated_at = now();
  end loop;
end
$$;
