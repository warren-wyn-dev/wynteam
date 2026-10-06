-- Merchant QA fix: complete sales report aggregation in Bangkok time.
--
-- Read-only. Keeps the same Merchant access boundary as the existing order
-- report: any active member/staff member who can access the store may read it.

create or replace function public.merchant_sales_report(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_week_start date := date_trunc('week', now() at time zone 'Asia/Bangkok')::date;
  v_month_start date := date_trunc('month', now() at time zone 'Asia/Bangkok')::date;
  v_result jsonb;
begin
  if not public.food_has_merchant_access(p_store_id) then
    raise exception 'merchant access required';
  end if;

  with delivered as (
    select
      o.id,
      coalesce(o.total, 0)::numeric as total,
      (coalesce(o.delivered_at, o.updated_at) at time zone 'Asia/Bangkok')::date as delivered_day
    from public.food_orders o
    where o.store_id = p_store_id
      and o.status = 'delivered'
  ),
  item_totals as (
    select i.item_name as name, sum(i.quantity)::bigint as quantity
    from delivered d
    join public.food_order_items i on i.order_id = d.id
    group by i.item_name
    order by quantity desc, i.item_name asc
    limit 5
  )
  select jsonb_build_object(
    'today_sales', coalesce((select sum(total) from delivered where delivered_day = v_today), 0),
    'today_orders', (select count(*) from delivered where delivered_day = v_today),
    'week_sales', coalesce((select sum(total) from delivered where delivered_day between v_week_start and v_today), 0),
    'week_orders', (select count(*) from delivered where delivered_day between v_week_start and v_today),
    'month_sales', coalesce((select sum(total) from delivered where delivered_day between v_month_start and v_today), 0),
    'month_orders', (select count(*) from delivered where delivered_day between v_month_start and v_today),
    'total_orders', (select count(*) from delivered),
    'average_order', coalesce((select avg(total) from delivered), 0),
    'best', coalesce(
      (select jsonb_agg(jsonb_build_object('name', name, 'quantity', quantity) order by quantity desc, name asc)
       from item_totals),
      '[]'::jsonb
    )
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.merchant_sales_report(uuid) from public, anon;
grant execute on function public.merchant_sales_report(uuid) to authenticated;
