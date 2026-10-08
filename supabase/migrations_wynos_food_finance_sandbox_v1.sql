-- WYNOS Food Finance & Revenue Sharing v1 -- QA/Sandbox ONLY.
-- For Supabase QA project pcatuxtenluqzjzzwsvl, not Production.
-- All financial projections are immutable and SIMULATION ONLY.
-- No Stripe API call, application_fee_amount, transfer, payout, or webhook change.
-- Rates are not created here; source is an existing immutable GP order snapshot.

create table if not exists public.food_finance_order_projections_qa (
  order_id uuid primary key references public.food_gp_order_snapshots(order_id)
    on delete restrict,
  store_id uuid not null references public.food_stores(id) on delete restrict,
  order_number text not null,
  stripe_account_id text not null,
  stripe_payment_intent_id text not null,
  payment_method text not null default 'promptpay' check (payment_method = 'promptpay'),
  charge_model text not null default 'direct_charge_connected_account'
    check (charge_model = 'direct_charge_connected_account'),
  currency text not null default 'thb' check (currency = 'thb'),
  food_gross_satang bigint not null check (food_gross_satang >= 0),
  delivery_fee_satang bigint not null check (delivery_fee_satang >= 0),
  unallocated_discount_satang bigint not null check (unallocated_discount_satang >= 0),
  customer_paid_satang bigint not null check (customer_paid_satang > 0),
  gp_rate_bps integer not null check (gp_rate_bps between 0 and 10000),
  estimated_platform_gp_satang bigint not null check (estimated_platform_gp_satang >= 0),
  estimated_store_food_satang bigint not null check (estimated_store_food_satang >= 0),
  -- Provider fee is deliberately UNKNOWN, not zero and not a live estimate.
  stripe_processing_fee_satang bigint check (stripe_processing_fee_satang is null),
  stripe_fee_status text not null default 'unknown'
    check (stripe_fee_status = 'unknown'),
  discount_allocation_status text not null default 'unallocated'
    check (discount_allocation_status = 'unallocated'),
  merchant_payout_status text not null default 'not_reconciled'
    check (merchant_payout_status = 'not_reconciled'),
  actually_collected_gp_satang bigint not null default 0
    check (actually_collected_gp_satang = 0),
  actual_platform_transfer_satang bigint not null default 0
    check (actual_platform_transfer_satang = 0),
  mode text not null default 'simulation_only'
    check (mode = 'simulation_only'),
  created_at timestamptz not null default now(),
  constraint food_finance_customer_reconciliation_qa check (
    food_gross_satang + delivery_fee_satang
      = customer_paid_satang + unallocated_discount_satang
  ),
  constraint food_finance_food_share_reconciliation_qa check (
    estimated_platform_gp_satang + estimated_store_food_satang
      = food_gross_satang
  )
);

-- Signed reconciliation lines in two independent, balanced books:
-- customer_reconciliation: gross food + delivery - discount - customer paid = 0
-- food_share_projection: estimated GP + estimated merchant food - food basis = 0
-- These are NOT actual double-entry entries, receivables or Stripe transfers.
create table if not exists public.food_finance_projection_lines_qa (
  order_id uuid not null references public.food_finance_order_projections_qa(order_id)
    on delete restrict,
  book text not null check (book in ('customer_reconciliation','food_share_projection')),
  line_type text not null check (line_type in (
    'food_gross', 'delivery_fee', 'unallocated_discount', 'customer_paid',
    'estimated_platform_gp', 'estimated_store_food', 'food_basis_offset'
  )),
  signed_amount_satang bigint not null,
  mode text not null default 'simulation_only' check (mode = 'simulation_only'),
  primary key (order_id, book, line_type),
  constraint food_finance_line_book_qa check (
    (
      book = 'customer_reconciliation'
      and line_type in ('food_gross','delivery_fee','unallocated_discount','customer_paid')
      and (
        (line_type in ('food_gross','delivery_fee') and signed_amount_satang >= 0)
        or (line_type in ('unallocated_discount','customer_paid') and signed_amount_satang <= 0)
      )
    ) or (
      book = 'food_share_projection'
      and line_type in ('estimated_platform_gp','estimated_store_food','food_basis_offset')
      and (
        (line_type in ('estimated_platform_gp','estimated_store_food') and signed_amount_satang >= 0)
        or (line_type = 'food_basis_offset' and signed_amount_satang <= 0)
      )
    )
  )
);

