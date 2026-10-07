-- WYNOS Finance Control Center v1
-- Additive finance/control-plane schema for WYNOS Food, Merchant, Payment and Rider.
-- Existing order/payment/campaign/Stripe mappings remain authoritative and are never deleted.

-- ---------------------------------------------------------------------------
-- 1. Versioned platform finance configuration
-- ---------------------------------------------------------------------------

create table if not exists public.food_finance_configs (
  id uuid primary key default gen_random_uuid(),
  effective_from timestamptz not null,
  default_gp_bps integer not null default 1000 check (default_gp_bps between 0 and 10000),

  delivery_base_fee_satang bigint not null default 2500 check (delivery_base_fee_satang >= 0),
  delivery_base_distance_m integer not null default 2000 check (delivery_base_distance_m >= 0),
  delivery_per_km_satang bigint not null default 700 check (delivery_per_km_satang >= 0),
  delivery_min_fee_satang bigint not null default 0 check (delivery_min_fee_satang >= 0),
  delivery_max_fee_satang bigint check (delivery_max_fee_satang is null or delivery_max_fee_satang >= delivery_min_fee_satang),
  delivery_rounding_m integer not null default 1000 check (delivery_rounding_m between 1 and 10000),
  free_delivery_threshold_satang bigint check (free_delivery_threshold_satang is null or free_delivery_threshold_satang >= 0),
  peak_surcharge_satang bigint not null default 0 check (peak_surcharge_satang >= 0),
  rain_surcharge_satang bigint not null default 0 check (rain_surcharge_satang >= 0),
  long_distance_threshold_m integer check (long_distance_threshold_m is null or long_distance_threshold_m >= 0),
  long_distance_surcharge_satang bigint not null default 0 check (long_distance_surcharge_satang >= 0),

  rider_base_pay_satang bigint not null default 2500 check (rider_base_pay_satang >= 0),
  rider_pay_per_km_satang bigint not null default 500 check (rider_pay_per_km_satang >= 0),
  rider_min_earning_satang bigint not null default 2500 check (rider_min_earning_satang >= 0),
  rider_long_distance_threshold_m integer check (rider_long_distance_threshold_m is null or rider_long_distance_threshold_m >= 0),
  rider_long_distance_bonus_satang bigint not null default 0 check (rider_long_distance_bonus_satang >= 0),
  rider_peak_bonus_satang bigint not null default 0 check (rider_peak_bonus_satang >= 0),
  rider_rain_bonus_satang bigint not null default 0 check (rider_rain_bonus_satang >= 0),
  rider_incentive_order_count integer check (rider_incentive_order_count is null or rider_incentive_order_count > 0),
  rider_incentive_bonus_satang bigint not null default 0 check (rider_incentive_bonus_satang >= 0),
  rider_platform_fee_bps integer not null default 0 check (rider_platform_fee_bps between 0 and 10000),

  stripe_fee_payer text not null default 'wynos' check (stripe_fee_payer in ('wynos','merchant','shared')),
  stripe_shared_merchant_bps integer not null default 5000 check (stripe_shared_merchant_bps between 0 and 10000),

  service_fee_mode text not null default 'fixed' check (service_fee_mode in ('fixed','percent')),
  service_fee_value bigint not null default 0 check (service_fee_value >= 0),
  service_fee_min_satang bigint not null default 0 check (service_fee_min_satang >= 0),
  service_fee_max_satang bigint check (service_fee_max_satang is null or service_fee_max_satang >= service_fee_min_satang),

  small_order_threshold_satang bigint not null default 0 check (small_order_threshold_satang >= 0),
  small_order_fee_mode text not null default 'fixed' check (small_order_fee_mode in ('fixed','percent')),
  small_order_fee_value bigint not null default 0 check (small_order_fee_value >= 0),
  small_order_fee_max_satang bigint check (small_order_fee_max_satang is null or small_order_fee_max_satang >= 0),

  surge_fee_mode text not null default 'fixed' check (surge_fee_mode in ('fixed','percent')),
  surge_fee_value bigint not null default 0 check (surge_fee_value >= 0),
  surge_fee_max_satang bigint check (surge_fee_max_satang is null or surge_fee_max_satang >= 0),

  tax_enabled boolean not null default false,
  vat_registered boolean not null default false,
  vat_percent_bps integer not null default 700 check (vat_percent_bps between 0 and 10000),

  created_by uuid references auth.users(id) on delete set null,
  reason text not null default 'Initial configuration' check (char_length(reason) between 1 and 500),
  created_at timestamptz not null default now(),
  unique (effective_from)
);

