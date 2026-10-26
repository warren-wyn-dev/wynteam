-- ZOKY-FULFILL-001. Built from read-only production definitions run 40318273032.
-- No production rows or credentials are included. Apply atomically after reviewed staging.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
-- Fail closed when a production function changed after the inspected baseline.
do $baseline$
declare r record;
begin
  for r in select * from (values
    ('internal.food_set_scheduled_order(uuid,timestamp with time zone)','fb7dd97ba95ac6b2881f9326e03c7d1c'),
    ('public.food_create_order(uuid,text,text,text,text,jsonb,double precision,double precision)','cfe2a645c82ffc1d17867032f00e7ea1'),
    ('public.food_quote_order(uuid,jsonb,double precision,double precision)','ebebd00a989bb51c69362f1a34feb870'),
    ('public.food_transition_order(uuid,text,integer,text)','0f76c766864a640bebcc543be04d755a'),
    ('public.food_complete_delivery(uuid,text,text,text)','b0c073dbca20e074ea1f243dec04ecac'),
    ('public.food_cancel_order(uuid,text)','046537ab68639a91e0d8d273b44c2997'),
    ('public.food_submit_payment(uuid,text)','79bcdaf6bdefb7e027d6b43806c3eb9e'),
    ('public.food_set_payment_status(uuid,text,text)','29a06116674586bad1f3ef86f95f9257'),
    ('public.food_timeout_cancel(uuid,text)','b2b16f5a9a6a0335a9f1c6441222806d'),
    ('public.merchant_set_refund_status(uuid,text,text)','63779727be610d1e2d52d9ad0911e3b5'),
    ('public.merchant_sales_report(uuid)','1d013ec8bc28ff70cca388eea65b90df'),
    ('internal.food_orders_gp_snapshot()','0dba3344077f213dca93bfa94a05df4e'),
    ('internal.food_order_status_notify()','7c22fc77abc300ecfd3040f1fc6f5f28'),
    ('public.food_public_catalog()','3fd4dd02c4f404f59093de91be277913'),
    ('public.food_submit_store_review(uuid,integer,text,text[],boolean)','3a82c3ff72520a56c7dbde0d539102bd')
  ) as baseline(signature,definition_md5) loop
    if to_regprocedure(r.signature) is null or md5(pg_get_functiondef(to_regprocedure(r.signature)))<>r.definition_md5 then
      raise exception 'fulfillment baseline drift: %',r.signature;
    end if;
  end loop;
end;
$baseline$;

alter table public.food_stores
  add column pickup_enabled boolean not null default false,
  add column delivery_enabled boolean not null default true,
  add column cod_enabled boolean not null default false,
  add column prep_minutes integer not null default 15,
  add constraint food_stores_fulfillment_modes check(pickup_enabled or delivery_enabled),
  add constraint food_stores_fulfillment_cod check(not cod_enabled or delivery_enabled),
  add constraint food_stores_fulfillment_prep check(prep_minutes between 5 and 120);
alter table public.food_orders
  add column fulfillment_type text not null default 'delivery',
  add column payment_method text not null default 'transfer',
  add column pickup_at timestamptz,
  add column pickup_code text,
  add column picked_up_at timestamptz,
  add column cancel_requested_at timestamptz,
  add column cancel_request_note text,
  add column refund_slip_path text,
  add column refunded_by_store_at timestamptz,
  add constraint food_orders_fulfillment_type check(fulfillment_type in ('delivery','pickup')),
  add constraint food_orders_fulfillment_payment check(payment_method in ('transfer','cod') and (payment_method<>'cod' or fulfillment_type='delivery')),
  add constraint food_orders_fulfillment_pickup check((fulfillment_type='delivery' and pickup_at is null and pickup_code is null) or (fulfillment_type='pickup' and pickup_at is not null and pickup_code is not null and payment_method='transfer' and delivery_fee=0 and delivery_discount=0 and delivery_latitude is null and delivery_longitude is null)),
  add constraint food_orders_fulfillment_note check(cancel_request_note is null or char_length(cancel_request_note)<=1000);
alter table public.food_orders drop constraint food_orders_status_check;
alter table public.food_orders add constraint food_orders_status_check check(status in ('pending_acceptance','preparing','ready_for_delivery','out_for_delivery','delivered','cancelled','ready_for_pickup','picked_up'));
create sequence public.food_pickup_code_sequence;
revoke all on sequence public.food_pickup_code_sequence from public,anon,authenticated;
create unique index food_orders_pickup_code_unique on public.food_orders(store_id,((pickup_at at time zone 'Asia/Bangkok')::date),pickup_code) where fulfillment_type='pickup';
create index food_orders_refund_owed on public.food_orders(refund_requested_at,store_id) where refund_status='pending' and payment_method='transfer';
create index food_orders_cancel_requested on public.food_orders(store_id,cancel_requested_at) where cancel_requested_at is not null;

-- New money/state fields can only be written by trusted server RPCs/workers.
create function internal.food_fulfillment_order_guard() returns trigger language plpgsql set search_path='' as $$
begin
  if current_user <> 'service_role' and not pg_has_role(current_user,(select relowner from pg_catalog.pg_class where oid='public.food_orders'::regclass),'USAGE') then
    if tg_op='INSERT' then raise exception 'order creation requires RPC'; end if;
    raise exception 'order state requires RPC';
  end if;
  return new;
end;
$$;
create trigger food_fulfillment_order_guard before insert or update on public.food_orders for each row execute function internal.food_fulfillment_order_guard();

-- A server-only clock boundary also permits deterministic local slot tests.
create function internal.food_fulfillment_now() returns timestamptz language sql stable set search_path='' as $$ select now() $$;
revoke all on function internal.food_fulfillment_now() from public,anon,authenticated;

-- Same-day pickup windows use the server clock and the store's Bangkok schedule.
create function internal.food_pickup_slots(p_store_id uuid,p_at timestamptz default internal.food_fulfillment_now()) returns setof timestamptz
language plpgsql stable security definer set search_path='' as $$
declare
  s public.food_stores%rowtype; local_now timestamp := p_at at time zone 'Asia/Bangkok';
  today date := local_now::date; slot jsonb; prior jsonb; opens time; closes time;
  close_at timestamptz; first_at timestamptz; last_at timestamptz; d integer := extract(isodow from local_now)::integer;
begin
  select * into s from public.food_stores where id=p_store_id;
  if not found or not s.pickup_enabled or not s.is_published or not internal.food_store_effectively_open(s.id,p_at) then return; end if;
  if jsonb_typeof(s.business_schedule->'weekly') is distinct from 'object' then return; end if;
  slot:=s.business_schedule->'weekly'->internal.food_schedule_day_key(d);
  prior:=s.business_schedule->'weekly'->internal.food_schedule_day_key(case when d=1 then 7 else d-1 end);
  begin
    if coalesce((slot->>'enabled')::boolean,false) then
      opens:=(slot->>'open')::time; closes:=(slot->>'close')::time;
      if opens<closes and local_now::time>=opens and local_now::time<closes then
        close_at:=(today+closes) at time zone 'Asia/Bangkok';
      elsif closes<opens and local_now::time>=opens then
        close_at:=((today+1)+closes) at time zone 'Asia/Bangkok';
      end if;
    end if;
    if close_at is null and coalesce((prior->>'enabled')::boolean,false) then
      opens:=(prior->>'open')::time; closes:=(prior->>'close')::time;
      if closes<opens and local_now::time<closes then close_at:=(today+closes) at time zone 'Asia/Bangkok'; end if;
    end if;
  exception when invalid_text_representation or datetime_field_overflow then return;
  end;
  if close_at is null then return; end if;
  first_at:=to_timestamp(ceil(extract(epoch from (p_at+make_interval(mins=>s.prep_minutes)))/900)*900);
  last_at:=least(close_at-make_interval(mins=>s.prep_minutes),((today+1)::timestamp at time zone 'Asia/Bangkok')-interval '1 microsecond');
  return query select t from generate_series(first_at,last_at,interval '15 minutes') t
    where (t at time zone 'Asia/Bangkok')::date=today and internal.food_store_effectively_open(s.id,t);
