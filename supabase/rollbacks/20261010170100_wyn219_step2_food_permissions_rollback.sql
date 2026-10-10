-- ROLLBACK for WYN-219 Phase 2, step 2 (Food): WYNOS Food admin checks -> food:view|edit
--
-- Generated from the production definitions dumped by
-- wyn219-dump-admin-check-definitions.yml (run 38059388028, 2026-10-10). Each
-- definition is copied verbatim; only its role-check expression changes:
--   staff check (admin or moderator) -> view (or edit where noted)
--   admin check                      -> edit
-- Data uses of profiles.platform_role (e.g. announcement audiences, the user
-- directory's role column) are unchanged.
--
-- public.food_is_platform_admin() becomes food:edit or merchant:edit.
--
-- Effect (Founder decisions 2026-10-10): the super admin keeps full access;
-- everyone else needs the matching permission from the Team Permissions page.
-- Requires: 20261010150000_wyn219_admin_permissions_foundation.sql applied.
-- Test: supabase/tests/wyn_219_step2_remaining_systems_test.sh
-- ROLLBACK: supabase/rollbacks/20261010170100_wyn219_step2_food_permissions_rollback.sql

-- public.admin_food_overview(): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_result jsonb;
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  select jsonb_build_object(
    'stores_total', (select count(*) from public.food_stores),
    'stores_published', (select count(*) from public.food_stores where is_published),
    'stores_open', (select count(*) from public.food_stores where is_open),
    'stores_suspended', (select count(*) from public.food_stores where admin_suspended_at is not null),
    'orders_today', (
      select count(*) from public.food_orders
      where (created_at at time zone 'Asia/Bangkok')::date = v_today
    ),
    'sales_today', (
      select coalesce(sum(total), 0) from public.food_orders
      where status = 'delivered' and (delivered_at at time zone 'Asia/Bangkok')::date = v_today
    ),
    'active_orders', (
      select count(*) from public.food_orders
      where status not in ('delivered', 'cancelled')
    ),
    'days', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'day', d.day,
        'orders', (
          select count(*) from public.food_orders o
          where (o.created_at at time zone 'Asia/Bangkok')::date = d.day
        ),
        'sales', (
          select coalesce(sum(o.total), 0) from public.food_orders o
          where o.status = 'delivered' and (o.delivered_at at time zone 'Asia/Bangkok')::date = d.day
        )
      ) order by d.day), '[]'::jsonb)
      from generate_series(v_today - 6, v_today, interval '1 day') as g(day_ts),
      lateral (select g.day_ts::date as day) d
    )
  ) into v_result;
  return v_result;
end;
$function$;

