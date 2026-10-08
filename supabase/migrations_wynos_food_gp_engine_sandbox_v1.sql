-- WYNOS GP Engine v1: QA/Sandbox simulation only.
-- NEVER apply to production. No default GP rate, no Stripe fee, no settlement.
-- Order snapshots are captured explicitly through service_role after a paid,
-- test-mode Stripe transaction; capturing never changes an order or gateway.
-- Basis is pre-discount food subtotal, not delivery; discount policy is
-- intentionally left for approval before any non-simulated implementation.

create table if not exists public.food_gp_order_snapshots (
  order_id uuid primary key references public.food_orders(id) on delete restrict,
  store_id uuid not null references public.food_stores(id) on delete restrict,
  order_number text not null,
  currency text not null default 'thb' check (currency = 'thb'),
  rate_bps integer not null check (rate_bps between 0 and 10000),
  rate_configured_at timestamptz not null,
  basis text not null default 'food_subtotal_excluding_delivery'
    check (basis = 'food_subtotal_excluding_delivery'),
  food_subtotal_satang bigint not null check (food_subtotal_satang >= 0),
  delivery_fee_satang bigint not null check (delivery_fee_satang >= 0),
  customer_paid_satang bigint not null check (customer_paid_satang > 0),
  order_discount_satang bigint not null check (order_discount_satang >= 0),
  estimated_gp_satang bigint not null check (estimated_gp_satang >= 0),
  estimated_store_food_satang bigint not null check (estimated_store_food_satang >= 0),
  actually_collected_gp_satang bigint not null default 0
    check (actually_collected_gp_satang = 0),
  stripe_payment_intent_id text,
  mode text not null default 'simulation_only' check (mode = 'simulation_only'),
  created_at timestamptz not null default now(),
  constraint gp_snapshot_amount_sum check (
    estimated_gp_satang + estimated_store_food_satang = food_subtotal_satang
    and estimated_gp_satang <= food_subtotal_satang
  )
);

create index if not exists food_gp_order_snapshots_store_created_idx
  on public.food_gp_order_snapshots(store_id, created_at desc);

alter table public.food_gp_order_snapshots enable row level security;
revoke all on table public.food_gp_order_snapshots from public, anon, authenticated;
grant select, insert on table public.food_gp_order_snapshots to service_role;

-- A captured per-order rate and allocation never change, even if store rates,
-- order statuses, refunds or the future revenue model later change.
create or replace function public.food_gp_snapshot_immutable_qa()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'GP QA snapshots are immutable (no update or delete)' using errcode = '23514';
end;
$$;
revoke all on function public.food_gp_snapshot_immutable_qa() from public, anon, authenticated;
drop trigger if exists food_gp_snapshots_immutable_qa on public.food_gp_order_snapshots;
create trigger food_gp_snapshots_immutable_qa
  before update or delete on public.food_gp_order_snapshots
  for each row execute function public.food_gp_snapshot_immutable_qa();

-- Pure integer-satang calculation. Half-up rounding is explicit.
-- Kept server-only so users cannot use it to infer private draft rates.
create or replace function public.food_gp_calculate_qa(
  p_food_subtotal_satang bigint, p_rate_bps integer
) returns jsonb language plpgsql immutable set search_path = '' as $$
declare v_gp bigint;
begin
  if p_food_subtotal_satang is null or p_food_subtotal_satang < 0
     or p_food_subtotal_satang > 100000000000 then
    raise exception 'invalid GP basis satang amount';
  end if;
  if p_rate_bps is null or p_rate_bps not between 0 and 10000 then
    raise exception 'invalid GP rate';
  end if;
  v_gp := floor(p_food_subtotal_satang::numeric * p_rate_bps / 10000 + 0.5)::bigint;
  return jsonb_build_object(
    'basis', 'food_subtotal_excluding_delivery',
    'food_subtotal_satang', p_food_subtotal_satang,
    'rate_bps', p_rate_bps,
    'estimated_gp_satang', v_gp,
    'estimated_store_food_satang', p_food_subtotal_satang - v_gp,
    'actually_collected_gp_satang', 0,
    'mode', 'simulation_only'
  );
end;
$$;
revoke all on function public.food_gp_calculate_qa(bigint,integer) from public, anon, authenticated;
grant execute on function public.food_gp_calculate_qa(bigint,integer) to service_role;