create index if not exists food_finance_configs_effective_idx
  on public.food_finance_configs(effective_from desc);

insert into public.food_finance_configs(
  effective_from, default_gp_bps,
  delivery_base_fee_satang, delivery_base_distance_m, delivery_per_km_satang,
  delivery_min_fee_satang, delivery_rounding_m,
  rider_base_pay_satang, rider_pay_per_km_satang, rider_min_earning_satang,
  stripe_fee_payer, stripe_shared_merchant_bps,
  tax_enabled, vat_registered, vat_percent_bps,
  reason
)
select '-infinity'::timestamptz, 1000,
       2500, 2000, 700, 0, 1000,
       2500, 500, 2500,
       'wynos', 5000,
       false, false, 700,
       'WYNOS Finance Control Center baseline'
where not exists (select 1 from public.food_finance_configs);

create table if not exists public.food_feature_flags (
  flag_key text not null,
  effective_from timestamptz not null,
  enabled boolean not null,
  created_by uuid references auth.users(id) on delete set null,
  reason text not null check (char_length(reason) between 1 and 500),
  created_at timestamptz not null default now(),
  primary key (flag_key, effective_from),
  check (flag_key ~ '^[a-z0-9_]{2,80}$')
);

create index if not exists food_feature_flags_lookup_idx
  on public.food_feature_flags(flag_key, effective_from desc);

insert into public.food_feature_flags(flag_key,effective_from,enabled,reason)
values
  ('promptpay_enabled','-infinity',true,'Current WYNOS default'),
  ('card_enabled','-infinity',false,'Current WYNOS default'),
  ('apple_pay_enabled','-infinity',false,'Current WYNOS default'),
  ('google_pay_enabled','-infinity',false,'Current WYNOS default'),
  ('rider_enabled','-infinity',false,'Prepared but not production-enabled'),
  ('service_fee_enabled','-infinity',false,'Current WYNOS default'),
  ('small_order_fee_enabled','-infinity',false,'Current WYNOS default'),
  ('surge_pricing_enabled','-infinity',false,'Current WYNOS default'),
  ('peak_pricing_enabled','-infinity',false,'Current WYNOS default'),
  ('rain_surcharge_enabled','-infinity',false,'Current WYNOS default'),
  ('merchant_payout_enabled','-infinity',false,'Prepared but not production-enabled'),
  ('promotion_enabled','-infinity',true,'Preserve existing WYNOS Food campaign behavior')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. Merchant/store overrides and effective GP
-- ---------------------------------------------------------------------------

create table if not exists public.food_store_finance_overrides (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id) on delete cascade,
  effective_from timestamptz not null,
  custom_gp_bps integer check (custom_gp_bps is null or custom_gp_bps between 0 and 10000),

  delivery_base_fee_satang bigint check (delivery_base_fee_satang is null or delivery_base_fee_satang >= 0),
  delivery_base_distance_m integer check (delivery_base_distance_m is null or delivery_base_distance_m >= 0),
  delivery_per_km_satang bigint check (delivery_per_km_satang is null or delivery_per_km_satang >= 0),
  delivery_min_fee_satang bigint check (delivery_min_fee_satang is null or delivery_min_fee_satang >= 0),
  delivery_max_fee_satang bigint check (delivery_max_fee_satang is null or delivery_max_fee_satang >= 0),
  delivery_rounding_m integer check (delivery_rounding_m is null or delivery_rounding_m between 1 and 10000),
  free_delivery_threshold_satang bigint check (free_delivery_threshold_satang is null or free_delivery_threshold_satang >= 0),

  payment_enabled boolean,
  payout_suspended boolean,
  promotion_eligible boolean,

  created_by uuid references auth.users(id) on delete set null,
  reason text not null check (char_length(reason) between 1 and 500),
  created_at timestamptz not null default now(),
  unique (store_id, effective_from)
);

create index if not exists food_store_finance_overrides_lookup_idx
  on public.food_store_finance_overrides(store_id, effective_from desc);

-- Preserve every current store's delivery pricing before platform defaults
-- become active. Admin can later create a new override with null delivery
-- fields to inherit platform/zone pricing.
insert into public.food_store_finance_overrides(
  store_id,effective_from,
  delivery_base_fee_satang,delivery_base_distance_m,delivery_per_km_satang,
  delivery_min_fee_satang,delivery_rounding_m,
  payment_enabled,payout_suspended,promotion_eligible,reason
)
select s.id,'-infinity'::timestamptz,
       round(s.delivery_fee * 100)::bigint,
       round(s.delivery_base_km * 1000)::integer,
       round(s.delivery_fee_per_km * 100)::bigint,
       round(s.delivery_fee * 100)::bigint,
       1000,
       null,false,true,
       'Preserve pre-control-center store delivery pricing'
