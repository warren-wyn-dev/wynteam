-- WYN-193: WYNOS Food requires a delivery photo for every completed delivery.
--
-- Couriers are hired outside WYNOS and send their photo to the store; the store
-- attaches it here before marking the order delivered. Both 'direct' and
-- 'dropoff' now need a photo that was actually uploaded under this order's
-- delivery folder. 'dropoff' still needs a location note. The buyer is notified
-- in-app (and by the existing notifications -> push path) when it is delivered,
-- unless they turned off 'system' notifications.
--
-- Additive and non-destructive: only replaces public.food_complete_delivery.
-- Existing delivered orders and food_delivery_proofs rows are not changed.
-- Rollback: re-run the food_complete_delivery definition from
-- supabase/migrations_wynos_merchant_core_completion_v1.sql.

create or replace function public.food_complete_delivery(
  p_order_id uuid,
  p_method text,
  p_location_note text default null,
  p_image_path text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
  v_note text := nullif(left(btrim(coalesce(p_location_note,''), E' \t\r\n'),500),'');
begin
  select * into v_order from public.food_orders where id=p_order_id for update;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders','delivery']) then
    raise exception 'delivery role required';
  end if;
  if v_order.status <> 'out_for_delivery' then
    raise exception 'order is not out for delivery';
  end if;
  if p_method is null or p_method not in ('direct','dropoff') then
    raise exception 'invalid delivery method';
  end if;
  if p_image_path is null
    or p_image_path not like 'delivery/' || p_order_id::text || '/%'
    or position('..' in p_image_path) > 0
    or not exists (
      select 1 from storage.objects o
      where o.bucket_id='food-private' and o.name=p_image_path
    )
  then
    raise exception 'delivery photo is required';
  end if;
  if p_method='dropoff' and v_note is null then
    raise exception 'dropoff location is required';
  end if;

  insert into public.food_delivery_proofs(order_id,method,location_note,image_path,delivered_by)
  values (
    p_order_id,p_method,
    case when p_method='dropoff' then v_note else null end,
    p_image_path,
    auth.uid()
  )
  on conflict (order_id) do update
  set method=excluded.method,
      location_note=excluded.location_note,
      image_path=excluded.image_path,
      delivered_by=excluded.delivered_by,
      created_at=now();

  update public.food_orders
  set status='delivered', delivered_at=now()
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,from_status,to_status,note,actor_id)
  values (
    p_order_id,'delivered','out_for_delivery','delivered',
    case when p_method='dropoff' then v_note else 'ส่งให้ผู้รับโดยตรง' end,
    auth.uid()
  );

  if v_order.buyer_id is not null and internal.notification_enabled(v_order.buyer_id, 'system') then
    insert into public.notifications(recipient_id,actor_id,type,reason)
    values (
      v_order.buyer_id,null,'system',
      'ออเดอร์ #' || v_order.order_number || ' ส่งถึงแล้ว · ดูรูปยืนยันการจัดส่งได้ในหน้าออเดอร์'
    );
  end if;
end;
$$;

revoke all on function public.food_complete_delivery(uuid,text,text,text) from public, anon;
grant execute on function public.food_complete_delivery(uuid,text,text,text) to authenticated;
