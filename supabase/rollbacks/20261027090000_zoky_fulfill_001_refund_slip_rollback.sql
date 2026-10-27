-- Rollback of 20261027090000_zoky_fulfill_001_refund_slip.sql: drops the
-- refund-slip guard and restores food_store_mark_refunded as shipped in
-- 20261026120000_zoky_fulfill_001.sql. Run before the main rollback.
drop trigger if exists food_orders_refund_slip_guard on public.food_orders;
drop function if exists internal.food_orders_refund_slip_guard();

create or replace function public.food_store_mark_refunded(
  p_order_id uuid, p_refund_slip_path text, p_note text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.food_orders%rowtype;
begin
  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager']) then
    raise exception 'refund role required';
  end if;
  if v_order.refund_status <> 'pending' then raise exception 'no refund pending'; end if;
  if p_refund_slip_path is null
     or p_refund_slip_path not like 'refunds/' || p_order_id::text || '/%'
     or position('..' in p_refund_slip_path) > 0
     or not exists (select 1 from storage.objects o where o.bucket_id = 'food-private' and o.name = p_refund_slip_path) then
    raise exception 'refund slip is required';
  end if;
  perform public.merchant_set_refund_status(p_order_id, 'refunded', p_note);
  update public.food_orders
  set refund_slip_path = p_refund_slip_path, refunded_by_store_at = now()
  where id = p_order_id;
end;
$$;
revoke all on function public.food_store_mark_refunded(uuid, text, text) from public, anon;
grant execute on function public.food_store_mark_refunded(uuid, text, text) to authenticated;
