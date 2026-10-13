-- Additive development rollout. Existing v1/v2 quote/create RPCs stay intact.
-- Flags are OFF and developer-only by default. No cron, payment call or payout.
-- Offline migration filename: Supabase CLI could not start in this executor.
begin;

create table if not exists public.food_development_features (
  name text primary key,
  enabled boolean not null default false,
  developer_only boolean not null default true
);
alter table public.food_development_features enable row level security;
revoke all on public.food_development_features from public, anon, authenticated;
insert into public.food_development_features(name) values ('checkout_v3'),('small_order_fee'),('menu_min_select')
on conflict do nothing;

create or replace function internal.food_development_feature_enabled(p_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select f.enabled and (not f.developer_only or public.is_developer_account())
    from public.food_development_features f where f.name = p_name), false);
$$;
revoke all on function internal.food_development_feature_enabled(text) from public, anon, authenticated;

create or replace function public.food_checkout_features()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  return jsonb_build_object('checkout_v3', internal.food_development_feature_enabled('checkout_v3'),
    'small_order_fee', internal.food_development_feature_enabled('small_order_fee'),
    'menu_min_select', internal.food_development_feature_enabled('menu_min_select'));
end;
$$;
revoke all on function public.food_checkout_features() from public, anon;
grant execute on function public.food_checkout_features() to authenticated;

alter table public.food_orders add column if not exists small_order_fee numeric(10,2) not null default 0;
alter table public.food_orders add column if not exists pricing_rule_version text;
do $$ begin
  if not exists(select 1 from pg_constraint where conrelid='public.food_orders'::regclass and conname='food_small_order_fee_rule') then
    alter table public.food_orders add constraint food_small_order_fee_rule check (small_order_fee in (0,15));
  end if;
end $$;

-- No client amount determines the fee. Promotions use the existing resolver;
-- the fee is applied after discounts, from FOOD SUBTOTAL BEFORE discounts only.
create or replace function internal.food_small_order_fee(p_subtotal numeric)
returns numeric language plpgsql immutable set search_path = '' as $$
begin
  if p_subtotal is null or p_subtotal < 0 or p_subtotal::text in ('NaN','Infinity','-Infinity') then
    raise exception 'invalid food subtotal';
  end if;
  return case when p_subtotal < 60 then 15 else 0 end;
end;
$$;
revoke all on function internal.food_small_order_fee(numeric) from public, anon, authenticated;

-- Snapshot at INSERT so receipts, GP and notification triggers all see the
-- same final total, rather than correcting a notified total afterwards.
create or replace function internal.food_checkout_fee_snapshot()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('wyn.food_checkout_v3',true) = '1'
     and internal.food_development_feature_enabled('checkout_v3') then
    new.small_order_fee := case when internal.food_development_feature_enabled('small_order_fee')
      then internal.food_small_order_fee(new.subtotal) else 0 end;
    new.total := new.total + new.small_order_fee;
    new.pricing_rule_version := 'food_checkout_v3';
  else
    new.small_order_fee := 0;
    new.pricing_rule_version := null;
  end if;
  return new;
end;
$$;
revoke all on function internal.food_checkout_fee_snapshot() from public,anon,authenticated;
drop trigger if exists food_orders_checkout_fee_snapshot on public.food_orders;
create trigger food_orders_checkout_fee_snapshot before insert on public.food_orders
for each row execute function internal.food_checkout_fee_snapshot();

create table if not exists public.food_checkout_requests (
  buyer_id uuid not null,
  idempotency_key uuid not null,
  request_fingerprint text not null check (request_fingerprint ~ '^[0-9a-f]{64}$'),
  order_id uuid not null references public.food_orders(id),
  created_at timestamptz not null default now(),
  primary key (buyer_id,idempotency_key)
);
alter table public.food_checkout_requests enable row level security;
revoke all on public.food_checkout_requests from public, anon, authenticated;

