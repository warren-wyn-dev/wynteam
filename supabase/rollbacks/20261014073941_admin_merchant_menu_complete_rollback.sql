-- Revert the complete admin menu RPCs. Preserve archived_at, its safety
-- constraint, restore-unavailable guard, archived rows, media objects, audit,
-- and all order snapshots. Keep the guards for direct Merchant table updates,
-- including the image validator used by the retained trusted-image guard.
-- Retain the three restrictive Storage write policies for the reserved
-- food-public/admin-menu namespace, regardless of older permissive policies.
-- Restored legacy edit RPC still refuses archived items. Run only with an
-- explicitly approved rollback; this file is tested on synthetic fixtures only.
begin;
drop function if exists public.admin_authorize_merchant_menu_upload(uuid);
drop table if exists internal.admin_menu_upload_budgets;
drop function if exists public.admin_save_merchant_menu_categories(uuid,timestamptz,jsonb,jsonb,jsonb,text);
drop function if exists public.admin_set_merchant_menu_item_archived(uuid,timestamptz,boolean,text);
drop function if exists public.admin_save_merchant_menu_item(uuid,uuid,timestamptz,jsonb,text);
-- Replace the compatibility reader before removing its catalog dependency.
create or replace function public.admin_merchant_menu_items(p_store_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_items jsonb;
begin
  if auth.uid() is null or not internal.has_admin_permission('merchant', 'view') then
    raise exception 'Not authorized';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id,
    'store_id', m.store_id,
    'store_name', s.name,
    'name', m.name,
    'category', m.category,
    'description', m.description,
    'price', m.price,
    'is_available', m.is_available,
    'daily_stock_limit', m.daily_stock_limit,
    'sold_out_until', m.sold_out_until,
    'updated_at', m.updated_at
  ) order by s.name, m.category, m.sort_order, m.name), '[]'::jsonb) into v_items
  from public.food_menu_items m
  join public.food_stores s on s.id = m.store_id
  where (p_store_id is null or m.store_id = p_store_id);
  return v_items;
end;
$$;
revoke all on function public.admin_merchant_menu_items(uuid) from public, anon;
grant execute on function public.admin_merchant_menu_items(uuid) to authenticated;

create or replace function public.admin_update_merchant_menu_item(
  p_item_id uuid,
  p_expected jsonb,
  p_name text,
  p_category text,
  p_description text,
  p_price numeric,
  p_is_available boolean,
  p_daily_stock_limit integer,
  p_reason text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_item public.food_menu_items%rowtype;
  v_store_name text;
  v_before jsonb;
  v_after jsonb;
  v_name text := btrim(coalesce(p_name, ''));
  v_category text := btrim(coalesce(p_category, ''));
  v_description text := nullif(btrim(coalesce(p_description, '')), '');
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if auth.uid() is null or not internal.has_admin_permission('merchant', 'edit') then
    raise exception 'Not authorized';
  end if;
  if p_item_id is null or p_expected is null or jsonb_typeof(p_expected) <> 'object'
    or not (p_expected ?& array['name','category','description','price','is_available','daily_stock_limit']) then
    raise exception 'Missing menu item or original values';
  end if;
  if char_length(v_name) not between 1 and 160
    or char_length(v_category) not between 1 and 60
    or (v_description is not null and char_length(v_description) > 1000)
    or p_price is null or p_price::text = 'NaN' or p_price < 0 or p_price > 100000
    or p_is_available is null
    or (p_daily_stock_limit is not null and (p_daily_stock_limit < 1 or p_daily_stock_limit > 9999)) then
    raise exception 'Invalid menu settings';
  end if;
  if char_length(v_reason) not between 5 and 300 then
    raise exception 'A reason of 5-300 characters is required';
  end if;

  select * into v_item from public.food_menu_items where id = p_item_id for update;
  if not found then raise exception 'Menu item not found'; end if;
  if v_item.archived_at is not null then raise exception 'Restore archived menu before editing'; end if;
  select name into v_store_name from public.food_stores where id = v_item.store_id;

  v_before := jsonb_build_object(
    'name', v_item.name,
    'category', v_item.category,
    'description', v_item.description,
    'price', v_item.price,
    'is_available', v_item.is_available,
    'daily_stock_limit', v_item.daily_stock_limit
  );
  if p_expected is distinct from v_before then
    raise exception 'Menu item changed; refresh before saving';
  end if;
  v_after := jsonb_build_object(
    'name', v_name,
    'category', v_category,
    'description', v_description,
    'price', p_price,
    'is_available', p_is_available,
    'daily_stock_limit', p_daily_stock_limit
  );
  if v_after = v_before then raise exception 'No changes to save'; end if;

  update public.food_menu_items
  set name = v_name, category = v_category, description = v_description,
      price = p_price, is_available = p_is_available,
      daily_stock_limit = p_daily_stock_limit, updated_at = now()
  where id = v_item.id;
  perform internal.log_audit_event(
    auth.uid(), 'merchant_menu_updated', null,
    jsonb_build_object(
      'admin_menu_override', true, 'store_id', v_item.store_id,
      'store_name', v_store_name, 'item_id', v_item.id,
      'reason', v_reason, 'before', v_before, 'after', v_after
    )
  );
  return v_after;
end;
$$;
revoke all on function public.admin_update_merchant_menu_item(uuid,jsonb,text,text,text,numeric,boolean,integer,text) from public, anon;
grant execute on function public.admin_update_merchant_menu_item(uuid,jsonb,text,text,text,numeric,boolean,integer,text) to authenticated;

drop function if exists public.admin_merchant_menu_catalog(uuid);
drop function if exists internal.admin_menu_row(public.food_menu_items,text);
-- Keep internal.admin_menu_image_valid and food_menu_image_reference_guard:
-- existing trusted objects must remain store-bound after an application rollback.
drop function if exists internal.admin_menu_options(jsonb);
drop trigger if exists admin_menu_touch_store on public.food_menu_items;
drop function if exists internal.admin_menu_touch_store();
drop trigger if exists zz_admin_menu_monotonic_version on public.food_menu_items;
drop trigger if exists zz_admin_menu_catalog_version on public.food_stores;
drop function if exists internal.admin_menu_monotonic_version();
commit;
