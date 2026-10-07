-- WYNOS Stripe Connect v2 embedded onboarding + automatic payout hardening.
-- Additive migration. Existing Accounts v1 rows remain valid and continue on the compatibility path.

-- Raw Stripe records are backend-only. Re-assert service-role access explicitly
-- so a fresh database does not depend on environment-level default grants.
revoke all on table public.food_stripe_accounts from public, anon, authenticated;
revoke all on table public.food_stripe_payments from public, anon, authenticated;
revoke all on table public.food_stripe_webhook_events from public, anon, authenticated;
grant select, insert, update, delete on table public.food_stripe_accounts to service_role;
grant select, insert, update, delete on table public.food_stripe_payments to service_role;
grant select, insert, update, delete on table public.food_stripe_webhook_events to service_role;

alter table public.food_stripe_accounts
  add column if not exists account_api_version text,
  add column if not exists bank_name text,
  add column if not exists bank_last4 text,
  add column if not exists bank_ready boolean not null default false,
  add column if not exists payout_interval text not null default 'unknown',
  add column if not exists promptpay_status text not null default 'unknown',
  add column if not exists requirements_due_count integer not null default 0,
  add column if not exists balance_pending_satang bigint not null default 0,
  add column if not exists balance_available_satang bigint not null default 0,
  add column if not exists last_error_code text;

update public.food_stripe_accounts
set account_api_version = coalesce(account_api_version, 'v1')
where account_api_version is null;

alter table public.food_stripe_accounts
  alter column account_api_version set default 'v1',
  alter column account_api_version set not null;

do $guard$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'food_stripe_accounts_api_version_check'
  ) then
    alter table public.food_stripe_accounts
      add constraint food_stripe_accounts_api_version_check
      check (account_api_version in ('v1','v2'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'food_stripe_accounts_bank_last4_check'
  ) then
    alter table public.food_stripe_accounts
      add constraint food_stripe_accounts_bank_last4_check
      check (bank_last4 is null or bank_last4 ~ '^[0-9]{4}$');
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'food_stripe_accounts_payout_interval_check'
  ) then
    alter table public.food_stripe_accounts
      add constraint food_stripe_accounts_payout_interval_check
      check (payout_interval in ('daily','weekly','monthly','manual','unknown'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'food_stripe_accounts_promptpay_status_check'
  ) then
    alter table public.food_stripe_accounts
      add constraint food_stripe_accounts_promptpay_status_check
      check (promptpay_status in ('active','pending','inactive','unsupported','unrequested','unknown'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'food_stripe_accounts_requirements_due_count_check'
  ) then
    alter table public.food_stripe_accounts
      add constraint food_stripe_accounts_requirements_due_count_check
      check (requirements_due_count >= 0);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'food_stripe_accounts_balance_pending_check'
  ) then
    alter table public.food_stripe_accounts
      add constraint food_stripe_accounts_balance_pending_check
      check (balance_pending_satang >= 0);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'food_stripe_accounts_balance_available_check'
  ) then
    alter table public.food_stripe_accounts
      add constraint food_stripe_accounts_balance_available_check
      check (balance_available_satang >= 0);
  end if;
end
$guard$;

create table if not exists public.food_stripe_account_creation_locks (
  store_id uuid primary key references public.food_stores(id) on delete cascade,
  operation_token uuid not null,
  locked_until timestamptz not null,
  updated_at timestamptz not null default now()
);

alter table public.food_stripe_account_creation_locks enable row level security;
revoke all on table public.food_stripe_account_creation_locks from public, anon, authenticated;
grant select, insert, update, delete on table public.food_stripe_account_creation_locks to service_role;