-- public.admin_food_stores(p_query text): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_stores(p_query text DEFAULT NULL::text)
 RETURNS TABLE(id uuid, name text, slug text, phone text, is_open boolean, is_published boolean, admin_suspended_at timestamp with time zone, admin_suspended_reason text, owner_username text, staff_count integer, orders_total integer, orders_30d integer, sales_30d numeric, active_orders integer, last_order_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  return query
  select
    s.id,
    s.name,
    s.slug,
    s.phone,
    s.is_open,
    s.is_published,
    s.admin_suspended_at,
    s.admin_suspended_reason,
    (
      select p.username
      from public.merchant_memberships mm
      join public.profiles p on p.id = mm.user_id
      where mm.merchant_account_id = s.merchant_account_id and mm.role = 'owner'
      order by mm.active desc, mm.created_at
      limit 1
    ),
    (
      select count(*)::integer
      from public.merchant_memberships mm
      where mm.merchant_account_id = s.merchant_account_id and mm.active
    ),
    (select count(*)::integer from public.food_orders o where o.store_id = s.id),
    (
      select count(*)::integer from public.food_orders o
      where o.store_id = s.id and o.created_at >= now() - interval '30 days'
    ),
    (
      select coalesce(sum(o.total), 0) from public.food_orders o
      where o.store_id = s.id and o.status = 'delivered' and o.delivered_at >= now() - interval '30 days'
    ),
    (
      select count(*)::integer from public.food_orders o
      where o.store_id = s.id and o.status not in ('delivered', 'cancelled')
    ),
    (select max(o.created_at) from public.food_orders o where o.store_id = s.id),
    s.created_at
  from public.food_stores s
  where v_query is null
     or s.name ilike '%' || v_query || '%'
     or s.slug ilike '%' || v_query || '%'
     or coalesce(s.phone, '') ilike '%' || v_query || '%'
  order by (s.admin_suspended_at is not null) desc, s.created_at desc
  limit 500;
end;
$function$;

-- public.admin_food_store_detail(p_store_id uuid): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_store_detail(p_store_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_store public.food_stores%rowtype;
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;
  select * into v_store from public.food_stores where id = p_store_id;
  if not found then
    raise exception 'store not found';
  end if;

  return jsonb_build_object(
    'id', v_store.id,
    'name', v_store.name,
    'slug', v_store.slug,
    'phone', v_store.phone,
    'address', v_store.address,
    'business_hours', v_store.business_hours,
    'is_open', v_store.is_open,
    'is_published', v_store.is_published,
    'admin_suspended_at', v_store.admin_suspended_at,
    'admin_suspended_reason', v_store.admin_suspended_reason,
    'admin_suspended_by_username', (select p.username from public.profiles p where p.id = v_store.admin_suspended_by),
    'created_at', v_store.created_at,
    -- WYN-214: where the store is pinned and whether it may sell (WYN-211).
    'latitude', v_store.latitude,
    'longitude', v_store.longitude,
    'delivery_radius_km', v_store.delivery_radius_km,
    'in_service_area', internal.food_in_service_area(v_store.latitude, v_store.longitude),
    'readiness_missing', to_jsonb(coalesce(internal.food_store_readiness_missing(v_store.id), array[]::text[])),
    'orders_total', (select count(*) from public.food_orders o where o.store_id = v_store.id),
    'orders_30d', (
      select count(*) from public.food_orders o
      where o.store_id = v_store.id and o.created_at >= now() - interval '30 days'
    ),
    'sales_30d', (
      select coalesce(sum(o.total), 0) from public.food_orders o
      where o.store_id = v_store.id and o.status = 'delivered' and o.delivered_at >= now() - interval '30 days'
    ),
    'cancelled_30d', (
      select count(*) from public.food_orders o
      where o.store_id = v_store.id and o.status = 'cancelled' and o.created_at >= now() - interval '30 days'
    ),
    'active_orders', (
      select count(*) from public.food_orders o
      where o.store_id = v_store.id and o.status not in ('delivered', 'cancelled')
    ),
    'team', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'user_id', mm.user_id,
        'username', p.username,
        'display_name', p.display_name,
        'role', mm.role,
        'active', mm.active,
        'created_at', mm.created_at
      ) order by mm.active desc, case mm.role when 'owner' then 0 when 'admin' then 1 when 'manager' then 2 else 3 end, mm.created_at), '[]'::jsonb)
      from public.merchant_memberships mm
      left join public.profiles p on p.id = mm.user_id
      where mm.merchant_account_id = v_store.merchant_account_id
    )
  );
end;
$function$;

-- public.admin_platform_campaigns(): restore production definition
CREATE OR REPLACE FUNCTION public.admin_platform_campaigns()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_rows jsonb;
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;
  select coalesce(jsonb_agg(to_jsonb(pc) || jsonb_build_object(
    'joined_stores', (select count(*) from public.food_campaigns c where c.platform_campaign_id = pc.id and c.deleted_at is null),
    'delivered_orders', coalesce(st.delivered_orders, 0),
    'discount_total', coalesce(st.discount_total, 0),
    'platform_funded_total', coalesce(st.platform_funded_total, 0)
  ) order by pc.created_at desc), '[]'::jsonb) into v_rows
  from public.food_platform_campaigns pc
  left join lateral (
    select count(*)::integer as delivered_orders,
           sum(foc.campaign_discount + foc.delivery_discount) as discount_total,
           sum(foc.platform_funded) as platform_funded_total
    from public.food_order_campaigns foc
    join public.food_orders o on o.id = foc.order_id
    where foc.platform_campaign_id = pc.id and foc.released_at is null and o.status = 'delivered'
  ) st on true;
  return v_rows;
end;
$function$;