-- Explicit trusted-server capture. Never called by payment webhook or
-- checkout: GP simulation cannot block or alter the existing payment path.
-- Acquires store lock first, matching admin_food_gp_set_draft's lock order,
-- so a concurrent rate edit cannot change the rate mid-snapshot.
create or replace function public.food_gp_capture_order_qa(p_order_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_store_id uuid;
  v_order public.food_orders%rowtype;
  v_rate public.food_gp_store_rates%rowtype;
  v_ledger public.food_stripe_payments%rowtype;
  v_existing public.food_gp_order_snapshots%rowtype;
  v_calc jsonb;
  v_food bigint;
  v_delivery bigint;
  v_total bigint;
  v_discount bigint;
begin
  if p_order_id is null then raise exception 'order id required'; end if;

  select o.store_id into v_store_id
    from public.food_orders o where o.id = p_order_id;
  if not found then raise exception 'order not found'; end if;

  perform 1 from public.food_stores s where s.id = v_store_id for update;
  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found or v_order.store_id is distinct from v_store_id then
    raise exception 'order changed while locking';
  end if;

  select * into v_existing from public.food_gp_order_snapshots
    where order_id = p_order_id;
  if found then
    return jsonb_build_object('status','already_snapshotted',
      'snapshot',to_jsonb(v_existing),'actually_collected_gp_satang',0);
  end if;

  select * into v_rate from public.food_gp_store_rates
    where store_id = v_store_id;
  if not found then
    return jsonb_build_object('status','rate_not_configured',
      'order_id',p_order_id,'mode','simulation_only',
      'snapshot_created',false,'actually_collected_gp_satang',0);
  end if;

  -- No snapshot for unpaid/refunded/cancelled orders, and never for live Stripe.
  select * into v_ledger from public.food_stripe_payments
    where order_id = p_order_id;
  if v_order.payment_status <> 'paid'
    or v_order.payment_provider is distinct from 'stripe'
    or v_order.refund_status is distinct from 'none'
    or v_order.status = 'cancelled'
    or not found
    or v_ledger.status <> 'paid'
    or v_ledger.livemode is distinct from false
    or v_ledger.store_id is distinct from v_store_id
    or v_ledger.currency is distinct from 'thb'
    or v_ledger.payment_intent_id is distinct from v_order.stripe_payment_intent_id
  then
    return jsonb_build_object('status','not_eligible_paid_qa_stripe_order',
      'order_id',p_order_id,'mode','simulation_only',
      'snapshot_created',false,'actually_collected_gp_satang',0);
  end if;

  if v_order.subtotal < 0 or v_order.delivery_fee < 0 or v_order.total <= 0
     or v_order.subtotal * 100 <> trunc(v_order.subtotal * 100)
     or v_order.delivery_fee * 100 <> trunc(v_order.delivery_fee * 100)
     or v_order.total * 100 <> trunc(v_order.total * 100) then
    raise exception 'order monetary values require nonnegative THB amounts to two decimals';
  end if;

  v_food := (v_order.subtotal * 100)::bigint;
  v_delivery := (v_order.delivery_fee * 100)::bigint;
  v_total := (v_order.total * 100)::bigint;
  if v_ledger.amount_satang <> v_total then
    raise exception 'paid Stripe amount differs from order total';
  end if;
  if v_total > v_food + v_delivery then
    raise exception 'order total exceeds food plus delivery; review fee policy first';
  end if;
  v_discount := v_food + v_delivery - v_total;
  v_calc := public.food_gp_calculate_qa(v_food,v_rate.rate_bps);

  insert into public.food_gp_order_snapshots(
    order_id, store_id, order_number, rate_bps, rate_configured_at,
    food_subtotal_satang, delivery_fee_satang, customer_paid_satang,
    order_discount_satang, estimated_gp_satang, estimated_store_food_satang,
    stripe_payment_intent_id
  ) values (
    v_order.id, v_order.store_id, v_order.order_number, v_rate.rate_bps,
    v_rate.updated_at, v_food, v_delivery, v_total, v_discount,
    (v_calc->>'estimated_gp_satang')::bigint,
    (v_calc->>'estimated_store_food_satang')::bigint,
    v_ledger.payment_intent_id
  );

  select * into v_existing from public.food_gp_order_snapshots
    where order_id = p_order_id;
  return jsonb_build_object('status','snapshotted','snapshot',to_jsonb(v_existing),
    'snapshot_created',true,'actually_collected_gp_satang',0);
end;
$$;
revoke all on function public.food_gp_capture_order_qa(uuid) from public, anon, authenticated;
grant execute on function public.food_gp_capture_order_qa(uuid) to service_role;

-- Audited/admin-gated read of the frozen simulation; no buyer PII is exposed.
create or replace function public.admin_food_gp_order_snapshot(p_order_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_row public.food_gp_order_snapshots%rowtype;
begin
  if not public.wynos_gp_qa_is_admin() then
    raise exception 'Only WYNOS GP admins' using errcode = '42501';
  end if;
  select * into v_row from public.food_gp_order_snapshots where order_id=p_order_id;
  if not found then return jsonb_build_object('exists',false,'mode','simulation_only'); end if;
  return jsonb_build_object('exists',true,'snapshot',to_jsonb(v_row),'mode','simulation_only');
end;
$$;
revoke all on function public.admin_food_gp_order_snapshot(uuid) from public, anon;
grant execute on function public.admin_food_gp_order_snapshot(uuid) to authenticated, service_role;