from public.food_stores s
where not exists (
  select 1 from public.food_store_finance_overrides o where o.store_id=s.id
);

create table if not exists public.food_store_gp_promotions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id) on delete cascade,
  gp_bps integer not null check (gp_bps between 0 and 10000),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  reason text not null check (char_length(reason) between 1 and 500),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists food_store_gp_promotions_lookup_idx
  on public.food_store_gp_promotions(store_id, starts_at desc, ends_at);

create table if not exists public.food_delivery_zone_pricing (
  id uuid primary key default gen_random_uuid(),
  service_area_code text references public.food_service_areas(code) on delete cascade,
  province text,
  priority integer not null default 100,
  effective_from timestamptz not null,
  effective_to timestamptz,
  base_fee_satang bigint check (base_fee_satang is null or base_fee_satang >= 0),
  base_distance_m integer check (base_distance_m is null or base_distance_m >= 0),
  per_km_satang bigint check (per_km_satang is null or per_km_satang >= 0),
  min_fee_satang bigint check (min_fee_satang is null or min_fee_satang >= 0),
  max_fee_satang bigint check (max_fee_satang is null or max_fee_satang >= 0),
  rounding_m integer check (rounding_m is null or rounding_m between 1 and 10000),
  free_delivery_threshold_satang bigint check (free_delivery_threshold_satang is null or free_delivery_threshold_satang >= 0),
  created_by uuid references auth.users(id) on delete set null,
  reason text not null check (char_length(reason) between 1 and 500),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from),
  check (service_area_code is not null or province is not null)
);

create index if not exists food_delivery_zone_pricing_lookup_idx
  on public.food_delivery_zone_pricing(service_area_code, effective_from desc, priority);

-- ---------------------------------------------------------------------------
-- 3. Immutable-at-order pricing snapshot + payment fee enrichment
-- ---------------------------------------------------------------------------

alter table public.food_orders
  add column if not exists finance_config_id uuid references public.food_finance_configs(id) on delete restrict,
  add column if not exists service_fee numeric(12,2) not null default 0,
  add column if not exists small_order_fee numeric(12,2) not null default 0,
  add column if not exists surge_fee numeric(12,2) not null default 0;