end;
$$;
revoke all on function internal.food_pickup_slots(uuid,timestamptz) from public,anon,authenticated;

create function internal.food_validate_fulfillment(p_store_id uuid,p_mode text,p_payment text,p_pickup_at timestamptz default null,p_require_slot boolean default false)
returns void language plpgsql stable security definer set search_path='' as $$
declare s public.food_stores%rowtype;
begin
  if not public.food_customer_access_enabled() or auth.uid() is null then raise exception 'food customer access required'; end if;
  select * into s from public.food_stores where id=p_store_id;
  if not found or not s.is_published or not internal.food_store_effectively_open(s.id,internal.food_fulfillment_now()) then raise exception 'store is closed'; end if;
  if not public.is_developer_account() and not internal.food_in_service_area(s.latitude,s.longitude) then raise exception 'store is outside the service area'; end if;
  if p_mode is null or p_mode not in ('delivery','pickup') or p_payment is null or p_payment not in ('transfer','cod') then raise exception 'invalid fulfillment'; end if;
  if p_mode='delivery' and not s.delivery_enabled then raise exception 'delivery_disabled'; end if;
  if p_mode='pickup' and not s.pickup_enabled then raise exception 'pickup_disabled'; end if;
  if p_payment='cod' and (p_mode<>'delivery' or not s.cod_enabled) then raise exception 'cod_unavailable'; end if;
  if p_mode='delivery' and p_pickup_at is not null then raise exception 'invalid pickup time'; end if;
  if p_mode='pickup' and p_require_slot and (p_pickup_at is null or not exists(select 1 from internal.food_pickup_slots(s.id) t where t=p_pickup_at)) then raise exception 'invalid pickup time'; end if;
end;
$$;
revoke all on function internal.food_validate_fulfillment(uuid,text,text,timestamptz,boolean) from public,anon,authenticated;

-- Direct table UPDATE cannot bypass the owner/admin RPC for fulfillment settings.
create function internal.food_fulfillment_store_guard() returns trigger language plpgsql set search_path='' as $$
begin
  if row(new.pickup_enabled,new.delivery_enabled,new.cod_enabled,new.prep_minutes) is distinct from row(old.pickup_enabled,old.delivery_enabled,old.cod_enabled,old.prep_minutes)
    and not pg_has_role(current_user,(select c.relowner from pg_catalog.pg_class c where c.oid='public.food_stores'::regclass),'USAGE') then
    raise exception 'fulfillment settings require RPC';
  end if;
  return new;
end;
$$;
create trigger food_fulfillment_store_guard before update on public.food_stores for each row execute function internal.food_fulfillment_store_guard();

create function public.food_store_set_fulfillment(p_store_id uuid,p_pickup boolean,p_delivery boolean,p_cod boolean,p_prep_minutes integer)
returns void language plpgsql security definer set search_path='' as $$
declare s public.food_stores%rowtype;
begin
  if auth.uid() is null or not public.merchant_has_store_role(p_store_id,array['owner','admin']) then raise exception 'owner or admin role required'; end if;
  select * into s from public.food_stores where id=p_store_id for update;
  if not found then raise exception 'store not found'; end if;
  if p_pickup is null or p_delivery is null or p_cod is null or p_prep_minutes is null or p_prep_minutes not between 5 and 120 then raise exception 'invalid fulfillment settings'; end if;
  if not p_pickup and not p_delivery then raise exception 'at_least_one_mode'; end if;
  if p_cod and not p_delivery then raise exception 'cod_requires_delivery'; end if;
  if p_pickup and (jsonb_typeof(s.business_schedule->'weekly') is distinct from 'object' or not exists (
    select 1 from jsonb_each(s.business_schedule->'weekly') x
    where x.value->>'enabled'='true' and x.value->>'open' ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
      and x.value->>'close' ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' and x.value->>'open'<>x.value->>'close'
  )) then raise exception 'pickup_requires_schedule'; end if;
  update public.food_stores set pickup_enabled=p_pickup,delivery_enabled=p_delivery,cod_enabled=p_cod,prep_minutes=p_prep_minutes where id=p_store_id;
end;
$$;

create function public.food_quote_order_v3(p_store_id uuid,p_items jsonb,p_latitude double precision default null,p_longitude double precision default null,p_coupon_code text default null,p_fulfillment_type text default 'delivery')
returns jsonb language plpgsql security definer set search_path='' as $$
declare q jsonb; prev text := current_setting('wyn.food_fulfillment',true); slots jsonb;
begin
  perform internal.food_validate_fulfillment(p_store_id,p_fulfillment_type,'transfer');
  perform set_config('wyn.food_fulfillment',p_fulfillment_type,true);
  q:=public.food_quote_order_v2(p_store_id,p_items,p_latitude,p_longitude,p_coupon_code);
  perform set_config('wyn.food_fulfillment',coalesce(prev,''),true);
  select coalesce(jsonb_agg(t),'[]'::jsonb) into slots from internal.food_pickup_slots(p_store_id) t;
  return q||jsonb_build_object('fulfillment_type',p_fulfillment_type,'pickup_slots',case when p_fulfillment_type='pickup' then slots else '[]'::jsonb end);
exception when others then
  perform set_config('wyn.food_fulfillment',coalesce(prev,''),true); raise;
end;
$$;

create function public.food_create_order_v3(p_store_id uuid,p_recipient_name text,p_recipient_phone text,p_shipping_address text,p_customer_note text,p_items jsonb,p_latitude double precision default null,p_longitude double precision default null,p_coupon_code text default null,p_fulfillment_type text default 'delivery',p_pickup_at timestamptz default null,p_payment_method text default 'transfer')
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; prev_mode text:=current_setting('wyn.food_fulfillment',true); prev_payment text:=current_setting('wyn.food_payment_method',true); prev_time text:=current_setting('wyn.food_pickup_at',true);
begin
  -- Serialize settings updates with order creation; core create validates again.
  perform 1 from public.food_stores where id=p_store_id for share;
  perform internal.food_validate_fulfillment(p_store_id,p_fulfillment_type,p_payment_method,p_pickup_at,true);
  perform set_config('wyn.food_fulfillment',p_fulfillment_type,true);
  perform set_config('wyn.food_payment_method',p_payment_method,true);
  perform set_config('wyn.food_pickup_at',coalesce(p_pickup_at::text,''),true);
  result:=public.food_create_order_v2(p_store_id,p_recipient_name,p_recipient_phone,p_shipping_address,p_customer_note,p_items,p_latitude,p_longitude,p_coupon_code);
  perform set_config('wyn.food_fulfillment',coalesce(prev_mode,''),true);
  perform set_config('wyn.food_payment_method',coalesce(prev_payment,''),true);
  perform set_config('wyn.food_pickup_at',coalesce(prev_time,''),true);
  return result;
exception when others then
  perform set_config('wyn.food_fulfillment',coalesce(prev_mode,''),true);
  perform set_config('wyn.food_payment_method',coalesce(prev_payment,''),true);
  perform set_config('wyn.food_pickup_at',coalesce(prev_time,''),true); raise;
end;
$$;

create function public.food_request_cancel(p_order_id uuid,p_note text default null)
returns void language plpgsql security definer set search_path='' as $$
declare o public.food_orders%rowtype;
begin
  if auth.uid() is null or not public.food_customer_access_enabled() then raise exception 'food customer access required'; end if;
  select * into o from public.food_orders where id=p_order_id for update;
  if not found or o.buyer_id is distinct from auth.uid() then raise exception 'order not found'; end if;
  if o.status not in ('preparing','ready_for_pickup','ready_for_delivery','out_for_delivery') then raise exception 'cancel request unavailable'; end if;
  if o.cancel_requested_at is not null then return; end if;
  update public.food_orders set cancel_requested_at=now(),cancel_request_note=nullif(left(btrim(coalesce(p_note,'')),1000),'') where id=p_order_id;
  insert into public.food_order_events(order_id,event_type,from_status,to_status,note,actor_id)
  values(p_order_id,'cancel_requested',o.status,o.status,nullif(left(btrim(coalesce(p_note,'')),1000),''),auth.uid());
