-- WYNOS Food: Merchant-funded first-order offer, opt-in by each store.
-- Additive and initially disabled. Requires 20261008161000_food_admin_coupons.sql
-- before this migration; no automatic activation and no existing orders changed.
-- Offer terms are locked to food subtotal >= 120, discount 20, platform share 0.
--
-- Cancellation policy: unpaid cancelled orders release eligibility; an order
-- that reached paid/submitted/refunded payment state retains the consumed first
-- order even if later cancelled. Manual support can review exceptional cases.

alter table public.food_platform_campaigns
  add column if not exists first_order_only boolean not null default false;

create unique index if not exists food_platform_first_order_singleton_idx
  on public.food_platform_campaigns ((first_order_only))
  where first_order_only;

alter table public.food_platform_campaigns
  add constraint food_platform_first_order_fixed_terms_check
  check (
    not first_order_only or (
      campaign_type = 'fixed' and discount_value = 20
      and min_subtotal = 120 and max_discount is null
      and platform_share_percent = 0
    )
  );

-- Serializes ALL app orders for the same buyer, including orders from
-- merchants that have not joined the campaign. This prevents a concurrent
-- regular order and a promotional order both being treated as "first".
create or replace function internal.food_first_order_buyer_lock()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  if new.buyer_id is not null then
    perform pg_advisory_xact_lock(206120, hashtext(new.buyer_id::text));
  end if;
  return new;
end;
$fn$;

revoke all on function internal.food_first_order_buyer_lock() from public, anon, authenticated;
drop trigger if exists food_first_order_buyer_lock on public.food_orders;
create trigger food_first_order_buyer_lock
  before insert on public.food_orders
  for each row execute function internal.food_first_order_buyer_lock();

-- The quote is informational; this trigger rechecks the right to redeem
-- at the transaction boundary, after the food order and campaign snapshots
-- have been written, while holding the per-buyer advisory lock above.
create or replace function internal.food_first_order_validate_redemption()
returns trigger language plpgsql security definer set search_path = '' as $fn$
declare
  v_buyer uuid;
  v_is_first_order boolean;
begin
  select pc.first_order_only into v_is_first_order
  from public.food_platform_campaigns pc
  where pc.id = new.platform_campaign_id;
  if coalesce(v_is_first_order, false) = false then
    return new;
  end if;

  select o.buyer_id into v_buyer
  from public.food_orders o where o.id = new.order_id;
  if v_buyer is null then
    raise exception 'first_order_requires_customer';
  end if;
  if new.campaign_discount <> 20 or new.delivery_discount <> 0
     or new.platform_funded <> 0 then
    raise exception 'first_order_discount_mismatch';
  end if;
  if exists (
    select 1 from public.food_orders prior
    where prior.buyer_id = v_buyer
      and prior.id <> new.order_id
      and (
        prior.status <> 'cancelled'
        or prior.payment_status in ('paid','submitted','refunded')
      )
  ) then
    raise exception 'first_order_already_used';
  end if;
  return new;
end;
$fn$;

revoke all on function internal.food_first_order_validate_redemption() from public, anon, authenticated;
drop trigger if exists food_first_order_validate_redemption on public.food_order_campaigns;
create trigger food_first_order_validate_redemption
  after insert on public.food_order_campaigns
  for each row execute function internal.food_first_order_validate_redemption();

-- Admin controls a single preset. Merchants continue to opt in/out via
-- merchant_join_platform_campaign; no store is enrolled automatically.
create or replace function public.admin_food_first_order_set_active(p_active boolean)
returns uuid language plpgsql security definer set search_path = '' as $fn$
declare
  v_id uuid;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage WYNOS first-order promotions';
  end if;
  select id into v_id from public.food_platform_campaigns
  where first_order_only for update;
  if v_id is null then
    insert into public.food_platform_campaigns (
      name,description,campaign_type,discount_value,min_subtotal,max_discount,
      platform_share_percent,join_open,is_active,first_order_only,created_by
    ) values (
      'โปรลูกค้าใหม่ · สั่งครบ ฿120 ลด ฿20',
      'สำหรับลูกค้าที่ยังไม่เคยสั่งอาหารบน WYNOS Food ใช้ได้ 1 ครั้งต่อบัญชี ร้านเป็นผู้รับผิดชอบส่วนลดทั้งหมด',
      'fixed',20,120,null,0,true,false,true,auth.uid()
    ) returning id into v_id;
  end if;
  update public.food_platform_campaigns
  set is_active = coalesce(p_active,false),
      join_open = coalesce(p_active,false),
      updated_at = now()
  where id = v_id;
  perform set_config('wyn.platform_campaign_write', 'on', true);
  update public.food_campaigns
  set is_active=coalesce(p_active,false)
  where platform_campaign_id=v_id and deleted_at is null;
  perform set_config('wyn.platform_campaign_write', '', true);
  perform internal.log_audit_event(
    auth.uid(), 'admin_platform_campaign_saved', null,
    jsonb_build_object('campaign_id',v_id,'first_order_only',true,
      'is_active',coalesce(p_active,false),'merchant_funded',true)
  );
  return v_id;
