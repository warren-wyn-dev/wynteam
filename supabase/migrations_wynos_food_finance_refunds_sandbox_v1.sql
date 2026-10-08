-- WYNOS Finance refund adjustments v1 - QA/Sandbox only.
-- Target: pcatuxtenluqzjzzwsvl ONLY; never run in Production.
-- SIMULATION ONLY: no actual refund, transfer, payout, Stripe API or webhook call.
-- No default GP percentage. Based solely on frozen per-order Finance projection.
-- Existing GP/Finance snapshots remain immutable.

create table if not exists public.food_finance_refund_adjustments_qa (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.food_finance_order_projections_qa(order_id)
    on delete restrict,
  store_id uuid not null references public.food_stores(id) on delete restrict,
  simulation_key text not null check (
    simulation_key ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{2,79}$'
  ),
  sequence_number integer not null check (sequence_number > 0),
  reason text not null check (char_length(btrim(reason)) between 3 and 500),
  currency text not null default 'thb' check (currency = 'thb'),
  refund_kind text not null check (refund_kind in ('partial','full')),
  food_refund_satang bigint not null check (food_refund_satang >= 0),
  delivery_refund_satang bigint not null check (delivery_refund_satang >= 0),
  customer_refund_satang bigint not null check (customer_refund_satang > 0),
  estimated_platform_gp_reversal_satang bigint not null
    check (estimated_platform_gp_reversal_satang >= 0),
  estimated_store_food_reversal_satang bigint not null
    check (estimated_store_food_reversal_satang >= 0),
  cumulative_food_refund_satang bigint not null
    check (cumulative_food_refund_satang >= 0),
  cumulative_delivery_refund_satang bigint not null
    check (cumulative_delivery_refund_satang >= 0),
  cumulative_customer_refund_satang bigint not null
    check (cumulative_customer_refund_satang > 0),
  cumulative_gp_reversal_satang bigint not null
    check (cumulative_gp_reversal_satang >= 0),
  remaining_customer_paid_satang bigint not null
    check (remaining_customer_paid_satang >= 0),
  remaining_estimated_gp_satang bigint not null
    check (remaining_estimated_gp_satang >= 0),
  remaining_estimated_store_food_satang bigint not null
    check (remaining_estimated_store_food_satang >= 0),
  stripe_fee_refund_satang bigint check (stripe_fee_refund_satang is null),
  stripe_fee_refund_status text not null default 'unknown'
    check (stripe_fee_refund_status = 'unknown'),
  actual_customer_refunded_satang bigint not null default 0
    check (actual_customer_refunded_satang = 0),
  actual_platform_gp_reversed_satang bigint not null default 0
    check (actual_platform_gp_reversed_satang = 0),
  stripe_refund_id text check (stripe_refund_id is null),
  mode text not null default 'simulation_only' check (mode = 'simulation_only'),
  created_at timestamptz not null default now(),
  unique (order_id, simulation_key),
  unique (order_id, sequence_number),
  constraint food_finance_refund_customer_split_qa check (
    food_refund_satang + delivery_refund_satang = customer_refund_satang
  ),
  constraint food_finance_refund_share_split_qa check (
    estimated_platform_gp_reversal_satang
      + estimated_store_food_reversal_satang = food_refund_satang
  ),
  constraint food_finance_refund_kind_qa check (
    (refund_kind='full' and remaining_customer_paid_satang=0)
    or (refund_kind='partial' and remaining_customer_paid_satang>0)
  )
);