create table if not exists public.food_order_financials (
  order_id uuid primary key references public.food_orders(id) on delete cascade,
  store_id uuid not null references public.food_stores(id) on delete cascade,
  config_id uuid not null references public.food_finance_configs(id) on delete restrict,
  store_override_id uuid references public.food_store_finance_overrides(id) on delete set null,
  gp_promotion_id uuid references public.food_store_gp_promotions(id) on delete set null,
  gp_source text not null check (gp_source in ('promotion','custom','default')),
  currency text not null default 'thb',

  subtotal_satang bigint not null check (subtotal_satang >= 0),
  delivery_fee_satang bigint not null check (delivery_fee_satang >= 0),
  service_fee_satang bigint not null default 0 check (service_fee_satang >= 0),
  small_order_fee_satang bigint not null default 0 check (small_order_fee_satang >= 0),
  surge_fee_satang bigint not null default 0 check (surge_fee_satang >= 0),

  customer_discount_satang bigint not null default 0 check (customer_discount_satang >= 0),
  merchant_discount_satang bigint not null default 0 check (merchant_discount_satang >= 0),
  platform_discount_satang bigint not null default 0 check (platform_discount_satang >= 0),

  gp_bps integer not null check (gp_bps between 0 and 10000),
  gp_amount_satang bigint not null default 0 check (gp_amount_satang >= 0),

  rider_earning_satang bigint not null default 0 check (rider_earning_satang >= 0),
  rider_bonus_satang bigint not null default 0 check (rider_bonus_satang >= 0),
  rider_adjustment_satang bigint not null default 0,

  stripe_fee_policy text not null check (stripe_fee_policy in ('wynos','merchant','shared')),
  stripe_shared_merchant_bps integer not null default 0 check (stripe_shared_merchant_bps between 0 and 10000),
  stripe_fee_satang bigint not null default 0 check (stripe_fee_satang >= 0),
  stripe_fee_merchant_satang bigint not null default 0 check (stripe_fee_merchant_satang >= 0),
  stripe_fee_platform_satang bigint not null default 0 check (stripe_fee_platform_satang >= 0),

  merchant_adjustment_satang bigint not null default 0,
  platform_adjustment_satang bigint not null default 0,
  merchant_refund_cost_satang bigint not null default 0 check (merchant_refund_cost_satang >= 0),
  platform_refund_cost_satang bigint not null default 0 check (platform_refund_cost_satang >= 0),
  gp_refunded_satang bigint not null default 0 check (gp_refunded_satang >= 0),

  merchant_net_satang bigint not null default 0,
  platform_revenue_satang bigint not null default 0,
  customer_total_satang bigint not null check (customer_total_satang >= 0),

  tax_enabled boolean not null default false,
  vat_registered boolean not null default false,
  vat_percent_bps integer not null default 700 check (vat_percent_bps between 0 and 10000),

  priced_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists food_order_financials_store_priced_idx
  on public.food_order_financials(store_id, priced_at desc);

alter table public.food_stripe_payments
  add column if not exists gross_amount_satang bigint,
  add column if not exists stripe_fee_satang bigint,
  add column if not exists stripe_fee_merchant_satang bigint,
  add column if not exists stripe_fee_platform_satang bigint,
  add column if not exists platform_fee_satang bigint,
  add column if not exists merchant_net_satang bigint,
  add column if not exists stripe_fee_policy text,
  add column if not exists balance_transaction_id text;

alter table public.food_stripe_payments drop constraint if exists food_stripe_payments_fee_policy_check;
alter table public.food_stripe_payments add constraint food_stripe_payments_fee_policy_check
  check (stripe_fee_policy is null or stripe_fee_policy in ('wynos','merchant','shared'));

update public.food_stripe_payments
set gross_amount_satang = coalesce(gross_amount_satang, amount_satang)
where gross_amount_satang is null;

-- ---------------------------------------------------------------------------
-- 4. Refund ledger
-- ---------------------------------------------------------------------------

create table if not exists public.food_refunds (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.food_orders(id) on delete restrict,
  store_id uuid not null references public.food_stores(id) on delete restrict,
  stripe_account_id text not null,
  payment_intent_id text not null,
  stripe_refund_id text unique,
  idempotency_key text not null unique,
  amount_satang bigint not null check (amount_satang > 0),
  currency text not null default 'thb',
  status text not null default 'pending' check (status in ('pending','succeeded','failed','cancelled')),
  reason text not null check (char_length(reason) between 1 and 500),
  liability text not null check (liability in ('wynos','merchant','shared')),
  merchant_liability_satang bigint not null default 0 check (merchant_liability_satang >= 0),
  platform_liability_satang bigint not null default 0 check (platform_liability_satang >= 0),
  refund_gp boolean not null default false,
  gp_refund_satang bigint not null default 0 check (gp_refund_satang >= 0),
  refund_delivery boolean not null default false,
  delivery_refund_satang bigint not null default 0 check (delivery_refund_satang >= 0),
  stripe_refund_fee_satang bigint check (stripe_refund_fee_satang is null or stripe_refund_fee_satang >= 0),
  livemode boolean not null,
  requested_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists food_refunds_order_created_idx
  on public.food_refunds(order_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 5. Merchant settlement ledger
-- ---------------------------------------------------------------------------

create table if not exists public.food_merchant_settlements (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id) on delete restrict,
  period_from timestamptz not null,
  period_to timestamptz not null,
  status text not null default 'pending' check (status in ('pending','paid','cancelled')),
  order_count integer not null check (order_count >= 0),
  gross_sales_satang bigint not null default 0,
  merchant_discount_satang bigint not null default 0,
  gp_satang bigint not null default 0,
  payment_fees_satang bigint not null default 0,
  refunds_satang bigint not null default 0,
  adjustments_satang bigint not null default 0,
  net_satang bigint not null default 0,
  reference text,
  note text,
  created_by uuid references auth.users(id) on delete set null,
  paid_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  check (period_to > period_from)
);

create table if not exists public.food_merchant_settlement_lines (
  settlement_id uuid not null references public.food_merchant_settlements(id) on delete cascade,
  order_id uuid not null references public.food_orders(id) on delete restrict,
  gross_sales_satang bigint not null,
  merchant_discount_satang bigint not null,
  gp_satang bigint not null,
  payment_fees_satang bigint not null,
  refunds_satang bigint not null,
  adjustments_satang bigint not null,
  net_satang bigint not null,
  primary key (settlement_id, order_id),
  unique (order_id)
);

create index if not exists food_merchant_settlements_store_created_idx
  on public.food_merchant_settlements(store_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 6. Rider-ready schema (feature flag remains OFF)
-- ---------------------------------------------------------------------------

create table if not exists public.food_riders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending','approved','suspended','inactive')),
  active boolean not null default false,
  service_area_code text references public.food_service_areas(code) on delete set null,
  payout_suspended boolean not null default false,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  suspended_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.food_rider_jobs (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.food_orders(id) on delete restrict,
  rider_id uuid not null references public.food_riders(id) on delete restrict,
  status text not null default 'assigned' check (status in ('assigned','accepted','picked_up','delivered','cancelled')),
  distance_m integer not null default 0 check (distance_m >= 0),
  base_pay_satang bigint not null default 0,
  distance_pay_satang bigint not null default 0,
  bonus_satang bigint not null default 0,
  gross_earning_satang bigint not null default 0,
  adjustment_satang bigint not null default 0,
  net_earning_satang bigint not null default 0,
  config_id uuid not null references public.food_finance_configs(id) on delete restrict,
  assigned_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.food_rider_adjustments (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid not null references public.food_riders(id) on delete restrict,
  order_id uuid references public.food_orders(id) on delete set null,
  amount_satang bigint not null,
  reason text not null check (char_length(reason) between 1 and 500),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.food_rider_payouts (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid not null references public.food_riders(id) on delete restrict,
  period_from timestamptz not null,
  period_to timestamptz not null,
  gross_earnings_satang bigint not null default 0,
  bonus_satang bigint not null default 0,
  adjustments_satang bigint not null default 0,
  amount_satang bigint not null default 0,
  status text not null default 'pending' check (status in ('pending','paid','cancelled')),
  reference text,
  created_by uuid references auth.users(id) on delete set null,
  paid_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  check (period_to > period_from)
);

-- ---------------------------------------------------------------------------
-- 7. Generic finance adjustments
-- ---------------------------------------------------------------------------

create table if not exists public.food_financial_adjustments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.food_orders(id) on delete restrict,
  store_id uuid references public.food_stores(id) on delete restrict,
  rider_id uuid references public.food_riders(id) on delete restrict,
  applies_to text not null check (applies_to in ('merchant','platform','rider')),
  amount_satang bigint not null,
  reason text not null check (char_length(reason) between 1 and 500),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check (order_id is not null or store_id is not null or rider_id is not null)
);

-- ---------------------------------------------------------------------------
-- 8. Deny-by-default RLS for financial/config/ledger tables
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'food_finance_configs',
    'food_feature_flags',
    'food_store_finance_overrides',
    'food_store_gp_promotions',
    'food_delivery_zone_pricing',
    'food_order_financials',
    'food_refunds',
    'food_merchant_settlements',
    'food_merchant_settlement_lines',
    'food_riders',
    'food_rider_jobs',
    'food_rider_adjustments',
    'food_rider_payouts',
    'food_financial_adjustments'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Audit event types. Keep every existing type.
-- ---------------------------------------------------------------------------

do $$
declare
  v_def text;
  v_types text[];
begin
  select pg_get_constraintdef(c.oid) into v_def
  from pg_constraint c
  where c.conname='audit_log_event_type_check'
    and c.conrelid='public.audit_log'::regclass;

  select coalesce(array_agg(distinct t), '{}') into v_types
  from regexp_matches(coalesce(v_def,''), '''([^'']*)''', 'g') as m,
       unnest(string_to_array(btrim(m[1], '{}'), ',')) as raw,
       btrim(raw, ' "') as t
  where t ~ '^[a-z0-9_]+$';

  select array_agg(distinct t order by t) into v_types
  from unnest(v_types || array[
    'admin_finance_config_changed',
    'admin_feature_flag_changed',
    'admin_store_finance_changed',
    'admin_store_gp_promotion_created',
    'admin_delivery_zone_pricing_changed',
    'admin_finance_adjustment_created',
    'admin_merchant_settlement_created',
    'admin_merchant_settlement_paid',
    'admin_refund_requested',
    'admin_rider_status_changed',
    'admin_rider_adjustment_created',
    'admin_rider_payout_changed'
  ]) as t;

  alter table public.audit_log drop constraint if exists audit_log_event_type_check;
  execute format(
    'alter table public.audit_log add constraint audit_log_event_type_check check (event_type = any (%L::text[]))',
    v_types
  );
end;
$$;
