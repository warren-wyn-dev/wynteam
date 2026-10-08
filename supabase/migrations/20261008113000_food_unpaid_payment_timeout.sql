-- WYNOS Food: expire new, still-unpaid customer orders 10 minutes after placement.
-- Existing orders are intentionally NOT backfilled to avoid retroactive cancellation.
-- Rollout order: deploy food-unpaid-timeout Edge Function first, then apply this migration.
-- Only source='app' orders are affected; manually entered merchant orders are excluded.
-- A slip submitted in time (payment_status='submitted') is protected while reviewed.
-- Stripe's open checkout MUST be expired by the Edge worker before DB cancellation.
--
-- Rollback requires Founder approval; disable the cron job first. Do not remove
-- payment_due_at from existing orders until all payment operations are reconciled.

alter table public.food_orders add column if not exists payment_due_at timestamptz;
-- Set AFTER adding the column so existing orders keep NULL and are exempt.
alter table public.food_orders alter column payment_due_at
  set default (now() + interval '10 minutes');

create index if not exists food_orders_unpaid_due_idx
on public.food_orders(payment_due_at, id)
where source='app' and status='pending_acceptance'
  and payment_status in ('pending','issue') and payment_due_at is not null;

-- Do not allow a late upload to race the expiry worker or revive a cancelled order.
-- Stripe webhook-paid events remain allowed after 10 minutes because a payment
-- might have completed just before the deadline but its webhook arrived late.
create or replace function internal.food_guard_late_slip()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.payment_status = 'submitted'
     and old.payment_status in ('pending','issue')
     and (old.status = 'cancelled'
       or (old.source='app' and old.payment_due_at is not null
           and clock_timestamp() >= old.payment_due_at)) then
    raise exception 'payment deadline expired'
      using errcode='P0001';
  end if;
  return new;
end;
$$;
revoke all on function internal.food_guard_late_slip() from public, anon, authenticated;
drop trigger if exists trg_food_guard_late_slip on public.food_orders;
create trigger trg_food_guard_late_slip
before update of payment_status on public.food_orders
for each row execute function internal.food_guard_late_slip();

-- This RPC is exclusively called by the authenticated Edge worker. The session
-- ID must match the one Stripe has just confirmed expired. FOR UPDATE serializes
-- against the Stripe webhook and payment submission; no client may call it.
create or replace function public.food_timeout_cancel(
  p_order_id uuid,
  p_expected_session_id text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.food_orders%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service role required';
  end if;

  select * into v_order
  from public.food_orders
  where id=p_order_id
  for update;

  if not found or v_order.source <> 'app'
     or v_order.status <> 'pending_acceptance'
     or v_order.payment_status not in ('pending','issue')
     or v_order.paid_at is not null
     or v_order.payment_due_at is null
     or v_order.payment_due_at > clock_timestamp()
     or v_order.stripe_checkout_session_id is distinct from p_expected_session_id
  then
    return false;
  end if;

  update public.food_orders
  set status='cancelled', cancelled_at=clock_timestamp()
  where id=v_order.id;

  insert into public.food_order_events
    (order_id,event_type,from_status,to_status,note,actor_id)
  values
    (v_order.id,'auto_cancelled_unpaid',v_order.status,'cancelled',
     'ระบบยกเลิกอัตโนมัติ: ไม่ชำระเงินภายใน 10 นาที',null);

  return true;
end;
$$;
revoke all on function public.food_timeout_cancel(uuid,text) from public, anon, authenticated;
grant execute on function public.food_timeout_cancel(uuid,text) to service_role;

-- Separate secret for the cron->Edge request (never stored in source code).
do $$
begin
  if not exists (select 1 from vault.secrets where name='wynos_food_unpaid_timeout_cron_key') then
    perform vault.create_secret(
      encode(gen_random_bytes(32),'hex'),
      'wynos_food_unpaid_timeout_cron_key',
      'Authenticate the Food 10-minute payment timeout worker'
    );
  end if;
end;
$$;

create or replace function public.food_timeout_cron_authorized(p_token text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_token is not null and exists (
    select 1 from vault.decrypted_secrets s
    where s.name='wynos_food_unpaid_timeout_cron_key'
      and s.decrypted_secret = p_token
  )
$$;
revoke all on function public.food_timeout_cron_authorized(text) from public, anon, authenticated;
grant execute on function public.food_timeout_cron_authorized(text) to service_role;

-- The cron launcher only sends a signed request. Stripe processing and the
-- atomic cancellation happen in the Edge worker, never in this function.
create or replace function internal.food_timeout_tick()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text;
  v_url text;
  v_request_id bigint;
begin
  select decrypted_secret into v_token from vault.decrypted_secrets
  where name='wynos_food_unpaid_timeout_cron_key';
  select decrypted_secret into v_url from vault.decrypted_secrets
  where name='wynos_project_url';

  if nullif(v_token,'') is null or v_url !~ '^https://[a-z0-9-]+[.]supabase[.]co/?$' then
    raise exception 'food timeout cron vault configuration missing';
  end if;

  select net.http_post(
    url := rtrim(v_url,'/') || '/functions/v1/food-unpaid-timeout',
    headers := jsonb_build_object('Content-Type','application/json','x-wynos-cron-key',v_token),
    body := '{}'::jsonb,
    timeout_milliseconds := 25000
  ) into v_request_id;
  return v_request_id;
end;
$$;
revoke all on function internal.food_timeout_tick() from public, anon, authenticated;

-- Only enable the job after the worker is deployed and verified.
-- This section is idempotent when rerun on the production project.
do $$
declare v_job bigint;
begin
  if exists (select 1 from pg_extension where extname='pg_cron')
     and exists (select 1 from pg_extension where extname='pg_net') then
    for v_job in select jobid from cron.job
      where jobname='wynos-food-unpaid-timeout' loop
      perform cron.unschedule(v_job);
    end loop;
    perform cron.schedule('wynos-food-unpaid-timeout','* * * * *',
      'select internal.food_timeout_tick();');
  else
    raise exception 'pg_cron and pg_net required to enforce the timeout';
  end if;
end;
$$;