create table if not exists public.food_finance_refund_lines_qa (
  adjustment_id uuid not null references public.food_finance_refund_adjustments_qa(id)
    on delete restrict,
  book text not null check (book in (
    'customer_refund_reversal','food_share_refund_reversal'
  )),
  line_type text not null check (line_type in (
    'customer_refund','food_refund','delivery_refund',
    'gp_reversal','store_food_reversal','food_basis_restore'
  )),
  signed_amount_satang bigint not null,
  mode text not null default 'simulation_only' check (mode='simulation_only'),
  primary key (adjustment_id,book,line_type),
  constraint food_finance_refund_line_sign_qa check (
    (book='customer_refund_reversal' and (
      (line_type='customer_refund' and signed_amount_satang>0)
      or (line_type in ('food_refund','delivery_refund') and signed_amount_satang<=0)
    )) or
    (book='food_share_refund_reversal' and (
      (line_type in ('gp_reversal','store_food_reversal') and signed_amount_satang<=0)
      or (line_type='food_basis_restore' and signed_amount_satang>=0)
    ))
  )
);
create index if not exists food_finance_refunds_order_seq_qa_idx
  on public.food_finance_refund_adjustments_qa(order_id,sequence_number);

alter table public.food_finance_refund_adjustments_qa enable row level security;
alter table public.food_finance_refund_lines_qa enable row level security;
revoke all on public.food_finance_refund_adjustments_qa,
  public.food_finance_refund_lines_qa from public,anon,authenticated;
grant select,insert on public.food_finance_refund_adjustments_qa,
  public.food_finance_refund_lines_qa to service_role;

drop trigger if exists food_finance_refunds_immutable_qa
  on public.food_finance_refund_adjustments_qa;
create trigger food_finance_refunds_immutable_qa
  before update or delete on public.food_finance_refund_adjustments_qa
  for each row execute function public.food_finance_immutable_qa();

drop trigger if exists food_finance_refund_lines_immutable_qa
  on public.food_finance_refund_lines_qa;
create trigger food_finance_refund_lines_immutable_qa
  before update or delete on public.food_finance_refund_lines_qa
  for each row execute function public.food_finance_immutable_qa();

-- Pure hypothetical calculation: any rate supplied here is ONLY A TEST INPUT.
-- GP reversal is the difference between two CUMULATIVE half-up amounts.
-- Thus splitting one return into 2+ events gives the same eventual total GP
-- reversal as one full refund (no per-event rounding drift).
create or replace function public.food_finance_refund_math_qa(
  p_food_gross_satang bigint,
  p_delivery_gross_satang bigint,
  p_hypothetical_rate_bps integer,
  p_food_already_refunded_satang bigint,
  p_delivery_already_refunded_satang bigint,
  p_new_food_refund_satang bigint,
  p_new_delivery_refund_satang bigint
) returns jsonb language plpgsql immutable set search_path='' as $$
declare
  v_new_food_cumulative bigint;
  v_new_delivery_cumulative bigint;
  v_before_gp bigint;
  v_after_gp bigint;
  v_original_gp bigint;
  v_event_gp bigint;
  v_remaining_gp bigint;
  v_refund_amount bigint;
