-- WYNOS Food opt-in coupon layer. Additive: legacy order/quote RPCs and auto campaigns remain intact.
-- Release gate: do not apply until CI and integration tests approve.

alter table public.food_platform_campaigns
  add column if not exists coupon_required boolean not null default false;

create table if not exists public.food_coupon_codes (
  id uuid primary key default gen_random_uuid(),
  platform_campaign_id uuid not null references public.food_platform_campaigns(id) on delete restrict,
  code text not null,
  is_active boolean not null default true,
  max_total_uses integer,
  max_uses_per_user integer not null default 1,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_coupon_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{3,23}$'),
  constraint food_coupon_code_unique unique (code),
  constraint food_coupon_one_code_per_campaign unique (platform_campaign_id),
  constraint food_coupon_total_uses_valid check (max_total_uses is null or max_total_uses > 0),
  constraint food_coupon_per_user_valid check (max_uses_per_user between 1 and 20),
  constraint food_coupon_dates_valid check (ends_at is null or ends_at > starts_at)
);

create table if not exists public.food_coupon_redemptions (
  order_id uuid primary key references public.food_orders(id) on delete restrict,
  coupon_id uuid not null references public.food_coupon_codes(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists food_coupon_redemptions_coupon_idx on public.food_coupon_redemptions(coupon_id, user_id);

-- For quota accounting use the real order state. Timed-out, refunded and cancelled
-- orders no longer consume a coupon without relying on a fragile webhook counter.
create or replace function internal.food_coupon_usage_active(p_order_id uuid)
returns boolean language sql stable set search_path = '' as $fn$
 select exists(
   select 1 from public.food_orders o
   where o.id = p_order_id
     and o.status <> 'cancelled'
     and o.payment_status <> 'refunded'
     and (o.payment_status = 'paid'
          or o.payment_due_at is null
          or o.payment_due_at > now())
 )
$fn$;

create or replace function public.admin_food_issue_coupon(
  p_campaign_id uuid,
  p_code text,
  p_max_total_uses integer default null,
  p_max_uses_per_user integer default 1,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null
) returns uuid language plpgsql security definer set search_path = '' as $fn$
declare
  v_campaign public.food_platform_campaigns%rowtype;
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_id uuid;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage WYNOS Food coupons';
  end if;
  if v_code !~ '^[A-Z0-9][A-Z0-9_-]{3,23}$' then
    raise exception 'invalid_coupon_code';
  end if;
  select * into v_campaign from public.food_platform_campaigns
  where id = p_campaign_id for update;
  if not found then raise exception 'campaign_not_found'; end if;
  if exists(select 1 from public.food_coupon_codes where platform_campaign_id=p_campaign_id) then
    raise exception 'campaign_already_has_coupon';
  end if;
  if exists(
    select 1 from public.food_order_campaigns oc
    where oc.platform_campaign_id=p_campaign_id
  ) then
    raise exception 'cannot_change_campaign_after_orders';
  end if;
  if p_max_total_uses is not null and p_max_total_uses < 1 then
    raise exception 'invalid_usage_limit';
  end if;
  if p_max_uses_per_user not between 1 and 20 then
    raise exception 'invalid_per_user_limit';
  end if;
  -- Set the gate and issue the code in one transaction. Existing campaigns
  -- cannot be retrofitted once orders have already used them.
  update public.food_platform_campaigns
     set coupon_required = true, updated_at = now()
   where id=p_campaign_id;
  insert into public.food_coupon_codes (
    platform_campaign_id,code,max_total_uses,max_uses_per_user,
    starts_at,ends_at,created_by
  ) values (
    p_campaign_id,v_code,p_max_total_uses,p_max_uses_per_user,
    coalesce(p_starts_at,v_campaign.starts_at),coalesce(p_ends_at,v_campaign.ends_at),
    auth.uid()
  ) returning id into v_id;
  return v_id;
end;
$fn$;

create or replace function public.admin_food_coupon_list()
returns jsonb language sql stable security definer set search_path = '' as $fn$
  select case when coalesce(internal.current_platform_role(), '') <> 'admin'
    then '[]'::jsonb
    else coalesce(jsonb_agg(jsonb_build_object(
      'id',c.id,'code',c.code,'campaign_id',c.platform_campaign_id,
      'campaign_name',p.name,'is_active',c.is_active,
      'starts_at',c.starts_at,'ends_at',c.ends_at,
      'max_total_uses',c.max_total_uses,'max_uses_per_user',c.max_uses_per_user,
      'used', (select count(*) from public.food_coupon_redemptions r
               where r.coupon_id=c.id and internal.food_coupon_usage_active(r.order_id))
    ) order by c.created_at desc), '[]'::jsonb)
  end
  from public.food_coupon_codes c
  join public.food_platform_campaigns p on p.id=c.platform_campaign_id
$fn$;

create or replace function public.admin_food_coupon_set_active(p_coupon_id uuid,p_active boolean)
returns void language plpgsql security definer set search_path = '' as $fn$
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage WYNOS Food coupons';
  end if;
  update public.food_coupon_codes
     set is_active=p_active, updated_at=now()
   where id=p_coupon_id;
  if not found then raise exception 'coupon_not_found'; end if;
end;
$fn$;

-- Preserve the established campaign ranking and price formulas. Only campaigns
-- marked coupon_required require a code. All existing auto campaigns are untouched.
create or replace function internal.food_campaign_candidates(
  p_store_id uuid, p_subtotal numeric, p_delivery_fee numeric, p_item_totals jsonb
)
returns table (
  campaign_id uuid, campaign_name text, campaign_type text,
  campaign_discount numeric, delivery_discount numeric, saving numeric
) language sql stable set search_path = '' as $fn$
  with base as (
    select
      c.id, c.name, c.campaign_type, c.discount_value, c.max_discount, c.scope,
      case when c.scope='store' then greatest(coalesce(p_subtotal,0),0)
           else greatest(coalesce(scoped.item_subtotal,0),0) end as eligible_subtotal
    from public.food_campaigns c
    left join public.food_platform_campaigns pc on pc.id=c.platform_campaign_id
    left join lateral (
      select coalesce(sum((e.value)::numeric),0) as item_subtotal
      from jsonb_each_text(coalesce(p_item_totals,'{}'::jsonb)) as e(key,value)
      join public.food_campaign_items ci on ci.campaign_id=c.id
       and ci.menu_item_id=(e.key)::uuid
    ) scoped on true
    where c.store_id=p_store_id
      and c.deleted_at is null and c.is_active
      and c.starts_at <= now()
      and (c.ends_at is null or c.ends_at > now())
      and (c.usage_limit is null or c.usage_count < c.usage_limit)
      and greatest(coalesce(p_subtotal,0),0) >= c.min_subtotal
      and (
        pc.coupon_required is distinct from true
        or exists (
          select 1 from public.food_coupon_codes cp
          where cp.platform_campaign_id = c.platform_campaign_id
            and cp.code = nullif(current_setting('wyn.food_coupon_code', true),'')
            and cp.is_active and cp.starts_at <= now()
            and (cp.ends_at is null or cp.ends_at > now())
            and auth.uid() is not null
            and (
              cp.max_total_uses is null
              or (select count(*) from public.food_coupon_redemptions r
                    where r.coupon_id=cp.id
                      and internal.food_coupon_usage_active(r.order_id)) < cp.max_total_uses
            )
            and (select count(*) from public.food_coupon_redemptions r
                 where r.coupon_id=cp.id and r.user_id=auth.uid()
                 and internal.food_coupon_usage_active(r.order_id)) < cp.max_uses_per_user
        )
      )
  ),
  calc as (
    select id, name, campaign_type,
      case when campaign_type='percentage' and eligible_subtotal > 0 then
             round(least(eligible_subtotal*discount_value/100,
                         coalesce(max_discount,eligible_subtotal*discount_value/100),
                         eligible_subtotal),2)
           when campaign_type='fixed' and eligible_subtotal > 0 then
             round(least(discount_value,eligible_subtotal),2)
           else 0::numeric end as campaign_discount,
      case when campaign_type='free_delivery' then
             round(greatest(coalesce(p_delivery_fee,0),0),2)
           else 0::numeric end as delivery_discount
    from base
  )
  select id as campaign_id,name as campaign_name,campaign_type,campaign_discount,
         delivery_discount,campaign_discount+delivery_discount as saving
  from calc where campaign_discount+delivery_discount > 0
  order by saving desc,id
$fn$;

create or replace function public.food_quote_order_v2(
  p_store_id uuid,p_items jsonb,p_latitude double precision default null,
  p_longitude double precision default null,p_coupon_code text default null
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
  v_quote jsonb;
  v_coupon public.food_coupon_codes%rowtype;
  v_code text := upper(btrim(coalesce(p_coupon_code,'')));
  v_applied boolean := false;
begin
  if length(v_code)>0 then
    if v_code !~ '^[A-Z0-9][A-Z0-9_-]{3,23}$' then
      raise exception 'invalid_coupon_code';
    end if;
    select * into v_coupon from public.food_coupon_codes
    where code=v_code and is_active and starts_at<=now()
      and (ends_at is null or ends_at>now());
    if not found then raise exception 'coupon_unavailable'; end if;
  end if;
  perform set_config('wyn.food_coupon_code',v_code,true);
  v_quote := public.food_quote_order(p_store_id,p_items,p_latitude,p_longitude);
  if v_code <> '' then
    select exists(
      select 1 from public.food_campaigns c
      where c.id=(v_quote->>'campaign_id')::uuid
        and c.platform_campaign_id=v_coupon.platform_campaign_id
    ) into v_applied;
    if not v_applied then
      raise exception 'coupon_not_applicable_or_better_automatic_discount';
    end if;
  end if;
  return v_quote || jsonb_build_object(
     'coupon_code', nullif(v_code,''), 'coupon_applied',v_applied
  );
end;
$fn$;

create or replace function public.food_create_order_v2(
  p_store_id uuid,p_recipient_name text,p_recipient_phone text,
  p_shipping_address text,p_customer_note text,p_items jsonb,
  p_latitude double precision default null,p_longitude double precision default null,
  p_coupon_code text default null
) returns uuid language plpgsql security definer set search_path='' as $fn$
declare
  v_coupon public.food_coupon_codes%rowtype;
  v_code text := upper(btrim(coalesce(p_coupon_code,'')));
  v_id uuid;
  v_chosen uuid;
  v_used integer;
begin
  if v_code = '' then
    return public.food_create_order(p_store_id,p_recipient_name,p_recipient_phone,
      p_shipping_address,p_customer_note,p_items,p_latitude,p_longitude);
  end if;
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if v_code !~ '^[A-Z0-9][A-Z0-9_-]{3,23}$' then raise exception 'invalid_coupon_code'; end if;
  -- Serialize redemption for this code. The lock lasts through both the
  -- original order creation and this function's redemption insert.
  select * into v_coupon from public.food_coupon_codes
   where code=v_code for update;
  if not found or not v_coupon.is_active or v_coupon.starts_at>now()
    or (v_coupon.ends_at is not null and v_coupon.ends_at<=now()) then
    raise exception 'coupon_unavailable';
  end if;
  select count(*) into v_used from public.food_coupon_redemptions r
    where r.coupon_id=v_coupon.id and internal.food_coupon_usage_active(r.order_id);
  if v_coupon.max_total_uses is not null and v_used>=v_coupon.max_total_uses then
    raise exception 'coupon_sold_out';
  end if;
  select count(*) into v_used from public.food_coupon_redemptions r
    where r.coupon_id=v_coupon.id and r.user_id=auth.uid()
      and internal.food_coupon_usage_active(r.order_id);
  if v_used>=v_coupon.max_uses_per_user then raise exception 'coupon_already_used'; end if;
  perform set_config('wyn.food_coupon_code',v_code,true);
  v_id:=public.food_create_order(p_store_id,p_recipient_name,p_recipient_phone,
        p_shipping_address,p_customer_note,p_items,p_latitude,p_longitude);
  select c.platform_campaign_id into v_chosen from public.food_orders o
    left join public.food_campaigns c on c.id=o.campaign_id
    where o.id=v_id;
  if v_chosen is distinct from v_coupon.platform_campaign_id then
    raise exception 'coupon_not_applicable_or_better_automatic_discount';
  end if;
  insert into public.food_coupon_redemptions(order_id,coupon_id,user_id)
    values(v_id,v_coupon.id,auth.uid());
  return v_id;
end;
$fn$;

create or replace function public.food_create_scheduled_order_v2(
  p_store_id uuid,p_recipient_name text,p_recipient_phone text,
  p_shipping_address text,p_customer_note text,p_items jsonb,
  p_scheduled_for timestamptz,
  p_latitude double precision default null,p_longitude double precision default null,
  p_coupon_code text default null
) returns uuid language plpgsql security definer set search_path='' as $fn$
declare v_id uuid;
begin
  v_id:=public.food_create_order_v2(p_store_id,p_recipient_name,p_recipient_phone,
    p_shipping_address,p_customer_note,p_items,p_latitude,p_longitude,p_coupon_code);
  perform internal.food_set_scheduled_order(v_id,p_scheduled_for);
  return v_id;
end;
$fn$;

-- New tables are private: even authenticated users must go through checked RPCs.
alter table public.food_coupon_codes enable row level security;
alter table public.food_coupon_redemptions enable row level security;
revoke all on public.food_coupon_codes,public.food_coupon_redemptions from public,anon,authenticated;
revoke all on function public.admin_food_issue_coupon(uuid,text,integer,integer,timestamptz,timestamptz) from public,anon;
revoke all on function public.admin_food_coupon_list() from public,anon;
revoke all on function public.admin_food_coupon_set_active(uuid,boolean) from public,anon;
grant execute on function public.admin_food_issue_coupon(uuid,text,integer,integer,timestamptz,timestamptz) to authenticated;
grant execute on function public.admin_food_coupon_list() to authenticated;
grant execute on function public.admin_food_coupon_set_active(uuid,boolean) to authenticated;
revoke all on function public.food_quote_order_v2(uuid,jsonb,double precision,double precision,text) from public,anon;
revoke all on function public.food_create_order_v2(uuid,text,text,text,text,jsonb,double precision,double precision,text) from public,anon;
revoke all on function public.food_create_scheduled_order_v2(uuid,text,text,text,text,jsonb,timestamptz,double precision,double precision,text) from public,anon;
grant execute on function public.food_quote_order_v2(uuid,jsonb,double precision,double precision,text) to authenticated;
grant execute on function public.food_create_order_v2(uuid,text,text,text,text,jsonb,double precision,double precision,text) to authenticated;
grant execute on function public.food_create_scheduled_order_v2(uuid,text,text,text,text,jsonb,timestamptz,double precision,double precision,text) to authenticated;