end;
$$;

create function public.food_store_cancel_order(p_order_id uuid,p_refund boolean,p_note text default null)
returns void language plpgsql security definer set search_path='' as $$
declare o public.food_orders%rowtype;
begin
  select * into o from public.food_orders where id=p_order_id for update;
  if auth.uid() is null or not found or not public.merchant_has_store_role(o.store_id,array['owner','admin','manager','orders']) then raise exception 'order management role required'; end if;
  if p_refund is null then raise exception 'refund decision required'; end if;
  if o.status in ('delivered','picked_up','cancelled') then raise exception 'order is closed'; end if;
  if p_refund and o.payment_status<>'paid' then raise exception 'only paid orders can be refunded'; end if;
  update public.food_orders set status='cancelled',cancelled_at=now(),cancel_requested_at=null,cancel_request_note=null,
    refund_status=case when p_refund then 'pending' else 'none' end,
    refund_requested_at=case when p_refund then now() else null end,
    refund_note=nullif(left(btrim(coalesce(p_note,'')),800),'') where id=p_order_id;
  insert into public.food_order_events(order_id,event_type,from_status,to_status,note,actor_id)
  values(p_order_id,case when p_refund then 'cancelled_refund_owed' else 'cancelled_no_refund' end,o.status,'cancelled',nullif(left(btrim(coalesce(p_note,'')),1000),''),auth.uid());
end;
$$;

create function public.food_resolve_cancel_request(p_order_id uuid,p_approve boolean,p_refund boolean,p_note text default null)
returns void language plpgsql security definer set search_path='' as $$
declare o public.food_orders%rowtype;
begin
  select * into o from public.food_orders where id=p_order_id for update;
  if auth.uid() is null or not found or not public.merchant_has_store_role(o.store_id,array['owner','admin','manager','orders']) then raise exception 'order management role required'; end if;
  if p_approve is null or p_refund is null then raise exception 'refund decision required'; end if;
  if o.cancel_requested_at is null or o.status in ('delivered','picked_up','cancelled') then raise exception 'cancel request unavailable'; end if;
  if p_approve then
    perform public.food_store_cancel_order(p_order_id,p_refund,p_note);
  else
    update public.food_orders set cancel_requested_at=null,cancel_request_note=null where id=p_order_id;
    insert into public.food_order_events(order_id,event_type,from_status,to_status,note,actor_id)
    values(p_order_id,'cancel_rejected',o.status,o.status,nullif(left(btrim(coalesce(p_note,'')),1000),''),auth.uid());
    insert into public.notifications(recipient_id,actor_id,type,reason) values(o.buyer_id,null,'system','ออเดอร์ #'||o.order_number||' ร้านปฏิเสธคำขอยกเลิก');
  end if;
end;
$$;

create function public.food_store_mark_refunded(p_order_id uuid,p_refund_slip_path text,p_note text default null)
returns void language plpgsql security definer set search_path='' as $$
declare o public.food_orders%rowtype;
begin
  select * into o from public.food_orders where id=p_order_id for update;
  if auth.uid() is null or not found or not public.merchant_has_store_role(o.store_id,array['owner','admin','manager']) then raise exception 'refund management role required'; end if;
  if o.payment_provider='stripe' or o.payment_method='cod' then raise exception 'store transfer refund unavailable'; end if;
  if o.refund_status='refunded' and o.refund_slip_path=p_refund_slip_path then return; end if;
  if o.refund_status<>'pending' or o.status<>'cancelled' or o.payment_status<>'paid' then raise exception 'refund not owed'; end if;
  if p_refund_slip_path is null or position('..' in p_refund_slip_path)>0 or p_refund_slip_path not like 'food-refund-slips/'||o.store_id::text||'/'||o.id::text||'/%'
    or not exists(select 1 from storage.objects f where f.bucket_id='food-private' and f.name=p_refund_slip_path) then raise exception 'refund slip required'; end if;
  update public.food_orders set refund_status='refunded',payment_status='refunded',refund_slip_path=p_refund_slip_path,refunded_by_store_at=now(),refunded_at=now(),refund_updated_by=auth.uid(),refund_note=nullif(left(btrim(coalesce(p_note,'')),800),'') where id=p_order_id;
  insert into public.food_order_events(order_id,event_type,note,actor_id) values(p_order_id,'store_refunded',nullif(left(btrim(coalesce(p_note,'')),1000),''),auth.uid());
end;
$$;

create function internal.food_refund_storage_access(p_name text,p_write boolean) returns boolean
language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists (
    select 1 from public.food_orders o where p_name like 'food-refund-slips/'||o.store_id::text||'/'||o.id::text||'/%'
      and position('..' in p_name)=0
      and case when p_write then o.status='cancelled' and o.refund_status='pending' and o.payment_status='paid' and o.payment_provider is distinct from 'stripe' and o.payment_method='transfer'
        and public.merchant_has_store_role(o.store_id,array['owner','admin','manager'])
      else public.food_has_merchant_access(o.store_id) or (o.buyer_id=auth.uid() and public.food_customer_access_enabled()) or internal.has_admin_permission('food','view') end
  );
$$;
revoke all on function internal.food_refund_storage_access(text,boolean) from public,anon;
grant execute on function internal.food_refund_storage_access(text,boolean) to authenticated;
create policy "Refund slips scoped read" on storage.objects for select to authenticated using(bucket_id='food-private' and name like 'food-refund-slips/%' and internal.food_refund_storage_access(name,false));
create policy "Refund slips scoped insert" on storage.objects for insert to authenticated with check(bucket_id='food-private' and name like 'food-refund-slips/%' and internal.food_refund_storage_access(name,true));
-- Restrictive policies also constrain older, broader permissive media policies.
create policy "Refund slips restrict read" on storage.objects as restrictive for select to authenticated using(bucket_id<>'food-private' or name not like 'food-refund-slips/%' or internal.food_refund_storage_access(name,false));
create policy "Refund slips restrict insert" on storage.objects as restrictive for insert to authenticated with check(bucket_id<>'food-private' or name not like 'food-refund-slips/%' or internal.food_refund_storage_access(name,true));
create policy "Refund slips immutable update" on storage.objects as restrictive for update to authenticated using(bucket_id<>'food-private' or name not like 'food-refund-slips/%') with check(bucket_id<>'food-private' or name not like 'food-refund-slips/%');
create policy "Refund slips immutable delete" on storage.objects as restrictive for delete to authenticated using(bucket_id<>'food-private' or name not like 'food-refund-slips/%');

create function internal.food_fulfillment_notify() returns trigger language plpgsql security definer set search_path='' as $$
declare account uuid; reason text;
begin
  if new.cancel_requested_at is not null and old.cancel_requested_at is null then
    select merchant_account_id into account from public.food_stores where id=new.store_id;
    reason:='WYNOS Merchant · ลูกค้าขอยกเลิกออเดอร์ #'||new.order_number;
    insert into public.merchant_notifications(merchant_account_id,recipient_user_id,type,reason)
      select account,m.user_id,'order',reason from public.merchant_memberships m where m.merchant_account_id=account and m.active;
    insert into public.notifications(recipient_id,actor_id,type,reason)
      select f.user_id,null,'system',reason from public.food_staff f where f.store_id=new.store_id and f.active;
  end if;
  if new.status='ready_for_pickup' and old.status is distinct from new.status then
    insert into public.notifications(recipient_id,actor_id,type,reason) values(new.buyer_id,null,'system','ออเดอร์ #'||new.order_number||' พร้อมให้รับที่ร้าน · รหัส '||new.pickup_code);
  elsif new.status='picked_up' and old.status is distinct from new.status then
    insert into public.notifications(recipient_id,actor_id,type,reason) values(new.buyer_id,null,'system','ออเดอร์ #'||new.order_number||' ลูกค้ารับแล้ว');
  elsif new.refund_status='refunded' and old.refund_status is distinct from new.refund_status and new.refunded_by_store_at is not null then
    insert into public.notifications(recipient_id,actor_id,type,reason) values(new.buyer_id,null,'system','ออเดอร์ #'||new.order_number||' ร้านโอนเงินคืนแล้ว');
  elsif new.status='delivered' and old.status is distinct from new.status and new.payment_method='cod' then
    insert into public.food_order_events(order_id,event_type,note,actor_id) values(new.id,'cash_received','ได้รับเงินสดแล้ว',auth.uid());
  end if;
  return new;
