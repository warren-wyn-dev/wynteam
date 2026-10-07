-- WYNOS Finance Control Center runtime engine.
-- Depends on migrations_wynos_finance_control_center_v1.sql.

alter table public.food_order_financials
  add column if not exists campaign_discount_satang bigint not null default 0,
  add column if not exists delivery_discount_satang bigint not null default 0;

alter table public.food_order_campaigns
  add column if not exists funding_model text,
  add column if not exists merchant_funded_satang bigint,
  add column if not exists platform_funded_satang bigint,
  add column if not exists delivery_subsidy_satang bigint;

alter table public.food_order_campaigns drop constraint if exists food_order_campaigns_funding_model_check;
alter table public.food_order_campaigns add constraint food_order_campaigns_funding_model_check
  check (funding_model is null or funding_model in ('merchant','wynos','shared','delivery_subsidy','platform_campaign','store_coupon'));

-- ---------------------------------------------------------------------------
-- Effective configuration helpers
-- ---------------------------------------------------------------------------

create or replace function internal.food_finance_config_at(p_at timestamptz default now())
returns public.food_finance_configs
language sql
stable
security definer
set search_path = ''
as $$
  select c
  from public.food_finance_configs c
  where c.effective_from <= coalesce(p_at, now())
  order by c.effective_from desc
  limit 1
$$;

revoke all on function internal.food_finance_config_at(timestamptz) from public, anon, authenticated;

create or replace function internal.food_feature_enabled(p_key text, p_at timestamptz default now())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select f.enabled
    from public.food_feature_flags f
    where f.flag_key = p_key
      and f.effective_from <= coalesce(p_at, now())
    order by f.effective_from desc
    limit 1
  ), false)
$$;

revoke all on function internal.food_feature_enabled(text,timestamptz) from public, anon, authenticated;

create or replace function internal.food_store_finance_override_at(p_store_id uuid, p_at timestamptz default now())
returns public.food_store_finance_overrides
language sql
stable
security definer
set search_path = ''
as $$
  select o
  from public.food_store_finance_overrides o
  where o.store_id = p_store_id
    and o.effective_from <= coalesce(p_at, now())
  order by o.effective_from desc
  limit 1
$$;

revoke all on function internal.food_store_finance_override_at(uuid,timestamptz) from public, anon, authenticated;

