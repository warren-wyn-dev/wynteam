-- WYNOS Food home directory v2.
-- Extends the customer store-directory RPC for the Founder-approved Food Home:
-- search by store/menu, nearby sorting, review/category metadata, popularity and
-- active promotion badges. Existing checkout pricing stays server-authoritative.

drop function if exists public.food_store_directory(text);

create function public.food_store_directory(p_query text default null)
returns table (
  id uuid,
  slug text,
  name text,
  logo_path text,
  cover_path text,
  address text,
  business_hours text,
  delivery_fee numeric,
  latitude double precision,
  longitude double precision,
  prep_time_min_minutes integer,
  prep_time_max_minutes integer,
  categories text[],
  rating_average numeric,
  rating_count bigint,
  delivered_order_count bigint,
  promo_name text,
  promo_type text,
  promo_value numeric,
  promo_min_subtotal numeric,
  is_open boolean,
  is_ad boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $directory$
declare
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
  v_pattern text;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food access required';
  end if;

  if v_query is not null then
    v_pattern := '%' || replace(replace(replace(v_query, E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_') || '%';
  end if;

  return query
  select
    s.id,
    s.slug,
    s.name,
    s.logo_path,
    s.cover_path,
    s.address,
    s.business_hours,
    s.delivery_fee::numeric,
    s.latitude,
    s.longitude,
    s.prep_time_min_minutes,
    s.prep_time_max_minutes,
    coalesce(menu_meta.categories, '{}'::text[]) as categories,
    coalesce(review_meta.rating_average, 0::numeric) as rating_average,
    coalesce(review_meta.rating_count, 0::bigint) as rating_count,
    coalesce(order_meta.delivered_order_count, 0::bigint) as delivered_order_count,
    promo.name as promo_name,
    promo.campaign_type as promo_type,
    promo.discount_value::numeric as promo_value,
    promo.min_subtotal::numeric as promo_min_subtotal,
    internal.food_store_effectively_open(s.id, now()) as is_open,
    internal.food_ad_is_live(s.id) as is_ad
  from public.food_stores s
  left join lateral (
    select array_agg(distinct m.category order by m.category) as categories
    from public.food_menu_items m
    where m.store_id = s.id
      and m.is_available
  ) menu_meta on true
  left join lateral (
    select
      round(avg(r.rating)::numeric, 1) as rating_average,
      count(*)::bigint as rating_count
    from public.food_store_reviews r
    where r.store_id = s.id
  ) review_meta on true
  left join lateral (
    select count(*)::bigint as delivered_order_count
    from public.food_orders o
    where o.store_id = s.id
      and o.status = 'delivered'
  ) order_meta on true
  left join lateral (
    select c.name, c.campaign_type, c.discount_value, c.min_subtotal
    from public.food_campaigns c
    where c.store_id = s.id
      and c.deleted_at is null
      and c.is_active
      and c.starts_at <= now()
      and (c.ends_at is null or c.ends_at > now())
      and (c.usage_limit is null or c.usage_count < c.usage_limit)
    order by
      case c.campaign_type
        when 'free_delivery' then 3
        when 'percentage' then 2
        when 'fixed' then 1
        else 0
      end desc,
      c.discount_value desc,
      c.created_at desc
    limit 1
  ) promo on true
  where s.is_published
    and s.admin_suspended_at is null
    and (
      v_query is null
      or s.name ilike v_pattern escape E'\\'
      or coalesce(s.address, '') ilike v_pattern escape E'\\'
      or exists (
        select 1
        from public.food_menu_items search_menu
        where search_menu.store_id = s.id
          and search_menu.is_available
          and (
            search_menu.name ilike v_pattern escape E'\\'
            or search_menu.category ilike v_pattern escape E'\\'
          )
      )
    )
  order by
    internal.food_ad_is_live(s.id) desc,
    internal.food_store_effectively_open(s.id, now()) desc,
    coalesce(order_meta.delivered_order_count, 0) desc,
    coalesce(review_meta.rating_average, 0) desc,
    s.name
  limit 100;
end;
$directory$;

revoke all on function public.food_store_directory(text) from public, anon;
grant execute on function public.food_store_directory(text) to authenticated;