begin
  if p_food_gross_satang is null or p_delivery_gross_satang is null
     or p_food_already_refunded_satang is null
     or p_delivery_already_refunded_satang is null
     or p_new_food_refund_satang is null or p_new_delivery_refund_satang is null
     or p_food_gross_satang < 0 or p_delivery_gross_satang < 0
     or p_food_gross_satang + p_delivery_gross_satang > 100000000000
     or p_food_already_refunded_satang < 0
     or p_delivery_already_refunded_satang < 0
     or p_new_food_refund_satang < 0 or p_new_delivery_refund_satang < 0
     or p_hypothetical_rate_bps is null
     or p_hypothetical_rate_bps not between 0 and 10000
  then raise exception 'invalid QA refund calculator arguments'; end if;

  v_refund_amount := p_new_food_refund_satang + p_new_delivery_refund_satang;
  v_new_food_cumulative := p_food_already_refunded_satang+p_new_food_refund_satang;
  v_new_delivery_cumulative := p_delivery_already_refunded_satang+p_new_delivery_refund_satang;
  if v_refund_amount <= 0 or v_new_food_cumulative > p_food_gross_satang
    or v_new_delivery_cumulative > p_delivery_gross_satang then
    raise exception 'refund exceeds remaining food or delivery';
  end if;

  v_original_gp := floor(p_food_gross_satang::numeric
    * p_hypothetical_rate_bps/10000 + 0.5)::bigint;
  v_before_gp := floor(p_food_already_refunded_satang::numeric
    * p_hypothetical_rate_bps/10000 + 0.5)::bigint;
  v_after_gp := floor(v_new_food_cumulative::numeric
    * p_hypothetical_rate_bps/10000 + 0.5)::bigint;
  v_event_gp := v_after_gp-v_before_gp;
  v_remaining_gp := v_original_gp-v_after_gp;
  return jsonb_build_object(
    'mode','simulation_only',
    'rate_source','hypothetical_input_only',
    'customer_refund_satang',v_refund_amount,
    'food_refund_satang',p_new_food_refund_satang,
    'delivery_refund_satang',p_new_delivery_refund_satang,
    'estimated_platform_gp_reversal_satang',v_event_gp,
    'estimated_store_food_reversal_satang',p_new_food_refund_satang-v_event_gp,
    'cumulative_food_refund_satang',v_new_food_cumulative,
    'cumulative_delivery_refund_satang',v_new_delivery_cumulative,
    'cumulative_customer_refund_satang',
      v_new_food_cumulative+v_new_delivery_cumulative,
    'cumulative_gp_reversal_satang',v_after_gp,
    'remaining_estimated_gp_satang',v_remaining_gp,
    'remaining_estimated_store_food_satang',
      (p_food_gross_satang-v_original_gp)
       -(v_new_food_cumulative-v_after_gp),
    'remaining_customer_paid_satang',
      p_food_gross_satang+p_delivery_gross_satang-
       v_new_food_cumulative-v_new_delivery_cumulative,
    'actual_customer_refunded_satang',0,
    'actual_platform_gp_reversed_satang',0,
    'stripe_fee_refund_satang',null,
    'stripe_fee_refund_status','unknown'
  );
end;
$$;
revoke all on function public.food_finance_refund_math_qa(
  bigint,bigint,integer,bigint,bigint,bigint,bigint
) from public,anon,authenticated;
grant execute on function public.food_finance_refund_math_qa(
  bigint,bigint,integer,bigint,bigint,bigint,bigint
) to service_role;

