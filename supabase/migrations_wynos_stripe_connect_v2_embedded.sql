-- WYNOS Stripe Connect v2 hardening and merchant-friendly payout state.
-- Additive to migrations_wynos_stripe_payment_core_v1.sql.
-- New connected accounts are provisioned with Accounts v2 in Edge Functions.
-- Existing Accounts v1 rows remain supported and are never recreated.

alter table public.food_stripe_accounts
  add column if not exists account_api text not null default 'v1',
  add column if not exists requirements_due boolean not null default false,
  add column if not exists promptpay_supported boolean not null default false,
  add column if not exists payout_bank_ready boolean not null default false,
  add column if not exists payout_bank_name text,
  add column if not exists payout_bank_last4 text,
  add column if not exists payout_interval text,
  add column if not exists balance_pending_satang bigint not null default 0,
  add column if not exists balance_available_satang bigint not null default 0,
  add column if not exists last_payout_status text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'food_stripe_accounts_account_api_check'
      and conrelid = 'public.food_stripe_accounts'::regclass
  ) then
    alter table public.food_stripe_accounts
      add constraint food_stripe_accounts_account_api_check
      check (account_api in ('v1','v2'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'food_stripe_accounts_bank_last4_check'
      and conrelid = 'public.food_stripe_accounts'::regclass
  ) then
    alter table public.food_stripe_accounts
      add constraint food_stripe_accounts_bank_last4_check
      check (payout_bank_last4 is null or payout_bank_last4 ~ '^[0-9]{4}$');
  end if;
end
$$;

create table if not exists public.food_stripe_payouts (
  payout_id text primary key,
  store_id uuid not null references public.food_stores(id) on delete cascade,
  stripe_account_id text not null,
  amount_satang bigint not null check (amount_satang >= 0),
  currency text not null default 'thb',
  status text not null,
  arrival_date timestamptz,
  failure_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists food_stripe_payouts_store_created_idx
  on public.food_stripe_payouts(store_id, created_at desc);

create table if not exists public.food_stripe_connect_locks (
  store_id uuid primary key references public.food_stores(id) on delete cascade,
  lock_token text not null,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);

alter table public.food_stripe_payouts enable row level security;
alter table public.food_stripe_connect_locks enable row level security;

revoke all on table public.food_stripe_payouts from public, anon, authenticated;
revoke all on table public.food_stripe_connect_locks from public, anon, authenticated;

-- Edge Function only. One store can provision at a time; an abandoned lock
-- expires quickly so a crashed request cannot block onboarding permanently.
create or replace function public.merchant_acquire_stripe_connect_lock(
  p_store_id uuid,
  p_lock_token text,
  p_ttl_seconds integer default 45
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_store_id is null or nullif(btrim(p_lock_token),'') is null then
    return false;
  end if;

  insert into public.food_stripe_connect_locks(store_id, lock_token, expires_at, updated_at)
  values (
    p_store_id,
    p_lock_token,
    now() + make_interval(secs => greatest(10, least(coalesce(p_ttl_seconds,45),120))),
    now()
  )
  on conflict (store_id) do update
    set lock_token = excluded.lock_token,
        expires_at = excluded.expires_at,
        updated_at = now()
    where public.food_stripe_connect_locks.expires_at <= now();

  return found;
end;
$$;

create or replace function public.merchant_release_stripe_connect_lock(
  p_store_id uuid,
  p_lock_token text
)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.food_stripe_connect_locks
  where store_id = p_store_id and lock_token = p_lock_token
$$;

revoke all on function public.merchant_acquire_stripe_connect_lock(uuid,text,integer)
  from public, anon, authenticated;
revoke all on function public.merchant_release_stripe_connect_lock(uuid,text)
  from public, anon, authenticated;
grant execute on function public.merchant_acquire_stripe_connect_lock(uuid,text,integer)
  to service_role;
grant execute on function public.merchant_release_stripe_connect_lock(uuid,text)
  to service_role;

-- Merchant-safe status only. Never expose acct IDs, external-account IDs,
-- full bank account numbers, requirements payloads or gateway errors.
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
      'promptpay_supported', false,
      'requirements_due', false,
      'bank_ready', false,
      'bank_name', null,
      'bank_last4', null,
      'payout_interval', null,
      'balance_pending_satang', 0,
      'balance_available_satang', 0,
      'last_payout_status', null,
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
    'promptpay_supported', a.promptpay_supported,
    'requirements_due', a.requirements_due,
    'bank_ready', a.payout_bank_ready,
    'bank_name', a.payout_bank_name,
    'bank_last4', a.payout_bank_last4,
    'payout_interval', a.payout_interval,
    'balance_pending_satang', a.balance_pending_satang,
    'balance_available_satang', a.balance_available_satang,
    'last_payout_status', a.last_payout_status,
    'last_synced_at', a.last_synced_at
  );
end;
$$;

revoke all on function public.merchant_stripe_status(uuid) from public, anon;
grant execute on function public.merchant_stripe_status(uuid) to authenticated;