-- public.admin_food_promo_list(): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_promo_list()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_result jsonb;
begin
  if coalesce(internal.current_platform_role(),'') not in ('admin','moderator') then
    raise exception 'Admin access required';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
   'id',p.id,'title',p.title,'body',p.body,'audience',p.audience,
   'scheduled_at',p.scheduled_at,'state',p.state,
   'coupon_code',c.code,'coupon_id',p.coupon_id,
   'inbox_count',(select count(*) from public.food_notifications n where n.broadcast_id=p.id),
   'push_sent',(select count(*) from public.food_promo_deliveries d where d.broadcast_id=p.id and d.state='sent'),
   'push_failed',(select count(*) from public.food_promo_deliveries d where d.broadcast_id=p.id and d.state='failed')
  ) order by p.created_at desc),'[]'::jsonb) into v_result
  from (select * from public.food_promo_broadcasts order by created_at desc limit 100) p
  left join public.food_coupon_codes c on c.id=p.coupon_id;
  return v_result;
end;
$function$;

-- public.admin_food_order_detail(p_order_id uuid): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_order_detail(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin uuid := auth.uid();
  v_order public.food_orders%rowtype;
  v_result jsonb;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can view Food orders';
  end if;
  select * into v_order from public.food_orders where id = p_order_id;
  if not found then
    raise exception 'order not found';
  end if;

  select jsonb_build_object(
    'order', to_jsonb(v_order),
    'store_name', (select s.name from public.food_stores s where s.id = v_order.store_id),
    'buyer_username', (select p.username from public.profiles p where p.id = v_order.buyer_id),
    'items', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'item_name', i.item_name,
        'quantity', i.quantity,
        'unit_price', i.unit_price,
        'item_note', i.item_note
      ) order by i.created_at), '[]'::jsonb)
      from public.food_order_items i where i.order_id = v_order.id
    ),
    'events', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'event_type', e.event_type,
        'from_status', e.from_status,
        'to_status', e.to_status,
        'note', e.note,
        'actor_username', p.username,
        'created_at', e.created_at
      ) order by e.created_at), '[]'::jsonb)
      from public.food_order_events e
      left join public.profiles p on p.id = e.actor_id
      where e.order_id = v_order.id
    ),
    'proof', (
      select jsonb_build_object(
        'method', d.method,
        'location_note', d.location_note,
        'image_path', d.image_path,
        'created_at', d.created_at
      )
      from public.food_delivery_proofs d where d.order_id = v_order.id
    )
  ) into v_result;

  perform internal.log_audit_event(
    v_admin,
    'admin_food_order_viewed',
    v_order.buyer_id,
    jsonb_build_object('order_id', v_order.id, 'order_number', v_order.order_number, 'store_id', v_order.store_id)
  );
  return v_result;
end;
$function$;

-- public.admin_food_orders(p_store_id uuid, p_status text, p_query text, p_limit integer): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_orders(p_store_id uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_query text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, order_number text, store_id uuid, store_name text, status text, payment_status text, refund_status text, recipient_name text, recipient_phone text, total numeric, created_at timestamp with time zone, delivered_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can view Food orders';
  end if;
  if p_status is not null and p_status not in ('active', 'pending_acceptance', 'preparing', 'ready_for_delivery', 'out_for_delivery', 'delivered', 'cancelled', 'refund_pending', 'payment_review') then
    raise exception 'Invalid order status: %', p_status;
  end if;

  return query
  select
    o.id,
    o.order_number::text,
    o.store_id,
    s.name,
    o.status,
    o.payment_status,
    o.refund_status,
    o.recipient_name,
    o.recipient_phone,
    o.total,
    o.created_at,
    o.delivered_at
  from public.food_orders o
  join public.food_stores s on s.id = o.store_id
  where (p_store_id is null or o.store_id = p_store_id)
    and (
      p_status is null
      or (p_status = 'active' and o.status not in ('delivered', 'cancelled'))
      -- WYN-214: money that still needs someone.
      or (p_status = 'refund_pending' and o.refund_status in ('pending', 'failed'))
      or (p_status = 'payment_review' and o.payment_status in ('submitted', 'issue'))
      or o.status = p_status
    )
    and (
      v_query is null
      or o.order_number::text ilike '%' || v_query || '%'
      or o.recipient_name ilike '%' || v_query || '%'
      or o.recipient_phone ilike '%' || v_query || '%'
    )
  order by o.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 300));
end;
$function$;

