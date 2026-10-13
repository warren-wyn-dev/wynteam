-- WYNOS Admin: Merchant-delivered fee & radius editing, governed by merchant:edit.
-- Additive API only. Does not change any store settings until a staff member saves.
-- Uses the SAME live food_stores fields and checkout fee calculation as Merchant.
-- Existing merchant_store_updated audit event is reused to avoid altering audit constraints.
-- Rollback: DROP FUNCTION public.admin_update_merchant_delivery(uuid,jsonb,numeric,numeric,numeric,numeric,text);
--           DROP FUNCTION public.admin_merchant_delivery_stores();

create or replace function public.admin_merchant_delivery_stores()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_data jsonb;
begin
  if not internal.has_admin_permission('merchant', 'view') then
    raise exception 'Not authorized';
  end if;
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', s.id,
      'name', s.name,
      'published', s.is_published,
      'geocoded', s.latitude is not null and s.longitude is not null,
      'delivery_fee', s.delivery_fee,
      'delivery_radius_km', s.delivery_radius_km,
      'delivery_base_km', s.delivery_base_km,
      'delivery_fee_per_km', s.delivery_fee_per_km
    ) order by s.name, s.id
  ), '[]'::jsonb) into v_data
  from public.food_stores s;
  return v_data;
end;
$$;
revoke all on function public.admin_merchant_delivery_stores() from public, anon;
grant execute on function public.admin_merchant_delivery_stores() to authenticated;

create or replace function public.admin_update_merchant_delivery(
  p_store_id uuid,
  p_expected jsonb,
  p_delivery_fee numeric,
  p_delivery_radius_km numeric,
  p_delivery_base_km numeric,
  p_delivery_fee_per_km numeric,
  p_reason text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_actor uuid := auth.uid();
  v_reason text := btrim(coalesce(p_reason, ''));
  v_old jsonb;
  v_new jsonb;
begin
  if not internal.has_admin_permission('merchant', 'edit') then
    raise exception 'Not authorized';
  end if;
  if p_store_id is null then
    raise exception 'Store is required';
  end if;
  if p_expected is null or jsonb_typeof(p_expected) <> 'object'
     or not (p_expected ?& array['delivery_fee','delivery_radius_km','delivery_base_km','delivery_fee_per_km']) then
    raise exception 'Missing original values; refresh the page';
  end if;
  if p_delivery_fee is null or p_delivery_radius_km is null
     or p_delivery_base_km is null or p_delivery_fee_per_km is null
     or p_delivery_fee::text = 'NaN' or p_delivery_radius_km::text = 'NaN'
     or p_delivery_base_km::text = 'NaN' or p_delivery_fee_per_km::text = 'NaN'
     or p_delivery_fee < 0 or p_delivery_fee > 10000
     or p_delivery_radius_km <= 0 or p_delivery_radius_km > 50
     or p_delivery_base_km < 0 or p_delivery_base_km > 50
     or p_delivery_fee_per_km < 0 or p_delivery_fee_per_km > 1000 then
    raise exception 'Delivery configuration is out of range';
  end if;
  if char_length(v_reason) < 5 or char_length(v_reason) > 300 then
    raise exception 'A reason of 5-300 characters is required';
  end if;
  select * into v_store from public.food_stores where id = p_store_id for update;
  if not found then
    raise exception 'Store not found';
  end if;
  v_old := jsonb_build_object(
    'delivery_fee', v_store.delivery_fee,
    'delivery_radius_km', v_store.delivery_radius_km,
    'delivery_base_km', v_store.delivery_base_km,
    'delivery_fee_per_km', v_store.delivery_fee_per_km
  );
  if (p_expected ->> 'delivery_fee')::numeric is distinct from v_store.delivery_fee
     or (p_expected ->> 'delivery_radius_km')::numeric is distinct from v_store.delivery_radius_km
     or (p_expected ->> 'delivery_base_km')::numeric is distinct from v_store.delivery_base_km
     or (p_expected ->> 'delivery_fee_per_km')::numeric is distinct from v_store.delivery_fee_per_km then
    raise exception 'Delivery settings changed; refresh before saving';
  end if;
  v_new := jsonb_build_object(
    'delivery_fee', p_delivery_fee,
    'delivery_radius_km', p_delivery_radius_km,
    'delivery_base_km', p_delivery_base_km,
    'delivery_fee_per_km', p_delivery_fee_per_km
  );
  if v_new = v_old then
    raise exception 'No changes to save';
  end if;
  update public.food_stores
  set delivery_fee = p_delivery_fee,
      delivery_radius_km = p_delivery_radius_km,
      delivery_base_km = p_delivery_base_km,
      delivery_fee_per_km = p_delivery_fee_per_km
  where id = p_store_id;

  perform internal.log_audit_event(
    v_actor, 'merchant_store_updated', null,
    jsonb_build_object(
      'admin_delivery_override', true,
      'store_id', v_store.id,
      'store_name', v_store.name,
      'before', v_old,
      'after', v_new,
      'reason', v_reason
    )
  );
  return v_new;
end;
$$;
revoke all on function public.admin_update_merchant_delivery(uuid,jsonb,numeric,numeric,numeric,numeric,text)
  from public, anon;
grant execute on function public.admin_update_merchant_delivery(uuid,jsonb,numeric,numeric,numeric,numeric,text)
  to authenticated;