end;
$$;
create trigger food_fulfillment_notify after update on public.food_orders for each row execute function internal.food_fulfillment_notify();

-- ZOKY-FULFILL-001 Admin read models. The original RPC remains unchanged for old clients.
create or replace function public.admin_food_orders_v2(
  p_store_id uuid default null,
  p_status text default null,
  p_query text default null,
  p_limit integer default 100,
  p_fulfillment_type text default null,
  p_payment_method text default null
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
  v_result jsonb;
begin
  if auth.uid() is null or not internal.has_admin_permission('food', 'edit') then
    raise exception 'Only admins can view Food orders';
  end if;
  if p_status is not null and p_status not in ('active','pending_acceptance','preparing','ready_for_delivery','out_for_delivery','delivered','ready_for_pickup','picked_up','cancelled','refund_pending','refund_overdue','payment_review','cancel_requested') then
    raise exception 'Invalid order status';
  end if;
  if p_fulfillment_type is not null and p_fulfillment_type not in ('pickup','delivery') then
    raise exception 'Invalid fulfillment type';
  end if;
  if p_payment_method is not null and p_payment_method not in ('transfer','cod','stripe') then
    raise exception 'Invalid payment method';
  end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc, x.id desc), '[]'::jsonb)
  into v_result
  from (
    select o.id, o.order_number::text, o.store_id, s.name as store_name,
      o.status, o.payment_status, o.refund_status, o.recipient_name, o.recipient_phone,
      o.total, o.created_at, o.delivered_at, o.fulfillment_type, o.payment_method,
      o.payment_provider, o.pickup_at, o.pickup_code, o.picked_up_at,
      o.cancel_requested_at, o.cancel_request_note, o.refund_requested_at, o.cancelled_at,
      o.refund_slip_path, o.refunded_by_store_at
    from public.food_orders o join public.food_stores s on s.id = o.store_id
    where (p_store_id is null or o.store_id = p_store_id)
      and (p_fulfillment_type is null or o.fulfillment_type = p_fulfillment_type)
      and (p_payment_method is null
        or (p_payment_method = 'stripe' and o.payment_provider = 'stripe')
        or (p_payment_method = 'transfer' and o.payment_method = 'transfer' and o.payment_provider is distinct from 'stripe')
        or (p_payment_method = 'cod' and o.payment_method = 'cod'))
      and (p_status is null or o.status = p_status
        or (p_status = 'active' and o.status not in ('delivered','picked_up','cancelled'))
        or (p_status = 'refund_pending' and o.refund_status in ('pending','failed'))
        or (p_status = 'refund_overdue' and o.refund_status = 'pending'
          and o.payment_method = 'transfer' and o.payment_provider is distinct from 'stripe'
          and coalesce(o.refund_requested_at,o.cancelled_at,o.created_at) < now() - interval '24 hours')
        or (p_status = 'cancel_requested' and o.cancel_requested_at is not null and o.status not in ('delivered','picked_up','cancelled'))
        or (p_status = 'payment_review' and o.payment_status in ('submitted','issue')))
      and (v_query is null or o.order_number::text ilike '%'||v_query||'%'
        or o.recipient_name ilike '%'||v_query||'%' or o.recipient_phone ilike '%'||v_query||'%')
    order by o.created_at desc, o.id desc
    limit greatest(1,least(coalesce(p_limit,100),300))
  ) x;
  return v_result;
end;
$$;
revoke all on function public.admin_food_orders_v2(uuid,text,text,integer,text,text) from public, anon;
grant execute on function public.admin_food_orders_v2(uuid,text,text,integer,text,text) to authenticated;

create or replace function public.admin_food_fulfillment_summary(p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_rows jsonb;
begin
  if auth.uid() is null or not internal.has_admin_permission('merchant','view') then
    raise exception 'Not authorized';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 365 then
    raise exception 'Invalid date range';
  end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.fulfillment_type,x.payment_method),'[]'::jsonb)
  into v_rows from (
    select o.fulfillment_type,
      case when o.payment_provider = 'stripe' then 'stripe' else o.payment_method end as payment_method,
      count(*) filter (where o.status in ('delivered','picked_up') and o.payment_status = 'paid') as orders,
      coalesce(sum(o.total) filter (where o.status in ('delivered','picked_up') and o.payment_status = 'paid'),0) as sales,
      count(*) filter (where o.refund_status = 'pending' and o.payment_method = 'transfer' and o.payment_provider is distinct from 'stripe') as pending_refund_count,
      count(*) filter (where o.refund_status = 'pending' and o.payment_method = 'transfer' and o.payment_provider is distinct from 'stripe'
        and coalesce(o.refund_requested_at,o.cancelled_at,o.created_at) < now() - interval '24 hours') as overdue_refund_count
    from public.food_orders o
    where o.created_at >= (p_from::timestamp at time zone 'Asia/Bangkok')
      and o.created_at < ((p_to + 1)::timestamp at time zone 'Asia/Bangkok')
    group by o.fulfillment_type, case when o.payment_provider = 'stripe' then 'stripe' else o.payment_method end
  ) x;
  return jsonb_build_object('from',p_from,'to',p_to,'rows',v_rows);
end;
$$;
revoke all on function public.admin_food_fulfillment_summary(date,date) from public, anon;
grant execute on function public.admin_food_fulfillment_summary(date,date) to authenticated;