create or replace function internal.food_bps_amount(p_amount_satang bigint, p_bps integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case
    when coalesce(p_amount_satang,0) <= 0 or coalesce(p_bps,0) <= 0 then 0::bigint
    else ((p_amount_satang * p_bps::bigint) + 5000) / 10000
  end
$$;

revoke all on function internal.food_bps_amount(bigint,integer) from public, anon, authenticated;

create or replace function internal.food_effective_gp(
  p_store_id uuid,
  p_at timestamptz default now()
)
returns table(
  gp_bps integer,
  gp_source text,
  config_id uuid,
  override_id uuid,
  promotion_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.food_finance_configs%rowtype;
  o public.food_store_finance_overrides%rowtype;
  p public.food_store_gp_promotions%rowtype;
begin
  c := internal.food_finance_config_at(p_at);
  if c.id is null then raise exception 'finance configuration missing'; end if;
  o := internal.food_store_finance_override_at(p_store_id,p_at);

  select * into p
  from public.food_store_gp_promotions g
  where g.store_id=p_store_id
    and g.active
    and g.starts_at <= coalesce(p_at,now())
    and g.ends_at > coalesce(p_at,now())
  order by g.starts_at desc, g.created_at desc
  limit 1;

  if p.id is not null then
    return query select p.gp_bps,'promotion'::text,c.id,o.id,p.id;
  elsif o.id is not null and o.custom_gp_bps is not null then
    return query select o.custom_gp_bps,'custom'::text,c.id,o.id,null::uuid;
  else
    return query select c.default_gp_bps,'default'::text,c.id,o.id,null::uuid;
  end if;
end;
$$;

revoke all on function internal.food_effective_gp(uuid,timestamptz) from public, anon, authenticated;

create or replace function internal.food_service_area_code(p_lat double precision, p_lng double precision)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select a.code
  from public.food_service_areas a
  where a.active
    and p_lat is not null and p_lng is not null
    and p_lat between a.min_lat and a.max_lat
    and p_lng between a.min_lng and a.max_lng
    and internal.food_point_in_polygon(p_lat,p_lng,a.lats,a.lngs)
  order by a.code
  limit 1
$$;

revoke all on function internal.food_service_area_code(double precision,double precision) from public, anon, authenticated;

create or replace function internal.food_delivery_free_threshold(
  p_store_id uuid,
  p_at timestamptz default now()
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.food_finance_configs%rowtype;
  o public.food_store_finance_overrides%rowtype;
begin
  c := internal.food_finance_config_at(p_at);
  o := internal.food_store_finance_override_at(p_store_id,p_at);
  return coalesce(o.free_delivery_threshold_satang,c.free_delivery_threshold_satang);
end;
$$;

revoke all on function internal.food_delivery_free_threshold(uuid,timestamptz) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Delivery pricing: store override > service-area/zone rule > platform config.
-- Existing radius/service-area safety remains unchanged.
-- ---------------------------------------------------------------------------

create or replace function internal.food_delivery_fee(
  p_store_id uuid,
  p_latitude double precision,
  p_longitude double precision
)
returns table(distance_km numeric, delivery_fee numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s public.food_stores%rowtype;
  c public.food_finance_configs%rowtype;
  o public.food_store_finance_overrides%rowtype;
  z public.food_delivery_zone_pricing%rowtype;
  v_distance numeric;
  v_distance_m integer;
  v_base bigint;
  v_base_m integer;
  v_per_km bigint;
  v_min bigint;
  v_max bigint;
  v_round_m integer;
  v_extra_m integer;
  v_billable_m integer;
  v_fee bigint;
  v_area text;
  v_developer boolean := exists (
    select 1 from public.developer_accounts d where d.user_id=(select auth.uid())
  );
begin
  select * into s from public.food_stores where id=p_store_id;
  if not found then raise exception 'store is not accepting orders'; end if;

  if not v_developer and not internal.food_in_service_area(s.latitude,s.longitude) then
    raise exception 'store is outside the service area';
  end if;

  c := internal.food_finance_config_at(now());
  if c.id is null then raise exception 'finance configuration missing'; end if;
  o := internal.food_store_finance_override_at(p_store_id,now());

  if p_latitude is not null and p_longitude is not null then
    v_area := internal.food_service_area_code(p_latitude,p_longitude);
    select * into z
    from public.food_delivery_zone_pricing r
    where r.effective_from <= now()
      and (r.effective_to is null or r.effective_to > now())
      and r.service_area_code is not distinct from v_area
    order by r.priority asc,r.effective_from desc
    limit 1;
  end if;

  v_base := coalesce(o.delivery_base_fee_satang,z.base_fee_satang,c.delivery_base_fee_satang);
  v_base_m := coalesce(o.delivery_base_distance_m,z.base_distance_m,c.delivery_base_distance_m);
  v_per_km := coalesce(o.delivery_per_km_satang,z.per_km_satang,c.delivery_per_km_satang);
  v_min := coalesce(o.delivery_min_fee_satang,z.min_fee_satang,c.delivery_min_fee_satang,0);
  v_max := coalesce(o.delivery_max_fee_satang,z.max_fee_satang,c.delivery_max_fee_satang);
  v_round_m := greatest(1,coalesce(o.delivery_rounding_m,z.rounding_m,c.delivery_rounding_m,1000));

  if s.latitude is null then
    v_fee := greatest(v_base,v_min);
    if v_max is not null then v_fee := least(v_fee,v_max); end if;
    return query select null::numeric,(v_fee::numeric/100);
    return;
  end if;

  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'delivery location required';
  end if;
  if not v_developer and not internal.food_in_service_area(p_latitude,p_longitude) then
    raise exception 'outside service area';
  end if;

  v_distance := internal.food_distance_km(s.latitude,s.longitude,p_latitude,p_longitude);
  if v_distance > s.delivery_radius_km then raise exception 'outside delivery area'; end if;

  v_distance_m := greatest(0,round(v_distance*1000)::integer);
  v_extra_m := greatest(v_distance_m-v_base_m,0);
  v_billable_m := case
    when v_extra_m=0 then 0
    else ((v_extra_m+v_round_m-1)/v_round_m)*v_round_m
  end;
  v_fee := v_base + ((v_billable_m::bigint*v_per_km)+999)/1000;

  if internal.food_feature_enabled('peak_pricing_enabled',now()) then
    v_fee := v_fee + c.peak_surcharge_satang;
  end if;
  if internal.food_feature_enabled('rain_surcharge_enabled',now()) then
    v_fee := v_fee + c.rain_surcharge_satang;
  end if;
  if c.long_distance_threshold_m is not null and v_distance_m > c.long_distance_threshold_m then
    v_fee := v_fee + c.long_distance_surcharge_satang;
  end if;

  v_fee := greatest(v_fee,v_min);
  if v_max is not null then v_fee := least(v_fee,v_max); end if;

  return query select v_distance,(v_fee::numeric/100);
end;
$$;

revoke all on function internal.food_delivery_fee(uuid,double precision,double precision) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Customer/rider fee helpers
-- ---------------------------------------------------------------------------

create or replace function internal.food_customer_fee_components(
  p_subtotal_satang bigint,
  p_delivery_satang bigint,
  p_store_id uuid,
  p_at timestamptz
)
returns table(service_fee_satang bigint,small_order_fee_satang bigint,surge_fee_satang bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.food_finance_configs%rowtype;
  v_service bigint := 0;
  v_small bigint := 0;
  v_surge bigint := 0;
begin
  c := internal.food_finance_config_at(p_at);
  if c.id is null then raise exception 'finance configuration missing'; end if;

  if internal.food_feature_enabled('service_fee_enabled',p_at) then
    v_service := case when c.service_fee_mode='percent'
      then internal.food_bps_amount(p_subtotal_satang,least(c.service_fee_value,10000)::integer)
      else c.service_fee_value end;
    v_service := greatest(v_service,c.service_fee_min_satang);
    if c.service_fee_max_satang is not null then v_service:=least(v_service,c.service_fee_max_satang); end if;
  end if;

  if internal.food_feature_enabled('small_order_fee_enabled',p_at)
     and p_subtotal_satang < c.small_order_threshold_satang then
    v_small := case when c.small_order_fee_mode='percent'
      then internal.food_bps_amount(p_subtotal_satang,least(c.small_order_fee_value,10000)::integer)
      else c.small_order_fee_value end;
    if c.small_order_fee_max_satang is not null then v_small:=least(v_small,c.small_order_fee_max_satang); end if;
  end if;

  if internal.food_feature_enabled('surge_pricing_enabled',p_at) then
    v_surge := case when c.surge_fee_mode='percent'
      then internal.food_bps_amount(p_subtotal_satang+p_delivery_satang,least(c.surge_fee_value,10000)::integer)
      else c.surge_fee_value end;
    if c.surge_fee_max_satang is not null then v_surge:=least(v_surge,c.surge_fee_max_satang); end if;
  end if;

  return query select v_service,v_small,v_surge;
end;
$$;

revoke all on function internal.food_customer_fee_components(bigint,bigint,uuid,timestamptz) from public, anon, authenticated;

create or replace function internal.food_rider_earning(
  p_distance_km numeric,
  p_at timestamptz
)
returns table(base_satang bigint,distance_satang bigint,bonus_satang bigint,total_satang bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.food_finance_configs%rowtype;
  v_m integer := greatest(0,round(coalesce(p_distance_km,0)*1000)::integer);
  v_distance bigint;
  v_bonus bigint := 0;
  v_total bigint;
begin
  c := internal.food_finance_config_at(p_at);
  if c.id is null then raise exception 'finance configuration missing'; end if;

  v_distance := ((v_m::bigint*c.rider_pay_per_km_satang)+999)/1000;
  if c.rider_long_distance_threshold_m is not null and v_m > c.rider_long_distance_threshold_m then
    v_bonus:=v_bonus+c.rider_long_distance_bonus_satang;
  end if;
  if internal.food_feature_enabled('peak_pricing_enabled',p_at) then v_bonus:=v_bonus+c.rider_peak_bonus_satang; end if;
  if internal.food_feature_enabled('rain_surcharge_enabled',p_at) then v_bonus:=v_bonus+c.rider_rain_bonus_satang; end if;

  v_total:=greatest(c.rider_base_pay_satang+v_distance+v_bonus,c.rider_min_earning_satang);
  return query select c.rider_base_pay_satang,v_distance,v_bonus,v_total;
end;
$$;

revoke all on function internal.food_rider_earning(numeric,timestamptz) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Promotion gate and free-delivery threshold integrated before campaign choice.
-- ---------------------------------------------------------------------------

create or replace function internal.food_campaign_candidates(
  p_store_id uuid,
  p_subtotal numeric,
  p_delivery_fee numeric,
  p_item_totals jsonb
)
returns table(campaign_id uuid,campaign_name text,campaign_type text,campaign_discount numeric,delivery_discount numeric,saving numeric)
language sql
stable
security definer
set search_path = ''
as $$
  with gate as (
    select internal.food_feature_enabled('promotion_enabled',now()) as enabled,
           internal.food_delivery_free_threshold(p_store_id,now()) as free_threshold
  ),
  effective as (
    select case
      when g.free_threshold is not null and round(greatest(coalesce(p_subtotal,0),0)*100)::bigint >= g.free_threshold
        then 0::numeric
      else greatest(coalesce(p_delivery_fee,0),0)
    end as delivery_fee
    from gate g
  ),
  base as (
    select c.id,c.name,c.campaign_type,c.discount_value,c.max_discount,c.scope,
      case when c.scope='store' then greatest(coalesce(p_subtotal,0),0)
           else greatest(coalesce(scoped.item_subtotal,0),0) end as eligible_subtotal
    from public.food_campaigns c
    cross join gate g
    left join lateral (
      select coalesce(sum((e.value)::numeric),0) as item_subtotal
      from jsonb_each_text(coalesce(p_item_totals,'{}'::jsonb)) as e(key,value)
      join public.food_campaign_items ci
        on ci.campaign_id=c.id and ci.menu_item_id=(e.key)::uuid
    ) scoped on true
    left join public.food_store_finance_overrides o on o.id=(
      select oo.id from public.food_store_finance_overrides oo
      where oo.store_id=p_store_id and oo.effective_from<=now()
      order by oo.effective_from desc limit 1
    )
    where g.enabled
      and coalesce(o.promotion_eligible,true)
      and c.store_id=p_store_id
      and c.deleted_at is null and c.is_active
      and c.starts_at<=now() and (c.ends_at is null or c.ends_at>now())
      and (c.usage_limit is null or c.usage_count<c.usage_limit)
      and greatest(coalesce(p_subtotal,0),0)>=c.min_subtotal
  ),
  calc as (
    select id,name,campaign_type,
      case
        when campaign_type='percentage' and eligible_subtotal>0 then
          round(least(eligible_subtotal*discount_value/100,
                      coalesce(max_discount,eligible_subtotal*discount_value/100),
                      eligible_subtotal),2)
        when campaign_type='fixed' and eligible_subtotal>0 then round(least(discount_value,eligible_subtotal),2)
        else 0::numeric end as campaign_discount,
      case when campaign_type='free_delivery' then round((select delivery_fee from effective),2)
           else 0::numeric end as delivery_discount
    from base
  )
  select id,name,campaign_type,campaign_discount,delivery_discount,campaign_discount+delivery_discount
  from calc
  where campaign_discount+delivery_discount>0
  order by campaign_discount+delivery_discount desc,id
$$;

revoke all on function internal.food_campaign_candidates(uuid,numeric,numeric,jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Apply customer fees and freeze config ID on every newly-created order,
-- regardless of which server-side order creator inserted it.
-- ---------------------------------------------------------------------------

create or replace function internal.food_apply_order_financial_pricing()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.food_finance_configs%rowtype;
  f record;
  v_subtotal bigint;
  v_delivery bigint;
  v_campaign bigint;
  v_delivery_discount bigint;
  v_threshold bigint;
  v_total bigint;
begin
  c := internal.food_finance_config_at(coalesce(new.created_at,now()));
  if c.id is null then raise exception 'finance configuration missing'; end if;

  new.finance_config_id:=c.id;
  v_subtotal:=round(greatest(coalesce(new.subtotal,0),0)*100)::bigint;
  v_delivery:=round(greatest(coalesce(new.delivery_fee,0),0)*100)::bigint;
  v_campaign:=round(greatest(coalesce(new.campaign_discount,0),0)*100)::bigint;
  v_delivery_discount:=round(greatest(coalesce(new.delivery_discount,0),0)*100)::bigint;

  v_threshold:=internal.food_delivery_free_threshold(new.store_id,coalesce(new.created_at,now()));
  if v_threshold is not null and v_subtotal>=v_threshold then
    v_delivery:=0;
    new.delivery_fee:=0;
    v_delivery_discount:=0;
    new.delivery_discount:=0;
  end if;

  select * into f from internal.food_customer_fee_components(
    v_subtotal,v_delivery,new.store_id,coalesce(new.created_at,now())
  );

  new.service_fee:=f.service_fee_satang::numeric/100;
  new.small_order_fee:=f.small_order_fee_satang::numeric/100;
  new.surge_fee:=f.surge_fee_satang::numeric/100;

  v_total:=greatest(
    v_subtotal-v_campaign-v_delivery_discount+v_delivery+
    f.service_fee_satang+f.small_order_fee_satang+f.surge_fee_satang,
    0
  );
  new.total:=v_total::numeric/100;
  return new;
end;
$$;

revoke all on function internal.food_apply_order_financial_pricing() from public, anon, authenticated;

drop trigger if exists food_orders_financial_pricing on public.food_orders;
create trigger food_orders_financial_pricing
before insert on public.food_orders
for each row execute function internal.food_apply_order_financial_pricing();

create or replace function internal.food_recompute_order_financials(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  f public.food_order_financials%rowtype;
  v_merchant bigint;
  v_platform bigint;
begin
  select * into f from public.food_order_financials where order_id=p_order_id for update;
  if not found then return; end if;

  v_merchant :=
    f.subtotal_satang
    - f.merchant_discount_satang
    - f.gp_amount_satang
    + f.gp_refunded_satang
    - f.stripe_fee_merchant_satang
    - f.merchant_refund_cost_satang
    + f.merchant_adjustment_satang;

  v_platform :=
    f.gp_amount_satang
    - f.gp_refunded_satang
    + f.service_fee_satang
    + f.small_order_fee_satang
    + f.surge_fee_satang
    + f.delivery_fee_satang
    - f.rider_earning_satang
    - f.platform_discount_satang
    - f.stripe_fee_platform_satang
    - f.platform_refund_cost_satang
    + f.platform_adjustment_satang;

  update public.food_order_financials
  set merchant_net_satang=v_merchant,
      platform_revenue_satang=v_platform,
      updated_at=now()
  where order_id=p_order_id;
end;
$$;

revoke all on function internal.food_recompute_order_financials(uuid) from public, anon, authenticated;

create or replace function internal.food_snapshot_order_financials()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.food_finance_configs%rowtype;
  g record;
  r record;
  v_subtotal bigint;
  v_delivery bigint;
  v_campaign bigint;
  v_delivery_discount bigint;
  v_customer_discount bigint;
  v_gp bigint;
  v_rider bigint:=0;
  v_rider_bonus bigint:=0;
begin
  select * into c from public.food_finance_configs where id=new.finance_config_id;
  if not found then c:=internal.food_finance_config_at(new.created_at); end if;

  select * into g from internal.food_effective_gp(new.store_id,new.created_at);
  v_subtotal:=round(new.subtotal*100)::bigint;
  v_delivery:=round(new.delivery_fee*100)::bigint;
  v_campaign:=round(new.campaign_discount*100)::bigint;
  v_delivery_discount:=round(new.delivery_discount*100)::bigint;
  v_customer_discount:=v_campaign+v_delivery_discount;
  v_gp:=internal.food_bps_amount(v_subtotal,g.gp_bps);

  if internal.food_feature_enabled('rider_enabled',new.created_at) then
    select * into r from internal.food_rider_earning(new.delivery_distance_km,new.created_at);
    v_rider:=coalesce(r.total_satang,0);
    v_rider_bonus:=coalesce(r.bonus_satang,0);
  end if;

  insert into public.food_order_financials(
    order_id,store_id,config_id,store_override_id,gp_promotion_id,gp_source,
    subtotal_satang,delivery_fee_satang,service_fee_satang,small_order_fee_satang,surge_fee_satang,
    campaign_discount_satang,delivery_discount_satang,customer_discount_satang,
    merchant_discount_satang,platform_discount_satang,
    gp_bps,gp_amount_satang,rider_earning_satang,rider_bonus_satang,
    stripe_fee_policy,stripe_shared_merchant_bps,
    merchant_net_satang,platform_revenue_satang,customer_total_satang,
    tax_enabled,vat_registered,vat_percent_bps,priced_at
  ) values (
    new.id,new.store_id,c.id,g.override_id,g.promotion_id,g.gp_source,
    v_subtotal,v_delivery,
    round(new.service_fee*100)::bigint,round(new.small_order_fee*100)::bigint,round(new.surge_fee*100)::bigint,
    v_campaign,v_delivery_discount,v_customer_discount,
    v_customer_discount,0,
    g.gp_bps,v_gp,v_rider,v_rider_bonus,
    c.stripe_fee_payer,c.stripe_shared_merchant_bps,
    0,0,round(new.total*100)::bigint,
    c.tax_enabled,c.vat_registered,c.vat_percent_bps,new.created_at
  )
  on conflict (order_id) do nothing;

  perform internal.food_recompute_order_financials(new.id);
  return new;
end;
$$;

revoke all on function internal.food_snapshot_order_financials() from public, anon, authenticated;

drop trigger if exists food_orders_financial_snapshot on public.food_orders;
create trigger food_orders_financial_snapshot
after insert on public.food_orders
for each row execute function internal.food_snapshot_order_financials();

-- Existing campaign trigger computes public.food_order_campaigns.platform_funded.
-- This trigger freezes both sides of discount sharing in integer satang.
create or replace function internal.food_snapshot_campaign_funding()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total bigint;
  v_platform bigint;
  v_merchant bigint;
  v_model text;
begin
  v_total:=round((coalesce(new.campaign_discount,0)+coalesce(new.delivery_discount,0))*100)::bigint;
  v_platform:=least(v_total,greatest(0,round(coalesce(new.platform_funded,0)*100)::bigint));
  v_merchant:=greatest(v_total-v_platform,0);
  v_model:=case when v_platform=0 then 'merchant'
                when v_merchant=0 then 'wynos'
                else 'shared' end;

  update public.food_order_campaigns
  set funding_model=v_model,
      merchant_funded_satang=v_merchant,
      platform_funded_satang=v_platform,
      delivery_subsidy_satang=round(coalesce(new.delivery_discount,0)*100)::bigint
  where order_id=new.order_id;

  update public.food_order_financials
  set customer_discount_satang=v_total,
      merchant_discount_satang=v_merchant,
      platform_discount_satang=v_platform,
      updated_at=now()
  where order_id=new.order_id;

  perform internal.food_recompute_order_financials(new.order_id);
  return new;
end;
$$;

revoke all on function internal.food_snapshot_campaign_funding() from public, anon, authenticated;

drop trigger if exists food_order_campaigns_financial_snapshot on public.food_order_campaigns;
create trigger food_order_campaigns_financial_snapshot
after insert on public.food_order_campaigns
for each row execute function internal.food_snapshot_campaign_funding();

-- ---------------------------------------------------------------------------
-- Financial quote wrapper. Frontends display this; they do not calculate fees.
-- ---------------------------------------------------------------------------

create or replace function public.food_quote_order_financial(
  p_store_id uuid,
  p_items jsonb,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  q jsonb;
  f record;
  v_subtotal bigint;
  v_delivery bigint;
  v_campaign bigint;
  v_delivery_discount bigint;
  v_threshold bigint;
  v_total bigint;
begin
  q:=public.food_quote_order(p_store_id,p_items,p_latitude,p_longitude);
  v_subtotal:=round(coalesce((q->>'subtotal')::numeric,0)*100)::bigint;
  v_delivery:=round(coalesce((q->>'delivery_fee')::numeric,0)*100)::bigint;
  v_campaign:=round(coalesce((q->>'campaign_discount')::numeric,0)*100)::bigint;
  v_delivery_discount:=round(coalesce((q->>'delivery_discount')::numeric,0)*100)::bigint;

  v_threshold:=internal.food_delivery_free_threshold(p_store_id,now());
  if v_threshold is not null and v_subtotal>=v_threshold then
    v_delivery:=0;
    v_delivery_discount:=0;
  end if;

  select * into f from internal.food_customer_fee_components(v_subtotal,v_delivery,p_store_id,now());
  v_total:=greatest(v_subtotal-v_campaign-v_delivery_discount+v_delivery+
                    f.service_fee_satang+f.small_order_fee_satang+f.surge_fee_satang,0);

  return q || jsonb_build_object(
    'delivery_fee',v_delivery::numeric/100,
    'delivery_discount',v_delivery_discount::numeric/100,
    'service_fee',f.service_fee_satang::numeric/100,
    'small_order_fee',f.small_order_fee_satang::numeric/100,
    'surge_fee',f.surge_fee_satang::numeric/100,
    'total',v_total::numeric/100
  );
end;
$$;

revoke all on function public.food_quote_order_financial(uuid,jsonb,double precision,double precision) from public, anon;
grant execute on function public.food_quote_order_financial(uuid,jsonb,double precision,double precision) to authenticated;

create or replace function public.food_payment_configuration()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.food_finance_configs%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  c:=internal.food_finance_config_at(now());
  return jsonb_build_object(
    'promptpay_enabled',internal.food_feature_enabled('promptpay_enabled',now()),
    'card_enabled',internal.food_feature_enabled('card_enabled',now()),
    'apple_pay_enabled',internal.food_feature_enabled('apple_pay_enabled',now()),
    'google_pay_enabled',internal.food_feature_enabled('google_pay_enabled',now()),
    'stripe_fee_payer',c.stripe_fee_payer,
    'config_id',c.id
  );
end;
$$;

revoke all on function public.food_payment_configuration() from public, anon;
grant execute on function public.food_payment_configuration() to authenticated;

-- ---------------------------------------------------------------------------
-- Payment enrichment: actual Stripe fee is authoritative when available.
-- ---------------------------------------------------------------------------

create or replace function public.food_record_stripe_fee(
  p_order_id uuid,
  p_stripe_account_id text,
  p_fee_satang bigint,
  p_balance_transaction_id text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.food_stripe_payments%rowtype;
  f public.food_order_financials%rowtype;
  v_merchant bigint;
  v_platform bigint;
begin
  if current_user <> 'service_role' then raise exception 'service role required'; end if;
  if p_fee_satang is null or p_fee_satang<0 then raise exception 'invalid Stripe fee'; end if;

  select * into p from public.food_stripe_payments where order_id=p_order_id for update;
  if not found or p.stripe_account_id is distinct from p_stripe_account_id then
    raise exception 'original Stripe account mismatch';
  end if;
  select * into f from public.food_order_financials where order_id=p_order_id for update;
  if not found then raise exception 'financial snapshot missing'; end if;

  if f.stripe_fee_policy='merchant' then
    v_merchant:=p_fee_satang; v_platform:=0;
  elsif f.stripe_fee_policy='shared' then
    v_merchant:=internal.food_bps_amount(p_fee_satang,f.stripe_shared_merchant_bps);
    v_platform:=p_fee_satang-v_merchant;
  else
    v_merchant:=0; v_platform:=p_fee_satang;
  end if;

  update public.food_stripe_payments
  set gross_amount_satang=coalesce(gross_amount_satang,amount_satang),
      stripe_fee_satang=p_fee_satang,
      stripe_fee_merchant_satang=v_merchant,
      stripe_fee_platform_satang=v_platform,
      platform_fee_satang=f.gp_amount_satang,
      stripe_fee_policy=f.stripe_fee_policy,
      balance_transaction_id=coalesce(p_balance_transaction_id,balance_transaction_id),
      updated_at=now()
  where order_id=p_order_id;

  update public.food_order_financials
  set stripe_fee_satang=p_fee_satang,
      stripe_fee_merchant_satang=v_merchant,
      stripe_fee_platform_satang=v_platform,
      updated_at=now()
  where order_id=p_order_id;

  perform internal.food_recompute_order_financials(p_order_id);

  update public.food_stripe_payments p2
  set merchant_net_satang=f2.merchant_net_satang,
      platform_fee_satang=f2.gp_amount_satang,
      updated_at=now()
  from public.food_order_financials f2
  where p2.order_id=p_order_id and f2.order_id=p_order_id;
end;
$$;

revoke all on function public.food_record_stripe_fee(uuid,text,bigint,text) from public, anon, authenticated;
grant execute on function public.food_record_stripe_fee(uuid,text,bigint,text) to service_role;

-- ---------------------------------------------------------------------------
-- Refund request/result ledger. New refunds are pinned to original payment.
-- ---------------------------------------------------------------------------

create or replace function public.food_create_refund_request(
  p_order_id uuid,
  p_amount_satang bigint,
  p_reason text,
  p_liability text,
  p_refund_gp boolean,
  p_refund_delivery boolean,
  p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.food_orders%rowtype;
  p public.food_stripe_payments%rowtype;
  f public.food_order_financials%rowtype;
  v_id uuid;
  v_total_refunded bigint;
  v_merchant bigint;
  v_platform bigint;
  v_gp bigint;
  v_delivery bigint;
begin
  if current_user <> 'service_role' then raise exception 'service role required'; end if;
  select * into o from public.food_orders where id=p_order_id for update;
  select * into p from public.food_stripe_payments where order_id=p_order_id for update;
  select * into f from public.food_order_financials where order_id=p_order_id for update;
  if o.id is null or p.order_id is null or f.order_id is null then raise exception 'payment snapshot missing'; end if;
  if p.stripe_account_id is null or p.payment_intent_id is null then raise exception 'original Stripe payment identity missing'; end if;
  if p_amount_satang is null or p_amount_satang<=0 then raise exception 'invalid refund amount'; end if;

  select coalesce(sum(r.amount_satang),0) into v_total_refunded
  from public.food_refunds r
  where r.order_id=p_order_id and r.status in ('pending','succeeded');

  if v_total_refunded+p_amount_satang>f.customer_total_satang then raise exception 'refund exceeds payment'; end if;
  if p_liability not in ('wynos','merchant','shared') then raise exception 'invalid refund liability'; end if;
  if coalesce(length(btrim(p_reason)),0)=0 then raise exception 'refund reason required'; end if;

  if p_liability='merchant' then
    v_merchant:=p_amount_satang; v_platform:=0;
  elsif p_liability='shared' then
    v_merchant:=p_amount_satang/2; v_platform:=p_amount_satang-v_merchant;
  else
    v_merchant:=0; v_platform:=p_amount_satang;
  end if;

  v_gp:=case when p_refund_gp then least(
    f.gp_amount_satang-f.gp_refunded_satang,
    internal.food_bps_amount(p_amount_satang,f.gp_bps)
  ) else 0 end;
  v_delivery:=case when p_refund_delivery then least(f.delivery_fee_satang,p_amount_satang) else 0 end;

  insert into public.food_refunds(
    order_id,store_id,stripe_account_id,payment_intent_id,idempotency_key,
    amount_satang,currency,status,reason,liability,
    merchant_liability_satang,platform_liability_satang,
    refund_gp,gp_refund_satang,refund_delivery,delivery_refund_satang,
    livemode
  ) values (
    o.id,o.store_id,p.stripe_account_id,p.payment_intent_id,left(p_idempotency_key,160),
    p_amount_satang,p.currency,'pending',left(btrim(p_reason),500),p_liability,
    v_merchant,v_platform,
    p_refund_gp,v_gp,p_refund_delivery,v_delivery,
    p.livemode
  )
  on conflict (idempotency_key) do update set idempotency_key=excluded.idempotency_key
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.food_create_refund_request(uuid,bigint,text,text,boolean,boolean,text) from public, anon, authenticated;
grant execute on function public.food_create_refund_request(uuid,bigint,text,text,boolean,boolean,text) to service_role;

create or replace function public.food_apply_refund_result(
  p_refund_id uuid,
  p_stripe_refund_id text,
  p_status text,
  p_stripe_refund_fee_satang bigint default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.food_refunds%rowtype;
  v_merchant bigint;
  v_platform bigint;
  v_gp bigint;
begin
  if current_user <> 'service_role' then raise exception 'service role required'; end if;
  if p_status not in ('succeeded','failed','cancelled') then raise exception 'invalid refund status'; end if;

  select * into r from public.food_refunds where id=p_refund_id for update;
  if not found then raise exception 'refund request not found'; end if;
  if r.status='succeeded' then return; end if;

  update public.food_refunds
  set stripe_refund_id=coalesce(p_stripe_refund_id,stripe_refund_id),
      status=p_status,
      stripe_refund_fee_satang=coalesce(p_stripe_refund_fee_satang,stripe_refund_fee_satang),
      updated_at=now()
  where id=p_refund_id;

  if p_status='succeeded' then
    select coalesce(sum(merchant_liability_satang),0),
           coalesce(sum(platform_liability_satang),0),
           coalesce(sum(gp_refund_satang),0)
      into v_merchant,v_platform,v_gp
    from public.food_refunds
    where order_id=r.order_id and status='succeeded';

    update public.food_order_financials
    set merchant_refund_cost_satang=v_merchant,
        platform_refund_cost_satang=v_platform,
        gp_refunded_satang=v_gp,
        updated_at=now()
    where order_id=r.order_id;

    perform internal.food_recompute_order_financials(r.order_id);

    update public.food_orders
    set refund_status=case
          when (select coalesce(sum(amount_satang),0) from public.food_refunds where order_id=r.order_id and status='succeeded')
               >= (select customer_total_satang from public.food_order_financials where order_id=r.order_id)
          then 'refunded' else 'partial' end,
        refunded_at=case
          when (select coalesce(sum(amount_satang),0) from public.food_refunds where order_id=r.order_id and status='succeeded')
               >= (select customer_total_satang from public.food_order_financials where order_id=r.order_id)
          then coalesce(refunded_at,now()) else refunded_at end
    where id=r.order_id;
  end if;
end;
$$;

revoke all on function public.food_apply_refund_result(uuid,text,text,bigint) from public, anon, authenticated;
grant execute on function public.food_apply_refund_result(uuid,text,text,bigint) to service_role;

-- Existing order refund constraint may not know the new partial state.
alter table public.food_orders drop constraint if exists food_orders_refund_status_check;
alter table public.food_orders add constraint food_orders_refund_status_check
  check (refund_status in ('none','pending','failed','partial','refunded'));

-- ---------------------------------------------------------------------------
-- Safe payment configuration and financial breakdown for Merchant.
-- ---------------------------------------------------------------------------

create or replace function public.merchant_order_financial_breakdown(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  o public.food_orders%rowtype;
  f public.food_order_financials%rowtype;
begin
  select * into o from public.food_orders where id=p_order_id;
  if not found or not public.food_has_merchant_access(o.store_id) then raise exception 'order not found'; end if;
  select * into f from public.food_order_financials where order_id=p_order_id;
  if not found then return null; end if;
  return jsonb_build_object(
    'order_id',o.id,'order_number',o.order_number,
    'gross_sales_satang',f.subtotal_satang,
    'merchant_discount_satang',f.merchant_discount_satang,
    'gp_bps',f.gp_bps,'gp_satang',f.gp_amount_satang,
    'payment_fees_satang',f.stripe_fee_merchant_satang,
    'refunds_satang',f.merchant_refund_cost_satang,
    'adjustments_satang',f.merchant_adjustment_satang,
    'net_satang',f.merchant_net_satang,
    'currency',f.currency
  );
end;
$$;

revoke all on function public.merchant_order_financial_breakdown(uuid) from public, anon;
grant execute on function public.merchant_order_financial_breakdown(uuid) to authenticated;
