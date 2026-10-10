-- Public read-only storefront for signed-out Food visitors.
-- Deliberately expose ONLY published, unsuspended store/menu fields; never
-- grant anon SELECT on food_stores/food_menu_items or checkout/order RPCs.
-- Existing authenticated order/payment/RLS checks remain unchanged.
create or replace function public.food_public_catalog()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select case
    when not exists (
      select 1 from public.food_rollout_settings r
      where r.id = true and r.public_enabled = true
    ) then '[]'::jsonb
    else coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'slug', s.slug,
          'name', s.name,
          'description', s.description,
          'cover_path', s.cover_path,
          'logo_path', s.logo_path,
          'address', s.address,
          'delivery_fee', s.delivery_fee,
          'is_open', internal.food_store_effectively_open(s.id, now()),
          'menu', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'id', m.id,
                'store_id', m.store_id,
                'category', m.category,
                'name', m.name,
                'description', m.description,
                'price', m.price,
                'image_path', m.image_path,
                'options', coalesce(m.options, '[]'::jsonb),
                'sold_out_until', m.sold_out_until,
                'daily_stock_limit', m.daily_stock_limit
              ) order by m.sort_order, m.created_at
            )
            from (
              select * from public.food_menu_items mi
              where mi.store_id = s.id and mi.is_available = true
              order by mi.sort_order, mi.created_at
              limit 100
            ) m
          ), '[]'::jsonb)
        ) order by s.created_at
      )
      from (
        select * from public.food_stores fs
        where fs.is_published = true and fs.admin_suspended_at is null
        order by fs.created_at
        limit 60
      ) s
    ), '[]'::jsonb)
  end;
$fn$;

revoke all on function public.food_public_catalog() from public;
grant execute on function public.food_public_catalog() to anon, authenticated;

comment on function public.food_public_catalog() is
  'Read-only published Food storefront and menu preview for guests. Checkout and account data stay authenticated.';