CREATE OR REPLACE FUNCTION public.food_create_order(p_store_id uuid, p_recipient_name text, p_recipient_phone text, p_shipping_address text, p_customer_note text, p_items jsonb, p_latitude double precision DEFAULT NULL::double precision, p_longitude double precision DEFAULT NULL::double precision)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_store public.food_stores%rowtype;
  v_item public.food_menu_items%rowtype;
  v_campaign public.food_campaigns%rowtype;
  v_line jsonb;
  v_order_id uuid;
  v_menu_id uuid;
  v_qty integer;
  v_subtotal numeric(10,2) := 0;
  v_total numeric(10,2);
  v_count integer := 0;
  v_lines jsonb := '[]'::jsonb;
  v_recent integer;
  v_pending integer;
  v_item_totals jsonb := '{}'::jsonb;
  v_campaign_id uuid;
  v_campaign_name text;
  v_campaign_type text;
  v_campaign_discount numeric(10,2) := 0;
  v_delivery_discount numeric(10,2) := 0;
  v_delivery_fee numeric(10,2);
  v_distance numeric(6,2);
  v_options jsonb;
  v_surcharge numeric(10,2);
  v_unit numeric(10,2);
  v_mode text := coalesce(nullif(current_setting('wyn.food_fulfillment',true),''),'delivery');
  v_payment text := coalesce(nullif(current_setting('wyn.food_payment_method',true),''),'transfer');
  v_pickup_at timestamptz := nullif(current_setting('wyn.food_pickup_at',true),'')::timestamptz;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  if coalesce(char_length(trim(p_recipient_name)),0)=0
     or coalesce(char_length(trim(p_recipient_phone)),0)=0
     or (v_mode<>'pickup' and coalesce(char_length(trim(p_shipping_address)),0)=0) then
    raise exception 'recipient information is required';
  end if;

  if jsonb_typeof(p_items)<>'array'
     or jsonb_array_length(p_items)=0
     or jsonb_array_length(p_items)>50 then
    raise exception 'invalid order items';
  end if;

  -- WYN-218: limit how fast one buyer can place orders. One lock per buyer
  -- so parallel requests cannot slip past the count.
  if not public.is_developer_account() then
    perform pg_advisory_xact_lock(hashtext('food_create_order:' || auth.uid()::text));
    select count(*) into v_recent
    from public.food_orders o
    where o.buyer_id = auth.uid()
      and o.created_at > now() - interval '10 minutes';
    if v_recent >= 5 then
      raise exception 'too many orders, try again later';
    end if;
    select count(*) into v_pending
    from public.food_orders o
    where o.buyer_id = auth.uid()
      and o.store_id = p_store_id
      and o.status = 'pending_acceptance';
    if v_pending >= 3 then
      raise exception 'too many pending orders';
    end if;
  end if;

  select * into v_store from public.food_stores where id=p_store_id for share;
  if not found
     or not v_store.is_open
     or (
       not public.is_developer_account()
       and (
         not public.food_public_access_enabled()
         or not v_store.is_published
       )
     ) then
    raise exception 'store is not accepting orders';
  end if;

  perform internal.food_validate_fulfillment(p_store_id,v_mode,v_payment,v_pickup_at,true);
  -- WYN-196: distance-based fee and delivery radius, computed on the server.
  if v_mode='pickup' then
    v_delivery_fee:=0; v_distance:=null;
  else
    select z.distance_km, z.delivery_fee into v_distance, v_delivery_fee
    from internal.food_delivery_fee(p_store_id, p_latitude, p_longitude) z;
  end if;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_menu_id := (v_line->>'menu_item_id')::uuid;
      v_qty := greatest(1,least(99,coalesce((v_line->>'quantity')::integer,1)));
    exception when others then
      raise exception 'invalid order item';
    end;

    select * into v_item
    from public.food_menu_items
    where id=v_menu_id
      and store_id=p_store_id
      and is_available;
    if not found then raise exception 'menu item is unavailable'; end if;

    -- WYN-218: options are resolved from the menu, never taken from the client.
    select r.options, r.surcharge into v_options, v_surcharge
    from internal.food_resolve_menu_options(v_item.options, v_line->'selected_options') r;
    v_unit := v_item.price + v_surcharge;

    v_subtotal := v_subtotal + (v_unit * v_qty);
    v_count := v_count + 1;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'menu_item_id', v_item.id,
      'item_name', v_item.name,
      'unit_price', v_unit,
      'quantity', v_qty,
      'selected_options', v_options,
      'note', v_line->>'note'
    ));
    v_item_totals := v_item_totals || jsonb_build_object(
      v_menu_id::text,
      coalesce((v_item_totals->>v_menu_id::text)::numeric,0) + (v_unit * v_qty)
    );
  end loop;

  if v_count=0 or v_subtotal < v_store.minimum_order then
    raise exception 'minimum order not met';
  end if;

  -- Select the best promotion, lock it, then re-check under the lock.
  -- If another checkout consumed its final limited use while we waited,
  -- retry so the customer can still receive the next-best eligible campaign.
  loop
    v_campaign_id := null;
    v_campaign_name := null;
    v_campaign_type := null;
    v_campaign_discount := 0;
    v_delivery_discount := 0;

    select c.campaign_id,c.campaign_name,c.campaign_type,c.campaign_discount,c.delivery_discount
      into v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
    from internal.food_campaign_candidates(
      p_store_id,v_subtotal,v_delivery_fee,v_item_totals
    ) c
    limit 1;

    exit when v_campaign_id is null;

    select * into v_campaign
    from public.food_campaigns c
    where c.id=v_campaign_id
    for update;

    v_campaign_id := null;
    select c.campaign_id,c.campaign_name,c.campaign_type,c.campaign_discount,c.delivery_discount
      into v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
    from internal.food_campaign_candidates(
      p_store_id,v_subtotal,v_delivery_fee,v_item_totals
    ) c
    where c.campaign_id=v_campaign.id
    limit 1;

    exit when v_campaign_id is not null;
  end loop;

  v_campaign_discount := coalesce(v_campaign_discount,0);
  v_delivery_discount := coalesce(v_delivery_discount,0);
  if v_campaign_id is null then
    v_campaign_name := null;
    v_campaign_type := null;
    v_campaign_discount := 0;
    v_delivery_discount := 0;
  end if;

  v_total := greatest(v_subtotal - v_campaign_discount + v_delivery_fee - v_delivery_discount,0);

  insert into public.food_orders(
    store_id,buyer_id,created_by,source,status,payment_status,
    recipient_name,recipient_phone,shipping_address,customer_note,
    subtotal,delivery_fee,campaign_id,campaign_name,campaign_discount,delivery_discount,total,
    delivery_latitude,delivery_longitude,delivery_distance_km,fulfillment_type,payment_method,pickup_at,pickup_code,payment_due_at
  ) values (
    p_store_id,
    auth.uid(),
    auth.uid(),
    'app',
    'pending_acceptance',
    'pending',
    left(trim(p_recipient_name),120),
    left(trim(p_recipient_phone),50),
    case when v_mode='pickup' then 'รับเองที่ร้าน' else left(trim(p_shipping_address),800) end,
    nullif(left(trim(coalesce(p_customer_note,'')),800),''),
    v_subtotal,
    v_delivery_fee,
    v_campaign_id,
    v_campaign_name,
    v_campaign_discount,
    v_delivery_discount,
    v_total,
    case when v_distance is null then null else p_latitude end,
    case when v_distance is null then null else p_longitude end,
    v_distance,v_mode,v_payment,v_pickup_at,
    case when v_mode='pickup' then 'P'||upper(to_hex(nextval('public.food_pickup_code_sequence'))) else null end,
    case when v_payment='cod' then null else now()+interval '10 minutes' end
  )
  returning id into v_order_id;

  -- Insert the lines exactly as they were priced above.
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    insert into public.food_order_items(
      order_id,menu_item_id,item_name,unit_price,quantity,selected_options,item_note
    ) values (
      v_order_id,
      (v_line->>'menu_item_id')::uuid,
      v_line->>'item_name',
      (v_line->>'unit_price')::numeric,
      (v_line->>'quantity')::integer,
      v_line->'selected_options',
      nullif(left(trim(coalesce(v_line->>'note','')),500),'')
    );
  end loop;

  if v_campaign_id is not null then
    insert into public.food_order_campaigns(
      order_id,campaign_id,campaign_name,campaign_type,campaign_discount,delivery_discount
    ) values (
      v_order_id,v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
    );

    update public.food_campaigns
    set usage_count=usage_count+1
    where id=v_campaign_id;

    insert into public.food_order_events(order_id,event_type,note,actor_id)
    values (
      v_order_id,'campaign_applied',
      left(v_campaign_name || ' · ลด ฿' || trim(to_char(v_campaign_discount+v_delivery_discount,'FM999999990.00')),1000),
      auth.uid()
    );
  end if;

  insert into public.food_order_events(order_id,event_type,to_status,note,actor_id)
  values (v_order_id,'created','pending_acceptance','สร้างคำสั่งซื้อ',auth.uid());

  return v_order_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_quote_order(p_store_id uuid, p_items jsonb, p_latitude double precision DEFAULT NULL::double precision, p_longitude double precision DEFAULT NULL::double precision)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_store public.food_stores%rowtype;
  v_item public.food_menu_items%rowtype;
  v_line jsonb;
  v_menu_id uuid;
  v_qty integer;
  v_subtotal numeric(10,2) := 0;
  v_item_totals jsonb := '{}'::jsonb;
  v_campaign_id uuid;
  v_campaign_name text;
  v_campaign_type text;
  v_campaign_discount numeric(10,2) := 0;
  v_delivery_discount numeric(10,2) := 0;
  v_total numeric(10,2);
  v_delivery_fee numeric(10,2);
  v_distance numeric(6,2);
  v_options jsonb;
  v_surcharge numeric(10,2);
  v_unit numeric(10,2);
  v_needs_location boolean := false;
  v_mode text := coalesce(nullif(current_setting('wyn.food_fulfillment',true),''),'delivery');
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;
  if jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items)=0
     or jsonb_array_length(p_items)>50 then
    raise exception 'invalid order items';
  end if;

  select * into v_store from public.food_stores where id=p_store_id;
  if not found
     or (
       not public.is_developer_account()
       and (
         not public.food_public_access_enabled()
         or not v_store.is_published
       )
     ) then
    raise exception 'store is not accepting orders';
  end if;

  perform internal.food_validate_fulfillment(p_store_id,v_mode,'transfer');
  -- WYN-196: a store with a pinned location charges by distance and only
  -- delivers inside its radius. The cart can be quoted before an address is
  -- chosen; it then shows the base fee and says a location is needed.
  if v_mode='pickup' then
    v_delivery_fee:=0; v_distance:=null;
  elsif v_store.latitude is not null and (p_latitude is null or p_longitude is null) then
    v_needs_location := true;
    v_delivery_fee := v_store.delivery_fee;
  else
    select z.distance_km, z.delivery_fee into v_distance, v_delivery_fee
    from internal.food_delivery_fee(p_store_id, p_latitude, p_longitude) z;
  end if;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_menu_id := (v_line->>'menu_item_id')::uuid;
      v_qty := greatest(1,least(99,coalesce((v_line->>'quantity')::integer,1)));
    exception when others then
      raise exception 'invalid order item';
    end;

    select * into v_item
    from public.food_menu_items
    where id=v_menu_id and store_id=p_store_id and is_available;
    if not found then raise exception 'menu item is unavailable'; end if;

    -- WYN-218: options are resolved from the menu, never taken from the client.
    select r.options, r.surcharge into v_options, v_surcharge
    from internal.food_resolve_menu_options(v_item.options, v_line->'selected_options') r;
    v_unit := v_item.price + v_surcharge;

    v_subtotal := v_subtotal + (v_unit * v_qty);
    v_item_totals := v_item_totals || jsonb_build_object(
      v_menu_id::text,
      coalesce((v_item_totals->>v_menu_id::text)::numeric,0) + (v_unit * v_qty)
    );
  end loop;

  select c.campaign_id,c.campaign_name,c.campaign_type,c.campaign_discount,c.delivery_discount
    into v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
  from internal.food_campaign_candidates(
    p_store_id,v_subtotal,v_delivery_fee,v_item_totals
  ) c
  limit 1;

  v_campaign_discount := coalesce(v_campaign_discount,0);
  v_delivery_discount := coalesce(v_delivery_discount,0);
  v_total := greatest(v_subtotal - v_campaign_discount + v_delivery_fee - v_delivery_discount,0);

  return jsonb_build_object(
    'subtotal',v_subtotal,
    'delivery_fee',v_delivery_fee,
    'delivery_distance_km',v_distance,
    'delivery_radius_km',case when v_store.latitude is null then null else v_store.delivery_radius_km end,
    'delivery_needs_location',v_needs_location,
    'campaign_discount',v_campaign_discount,
    'delivery_discount',v_delivery_discount,
    'total',v_total,
    'campaign_id',v_campaign_id,
    'campaign_name',v_campaign_name,
    'campaign_type',v_campaign_type
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_transition_order(p_order_id uuid, p_status text, p_eta_minutes integer DEFAULT NULL::integer, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_order public.food_orders%rowtype;
  v_allowed boolean := false;
  v_roles text[];
begin
  select * into v_order from public.food_orders where id=p_order_id for update;
  if not found then raise exception 'order not found'; end if;

  v_roles := case
    when p_status='out_for_delivery' then array['owner','admin','manager','orders','delivery']
    else array['owner','admin','manager','orders']
  end;
  if not public.merchant_has_store_role(v_order.store_id, v_roles) then
    raise exception 'order management role required';
  end if;

  if p_eta_minutes is not null and (p_eta_minutes < 1 or p_eta_minutes > 240) then
    raise exception 'invalid ETA';
  end if;

  v_allowed := case
    when v_order.status='pending_acceptance' and p_status in ('preparing','cancelled') then true
    when v_order.status='preparing' and p_status='cancelled' then true
    when v_order.fulfillment_type='pickup' and v_order.status='preparing' and p_status='ready_for_pickup' then true
    when v_order.fulfillment_type='pickup' and v_order.status='ready_for_pickup' and p_status in ('picked_up','cancelled') then true
    when v_order.fulfillment_type='delivery' and v_order.status='preparing' and p_status='ready_for_delivery' then true
    when v_order.status='ready_for_delivery' and p_status in ('out_for_delivery','cancelled') then true
    when v_order.status='out_for_delivery' and p_status='cancelled' then true
    else false
  end;

  if not v_allowed then raise exception 'invalid order transition'; end if;
  if v_order.status='pending_acceptance' and p_status='preparing' and v_order.payment_status <> 'paid' and v_order.payment_method<>'cod' then
    raise exception 'payment must be verified first';
  end if;

  update public.food_orders
  set status=p_status,
      eta_minutes=coalesce(p_eta_minutes,eta_minutes),
      accepted_at=case when p_status='preparing' then coalesce(accepted_at,now()) else accepted_at end,
      ready_at=case when p_status in ('ready_for_delivery','ready_for_pickup') then now() else ready_at end,
      picked_up_at=case when p_status='picked_up' then now() else picked_up_at end,
      cancel_requested_at=case when p_status in ('picked_up','cancelled') then null else cancel_requested_at end,
      cancel_request_note=case when p_status in ('picked_up','cancelled') then null else cancel_request_note end,
      out_for_delivery_at=case when p_status='out_for_delivery' then now() else out_for_delivery_at end,
      cancelled_at=case when p_status='cancelled' then now() else cancelled_at end,
      refund_status=case
        when p_status='cancelled' and v_order.payment_status='paid' then 'pending'
        else refund_status
      end,
      refund_requested_at=case
        when p_status='cancelled' and v_order.payment_status='paid'
          then coalesce(refund_requested_at,now())
        else refund_requested_at
      end
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,from_status,to_status,note,actor_id)
  values (
    p_order_id,'status_changed',v_order.status,p_status,
    nullif(left(trim(coalesce(p_note,'')),1000),''),
    auth.uid()
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_complete_delivery(p_order_id uuid, p_method text, p_location_note text DEFAULT NULL::text, p_image_path text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_order public.food_orders%rowtype;
  v_note text := nullif(left(btrim(coalesce(p_location_note,''), E' \t\r\n'),500),'');
begin
  select * into v_order from public.food_orders where id=p_order_id for update;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders','delivery']) then
    raise exception 'delivery role required';
  end if;
  if v_order.status <> 'out_for_delivery' or v_order.fulfillment_type<>'delivery' then
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
  set status='delivered', delivered_at=now(),cancel_requested_at=null,cancel_request_note=null,
      payment_status=case when payment_method='cod' then 'paid' else payment_status end,
      paid_at=case when payment_method='cod' then now() else paid_at end,
      payment_provider=case when payment_method='cod' then 'merchant_cash' else payment_provider end
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
$function$;

CREATE OR REPLACE FUNCTION public.food_cancel_order(p_order_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_order public.food_orders%rowtype;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  select * into v_order
  from public.food_orders
  where id = p_order_id
  for update;

  if not found or v_order.buyer_id is distinct from auth.uid() then
    raise exception 'order not found';
  end if;

  if v_order.status <> 'pending_acceptance' then
    raise exception 'order cannot be cancelled by customer';
  end if;

  update public.food_orders
  set status = 'cancelled',
      cancelled_at = now(),
      refund_status=case when payment_status='paid' then 'pending' else refund_status end,
      refund_requested_at=case when payment_status='paid' then now() else refund_requested_at end
  where id = p_order_id;

  insert into public.food_order_events (
    order_id, event_type, from_status, to_status, note, actor_id
  ) values (
    p_order_id,
    'customer_cancelled',
    v_order.status,
    'cancelled',
    nullif(left(trim(coalesce(p_reason,'')),1000),''),
    auth.uid()
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_submit_payment(p_order_id uuid, p_slip_path text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_order public.food_orders%rowtype;
begin
  if not public.food_is_permanent_account() then raise exception 'permanent account required'; end if;

  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found or v_order.buyer_id is distinct from auth.uid() then raise exception 'order not found'; end if;
  if v_order.payment_method='cod' then raise exception 'COD does not accept slips'; end if;
  if v_order.status in ('delivered','picked_up','cancelled') then raise exception 'order is closed'; end if;
  if v_order.payment_status not in ('pending','issue') then
    raise exception 'payment already submitted';
  end if;
  if v_order.stripe_checkout_session_id is not null then
    raise exception 'cancel stripe checkout before submitting slip';
  end if;
  if p_slip_path is null or p_slip_path not like (auth.uid()::text || '/slips/' || p_order_id::text || '/%') then
    raise exception 'invalid slip path';
  end if;

  update public.food_orders
  set payment_status = 'submitted',
      payment_slip_path = p_slip_path,
      payment_note = null,
      payment_verification_status = 'manual_review',
      payment_provider = null,
      payment_provider_code = null,
      payment_transaction_ref = null,
      payment_verified_at = null,
      payment_verification_note = null
  where id = p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'payment_submitted','ลูกค้าแนบหลักฐานการชำระเงิน',auth.uid());
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_set_payment_status(p_order_id uuid, p_status text, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_order public.food_orders%rowtype;
  v_note text := nullif(left(trim(coalesce(p_note,'')),800),'');
begin
  select * into v_order from public.food_orders where id=p_order_id for update;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
  end if;
  if v_order.payment_status='refunded' or v_order.refund_status='refunded' then raise exception 'refund evidence is final'; end if;
  if v_order.payment_method='cod' then raise exception 'cash is confirmed at delivery completion'; end if;
  if p_status='refunded' and v_order.payment_provider is distinct from 'stripe' then raise exception 'refund slip required'; end if;
  if v_order.payment_provider = 'stripe'
     or (v_order.stripe_checkout_session_id is not null and v_order.payment_slip_path is null) then
    raise exception 'stripe payment status is managed by webhook';
  end if;
  if p_status not in ('paid','issue','refunded') then raise exception 'invalid payment status'; end if;

  update public.food_orders
  set payment_status=p_status,
      payment_note=v_note,
      payment_verification_status=case
        when p_status='paid' then 'manual_verified'
        when p_status='issue' then 'rejected'
        else payment_verification_status
      end,
      payment_provider=case when p_status in ('paid','issue') then 'merchant_manual' else payment_provider end,
      payment_verified_at=case when p_status in ('paid','issue') then now() else payment_verified_at end,
      payment_verification_note=case when p_status in ('paid','issue') then v_note else payment_verification_note end,
      paid_at=case when p_status='paid' then coalesce(paid_at,now()) else paid_at end,
      refund_status=case when p_status='refunded' then 'refunded' else refund_status end,
      refunded_at=case when p_status='refunded' then coalesce(refunded_at,now()) else refunded_at end,
      refund_updated_by=case when p_status='refunded' then auth.uid() else refund_updated_by end
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'payment_' || p_status,v_note,auth.uid());
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_timeout_cancel(p_order_id uuid, p_expected_session_id text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_order public.food_orders%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service role required';
  end if;

  select * into v_order
  from public.food_orders
  where id=p_order_id
  for update;

  if not found or v_order.payment_method='cod' or v_order.source <> 'app'
     or v_order.status <> 'pending_acceptance'
     or v_order.payment_status not in ('pending','issue')
     or v_order.paid_at is not null
     or v_order.payment_due_at is null
     or v_order.payment_due_at > clock_timestamp()
     or v_order.stripe_checkout_session_id is distinct from p_expected_session_id
  then
    return false;
  end if;

  perform set_config('wynos.food_auto_cancel','on',true);
  update public.food_orders
  set status='cancelled', cancelled_at=clock_timestamp()
  where id=v_order.id;
  perform set_config('wynos.food_auto_cancel','off',true);

  insert into public.food_order_events
    (order_id,event_type,from_status,to_status,note,actor_id)
  values
    (v_order.id,'auto_cancelled_unpaid',v_order.status,'cancelled',
     'ระบบยกเลิกอัตโนมัติ: ไม่ชำระเงินภายใน 10 นาที',null);

  return true;
end;
$function$;

CREATE OR REPLACE FUNCTION public.merchant_set_refund_status(p_order_id uuid, p_status text, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_order public.food_orders%rowtype;
  v_note text := nullif(left(trim(coalesce(p_note,'')),800),'');
begin
  select * into v_order
  from public.food_orders
  where id=p_order_id
  for update;

  if not found then raise exception 'order not found'; end if;
  if not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
  end if;
  if v_order.payment_provider = 'stripe' then
    raise exception 'stripe refunds must be processed through the payment gateway';
  end if;
  if v_order.status <> 'cancelled' then
    raise exception 'refund is available after cancellation';
  end if;
  if v_order.refund_status='refunded' then raise exception 'refund evidence is final'; end if;
  if p_status='refunded' then raise exception 'refund slip required'; end if;
  if p_status not in ('pending','refunded','failed') then
    raise exception 'invalid refund status';
  end if;
  if v_order.payment_status not in ('paid','refunded') then
    raise exception 'order is not eligible for refund';
  end if;

  update public.food_orders
  set refund_status=p_status,
      refund_note=v_note,
      refund_requested_at=case
        when p_status='pending' then coalesce(refund_requested_at,now())
        else refund_requested_at
      end,
      refunded_at=case when p_status='refunded' then now() else refunded_at end,
      refund_updated_by=(select auth.uid()),
      payment_status=case when p_status='refunded' then 'refunded' else payment_status end
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'refund_' || p_status,v_note,(select auth.uid()));

  if p_status='refunded' and v_order.buyer_id is not null then
    insert into public.notifications(recipient_id,actor_id,type,reason)
    values (
      v_order.buyer_id,null,'system',
      'คืนเงินออเดอร์ #' || v_order.order_number || ' แล้ว'
    );
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.merchant_sales_report(p_store_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      (o.created_at at time zone 'Asia/Bangkok')::date as order_day
    from public.food_orders o
    where o.store_id = p_store_id
      and o.status in ('delivered','picked_up')
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
    'today_sales', coalesce((select sum(total) from delivered where order_day = v_today), 0),
    'today_orders', (select count(*) from delivered where order_day = v_today),
    'week_sales', coalesce((select sum(total) from delivered where order_day between v_week_start and v_today), 0),
    'week_orders', (select count(*) from delivered where order_day between v_week_start and v_today),
    'month_sales', coalesce((select sum(total) from delivered where order_day between v_month_start and v_today), 0),
    'month_orders', (select count(*) from delivered where order_day between v_month_start and v_today),
    'total_orders', (select count(*) from delivered),
    'average_order', coalesce((select avg(total) from delivered), 0),
    'best', coalesce(
      (select jsonb_agg(jsonb_build_object('name', name, 'quantity', quantity) order by quantity desc, name asc)
       from item_totals),
      '[]'::jsonb
    )
  ) into v_result;

  return v_result || jsonb_build_object('fulfillment', (
    select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (
      select o.fulfillment_type,o.payment_method,count(*) as orders,coalesce(sum(o.total),0) as sales
      from public.food_orders o where o.store_id=p_store_id and o.status in ('delivered','picked_up')
      group by o.fulfillment_type,o.payment_method
    ) x
  ));
end;
$function$;

CREATE OR REPLACE FUNCTION internal.food_orders_gp_snapshot()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_rate record;
begin
  if tg_op = 'INSERT' and new.payment_method='cod' then
    new.gp_rate_bp:=0; new.gp_rate_id:=null; new.gp_rule_version:='cod_no_gp';
  elsif tg_op = 'INSERT' then
    select * into v_rate from internal.merchant_gp_rate_at(new.store_id, now());
    new.gp_rate_bp := coalesce(v_rate.rate_bp, 0);
    new.gp_rate_id := v_rate.rate_id;
    new.gp_rule_version := 'gp_v1_food_after_store_discount';
  else
    new.gp_rate_bp := old.gp_rate_bp;
    new.gp_rate_id := old.gp_rate_id;
    new.gp_rule_version := old.gp_rule_version;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION internal.food_order_status_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := auth.uid();
  v_account_id uuid;
  v_reason text;
begin
  if new.status is not distinct from old.status then return new; end if;

  if new.status = 'preparing' and new.buyer_id is not null then
    insert into public.notifications(recipient_id, actor_id, type, reason)
    values (new.buyer_id, null, 'system',
      'ออเดอร์ #' || new.order_number || ' ร้านรับออเดอร์แล้ว · กำลังเตรียมอาหาร'
      || case when new.eta_minutes is not null then ' (ประมาณ ' || new.eta_minutes || ' นาที)' else '' end);
  elsif new.status = 'out_for_delivery' and new.buyer_id is not null then
    insert into public.notifications(recipient_id, actor_id, type, reason)
    values (new.buyer_id, null, 'system',
      'ออเดอร์ #' || new.order_number || ' กำลังจัดส่ง · เตรียมรับอาหารได้เลย');
  elsif new.status = 'cancelled' then
    if current_setting('wynos.food_auto_cancel',true) = 'on' then
      if new.buyer_id is not null then
        insert into public.notifications(recipient_id, actor_id, type, reason)
        values (new.buyer_id, null, 'system',
          'ออเดอร์ #' || new.order_number || ' ถูกยกเลิกอัตโนมัติ เพราะไม่ชำระเงินภายใน 10 นาที');
      end if;
      v_reason := 'WYNOS Merchant · ออเดอร์ #' || new.order_number ||
                  ' ยกเลิกอัตโนมัติ (ไม่ได้ชำระเงินภายใน 10 นาที)';
      select s.merchant_account_id into v_account_id
      from public.food_stores s where s.id = new.store_id;
      if v_account_id is not null then
        insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
        select v_account_id, mm.user_id, 'order', v_reason
        from public.merchant_memberships mm
        where mm.merchant_account_id = v_account_id and mm.active;
      end if;
    elsif new.buyer_id is not null and v_actor is not distinct from new.buyer_id then
      v_reason := 'WYNOS Merchant · ลูกค้ายกเลิกออเดอร์ #' || new.order_number;
      select s.merchant_account_id into v_account_id from public.food_stores s where s.id = new.store_id;
      if v_account_id is not null then
        insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
        select v_account_id, mm.user_id, 'order', v_reason
        from public.merchant_memberships mm
        where mm.merchant_account_id = v_account_id and mm.active;
      end if;
      insert into public.notifications(recipient_id, actor_id, type, reason)
      select fs.user_id, null, 'system', v_reason
      from public.food_staff fs
      where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
    elsif new.buyer_id is not null then
      insert into public.notifications(recipient_id, actor_id, type, reason)
      values (new.buyer_id, null, 'system',
        'ออเดอร์ #' || new.order_number || ' ถูกร้านยกเลิก'
          || case when new.refund_status = 'pending' then ' · ร้านจะคืนเงินให้คุณ' else '' end);
    end if;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_public_catalog()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
          'pickup_enabled', s.pickup_enabled,
          'delivery_enabled', s.delivery_enabled,
          'cod_enabled', s.cod_enabled,
          'prep_minutes', s.prep_minutes,
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
$function$;

CREATE OR REPLACE FUNCTION public.food_submit_store_review(p_order_id uuid, p_rating integer, p_review_text text DEFAULT NULL::text, p_tags text[] DEFAULT '{}'::text[], p_anonymous boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_order public.food_orders%rowtype;
  v_review_id uuid;
  v_text text := nullif(left(btrim(coalesce(p_review_text,'')),500),'');
  v_tags text[];
  v_label text;
begin
  if (select auth.uid()) is null or not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'invalid review rating';
  end if;

  select array(
    select distinct btrim(t)
    from unnest(coalesce(p_tags,'{}'::text[])) as t
    where btrim(t) <> ''
    order by btrim(t)
  ) into v_tags;

  if cardinality(v_tags) > 5
     or not (v_tags <@ array['อร่อย','ปริมาณดี','แพ็กดี','ตรงปก','คุ้มราคา','ส่งเร็ว']::text[]) then
    raise exception 'invalid review tags';
  end if;

  select * into v_order
  from public.food_orders
  where id = p_order_id
    and buyer_id = (select auth.uid())
  for share;

  if not found then
    raise exception 'order not found';
  end if;
  if v_order.status not in ('delivered','picked_up') or coalesce(v_order.delivered_at,v_order.picked_up_at) is null then
    raise exception 'only delivered orders can be reviewed';
  end if;
  if exists (select 1 from public.food_store_reviews r where r.order_id = p_order_id) then
    raise exception 'order already reviewed';
  end if;

  v_label := case
    when coalesce(p_anonymous,false) then 'ไม่ระบุชื่อ'
    else internal.food_mask_reviewer_name(v_order.recipient_name)
  end;

  insert into public.food_store_reviews(
    order_id, store_id, buyer_id, rating, review_text, tags,
    reviewer_label, is_anonymous
  ) values (
    v_order.id, v_order.store_id, v_order.buyer_id, p_rating, v_text, v_tags,
    v_label, coalesce(p_anonymous,false)
  )
  returning id into v_review_id;

  return v_review_id;
end;
$function$;

create function public.food_store_directory_v2(p_query text default null)
returns table(id uuid, slug text, name text, logo_path text, cover_path text, address text, business_hours text, delivery_fee numeric, latitude double precision, longitude double precision, prep_time_min_minutes integer, prep_time_max_minutes integer, categories text[], rating_average numeric, rating_count bigint, delivered_order_count bigint, promo_name text, promo_type text, promo_value numeric, promo_min_subtotal numeric, is_open boolean, is_ad boolean, pickup_enabled boolean, delivery_enabled boolean, cod_enabled boolean, prep_minutes integer)
language sql stable security definer set search_path='' as $$
  select d.*,s.pickup_enabled,s.delivery_enabled,s.cod_enabled,s.prep_minutes
  from public.food_store_directory(p_query) d join public.food_stores s on s.id=d.id;
$$;

revoke all on function public.food_store_set_fulfillment(uuid,boolean,boolean,boolean,integer) from public,anon;
grant execute on function public.food_store_set_fulfillment(uuid,boolean,boolean,boolean,integer) to authenticated;
revoke all on function public.food_quote_order_v3(uuid,jsonb,double precision,double precision,text,text) from public,anon;
grant execute on function public.food_quote_order_v3(uuid,jsonb,double precision,double precision,text,text) to authenticated;
revoke all on function public.food_create_order_v3(uuid,text,text,text,text,jsonb,double precision,double precision,text,text,timestamptz,text) from public,anon;
grant execute on function public.food_create_order_v3(uuid,text,text,text,text,jsonb,double precision,double precision,text,text,timestamptz,text) to authenticated;
revoke all on function public.food_request_cancel(uuid,text) from public,anon;
grant execute on function public.food_request_cancel(uuid,text) to authenticated;
revoke all on function public.food_store_cancel_order(uuid,boolean,text) from public,anon;
grant execute on function public.food_store_cancel_order(uuid,boolean,text) to authenticated;
revoke all on function public.food_resolve_cancel_request(uuid,boolean,boolean,text) from public,anon;
grant execute on function public.food_resolve_cancel_request(uuid,boolean,boolean,text) to authenticated;
revoke all on function public.food_store_mark_refunded(uuid,text,text) from public,anon;
grant execute on function public.food_store_mark_refunded(uuid,text,text) to authenticated;
revoke all on function public.food_store_directory_v2(text) from public,anon;
grant execute on function public.food_store_directory_v2(text) to authenticated;
CREATE OR REPLACE FUNCTION internal.food_set_scheduled_order(p_order_id uuid,p_scheduled_for timestamptz) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN RAISE EXCEPTION 'delivery scheduling is unavailable; use same-day pickup slots'; END $$;
notify pgrst, 'reload schema';
commit;