-- public.admin_set_food_store_member_active(p_store_id uuid, p_user_id uuid, p_active boolean): restore production definition
CREATE OR REPLACE FUNCTION public.admin_set_food_store_member_active(p_store_id uuid, p_user_id uuid, p_active boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin uuid := auth.uid();
  v_store public.food_stores%rowtype;
  v_member public.merchant_memberships%rowtype;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can change store teams';
  end if;
  select * into v_store from public.food_stores where id = p_store_id;
  if not found or v_store.merchant_account_id is null then
    raise exception 'store not found';
  end if;
  -- One team change per merchant account at a time, so two concurrent
  -- requests cannot each switch off a different owner and leave none.
  perform 1 from public.merchant_accounts where id = v_store.merchant_account_id for update;
  select * into v_member from public.merchant_memberships
  where merchant_account_id = v_store.merchant_account_id and user_id = p_user_id
  for update;
  if not found then
    raise exception 'team member not found';
  end if;
  if not p_active and v_member.role = 'owner' and not exists (
    select 1 from public.merchant_memberships mm
    where mm.merchant_account_id = v_store.merchant_account_id
      and mm.role = 'owner' and mm.active and mm.user_id <> p_user_id
  ) then
    raise exception 'cannot deactivate the only owner';
  end if;

  update public.merchant_memberships
  set active = p_active, updated_at = now()
  where merchant_account_id = v_store.merchant_account_id and user_id = p_user_id;

  -- Keep the legacy per-store staff row in step.
  update public.food_staff
  set active = p_active
  where store_id = v_store.id and user_id = p_user_id;

  perform internal.log_audit_event(
    v_admin,
    'admin_food_staff_updated',
    p_user_id,
    jsonb_build_object('store_id', v_store.id, 'store_name', v_store.name, 'role', v_member.role, 'active', p_active)
  );
end;
$function$;

-- public.admin_set_food_store_suspension(p_store_id uuid, p_suspend boolean, p_reason text): restore production definition
CREATE OR REPLACE FUNCTION public.admin_set_food_store_suspension(p_store_id uuid, p_suspend boolean, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin uuid := auth.uid();
  v_store public.food_stores%rowtype;
  v_reason text := nullif(left(btrim(coalesce(p_reason, '')), 500), '');
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can suspend stores';
  end if;
  select * into v_store from public.food_stores where id = p_store_id for update;
  if not found then
    raise exception 'store not found';
  end if;
  if p_suspend and v_reason is null then
    raise exception 'suspension reason is required';
  end if;

  if p_suspend then
    update public.food_stores
    set admin_suspended_at = now(),
        admin_suspended_reason = v_reason,
        admin_suspended_by = v_admin,
        is_published = false,
        is_open = false
    where id = v_store.id;
  else
    -- The store stays unpublished and closed; its owner publishes again.
    update public.food_stores
    set admin_suspended_at = null,
        admin_suspended_reason = null,
        admin_suspended_by = null
    where id = v_store.id;
  end if;

  insert into public.notifications (recipient_id, actor_id, type, reason)
  select mm.user_id, null, 'system',
    case when p_suspend
      then 'ร้าน ' || v_store.name || ' ถูกระงับชั่วคราวโดยทีม WYNOS: ' || v_reason
      else 'ร้าน ' || v_store.name || ' ยกเลิกการระงับแล้ว เปิดร้านและเผยแพร่ได้อีกครั้งใน Wynos Merchant'
    end
  from public.merchant_memberships mm
  where mm.merchant_account_id = v_store.merchant_account_id
    and mm.active
    and mm.role in ('owner', 'admin');

  perform internal.log_audit_event(
    v_admin,
    case when p_suspend then 'admin_food_store_suspended' else 'admin_food_store_unsuspended' end,
    null,
    jsonb_build_object('store_id', v_store.id, 'store_name', v_store.name, 'reason', v_reason)
  );
end;
$function$;

-- public.admin_food_coupon_set_active(p_coupon_id uuid, p_active boolean): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_coupon_set_active(p_coupon_id uuid, p_active boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage WYNOS Food coupons';
  end if;
  update public.food_coupon_codes
     set is_active=p_active, updated_at=now()
   where id=p_coupon_id;
  if not found then raise exception 'coupon_not_found'; end if;
end;
$function$;

-- public.admin_food_issue_coupon(p_campaign_id uuid, p_code text, p_max_total_uses integer, p_max_uses_per_user integer, p_starts_at timestamp with time zone, p_ends_at timestamp with time zone): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_issue_coupon(p_campaign_id uuid, p_code text, p_max_total_uses integer DEFAULT NULL::integer, p_max_uses_per_user integer DEFAULT 1, p_starts_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_ends_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

-- public.admin_food_first_order_set_active(p_active boolean): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_first_order_set_active(p_active boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      'โปรลูกค้าใหม่ · สั่งครบ ฿100 ลด ฿40',
      'สำหรับลูกค้าที่ยังไม่เคยสั่งอาหารบน WYNOS Food ใช้ได้ 1 ครั้งต่อบัญชี ร้านเป็นผู้รับผิดชอบส่วนลดทั้งหมด',
      'fixed',40,100,null,0,true,false,true,auth.uid()
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
$function$;

-- public.admin_food_promo_cancel(p_broadcast_id uuid): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_promo_cancel(p_broadcast_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if coalesce(internal.current_platform_role(),'')<>'admin' then
    raise exception 'Only admins can cancel Food promotions';
  end if;
  update public.food_promo_broadcasts set state='cancelled'
  where id=p_broadcast_id and state='queued';
  if not found then raise exception 'already_sent_or_not_found'; end if;
end;
$function$;

-- public.admin_food_promo_schedule(p_title text, p_body text, p_coupon_id uuid, p_audience text, p_scheduled_at timestamp with time zone): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_promo_schedule(p_title text, p_body text, p_coupon_id uuid DEFAULT NULL::uuid, p_audience text DEFAULT 'all'::text, p_scheduled_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid;
begin
  if coalesce(internal.current_platform_role(), '')<>'admin' then
    raise exception 'Only admins can send Food promotions';
  end if;
  if p_coupon_id is not null and not exists(
    select 1 from public.food_coupon_codes where id=p_coupon_id and is_active
  ) then raise exception 'coupon_not_active'; end if;
  if p_audience not in ('all','returning') then raise exception 'invalid_audience'; end if;
  if char_length(trim(coalesce(p_title,''))) not between 3 and 90
    or char_length(trim(coalesce(p_body,''))) not between 5 and 260 then
    raise exception 'invalid_promotion_copy';
  end if;
  insert into public.food_promo_broadcasts(title,body,coupon_id,audience,scheduled_at,created_by)
  values(trim(p_title),trim(p_body),p_coupon_id,p_audience,coalesce(p_scheduled_at,now()),auth.uid())
  returning id into v_id;
  return v_id;
end;
$function$;

-- public.admin_ad_overview(): restore production definition
CREATE OR REPLACE FUNCTION public.admin_ad_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage ads';
  end if;
  return jsonb_build_object(
    'settings', (select to_jsonb(s) - 'id' from public.food_ad_settings s where s.id = 1),
    'pending_topups', coalesce((
      select jsonb_agg(jsonb_build_object('id', t.id, 'store_id', t.store_id, 'store_name', s.name, 'amount', t.amount,
        'slip_path', t.slip_path, 'created_at', t.created_at) order by t.created_at)
      from public.food_ad_topups t join public.food_stores s on s.id = t.store_id
      where t.status = 'pending'
    ), '[]'::jsonb),
    'accounts', coalesce((
      select jsonb_agg(jsonb_build_object('store_id', a.store_id, 'store_name', s.name, 'balance', a.balance,
        'total_spent', a.total_spent, 'status', a.status, 'stop_reason', a.stop_reason,
        'live', internal.food_ad_is_live(a.store_id),
        'clicks_7d', (select count(*) from public.food_ad_clicks c where c.store_id = a.store_id and c.click_day > v_today - 7),
        'spend_7d', coalesce((select sum(c.cost) from public.food_ad_clicks c where c.store_id = a.store_id and c.click_day > v_today - 7), 0)
      ) order by a.balance desc)
      from public.food_ad_accounts a join public.food_stores s on s.id = a.store_id
    ), '[]'::jsonb)
  );
end;
$function$;

-- public.admin_update_ad_settings(p_cost_per_click numeric, p_min_topup numeric, p_wynos_promptpay_name text, p_wynos_promptpay_id text, p_ads_enabled boolean): restore production definition
CREATE OR REPLACE FUNCTION public.admin_update_ad_settings(p_cost_per_click numeric, p_min_topup numeric, p_wynos_promptpay_name text, p_wynos_promptpay_id text, p_ads_enabled boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin uuid := auth.uid();
  v_promptpay text := nullif(btrim(coalesce(p_wynos_promptpay_id, '')), '');
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage ads';
  end if;
  if coalesce(p_ads_enabled, false) and v_promptpay is null then
    raise exception 'set the WYNOS PromptPay before turning ads on';
  end if;
  update public.food_ad_settings set
    cost_per_click = p_cost_per_click,
    min_topup = p_min_topup,
    wynos_promptpay_name = nullif(btrim(coalesce(p_wynos_promptpay_name, '')), ''),
    wynos_promptpay_id = v_promptpay,
    ads_enabled = coalesce(p_ads_enabled, false),
    updated_by = v_admin,
    updated_at = now()
  where id = 1;
  perform internal.log_audit_event(v_admin, 'admin_ad_settings_updated', null,
    jsonb_build_object('cost_per_click', p_cost_per_click, 'min_topup', p_min_topup,
      'ads_enabled', coalesce(p_ads_enabled, false), 'promptpay_set', v_promptpay is not null));
end;
$function$;

-- public.admin_review_ad_topup(p_topup_id uuid, p_approve boolean, p_note text): restore production definition
CREATE OR REPLACE FUNCTION public.admin_review_ad_topup(p_topup_id uuid, p_approve boolean, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin uuid := auth.uid();
  v_topup public.food_ad_topups%rowtype;
  v_store public.food_stores%rowtype;
  v_note text := nullif(left(btrim(coalesce(p_note, '')), 300), '');
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can review ad top-ups';
  end if;
  select * into v_topup from public.food_ad_topups where id = p_topup_id for update;
  if not found then
    raise exception 'top-up not found';
  end if;
  if v_topup.status <> 'pending' then
    raise exception 'top-up already reviewed';
  end if;
  if not p_approve and v_note is null then
    raise exception 'a reason is required to reject';
  end if;
  select * into v_store from public.food_stores where id = v_topup.store_id;

  update public.food_ad_topups
  set status = case when p_approve then 'approved' else 'rejected' end,
      note = v_note, reviewed_by = v_admin, reviewed_at = now()
  where id = p_topup_id;

  if p_approve then
    insert into public.food_ad_accounts (store_id, balance) values (v_topup.store_id, v_topup.amount)
    on conflict (store_id) do update set balance = public.food_ad_accounts.balance + excluded.balance, updated_at = now();
  end if;

  insert into public.notifications (recipient_id, actor_id, type, reason)
  select mm.user_id, null, 'system',
    case when p_approve
      then 'WYNOS เติมเครดิตโฆษณาร้าน ' || v_store.name || ' แล้ว ' || to_char(v_topup.amount, 'FM999,999,990.00') || ' บาท'
      else 'WYNOS ไม่อนุมัติการเติมเครดิตโฆษณาร้าน ' || v_store.name || ': ' || v_note
    end
  from public.merchant_memberships mm
  where mm.merchant_account_id = v_store.merchant_account_id and mm.active and mm.role in ('owner', 'admin', 'manager');

  perform internal.log_audit_event(v_admin, 'admin_ad_topup_reviewed', null,
    jsonb_build_object('topup_id', p_topup_id, 'store_id', v_topup.store_id, 'store_name', v_store.name,
      'amount', v_topup.amount, 'approved', p_approve, 'note', v_note));
end;
$function$;

-- public.admin_set_ad_account_status(p_store_id uuid, p_stop boolean, p_reason text): restore production definition
CREATE OR REPLACE FUNCTION public.admin_set_ad_account_status(p_store_id uuid, p_stop boolean, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin uuid := auth.uid();
  v_reason text := nullif(left(btrim(coalesce(p_reason, '')), 300), '');
  v_store public.food_stores%rowtype;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage ads';
  end if;
  if p_stop and v_reason is null then
    raise exception 'a reason is required to stop ads';
  end if;
  select * into v_store from public.food_stores where id = p_store_id;
  if not found then
    raise exception 'store not found';
  end if;
  insert into public.food_ad_accounts (store_id) values (p_store_id) on conflict (store_id) do nothing;
  -- Starting again leaves the ads paused; the store switches them back on.
  update public.food_ad_accounts
  set status = case when p_stop then 'stopped' else 'paused' end,
      stop_reason = case when p_stop then v_reason else null end,
      updated_at = now()
  where store_id = p_store_id;

  insert into public.notifications (recipient_id, actor_id, type, reason)
  select mm.user_id, null, 'system',
    case when p_stop
      then 'WYNOS หยุดโฆษณาร้าน ' || v_store.name || ': ' || v_reason
      else 'WYNOS เปิดให้ร้าน ' || v_store.name || ' ลงโฆษณาได้อีกครั้ง'
    end
  from public.merchant_memberships mm
  where mm.merchant_account_id = v_store.merchant_account_id and mm.active and mm.role in ('owner', 'admin', 'manager');

  perform internal.log_audit_event(v_admin, 'admin_ad_account_status', null,
    jsonb_build_object('store_id', p_store_id, 'store_name', v_store.name, 'stopped', p_stop, 'reason', v_reason));
end;
$function$;

-- public.admin_upsert_platform_campaign(p_campaign_id uuid, p_name text, p_description text, p_campaign_type text, p_discount_value numeric, p_min_subtotal numeric, p_max_discount numeric, p_starts_at timestamp with time zone, p_ends_at timestamp with time zone, p_usage_limit_per_store integer, p_platform_share_percent numeric, p_join_open boolean, p_is_active boolean): restore production definition
CREATE OR REPLACE FUNCTION public.admin_upsert_platform_campaign(p_campaign_id uuid, p_name text, p_description text, p_campaign_type text, p_discount_value numeric, p_min_subtotal numeric, p_max_discount numeric, p_starts_at timestamp with time zone, p_ends_at timestamp with time zone, p_usage_limit_per_store integer, p_platform_share_percent numeric, p_join_open boolean, p_is_active boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin uuid := auth.uid();
  v_id uuid;
  v_type text := lower(btrim(coalesce(p_campaign_type, '')));
  v_value numeric := case when lower(btrim(coalesce(p_campaign_type, ''))) = 'free_delivery' then 0 else coalesce(p_discount_value, 0) end;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage WYNOS campaigns';
  end if;

  if p_campaign_id is null then
    insert into public.food_platform_campaigns (
      name, description, campaign_type, discount_value, min_subtotal, max_discount, starts_at, ends_at,
      usage_limit_per_store, platform_share_percent, join_open, is_active, created_by
    ) values (
      btrim(coalesce(p_name, '')), nullif(btrim(coalesce(p_description, '')), ''), v_type, v_value,
      coalesce(p_min_subtotal, 0), p_max_discount, coalesce(p_starts_at, now()), p_ends_at,
      p_usage_limit_per_store, coalesce(p_platform_share_percent, 0), coalesce(p_join_open, true), coalesce(p_is_active, true), v_admin
    ) returning id into v_id;
  else
    update public.food_platform_campaigns set
      name = btrim(coalesce(p_name, '')),
      description = nullif(btrim(coalesce(p_description, '')), ''),
      campaign_type = v_type,
      discount_value = v_value,
      min_subtotal = coalesce(p_min_subtotal, 0),
      max_discount = p_max_discount,
      starts_at = coalesce(p_starts_at, starts_at),
      ends_at = p_ends_at,
      usage_limit_per_store = p_usage_limit_per_store,
      platform_share_percent = coalesce(p_platform_share_percent, 0),
      join_open = coalesce(p_join_open, true),
      is_active = coalesce(p_is_active, true),
      updated_at = now()
    where id = p_campaign_id
    returning id into v_id;
    if v_id is null then
      raise exception 'campaign not found';
    end if;

    -- Stores that joined follow the new terms for their next orders; orders
    -- already placed keep the share they were placed with.
    perform set_config('wyn.platform_campaign_write', 'on', true);
    update public.food_campaigns c set
      name = pc.name,
      campaign_type = pc.campaign_type,
      discount_value = pc.discount_value,
      min_subtotal = pc.min_subtotal,
      max_discount = pc.max_discount,
      starts_at = pc.starts_at,
      ends_at = pc.ends_at,
      usage_limit = pc.usage_limit_per_store,
      platform_share_percent = pc.platform_share_percent,
      is_active = pc.is_active
    from public.food_platform_campaigns pc
    where pc.id = v_id and c.platform_campaign_id = v_id and c.deleted_at is null;
    perform set_config('wyn.platform_campaign_write', '', true);
  end if;

  perform internal.log_audit_event(
    v_admin, 'admin_platform_campaign_saved', null,
    jsonb_build_object('campaign_id', v_id, 'name', btrim(coalesce(p_name, '')), 'campaign_type', v_type,
      'discount_value', v_value, 'platform_share_percent', coalesce(p_platform_share_percent, 0),
      'is_active', coalesce(p_is_active, true), 'join_open', coalesce(p_join_open, true))
  );
  return v_id;
end;
$function$;

-- public.admin_settle_platform_store(p_store_id uuid, p_reference text, p_expected_amount numeric, p_expected_count integer, p_note text): restore production definition
CREATE OR REPLACE FUNCTION public.admin_settle_platform_store(p_store_id uuid, p_reference text, p_expected_amount numeric, p_expected_count integer, p_note text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin uuid := auth.uid();
  v_reference text := left(btrim(coalesce(p_reference, '')), 120);
  v_note text := nullif(left(btrim(coalesce(p_note, '')), 300), '');
  v_store public.food_stores%rowtype;
  v_amount numeric;
  v_count integer;
  v_id uuid;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can record WYNOS campaign payouts';
  end if;
  if v_reference = '' then
    raise exception 'transfer reference is required';
  end if;
  select * into v_store from public.food_stores where id = p_store_id for update;
  if not found then
    raise exception 'store not found';
  end if;

  -- Lock the owed rows so two admins cannot settle the same orders twice.
  perform 1 from public.food_order_campaigns foc
  where foc.order_id in (select r.order_id from internal.food_platform_owed_rows(p_store_id) r)
  for update;

  select coalesce(sum(r.amount), 0), count(*)::integer into v_amount, v_count
  from internal.food_platform_owed_rows(p_store_id) r;
  if v_count = 0 then
    raise exception 'nothing to settle';
  end if;
  -- WYN-213: record exactly what the admin saw and transferred. If more
  -- orders became owed after the page loaded, stop and let them reload.
  if p_expected_amount is null or p_expected_count is null
     or round(p_expected_amount, 2) <> round(v_amount, 2) or p_expected_count <> v_count then
    raise exception 'owed amount changed, reload and check before recording';
  end if;

  insert into public.food_platform_settlements (store_id, amount, order_count, reference, note, settled_by)
  values (p_store_id, v_amount, v_count, v_reference, v_note, v_admin)
  returning id into v_id;

  update public.food_order_campaigns foc set settlement_id = v_id
  where foc.order_id in (select r.order_id from internal.food_platform_owed_rows(p_store_id) r);

  insert into public.notifications (recipient_id, actor_id, type, reason)
  select mm.user_id, null, 'system',
    'WYNOS โอนส่วนลดแคมเปญคืนร้าน ' || v_store.name || ' แล้ว ' || to_char(v_amount, 'FM999,999,990.00') || ' บาท (' || v_count || ' ออเดอร์) อ้างอิง ' || v_reference
  from public.merchant_memberships mm
  where mm.merchant_account_id = v_store.merchant_account_id and mm.active and mm.role in ('owner', 'admin');

  perform internal.log_audit_event(
    v_admin, 'admin_platform_campaign_settled', null,
    jsonb_build_object('store_id', p_store_id, 'store_name', v_store.name, 'amount', v_amount,
      'order_count', v_count, 'reference', v_reference, 'settlement_id', v_id)
  );
  return v_id;
end;
$function$;

-- public.admin_platform_owed(): restore production definition
CREATE OR REPLACE FUNCTION public.admin_platform_owed()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_rows jsonb;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can view WYNOS campaign payouts';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'store_id', s.id,
    'store_name', s.name,
    'promptpay_name', s.promptpay_name,
    'promptpay_id', s.promptpay_id,
    'bank_name', s.bank_name,
    'bank_account_name', s.bank_account_name,
    'bank_account_number', s.bank_account_number,
    'owed', o.owed,
    'owed_orders', o.owed_orders,
    'last_settled_at', (select max(ps.created_at) from public.food_platform_settlements ps where ps.store_id = s.id)
  ) order by o.owed desc), '[]'::jsonb) into v_rows
  from public.food_stores s
  join lateral (
    select sum(r.amount) as owed, count(*)::integer as owed_orders
    from internal.food_platform_owed_rows(s.id) r
  ) o on o.owed_orders > 0;
  return v_rows;
end;
$function$;

-- public.admin_food_coupon_list(): restore production definition
CREATE OR REPLACE FUNCTION public.admin_food_coupon_list()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

-- public.food_is_platform_admin(): restore production definition
CREATE OR REPLACE FUNCTION public.food_is_platform_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.platform_role = 'admin'
  );
$function$;