create table if not exists public.food_stripe_payouts (
  payout_id text primary key,
  store_id uuid not null references public.food_stores(id) on delete cascade,
  stripe_account_id text not null,
  amount_satang bigint not null check (amount_satang >= 0),
  currency text not null default 'thb',
  status text not null check (status in ('pending','in_transit','paid','failed','canceled')),
  arrival_date date,
  failure_code text,
  stripe_created_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists food_stripe_payouts_store_created_idx
  on public.food_stripe_payouts(store_id, stripe_created_at desc);

alter table public.food_stripe_payouts enable row level security;
revoke all on table public.food_stripe_payouts from public, anon, authenticated;
grant select, insert, update, delete on table public.food_stripe_payouts to service_role;

create or replace function public.food_claim_stripe_account_creation(
  p_store_id uuid,
  p_operation_token uuid,
  p_ttl_seconds integer default 90
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claimed boolean := false;
begin
  if p_ttl_seconds < 15 or p_ttl_seconds > 300 then
    raise exception 'invalid lock ttl';
  end if;

  insert into public.food_stripe_account_creation_locks(store_id, operation_token, locked_until, updated_at)
  values (p_store_id, p_operation_token, now() + make_interval(secs => p_ttl_seconds), now())
  on conflict (store_id) do update
    set operation_token = excluded.operation_token,
        locked_until = excluded.locked_until,
        updated_at = now()
    where public.food_stripe_account_creation_locks.locked_until <= now()
  returning operation_token = p_operation_token into v_claimed;

  return coalesce(v_claimed, false);
end;
$$;

revoke all on function public.food_claim_stripe_account_creation(uuid,uuid,integer)
  from public, anon, authenticated;
grant execute on function public.food_claim_stripe_account_creation(uuid,uuid,integer)
  to service_role;

create or replace function public.food_release_stripe_account_creation(
  p_store_id uuid,
  p_operation_token uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.food_stripe_account_creation_locks
  where store_id = p_store_id and operation_token = p_operation_token;
$$;

revoke all on function public.food_release_stripe_account_creation(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.food_release_stripe_account_creation(uuid,uuid)
  to service_role;

create or replace function public.food_record_stripe_payout_event(
  p_event_id text,
  p_event_type text,
  p_stripe_account_id text,
  p_payout_id text,
  p_amount_satang bigint,
  p_currency text,
  p_status text,
  p_arrival_date date default null,
  p_failure_code text default null,
  p_stripe_created_at timestamptz default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store_id uuid;
begin
  if p_event_id is null or length(p_event_id) < 3 then raise exception 'event id required'; end if;
  if p_payout_id is null or length(p_payout_id) < 3 then raise exception 'payout id required'; end if;
  if p_status not in ('pending','in_transit','paid','failed','canceled') then raise exception 'invalid payout status'; end if;
  if lower(coalesce(p_currency,'')) <> 'thb' then raise exception 'currency mismatch'; end if;

  select store_id into v_store_id
  from public.food_stripe_accounts
  where stripe_account_id = p_stripe_account_id;

  if v_store_id is null then raise exception 'stripe account mismatch'; end if;

  insert into public.food_stripe_webhook_events(event_id,event_type,stripe_account_id,order_id,object_id)
  values (p_event_id,p_event_type,p_stripe_account_id,null,p_payout_id)
  on conflict (event_id) do nothing;

  if not found then return false; end if;

  insert into public.food_stripe_payouts(
    payout_id, store_id, stripe_account_id, amount_satang, currency, status,
    arrival_date, failure_code, stripe_created_at, updated_at
  )
  values (
    p_payout_id, v_store_id, p_stripe_account_id, greatest(coalesce(p_amount_satang,0),0),
    'thb', p_status, p_arrival_date, nullif(left(coalesce(p_failure_code,''),120),''),
    p_stripe_created_at, now()
  )
  on conflict (payout_id) do update set
    status = excluded.status,
    amount_satang = excluded.amount_satang,
    arrival_date = coalesce(excluded.arrival_date, public.food_stripe_payouts.arrival_date),
    failure_code = excluded.failure_code,
    stripe_created_at = coalesce(excluded.stripe_created_at, public.food_stripe_payouts.stripe_created_at),
    updated_at = now();

  return true;
end;
$$;

revoke all on function public.food_record_stripe_payout_event(text,text,text,text,bigint,text,text,date,text,timestamptz)
  from public, anon, authenticated;
grant execute on function public.food_record_stripe_payout_event(text,text,text,text,bigint,text,text,date,text,timestamptz)
  to service_role;

create or replace function public.merchant_stripe_status(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  a public.food_stripe_accounts%rowtype;
  v_paid_today bigint := 0;
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
      'promptpay_status', 'unknown',
      'bank_ready', false,
      'bank_name', null,
      'bank_last4', null,
      'payout_interval', 'unknown',
      'requirements_due_count', 0,
      'balance_pending_satang', 0,
      'balance_available_satang', 0,
      'payouts_paid_today_satang', 0,
      'last_synced_at', null
    );
  end if;

  select coalesce(sum(p.amount_satang),0)::bigint
  into v_paid_today
  from public.food_stripe_payouts p
  where p.store_id = p_store_id
    and p.status = 'paid'
    and (p.updated_at at time zone 'Asia/Bangkok')::date = (now() at time zone 'Asia/Bangkok')::date;

  return jsonb_build_object(
    'connected', true,
    'status', a.status,
    'details_submitted', a.details_submitted,
    'charges_enabled', a.charges_enabled,
    'payouts_enabled', a.payouts_enabled,
    'promptpay_enabled', a.promptpay_enabled,
    'promptpay_status', a.promptpay_status,
    'bank_ready', a.bank_ready,
    'bank_name', a.bank_name,
    'bank_last4', a.bank_last4,
    'payout_interval', a.payout_interval,
    'requirements_due_count', a.requirements_due_count,
    'balance_pending_satang', a.balance_pending_satang,
    'balance_available_satang', a.balance_available_satang,
    'payouts_paid_today_satang', v_paid_today,
    'last_synced_at', a.last_synced_at
  );
end;
$$;

revoke all on function public.merchant_stripe_status(uuid) from public, anon;
grant execute on function public.merchant_stripe_status(uuid) to authenticated;

-- Rollback:
-- Restore merchant_stripe_status from migrations_wynos_stripe_payment_core_v1.sql.
-- Drop the lock/payout tables and new columns only after Stripe payout audit data is preserved.