create index if not exists food_finance_order_projections_store_created_qa_idx
  on public.food_finance_order_projections_qa(store_id, created_at desc);

alter table public.food_finance_order_projections_qa enable row level security;
alter table public.food_finance_projection_lines_qa enable row level security;
revoke all on table public.food_finance_order_projections_qa,
  public.food_finance_projection_lines_qa from public, anon, authenticated;
grant select, insert on table public.food_finance_order_projections_qa,
  public.food_finance_projection_lines_qa to service_role;

create or replace function public.food_finance_immutable_qa()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'QA finance projections and lines are immutable'
    using errcode='23514';
end;
$$;
revoke all on function public.food_finance_immutable_qa() from public,anon,authenticated;

drop trigger if exists food_finance_projections_immutable_qa
  on public.food_finance_order_projections_qa;
create trigger food_finance_projections_immutable_qa
  before update or delete on public.food_finance_order_projections_qa
  for each row execute function public.food_finance_immutable_qa();

drop trigger if exists food_finance_lines_immutable_qa
  on public.food_finance_projection_lines_qa;
create trigger food_finance_lines_immutable_qa
  before update or delete on public.food_finance_projection_lines_qa
  for each row execute function public.food_finance_immutable_qa();

-- Deliberately explicit invocation by service_role, NOT checkout/webhook.
-- Only accepts a frozen GP snapshot tied to a currently paid, non-refunded,
-- test-mode PromptPay direct charge with matching ledger/order/account data.
create or replace function public.food_finance_capture_order_qa(p_order_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_order public.food_orders%rowtype;
  v_snap public.food_gp_order_snapshots%rowtype;
  v_pay public.food_stripe_payments%rowtype;
  v_acct public.food_stripe_accounts%rowtype;
  v_projection public.food_finance_order_projections_qa%rowtype;
  v_recon bigint;
  v_share bigint;
begin
  if p_order_id is null then raise exception 'order id required'; end if;

  select * into v_order from public.food_orders where id=p_order_id for update;
  if not found then raise exception 'order not found'; end if;

  select * into v_projection from public.food_finance_order_projections_qa
    where order_id = p_order_id;
  if found then
    return jsonb_build_object('status','already_projected', 'projection',
      to_jsonb(v_projection), 'mode','simulation_only');
  end if;

  select * into v_snap from public.food_gp_order_snapshots
    where order_id=p_order_id;
  if not found then
    return jsonb_build_object('status','gp_snapshot_not_available',
      'order_id',p_order_id,'projection_created',false,
      'actually_collected_gp_satang',0,'mode','simulation_only');
  end if;

  select * into v_pay from public.food_stripe_payments
    where order_id=p_order_id;
  if not found then
    return jsonb_build_object('status','ineligible_payment',
      'order_id',p_order_id,'projection_created',false,
      'actually_collected_gp_satang',0,'mode','simulation_only');
  end if;

  select * into v_acct from public.food_stripe_accounts
    where store_id=v_order.store_id;
  if not found or v_order.payment_status is distinct from 'paid'
    or v_order.payment_provider is distinct from 'stripe'
    or v_order.refund_status is distinct from 'none'
    or v_order.status='cancelled'
    or v_pay.status is distinct from 'paid'
    or v_pay.payment_method is distinct from 'promptpay'
    or v_pay.livemode is distinct from false
    or v_acct.livemode is distinct from false
    or v_acct.account_type is distinct from 'standard'
    or v_acct.country is distinct from 'TH'
    or v_pay.currency is distinct from 'thb'
    or v_pay.store_id is distinct from v_order.store_id
    or v_snap.store_id is distinct from v_order.store_id
    or v_pay.stripe_account_id is distinct from v_acct.stripe_account_id
    or v_pay.payment_intent_id is null
    or v_pay.payment_intent_id is distinct from v_order.stripe_payment_intent_id
    or v_pay.payment_intent_id is distinct from v_snap.stripe_payment_intent_id
    or v_snap.mode is distinct from 'simulation_only'
    or v_snap.actually_collected_gp_satang <> 0
    or v_pay.amount_satang is distinct from v_snap.customer_paid_satang
    or v_snap.currency is distinct from 'thb'
    or v_snap.basis is distinct from 'food_subtotal_excluding_delivery'
  then
    return jsonb_build_object('status','ineligible_payment',
      'order_id',p_order_id,'projection_created',false,
      'actually_collected_gp_satang',0,'mode','simulation_only');
  end if;

  if v_snap.food_subtotal_satang + v_snap.delivery_fee_satang
    <> v_snap.customer_paid_satang + v_snap.order_discount_satang
    or v_snap.estimated_gp_satang + v_snap.estimated_store_food_satang
    <> v_snap.food_subtotal_satang then
    raise exception 'GP snapshot finance reconciliation mismatch';
  end if;

  insert into public.food_finance_order_projections_qa (
    order_id,store_id,order_number,stripe_account_id,stripe_payment_intent_id,
    food_gross_satang,delivery_fee_satang,unallocated_discount_satang,
    customer_paid_satang,gp_rate_bps,estimated_platform_gp_satang,
    estimated_store_food_satang
  ) values (
    v_snap.order_id,v_snap.store_id,v_snap.order_number,
    v_pay.stripe_account_id,v_pay.payment_intent_id,
    v_snap.food_subtotal_satang,v_snap.delivery_fee_satang,
    v_snap.order_discount_satang,v_snap.customer_paid_satang,
    v_snap.rate_bps,v_snap.estimated_gp_satang,v_snap.estimated_store_food_satang
  );

  insert into public.food_finance_projection_lines_qa(
    order_id,book,line_type,signed_amount_satang
  ) values
    (p_order_id,'customer_reconciliation','food_gross',v_snap.food_subtotal_satang),
    (p_order_id,'customer_reconciliation','delivery_fee',v_snap.delivery_fee_satang),
    (p_order_id,'customer_reconciliation','unallocated_discount',-v_snap.order_discount_satang),
    (p_order_id,'customer_reconciliation','customer_paid',-v_snap.customer_paid_satang),
    (p_order_id,'food_share_projection','estimated_platform_gp',v_snap.estimated_gp_satang),
    (p_order_id,'food_share_projection','estimated_store_food',v_snap.estimated_store_food_satang),
    (p_order_id,'food_share_projection','food_basis_offset',-v_snap.food_subtotal_satang);

  select coalesce(sum(signed_amount_satang),0) into v_recon
  from public.food_finance_projection_lines_qa
  where order_id=p_order_id and book='customer_reconciliation';
  select coalesce(sum(signed_amount_satang),0) into v_share
  from public.food_finance_projection_lines_qa
  where order_id=p_order_id and book='food_share_projection';
  if v_recon <> 0 or v_share <> 0 then
    raise exception 'finance reconciliation books are not balanced';
  end if;

  select * into v_projection from public.food_finance_order_projections_qa
    where order_id=p_order_id;
  return jsonb_build_object('status','projected',
    'projection_created',true,
    'projection',to_jsonb(v_projection),
    'customer_book_balance_satang',v_recon,
    'food_share_book_balance_satang',v_share,
    'mode','simulation_only');
end;
$$;

revoke all on function public.food_finance_capture_order_qa(uuid)
  from public, anon, authenticated;
grant execute on function public.food_finance_capture_order_qa(uuid)
  to service_role;

-- Read-only, explicitly allowlisted QA admin summary. Never reveals buyer PII.
create or replace function public.admin_food_finance_order_qa(p_order_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_projection public.food_finance_order_projections_qa%rowtype;
  v_lines jsonb;
begin
  if not public.wynos_gp_qa_is_admin() then
    raise exception 'Only WYNOS GP admins' using errcode='42501';
  end if;
  select * into v_projection from public.food_finance_order_projections_qa
    where order_id=p_order_id;
  if not found then
    return jsonb_build_object('exists',false,'mode','simulation_only');
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object('book',book,'line_type',line_type,
      'signed_amount_satang',signed_amount_satang)
    order by book,line_type
  ), '[]'::jsonb) into v_lines
  from public.food_finance_projection_lines_qa where order_id=p_order_id;

  return jsonb_build_object('exists',true,'mode','simulation_only',
    'projection',to_jsonb(v_projection),'lines',v_lines);
end;
$$;
revoke all on function public.admin_food_finance_order_qa(uuid) from public,anon;
grant execute on function public.admin_food_finance_order_qa(uuid)
  to authenticated,service_role;