-- Trusted explicit QA simulation only. NEVER wired into refund/webhook.
-- The original projection is locked to serialize concurrent simulated
-- refunds and eliminate double-spend/over-refund races per order.
create or replace function public.food_finance_append_refund_qa(
  p_order_id uuid,
  p_simulation_key text,
  p_food_refund_satang bigint,
  p_delivery_refund_satang bigint,
  p_reason text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_proj public.food_finance_order_projections_qa%rowtype;
  v_existing public.food_finance_refund_adjustments_qa%rowtype;
  v_order public.food_orders%rowtype;
  v_payment public.food_stripe_payments%rowtype;
  v_key text := btrim(coalesce(p_simulation_key,''));
  v_reason text := btrim(coalesce(p_reason,''));
  v_prev_food bigint;
  v_prev_delivery bigint;
  v_prev_customer bigint;
  v_seq integer;
  v_math jsonb;
  v_event_gp bigint;
  v_event_store bigint;
  v_customer_refund bigint;
  v_refund_id uuid;
  v_balance_customer bigint;
  v_balance_share bigint;
begin
  if p_order_id is null then raise exception 'order id required'; end if;
  if v_key !~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{2,79}$' then
    raise exception 'QA simulation key must be 3-80 safe characters';
  end if;
  if char_length(v_reason) not between 3 and 500 then
    raise exception 'refund reason must be between 3 and 500 chars';
  end if;
  if p_food_refund_satang is null or p_delivery_refund_satang is null
     or p_food_refund_satang < 0 or p_delivery_refund_satang < 0
     or p_food_refund_satang+p_delivery_refund_satang <= 0 then
    raise exception 'invalid refund amount';
  end if;

  select * into v_proj from public.food_finance_order_projections_qa
    where order_id=p_order_id for update;
  if not found then return jsonb_build_object('status','finance_projection_not_available',
    'order_id',p_order_id,'simulation_only',true,'actual_customer_refunded_satang',0); end if;

  select * into v_existing from public.food_finance_refund_adjustments_qa
    where order_id=p_order_id and simulation_key=v_key;
  if found then
    if v_existing.food_refund_satang is distinct from p_food_refund_satang
      or v_existing.delivery_refund_satang is distinct from p_delivery_refund_satang
      or v_existing.reason is distinct from v_reason then
      raise exception 'simulation key replay payload mismatch';
    end if;
    return jsonb_build_object('status','already_adjusted',
      'adjustment',to_jsonb(v_existing),'mode','simulation_only');
  end if;

  -- Never simulate unapproved discount payer rules by claiming a net refund
  -- or applying a false GP reversal. Delay until policy is approved.
  if v_proj.unallocated_discount_satang <> 0 then
    return jsonb_build_object('status','discount_allocation_unresolved',
      'order_id',p_order_id,'simulation_only',true,'adjustment_created',false,
      'actual_customer_refunded_satang',0);
  end if;

  select * into v_order from public.food_orders where id=p_order_id;
  select * into v_payment from public.food_stripe_payments where order_id=p_order_id;
  if v_order.payment_status is distinct from 'paid'
    or v_order.refund_status is distinct from 'none'
    or v_order.status is distinct from 'pending_acceptance'
       and v_order.status is distinct from 'preparing'
       and v_order.status is distinct from 'ready_for_delivery'
       and v_order.status is distinct from 'out_for_delivery'
       and v_order.status is distinct from 'delivered'
    or v_payment.status is distinct from 'paid'
    or v_payment.payment_method is distinct from 'promptpay'
    or v_payment.livemode is distinct from false
    or v_payment.currency is distinct from 'thb'
    or v_payment.stripe_account_id is distinct from v_proj.stripe_account_id
    or v_payment.payment_intent_id is distinct from v_proj.stripe_payment_intent_id
    or v_payment.amount_satang is distinct from v_proj.customer_paid_satang
    or v_proj.mode is distinct from 'simulation_only'
  then return jsonb_build_object('status','payment_state_not_eligible',
    'order_id',p_order_id,'adjustment_created',false,
    'actual_customer_refunded_satang',0,'mode','simulation_only'); end if;

  select coalesce(sum(food_refund_satang),0),
    coalesce(sum(delivery_refund_satang),0),
    coalesce(sum(customer_refund_satang),0),
    count(*)::integer
  into v_prev_food,v_prev_delivery,v_prev_customer,v_seq
  from public.food_finance_refund_adjustments_qa where order_id=p_order_id;

  -- Discount=0: customer refund = food refund + delivery refund.
  -- No cross-category overspending even when multiple refunds are submitted.
  v_math := public.food_finance_refund_math_qa(
    v_proj.food_gross_satang,
    v_proj.delivery_fee_satang,
    v_proj.gp_rate_bps,
    v_prev_food,v_prev_delivery,
    p_food_refund_satang,p_delivery_refund_satang
  );
  v_customer_refund := (v_math->>'customer_refund_satang')::bigint;
  if v_prev_customer + v_customer_refund > v_proj.customer_paid_satang then
    raise exception 'cumulative refund exceeds customer payment';
  end if;
  v_event_gp := (v_math->>'estimated_platform_gp_reversal_satang')::bigint;
  v_event_store := (v_math->>'estimated_store_food_reversal_satang')::bigint;

  insert into public.food_finance_refund_adjustments_qa(
    order_id,store_id,simulation_key,sequence_number,reason,refund_kind,
    food_refund_satang,delivery_refund_satang,customer_refund_satang,
    estimated_platform_gp_reversal_satang,
    estimated_store_food_reversal_satang,
    cumulative_food_refund_satang,cumulative_delivery_refund_satang,
    cumulative_customer_refund_satang,cumulative_gp_reversal_satang,
    remaining_customer_paid_satang,remaining_estimated_gp_satang,
    remaining_estimated_store_food_satang
  ) values (
    p_order_id,v_proj.store_id,v_key,v_seq+1,v_reason,
    case when (v_math->>'remaining_customer_paid_satang')::bigint=0
      then 'full' else 'partial' end,
    p_food_refund_satang,p_delivery_refund_satang,v_customer_refund,
    v_event_gp,v_event_store,
    (v_math->>'cumulative_food_refund_satang')::bigint,
    (v_math->>'cumulative_delivery_refund_satang')::bigint,
    (v_math->>'cumulative_customer_refund_satang')::bigint,
    (v_math->>'cumulative_gp_reversal_satang')::bigint,
    (v_math->>'remaining_customer_paid_satang')::bigint,
    (v_math->>'remaining_estimated_gp_satang')::bigint,
    (v_math->>'remaining_estimated_store_food_satang')::bigint
  ) returning id into v_refund_id;

  insert into public.food_finance_refund_lines_qa(
    adjustment_id,book,line_type,signed_amount_satang
  ) values
   (v_refund_id,'customer_refund_reversal','customer_refund',v_customer_refund),
   (v_refund_id,'customer_refund_reversal','food_refund',-p_food_refund_satang),
   (v_refund_id,'customer_refund_reversal','delivery_refund',-p_delivery_refund_satang),
   (v_refund_id,'food_share_refund_reversal','gp_reversal',-v_event_gp),
   (v_refund_id,'food_share_refund_reversal','store_food_reversal',-v_event_store),
   (v_refund_id,'food_share_refund_reversal','food_basis_restore',p_food_refund_satang);

  select sum(signed_amount_satang) into v_balance_customer
   from public.food_finance_refund_lines_qa
   where adjustment_id=v_refund_id and book='customer_refund_reversal';
  select sum(signed_amount_satang) into v_balance_share
   from public.food_finance_refund_lines_qa
   where adjustment_id=v_refund_id and book='food_share_refund_reversal';
  if v_balance_customer is distinct from 0 or v_balance_share is distinct from 0 then
    raise exception 'simulated refund reconciliation books not balanced';
  end if;

  select * into v_existing from public.food_finance_refund_adjustments_qa
   where id=v_refund_id;
  return jsonb_build_object('status','adjusted','adjustment_created',true,
    'adjustment',to_jsonb(v_existing),'customer_book_balance_satang',v_balance_customer,
    'food_share_book_balance_satang',v_balance_share,'mode','simulation_only');
end;
$$;

revoke all on function public.food_finance_append_refund_qa(
  uuid,text,bigint,bigint,text
) from public,anon,authenticated;
grant execute on function public.food_finance_append_refund_qa(
  uuid,text,bigint,bigint,text
) to service_role;

-- Read-only GP-allowlisted QA Admin; no raw user PII, no merchant access.
create or replace function public.admin_food_finance_refunds_qa(p_order_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_projection public.food_finance_order_projections_qa%rowtype;
  v_adjustments jsonb;
  v_count bigint;
begin
  if not public.wynos_gp_qa_is_admin() then
    raise exception 'Only WYNOS GP admins' using errcode='42501';
  end if;
  select * into v_projection from public.food_finance_order_projections_qa
    where order_id=p_order_id;
  if not found then return jsonb_build_object('exists',false,'mode','simulation_only'); end if;
  select count(*),coalesce(jsonb_agg(to_jsonb(a)
    order by a.sequence_number),'[]'::jsonb)
    into v_count,v_adjustments
    from public.food_finance_refund_adjustments_qa a where a.order_id=p_order_id;
  return jsonb_build_object('exists',true,'mode','simulation_only',
    'order_id',p_order_id,'refund_adjustments_count',v_count,
    'adjustments',v_adjustments,
    'actual_customer_refunded_satang',0,'actually_collected_gp_satang',0);
end;
$$;
revoke all on function public.admin_food_finance_refunds_qa(uuid) from public,anon;
grant execute on function public.admin_food_finance_refunds_qa(uuid)
  to authenticated,service_role;
