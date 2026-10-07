-- WYNOS Stripe payment core for WYNOS Food / Merchant.
-- Additive rollout: existing PromptPay + slip flow remains available.
-- Stripe uses Standard Connect + direct charges for Thai merchants; no application fee.
-- Secrets live only in Supabase Edge Function secrets.

alter table public.food_stores
  add column if not exists stripe_payments_enabled boolean not null default false;

alter table public.food_orders
  add column if not exists stripe_checkout_session_id text,
  add column if not exists stripe_payment_intent_id text,
  add column if not exists stripe_refund_id text;

create table if not exists public.food_stripe_accounts (
  store_id uuid primary key references public.food_stores(id) on delete cascade,
  stripe_account_id text not null unique,
  account_type text not null default 'standard' check (account_type = 'standard'),
  country text not null default 'TH' check (country = 'TH'),
  details_submitted boolean not null default false,
  charges_enabled boolean not null default false,
  payouts_enabled boolean not null default false,
  promptpay_enabled boolean not null default false,
  status text not null default 'onboarding' check (status in ('onboarding','pending','ready','restricted')),
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.food_stripe_payments (
  order_id uuid primary key references public.food_orders(id) on delete cascade,
  store_id uuid not null references public.food_stores(id) on delete cascade,
  buyer_id uuid references auth.users(id) on delete set null,
  stripe_account_id text not null,
  checkout_session_id text unique,
  payment_intent_id text unique,
  amount_satang bigint not null check (amount_satang > 0),
  currency text not null default 'thb' check (currency = 'thb'),
  status text not null default 'pending' check (status in ('pending','paid','failed','refunded')),
  attempt integer not null default 1 check (attempt >= 1),
  payment_method text,
  last_error text,
  paid_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.food_stripe_webhook_events (
  event_id text primary key,
  event_type text not null,
  stripe_account_id text,
  order_id uuid references public.food_orders(id) on delete set null,
  object_id text,
  received_at timestamptz not null default now()
);

create index if not exists food_stripe_payments_store_created_idx
  on public.food_stripe_payments(store_id, created_at desc);
create index if not exists food_stripe_webhook_events_received_idx
  on public.food_stripe_webhook_events(received_at desc);

alter table public.food_stripe_accounts enable row level security;
alter table public.food_stripe_payments enable row level security;
alter table public.food_stripe_webhook_events enable row level security;

revoke all on table public.food_stripe_accounts from public, anon, authenticated;
revoke all on table public.food_stripe_payments from public, anon, authenticated;
revoke all on table public.food_stripe_webhook_events from public, anon, authenticated;

-- Merchant-safe status; Stripe account IDs and raw gateway rows stay server-only.
create or replace function public.merchant_stripe_status(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  a public.food_stripe_accounts%rowtype;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin','manager','orders']) then
    raise exception 'merchant access required';
  end if;

  select * into a from public.food_stripe_accounts where store_id = p_store_id;
  if not found then
    return jsonb_build_object(
      'connected', false,
      'status', 'not_connected',
      'details_submitted', false,
      'charges_enabled', false,
      'payouts_enabled', false,
      'promptpay_enabled', false,
      'last_synced_at', null
    );
  end if;

  return jsonb_build_object(
    'connected', true,
    'status', a.status,
    'details_submitted', a.details_submitted,
    'charges_enabled', a.charges_enabled,
    'payouts_enabled', a.payouts_enabled,
    'promptpay_enabled', a.promptpay_enabled,
    'last_synced_at', a.last_synced_at
  );
end;
$$;

revoke all on function public.merchant_stripe_status(uuid) from public, anon;
grant execute on function public.merchant_stripe_status(uuid) to authenticated;

-- Webhook writes are atomic and idempotent. Only service_role can call this.
create or replace function public.food_apply_stripe_event(
  p_event_id text,
  p_event_type text,
  p_order_id uuid,
  p_stripe_account_id text,
  p_object_id text,
  p_checkout_session_id text,
  p_payment_intent_id text,
  p_amount_satang bigint,
  p_currency text,
  p_state text,
  p_payment_method text default null,
  p_note text default null,
  p_refund_id text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.food_orders%rowtype;
  a public.food_stripe_accounts%rowtype;
  expected_satang bigint;
begin
  if p_event_id is null or length(p_event_id) < 3 then
    raise exception 'event id required';
  end if;
  if p_state not in ('paid','failed','refunded','noop') then
    raise exception 'invalid stripe event state';
  end if;

  insert into public.food_stripe_webhook_events(event_id,event_type,stripe_account_id,order_id,object_id)
  values (p_event_id,p_event_type,p_stripe_account_id,p_order_id,p_object_id)
  on conflict (event_id) do nothing;

  if not found then
    return false;
  end if;

  if p_state = 'noop' or p_order_id is null then
    return true;
  end if;

  select * into o from public.food_orders where id = p_order_id for update;
  if not found then
    raise exception 'order not found';
  end if;

  select * into a from public.food_stripe_accounts where store_id = o.store_id;
  if not found or a.stripe_account_id is distinct from p_stripe_account_id then
    raise exception 'stripe account mismatch';
  end if;

  expected_satang := round(o.total::numeric * 100)::bigint;
  if lower(coalesce(p_currency,'')) <> 'thb' then
    raise exception 'currency mismatch';
  end if;
  if p_state in ('paid','refunded') and coalesce(p_amount_satang,0) <> expected_satang then
    raise exception 'amount mismatch';
  end if;

  insert into public.food_stripe_payments(
    order_id,store_id,buyer_id,stripe_account_id,checkout_session_id,payment_intent_id,
    amount_satang,currency,status,payment_method,paid_at,refunded_at,last_error
  )
  values (
    o.id,o.store_id,o.buyer_id,a.stripe_account_id,p_checkout_session_id,p_payment_intent_id,
    expected_satang,'thb',
    case when p_state='paid' then 'paid' when p_state='refunded' then 'refunded' else 'failed' end,
    p_payment_method,
    case when p_state in ('paid','refunded') then now() else null end,
    case when p_state='refunded' then now() else null end,
    case when p_state='failed' then left(coalesce(p_note,'Stripe payment failed'),500) else null end
  )
  on conflict (order_id) do update set
    checkout_session_id = coalesce(excluded.checkout_session_id, public.food_stripe_payments.checkout_session_id),
    payment_intent_id = coalesce(excluded.payment_intent_id, public.food_stripe_payments.payment_intent_id),
    status = excluded.status,
    payment_method = coalesce(excluded.payment_method, public.food_stripe_payments.payment_method),
    paid_at = coalesce(public.food_stripe_payments.paid_at, excluded.paid_at),
    refunded_at = coalesce(excluded.refunded_at, public.food_stripe_payments.refunded_at),
    last_error = excluded.last_error,
    updated_at = now();

  if p_state = 'paid' then
    update public.food_orders
    set payment_status = 'paid',
        payment_provider = 'stripe',
        payment_provider_code = p_event_type,
        payment_transaction_ref = p_payment_intent_id,
        payment_verified_at = coalesce(payment_verified_at, now()),
        payment_verification_status = 'auto_verified',
        payment_verification_note = 'Stripe webhook confirmed payment',
        stripe_checkout_session_id = coalesce(p_checkout_session_id, stripe_checkout_session_id),
        stripe_payment_intent_id = coalesce(p_payment_intent_id, stripe_payment_intent_id),
        paid_at = coalesce(paid_at, now()),
        payment_note = null
    where id = o.id and payment_status in ('pending','issue','submitted','paid');
  elsif p_state = 'failed' then
    update public.food_orders
    set payment_status = 'issue',
        payment_provider = 'stripe',
        payment_provider_code = p_event_type,
        stripe_checkout_session_id = coalesce(p_checkout_session_id, stripe_checkout_session_id),
        stripe_payment_intent_id = coalesce(p_payment_intent_id, stripe_payment_intent_id),
        payment_note = left(coalesce(p_note,'Stripe payment failed'),500)
    where id = o.id and payment_status in ('pending','issue');
  elsif p_state = 'refunded' then
    update public.food_orders
    set payment_status = 'refunded',
        refund_status = 'refunded',
        stripe_refund_id = coalesce(p_refund_id, stripe_refund_id),
        refunded_at = coalesce(refunded_at, now()),
        payment_provider_code = p_event_type,
        payment_note = null
    where id = o.id and payment_status in ('paid','refunded');
  end if;

  return true;
end;
$$;

revoke all on function public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)
  from public, anon, authenticated;
grant execute on function public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)
  to service_role;

-- Stripe can satisfy store payment readiness while manual PromptPay/bank remains a fallback.
create or replace function internal.food_store_publish_readiness_json(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s public.food_stores%rowtype;
  v_menu boolean;
  v_checks jsonb;
  v_missing jsonb := '[]'::jsonb;
  v_stripe_ready boolean := false;
begin
  select * into s from public.food_stores where id = p_store_id;
  if not found then
    return jsonb_build_object('ready', false, 'checks', '{}'::jsonb, 'missing', jsonb_build_array('store'));
  end if;

  select exists(select 1 from public.food_menu_items m where m.store_id = p_store_id) into v_menu;
  select exists(
    select 1 from public.food_stripe_accounts a
    where a.store_id = p_store_id
      and a.status = 'ready'
      and a.details_submitted
      and a.charges_enabled
  ) into v_stripe_ready;

  v_checks := jsonb_build_object(
    'name', length(btrim(coalesce(s.name,''))) > 0,
    'description', length(btrim(coalesce(s.description,''))) > 0,
    'phone', length(btrim(coalesce(s.phone,''))) > 0,
    'address', length(btrim(coalesce(s.address,''))) > 0,
    'logo', s.logo_path is not null,
    'cover', s.cover_path is not null,
    'location', s.latitude is not null and s.longitude is not null,
    'schedule', s.business_schedule <> '{}'::jsonb and jsonb_typeof(s.business_schedule->'weekly') = 'object',
    'prep_time', s.prep_time_min_minutes >= 1 and s.prep_time_max_minutes >= s.prep_time_min_minutes,
    'payment',
      v_stripe_ready
      or coalesce(nullif(btrim(s.promptpay_id),''), nullif(btrim(s.bank_account_number),'')) is not null
      or s.payment_qr_path is not null,
    'menu', v_menu
  );

  select coalesce(jsonb_agg(key order by key), '[]'::jsonb)
    into v_missing
  from jsonb_each(v_checks)
  where value <> 'true'::jsonb;

  return jsonb_build_object(
    'ready', jsonb_array_length(v_missing) = 0,
    'checks', v_checks,
    'missing', v_missing
  );
end;
$$;

revoke all on function internal.food_store_publish_readiness_json(uuid) from public, anon, authenticated;

-- Rollback:
-- 1) Disable Stripe in Merchant UI / Edge Functions.
-- 2) Restore internal.food_store_publish_readiness_json from
--    migrations_wynos_merchant_production_readiness_v1.sql.
-- 3) Drop the three Stripe tables and additive Stripe columns only after
--    preserving transaction references required for audit/refunds.
