-- WYNOS Food customer live daily stock remaining.
-- The insert trigger remains the source of truth and still locks the menu row
-- during checkout. This read-only RPC only improves customer UX before submit.

create or replace function public.food_menu_stock_remaining(p_store_id uuid)
returns table (
  menu_item_id uuid,
  remaining_stock integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    m.id as menu_item_id,
    case
      when m.daily_stock_limit is null then null::integer
      else greatest(
        m.daily_stock_limit - coalesce(sum(
          case
            when o.id is not null
             and o.status <> 'cancelled'
             and (o.created_at at time zone 'Asia/Bangkok')::date = (now() at time zone 'Asia/Bangkok')::date
            then oi.quantity
            else 0
          end
        ), 0)::integer,
        0
      )
    end as remaining_stock
  from public.food_menu_items m
  join public.food_stores s on s.id = m.store_id
  left join public.food_order_items oi on oi.menu_item_id = m.id
  left join public.food_orders o on o.id = oi.order_id
  where m.store_id = p_store_id
    and public.food_customer_access_enabled()
    and (
      public.is_developer_account()
      or (s.is_published and public.food_public_access_enabled())
    )
  group by m.id, m.daily_stock_limit;
$$;

revoke all on function public.food_menu_stock_remaining(uuid) from public, anon;
grant execute on function public.food_menu_stock_remaining(uuid) to authenticated;