end;
$fn$;
revoke all on function public.admin_food_first_order_set_active(boolean) from public, anon;
grant execute on function public.admin_food_first_order_set_active(boolean) to authenticated;

-- Reuse existing candidate/quote/order logic, adding a global first-order
-- eligibility predicate; keep the coupon-required logic intact.

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
      -- Do not offer a first-order campaign on any other Food order.
      -- Cancelled unpaid orders do not consume eligibility; paid/submitted
      -- orders still count, even if the store later cancelled them.
      and (pc.id is null or pc.is_active)
      and (
        pc.first_order_only is distinct from true
        or (
          auth.uid() is not null
          and not exists (
            select 1 from public.food_orders prior
            where prior.buyer_id = auth.uid()
              and (
                prior.status <> 'cancelled'
                or prior.payment_status in ('paid','submitted','refunded')
              )
          )
        )
      )
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

-- Include the flag in the Merchant Campaign Center snapshot.
create or replace function public.merchant_platform_campaigns(p_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaigns jsonb;
  v_owed numeric;
  v_owed_orders integer;
  v_settlements jsonb;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin','manager','orders','support','delivery']) then
    raise exception 'merchant access required';
  end if;

  select coalesce(jsonb_agg(x.payload order by x.sort_key desc), '[]'::jsonb) into v_campaigns
  from (
    select
      coalesce(sc.created_at, pc.starts_at) as sort_key,
      jsonb_build_object(
        'id', pc.id,
        'name', pc.name,
        'description', pc.description,
        'campaign_type', pc.campaign_type,
        'discount_value', pc.discount_value,
        'min_subtotal', pc.min_subtotal,
        'max_discount', pc.max_discount,
        'starts_at', pc.starts_at,
        'ends_at', pc.ends_at,
        'usage_limit_per_store', pc.usage_limit_per_store,
        'platform_share_percent', pc.platform_share_percent,
        'first_order_only', pc.first_order_only,
        'join_open', pc.join_open,
        'is_active', pc.is_active,
        'joined', sc.id is not null,
        'joined_at', sc.created_at,
        'usage_count', coalesce(sc.usage_count, 0),
        'delivered_orders', coalesce(st.delivered_orders, 0),
        'discount_total', coalesce(st.discount_total, 0),
        'platform_funded_total', coalesce(st.platform_funded_total, 0)
      ) as payload
    from public.food_platform_campaigns pc
    left join public.food_campaigns sc
      on sc.platform_campaign_id = pc.id and sc.store_id = p_store_id and sc.deleted_at is null
    left join lateral (
      select
        count(*)::integer as delivered_orders,
        sum(foc.campaign_discount + foc.delivery_discount) as discount_total,
        sum(foc.platform_funded) as platform_funded_total
      from public.food_order_campaigns foc
      join public.food_orders o on o.id = foc.order_id
      where foc.platform_campaign_id = pc.id
        and o.store_id = p_store_id
        and foc.released_at is null
        and o.status = 'delivered'
    ) st on true
    where sc.id is not null
       or (pc.is_active and pc.join_open and (pc.ends_at is null or pc.ends_at > now()))
  ) x;

  select coalesce(sum(r.amount), 0), count(*)::integer into v_owed, v_owed_orders
  from internal.food_platform_owed_rows(p_store_id) r;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', s.id, 'amount', s.amount, 'order_count', s.order_count,
    'reference', s.reference, 'note', s.note, 'created_at', s.created_at
  ) order by s.created_at desc), '[]'::jsonb) into v_settlements
  from (
    select * from public.food_platform_settlements
    where store_id = p_store_id
    order by created_at desc
    limit 20
  ) s;

  return jsonb_build_object(
    'can_manage', public.merchant_has_store_role(p_store_id, array['owner','admin','manager']),
    'campaigns', v_campaigns,
    'owed', v_owed,
    'owed_orders', v_owed_orders,
    'settlements', v_settlements
  );
end;
$$;

revoke all on function public.merchant_platform_campaigns(uuid) from public, anon;
grant execute on function public.merchant_platform_campaigns(uuid) to authenticated;