-- Resolve a lost response without exposing another buyer's order. Share the
-- create lock so an in-flight commit settles before a retry checks its result.
create or replace function public.food_resolve_checkout_request(p_idempotency_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_buyer uuid:=auth.uid(); v_order uuid;
begin
  if v_buyer is null or p_idempotency_key is null then raise exception 'authentication_required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_buyer::text||':'||p_idempotency_key::text,0));
  select order_id into v_order from public.food_checkout_requests
    where buyer_id=v_buyer and idempotency_key=p_idempotency_key;
  return v_order;
end;
$$;
revoke all on function public.food_resolve_checkout_request(uuid) from public,anon;
grant execute on function public.food_resolve_checkout_request(uuid) to authenticated;

create or replace function public.food_quote_order_v3(
  p_store_id uuid, p_items jsonb, p_latitude double precision default null,
  p_longitude double precision default null, p_coupon_code text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_quote jsonb; v_fee numeric := 0;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not internal.food_development_feature_enabled('checkout_v3') then raise exception 'food_feature_disabled'; end if;
  v_quote := public.food_quote_order_v2(p_store_id,p_items,p_latitude,p_longitude,p_coupon_code);
  if internal.food_development_feature_enabled('small_order_fee') then
    v_fee := internal.food_small_order_fee((v_quote->>'subtotal')::numeric);
  end if;
  return v_quote || jsonb_build_object('small_order_fee',v_fee,
    'total',(v_quote->>'total')::numeric+v_fee, 'pricing_rule_version','food_checkout_v3');
end;
$$;

create or replace function public.food_create_order_v3(
  p_store_id uuid,p_recipient_name text,p_recipient_phone text,p_shipping_address text,
  p_customer_note text,p_items jsonb,p_idempotency_key uuid,
  p_latitude double precision default null,p_longitude double precision default null,
  p_coupon_code text default null,p_expected_total numeric default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_buyer uuid := auth.uid(); v_request jsonb; v_fingerprint text; v_existing public.food_checkout_requests%rowtype;
  v_order uuid; v_total numeric; v_fee numeric := 0; v_previous_context text;
begin
  if v_buyer is null or not public.food_is_permanent_account() then raise exception 'authentication_required'; end if;
  if p_idempotency_key is null then raise exception 'idempotency_key_required'; end if;
  if not internal.food_development_feature_enabled('checkout_v3') then raise exception 'food_feature_disabled'; end if;
  -- Serialize BEFORE invoking legacy create: retries never reserve stock or
  -- redeem campaigns twice. The row and order commit in the same transaction.
  perform pg_advisory_xact_lock(hashtextextended(v_buyer::text||':'||p_idempotency_key::text,0));
  v_request := jsonb_build_object('store',p_store_id,'recipient',p_recipient_name,'phone',p_recipient_phone,
    'address',p_shipping_address,'note',coalesce(p_customer_note,''),'items',p_items,
    'lat',p_latitude,'lng',p_longitude,'coupon',upper(btrim(coalesce(p_coupon_code,''))),'expected_total',p_expected_total);
  v_fingerprint := encode(sha256(convert_to(v_request::text,'UTF8')),'hex');
  select * into v_existing from public.food_checkout_requests
    where buyer_id=v_buyer and idempotency_key=p_idempotency_key;
  if found then
    if v_existing.request_fingerprint is distinct from v_fingerprint then raise exception 'idempotency_key_conflict'; end if;
    return v_existing.order_id;
  end if;
  v_previous_context := current_setting('wyn.food_checkout_v3',true);
  perform set_config('wyn.food_checkout_v3','1',true);
  v_order := public.food_create_order_v2(p_store_id,p_recipient_name,p_recipient_phone,
    p_shipping_address,p_customer_note,p_items,p_latitude,p_longitude,p_coupon_code);
  perform set_config('wyn.food_checkout_v3',coalesce(v_previous_context,''),true);
  select total,small_order_fee into strict v_total,v_fee from public.food_orders where id=v_order for update;
  if p_expected_total is not null and (p_expected_total::text in ('NaN','Infinity','-Infinity') or p_expected_total <> v_total) then
    raise exception 'food_quote_changed'; -- rolls back ALL stock/coupon/order changes
  end if;
  insert into public.food_checkout_requests(buyer_id,idempotency_key,request_fingerprint,order_id)
    values(v_buyer,p_idempotency_key,v_fingerprint,v_order);
  insert into public.food_order_events(order_id,event_type,note,actor_id)
    values(v_order,'pricing_snapshot','food_checkout_v3; small_order_fee='||v_fee::text,v_buyer);
  return v_order;
end;
$$;
revoke all on function public.food_quote_order_v3(uuid,jsonb,double precision,double precision,text) from public,anon;
revoke all on function public.food_create_order_v3(uuid,text,text,text,text,jsonb,uuid,double precision,double precision,text,numeric) from public,anon;
grant execute on function public.food_quote_order_v3(uuid,jsonb,double precision,double precision,text) to authenticated;
grant execute on function public.food_create_order_v3(uuid,text,text,text,text,jsonb,uuid,double precision,double precision,text,numeric) to authenticated;
commit;
