-- ZOKY Stripe-only payments, step 1: durable Stripe jobs + automatic refunds.
-- Design: .wyn/docs/architecture/zoky-stripe-only-auto-refund-design.md (sections 1-4).
-- Founder approval: .wyn/company/APPROVALS.md 2026-10-22 (implementation only;
-- every production step needs its own Founder approval).
--
-- Additive only. No existing RPC is redefined. Behaviour comes from three
-- triggers on public.food_orders, so every cancel/payment path is covered
-- (food_cancel_order, food_transition_order, food_timeout_cancel,
-- food_apply_stripe_event, admin tools) and no client input is trusted:
--   * food_orders_payment_guard (BEFORE UPDATE): marks refund_status='pending'
--     when a Stripe-paid order becomes cancelled (or a cancelled order becomes
--     Stripe-paid), and, only while the Stripe-only policy is on, blocks slip
--     submission and non-Stripe paid/issue on source='app' orders (in-flight
--     legacy slips created before the cut-over can still be confirmed).
--   * food_orders_payment_jobs (AFTER UPDATE): queues expire_checkout and
--     refund jobs in the same transaction as the cancel/payment.
--   * food_orders_require_stripe_ready (BEFORE INSERT): while the policy is
--     on, a source='app' order needs a ready Stripe account.
-- The food-stripe-refund-worker Edge Function executes the jobs at Stripe.
--
-- Safe defaults: the policy row is created with stripe_only_from = NULL
-- (legacy behaviour; the slip block and order gate are off). The cron job is
-- enabled separately (20261023100100) and Stripe-only is activated separately
-- (20261023100200). Without cron, jobs simply wait in the queue.
-- ROLLBACK: supabase/rollbacks/20261023100000_food_stripe_jobs_auto_refund_rollback.sql
-- Test: supabase/tests/food_stripe_auto_refund_test.sh

-- ------------------------------------------------------------
-- Tables (server-only)
-- ------------------------------------------------------------

create table if not exists public.food_payment_policy (
  id boolean primary key default true check (id),
  stripe_only_from timestamptz,
  updated_at timestamptz not null default now()
);
insert into public.food_payment_policy(id) values (true) on conflict (id) do nothing;

create table if not exists public.food_stripe_jobs (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('expire_checkout','refund')),
  order_id uuid not null references public.food_orders(id) on delete cascade,
  store_id uuid not null references public.food_stores(id) on delete cascade,
  dedupe_key text not null unique,
  reason text not null
    check (reason in ('order_cancelled','store_cancelled','paid_after_cancel','duplicate_payment')),
  status text not null default 'queued'
    check (status in ('queued','awaiting_refund','done','failed','needs_attention')),
  checkout_session_id text,
  payment_intent_id text,
  stripe_refund_id text,
  attempts integer not null default 0 check (attempts >= 0),
  max_attempts integer not null default 8 check (max_attempts between 1 and 50),
  poll_count integer not null default 0 check (poll_count >= 0),
  requeue_count integer not null default 0 check (requeue_count >= 0),
  next_attempt_at timestamptz not null default now(),
  locked_until timestamptz,
  last_error_code text check (last_error_code is null or char_length(last_error_code) <= 120),
  requeued_by uuid,
  requeued_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists food_stripe_jobs_due_idx
  on public.food_stripe_jobs(next_attempt_at)
  where status in ('queued','awaiting_refund');
create index if not exists food_stripe_jobs_order_idx
  on public.food_stripe_jobs(order_id, created_at desc);

alter table public.food_payment_policy enable row level security;
alter table public.food_stripe_jobs enable row level security;
revoke all on table public.food_payment_policy from public, anon, authenticated;
revoke all on table public.food_stripe_jobs from public, anon, authenticated;
grant select on table public.food_payment_policy to service_role;
grant select on table public.food_stripe_jobs to service_role;

-- ------------------------------------------------------------
-- Internal helpers
-- ------------------------------------------------------------

create or replace function internal.food_stripe_only_from()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select p.stripe_only_from from public.food_payment_policy p where p.id
$$;
revoke all on function internal.food_stripe_only_from() from public, anon, authenticated;

create or replace function internal.food_stripe_only_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(internal.food_stripe_only_from() <= clock_timestamp(), false)
$$;
revoke all on function internal.food_stripe_only_active() from public, anon, authenticated;

-- Backoff after the n-th failed attempt / n-th poll: 1m, 5m, 15m, 1h, 6h, 24h.
create or replace function internal.food_stripe_job_delay(p_n integer)
returns interval
language sql
immutable
set search_path = ''
as $$
  select case
    when p_n <= 1 then interval '1 minute'
    when p_n = 2 then interval '5 minutes'
    when p_n = 3 then interval '15 minutes'
    when p_n = 4 then interval '1 hour'
    when p_n = 5 then interval '6 hours'
    else interval '24 hours'
  end
$$;
revoke all on function internal.food_stripe_job_delay(integer) from public, anon, authenticated;

-- Customer + merchant notifications, same tables and wording style as
-- internal.food_order_status_notify (20261008113000).
create or replace function internal.food_stripe_refund_notify(
  p_order_id uuid,
  p_customer_reason text,
  p_merchant_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buyer uuid;
  v_account uuid;
begin
  select o.buyer_id, s.merchant_account_id into v_buyer, v_account
  from public.food_orders o
  join public.food_stores s on s.id = o.store_id
  where o.id = p_order_id;

  if v_buyer is not null and p_customer_reason is not null then
    insert into public.notifications(recipient_id, actor_id, type, reason)
    values (v_buyer, null, 'system', p_customer_reason);
  end if;
  if v_account is not null and p_merchant_reason is not null then
    insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
    select v_account, mm.user_id, 'payment', p_merchant_reason
    from public.merchant_memberships mm
    where mm.merchant_account_id = v_account and mm.active;
  end if;
end;
$$;
revoke all on function internal.food_stripe_refund_notify(uuid,text,text) from public, anon, authenticated;

-- A refund job that cannot complete: the order shows refund_status='failed'
-- and the customer and merchant are told. The merchant can requeue it with
-- merchant_retry_stripe_refund. Expire jobs never touch the order.
create or replace function internal.food_stripe_job_fail(p_job_id uuid, p_error_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.food_stripe_jobs%rowtype;
  v_order_number text;
begin
  update public.food_stripe_jobs
  set status = 'failed',
      last_error_code = left(coalesce(p_error_code, 'failed'), 120),
      locked_until = null,
      completed_at = now(),
      updated_at = now()
  where id = p_job_id and status in ('queued','awaiting_refund')
  returning * into j;
  if not found or j.kind <> 'refund' then
    return;
  end if;

  update public.food_orders
  set refund_status = 'failed',
      refund_note = coalesce(refund_note, 'คืนเงินอัตโนมัติไม่สำเร็จ')
  where id = j.order_id
    and payment_status = 'paid'
    and refund_status is distinct from 'refunded'
  returning order_number into v_order_number;
  if not found then
    return;
  end if;

  insert into public.food_order_events(order_id, event_type, note, actor_id)
  values (j.order_id, 'refund_failed', 'คืนเงินอัตโนมัติไม่สำเร็จ (' || left(coalesce(p_error_code,'failed'),80) || ')', null);

  perform internal.food_stripe_refund_notify(
    j.order_id,
    'คืนเงินออเดอร์ #' || v_order_number || ' มีปัญหา กรุณาติดต่อร้าน',
    'WYNOS Merchant · คืนเงินอัตโนมัติออเดอร์ #' || v_order_number || ' ไม่สำเร็จ กรุณาตรวจสอบบัญชี Stripe แล้วกดลองใหม่'
  );
end;
$$;
revoke all on function internal.food_stripe_job_fail(uuid,text) from public, anon, authenticated;

-- ------------------------------------------------------------
-- Triggers on food_orders
-- ------------------------------------------------------------

create or replace function internal.food_orders_payment_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_from timestamptz;
begin
  -- Stripe-only (policy on, customer orders only; manual orders excluded, D7).
  if new.source = 'app' then
    v_from := internal.food_stripe_only_from();
    if v_from is not null and v_from <= clock_timestamp() then
      if new.payment_status = 'submitted' and old.payment_status is distinct from 'submitted' then
        raise exception 'stripe_only_payments'
          using errcode = 'P0001', hint = 'ออเดอร์นี้ชำระผ่าน Stripe เท่านั้น ไม่รับสลิป';
      end if;
      if new.payment_status in ('paid','issue')
         and (new.payment_status is distinct from old.payment_status
              or new.payment_provider is distinct from old.payment_provider)
         and new.payment_provider is distinct from 'stripe'
         -- In-flight legacy slip placed before the cut-over may be finished.
         and not (old.payment_status = 'submitted' and old.created_at < v_from) then
        raise exception 'stripe_only_payments'
          using errcode = 'P0001', hint = 'ออเดอร์นี้ชำระผ่าน Stripe เท่านั้น ยืนยันการชำระเงินเองไม่ได้';
      end if;
    end if;
  end if;

  -- A Stripe payment on a cancelled order is refunded automatically (D6: full).
  if new.status = 'cancelled' and new.payment_status = 'paid' and new.payment_provider = 'stripe'
     and not (old.status = 'cancelled' and old.payment_status = 'paid'
              and old.payment_provider is not distinct from 'stripe') then
    if new.refund_status is distinct from 'refunded' then
      new.refund_status := 'pending';
    end if;
    new.refund_requested_at := coalesce(new.refund_requested_at, now());
  end if;

  return new;
end;
$$;
revoke all on function internal.food_orders_payment_guard() from public, anon, authenticated;

create or replace function internal.food_orders_payment_jobs()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
  v_pi text;
  v_job_id uuid;
begin
  -- 1a. Any cancel of an unpaid order with a Checkout session: expire it.
  if new.status = 'cancelled' and old.status is distinct from 'cancelled'
     and new.payment_status in ('pending','issue')
     and new.stripe_checkout_session_id is not null then
    insert into public.food_stripe_jobs(kind, order_id, store_id, dedupe_key, reason, checkout_session_id)
    values ('expire_checkout', new.id, new.store_id,
            'expire_checkout:' || new.id || ':' || new.stripe_checkout_session_id,
            'order_cancelled', new.stripe_checkout_session_id)
    on conflict (dedupe_key) do nothing;
  end if;

  -- 1b/2. Cancelled + Stripe-paid: queue one full refund.
  if new.status = 'cancelled' and new.payment_status = 'paid' and new.payment_provider = 'stripe'
     and not (old.status = 'cancelled' and old.payment_status = 'paid'
              and old.payment_provider is not distinct from 'stripe') then
    v_reason := case when old.status = 'cancelled' then 'paid_after_cancel' else 'store_cancelled' end;
    v_pi := new.stripe_payment_intent_id;
    insert into public.food_stripe_jobs(kind, order_id, store_id, dedupe_key, reason,
                                        checkout_session_id, payment_intent_id)
    values ('refund', new.id, new.store_id,
            'refund:' || new.id || ':' || coalesce(v_pi, new.stripe_checkout_session_id, 'order'),
            v_reason, new.stripe_checkout_session_id, v_pi)
    on conflict (dedupe_key) do nothing
    returning id into v_job_id;

    if v_job_id is not null then
      insert into public.food_order_events(order_id, event_type, note, actor_id)
      values (new.id, 'refund_auto_queued',
              case when v_reason = 'paid_after_cancel'
                then 'ได้รับเงินหลังยกเลิกออเดอร์ ระบบจะคืนเงินอัตโนมัติ'
                else 'ระบบจะคืนเงินผ่าน Stripe อัตโนมัติ' end,
              null);
      if v_reason = 'paid_after_cancel' then
        perform internal.food_stripe_refund_notify(
          new.id,
          'ออเดอร์ #' || new.order_number || ' ถูกยกเลิกแล้ว ระบบกำลังคืนเงินให้อัตโนมัติ',
          'WYNOS Merchant · ได้รับเงินออเดอร์ #' || new.order_number || ' หลังยกเลิก ระบบกำลังคืนเงินลูกค้าอัตโนมัติ'
        );
      end if;
    end if;
  end if;

  -- Duplicate payment (another PaymentIntent on an already paid order).
  -- Not auto-refunded in this step: parked for review (P1).
  if old.payment_status = 'paid' and new.payment_status = 'paid'
     and new.payment_provider = 'stripe'
     and old.stripe_payment_intent_id is not null
     and new.stripe_payment_intent_id is distinct from old.stripe_payment_intent_id then
    insert into public.food_stripe_jobs(kind, order_id, store_id, dedupe_key, reason, status,
                                        payment_intent_id, last_error_code)
    values ('refund', new.id, new.store_id,
            'duplicate_payment:' || new.id || ':' || old.stripe_payment_intent_id,
            'duplicate_payment', 'needs_attention',
            old.stripe_payment_intent_id, 'duplicate_payment_review')
    on conflict (dedupe_key) do nothing;
  end if;

  return null;
end;
$$;
revoke all on function internal.food_orders_payment_jobs() from public, anon, authenticated;

create or replace function internal.food_orders_require_stripe_ready()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.source = 'app' and internal.food_stripe_only_active()
     and not exists (
       select 1
       from public.food_stores s
       join public.food_stripe_accounts a on a.store_id = s.id
       where s.id = new.store_id
         and s.stripe_payments_enabled
         and a.status = 'ready'
         and a.details_submitted
         and a.charges_enabled
     ) then
    raise exception 'store_not_accepting_orders'
      using errcode = 'P0001', hint = 'ร้านนี้ยังไม่เปิดรับออเดอร์';
  end if;
  return new;
end;
$$;
revoke all on function internal.food_orders_require_stripe_ready() from public, anon, authenticated;

drop trigger if exists food_orders_payment_guard on public.food_orders;
create trigger food_orders_payment_guard
before update of status, payment_status, payment_provider on public.food_orders
for each row execute function internal.food_orders_payment_guard();

drop trigger if exists food_orders_payment_jobs on public.food_orders;
create trigger food_orders_payment_jobs
after update of status, payment_status, payment_provider, stripe_payment_intent_id on public.food_orders
for each row execute function internal.food_orders_payment_jobs();

drop trigger if exists food_orders_require_stripe_ready on public.food_orders;
create trigger food_orders_require_stripe_ready
before insert on public.food_orders
for each row execute function internal.food_orders_require_stripe_ready();

-- ------------------------------------------------------------
-- Worker RPCs (service role only)
-- ------------------------------------------------------------

-- Claims due jobs with FOR UPDATE SKIP LOCKED and a 5-minute lease, so two
-- overlapping worker runs never process the same job. A queued job counts an
-- attempt when claimed; a refund being polled counts a poll instead.
create or replace function public.food_claim_stripe_jobs(p_limit integer default 10)
returns table (
  job_id uuid,
  kind text,
  status text,
  reason text,
  order_id uuid,
  attempts integer,
  requeue_count integer,
  checkout_session_id text,
  payment_intent_id text,
  stripe_refund_id text,
  stripe_account_id text,
  livemode boolean,
  amount_satang bigint,
  application_fee_satang bigint,
  order_status text,
  order_payment_status text,
  order_payment_provider text,
  order_refund_status text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_stale uuid;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service role required';
  end if;

  -- Jobs whose worker died after the last allowed attempt.
  for v_stale in
    select j.id from public.food_stripe_jobs j
    where j.status = 'queued' and j.attempts >= j.max_attempts
      and (j.locked_until is null or j.locked_until <= now())
    for update skip locked
  loop
    perform internal.food_stripe_job_fail(v_stale, 'max_attempts_exceeded');
  end loop;

  return query
  with due as (
    select j.id
    from public.food_stripe_jobs j
    where j.status in ('queued','awaiting_refund')
      and j.next_attempt_at <= now()
      and (j.locked_until is null or j.locked_until <= now())
      and (j.status = 'awaiting_refund' or j.attempts < j.max_attempts)
    order by j.next_attempt_at, j.created_at
    limit least(greatest(coalesce(p_limit, 10), 1), 25)
    for update skip locked
  ), claimed as (
    update public.food_stripe_jobs j
    set locked_until = now() + interval '5 minutes',
        attempts = j.attempts + case when j.status = 'queued' then 1 else 0 end,
        poll_count = j.poll_count + case when j.status = 'awaiting_refund' then 1 else 0 end,
        updated_at = now()
    from due
    where j.id = due.id
    returning j.*
  )
  select c.id, c.kind, c.status, c.reason, c.order_id, c.attempts, c.requeue_count,
         coalesce(c.checkout_session_id, o.stripe_checkout_session_id),
         coalesce(c.payment_intent_id, case when c.reason <> 'duplicate_payment' then o.stripe_payment_intent_id end),
         c.stripe_refund_id,
         -- Always the account that took the payment; the store's current
         -- account only for older orders without a payment ledger row.
         coalesce(p.stripe_account_id, a.stripe_account_id),
         case when p.order_id is not null then p.livemode else a.livemode end,
         coalesce(p.amount_satang, round(o.total * 100)::bigint),
         coalesce(p.application_fee_satang, 0),
         o.status, o.payment_status, o.payment_provider, o.refund_status
  from claimed c
  join public.food_orders o on o.id = c.order_id
  left join public.food_stripe_payments p on p.order_id = c.order_id
  left join public.food_stripe_accounts a on a.store_id = c.store_id;
end;
$$;
revoke all on function public.food_claim_stripe_jobs(integer) from public, anon, authenticated;
grant execute on function public.food_claim_stripe_jobs(integer) to service_role;

-- Records the outcome of one job run. Outcomes:
--   done            expire job finished (session expired/complete) or nothing to do
--   refund_requested refund exists at Stripe but is not final yet (poll later)
--   refunded        refund succeeded: order refunded
--   retry           transient error: back off (fails after max_attempts)
--   failed          permanent error or Stripe reported the refund failed
--   needs_attention parked for an operator (environment mismatch, partial refund)
create or replace function public.food_complete_stripe_job(
  p_job_id uuid,
  p_outcome text,
  p_refund_id text default null,
  p_error_code text default null,
  p_fee_refunded boolean default false
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.food_stripe_jobs%rowtype;
  v_code text := nullif(left(regexp_replace(coalesce(p_error_code,''), '[^A-Za-z0-9_.:-]', '', 'g'), 120), '');
  v_order_number text;
  v_fee bigint;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service role required';
  end if;
  if p_outcome not in ('done','refund_requested','refunded','retry','failed','needs_attention') then
    raise exception 'invalid job outcome';
  end if;
  if p_refund_id is not null and p_refund_id !~ '^[A-Za-z0-9_]{3,255}$' then
    raise exception 'invalid refund id';
  end if;

  select * into j from public.food_stripe_jobs where id = p_job_id for update;
  if not found then
    raise exception 'job not found';
  end if;
  if p_outcome in ('refund_requested','refunded') and j.kind <> 'refund' then
    raise exception 'invalid job outcome';
  end if;
  if j.status not in ('queued','awaiting_refund') then
    return j.status;   -- already final; replays are no-ops
  end if;

  if p_outcome = 'done' then
    update public.food_stripe_jobs
    set status = 'done', locked_until = null, completed_at = now(), updated_at = now(),
        last_error_code = v_code
    where id = j.id;
    -- Only when Stripe confirmed the session expired: a completed session
    -- whose webhook is late must keep its pending ledger row for the webhook.
    if j.kind = 'expire_checkout' and j.checkout_session_id is not null
       and v_code = 'session_expired' then
      update public.food_stripe_payments
      set status = 'failed',
          last_error = 'Order cancelled; Checkout expired',
          updated_at = now()
      where order_id = j.order_id and checkout_session_id = j.checkout_session_id
        and status = 'pending';
    end if;
    return 'done';

  elsif p_outcome = 'refund_requested' then
    if p_refund_id is null then raise exception 'refund id required'; end if;
    update public.food_stripe_jobs
    set status = 'awaiting_refund',
        stripe_refund_id = p_refund_id,
        last_error_code = null,
        locked_until = null,
        next_attempt_at = now() + internal.food_stripe_job_delay(j.poll_count + 1),
        updated_at = now()
    where id = j.id;
    if j.stripe_refund_id is distinct from p_refund_id then
      update public.food_orders
      set stripe_refund_id = p_refund_id,
          refund_status = case when refund_status = 'refunded' then refund_status else 'pending' end,
          refund_requested_at = coalesce(refund_requested_at, now())
      where id = j.order_id and payment_status = 'paid';
      insert into public.food_order_events(order_id, event_type, note, actor_id)
      values (j.order_id, 'refund_requested', 'ส่งคำขอคืนเงินไปที่ Stripe แล้ว (' || p_refund_id || ')', null);
    end if;
    if p_fee_refunded then
      -- GP v1: finance reverses GP only for a fee WYNOS actually asked back.
      update public.food_stripe_payments
      set application_fee_refunded_satang = application_fee_satang,
          application_fee_refunded_at = now()
      where order_id = j.order_id and application_fee_satang > 0
        and application_fee_refunded_satang = 0;
    end if;
    -- Refunds that never settle are handed to an operator (about 3 weeks).
    if j.poll_count >= 30 then
      update public.food_stripe_jobs
      set status = 'needs_attention', last_error_code = 'refund_pending_too_long'
      where id = j.id;
      return 'needs_attention';
    end if;
    return 'awaiting_refund';

  elsif p_outcome = 'refunded' then
    update public.food_stripe_jobs
    set status = 'done',
        stripe_refund_id = coalesce(p_refund_id, stripe_refund_id),
        last_error_code = null,
        locked_until = null, completed_at = now(), updated_at = now()
    where id = j.id;
    if p_fee_refunded then
      update public.food_stripe_payments
      set application_fee_refunded_satang = application_fee_satang,
          application_fee_refunded_at = now()
      where order_id = j.order_id and application_fee_satang > 0
        and application_fee_refunded_satang = 0;
    end if;
    update public.food_stripe_payments
    set status = 'refunded', refunded_at = coalesce(refunded_at, now()), updated_at = now()
    where order_id = j.order_id and status = 'paid';
    update public.food_orders
    set payment_status = 'refunded',
        refund_status = 'refunded',
        refunded_at = coalesce(refunded_at, now()),
        stripe_refund_id = coalesce(p_refund_id, j.stripe_refund_id, stripe_refund_id)
    where id = j.order_id and payment_status = 'paid'
    returning order_number into v_order_number;
    if found then
      insert into public.food_order_events(order_id, event_type, note, actor_id)
      values (j.order_id, 'refund_refunded', 'คืนเงินผ่าน Stripe สำเร็จ', null);
      perform internal.food_stripe_refund_notify(
        j.order_id, 'คืนเงินออเดอร์ #' || v_order_number || ' แล้ว', null);
    end if;
    return 'done';

  elsif p_outcome = 'retry' then
    if j.status = 'awaiting_refund' then
      update public.food_stripe_jobs
      set locked_until = null, last_error_code = v_code,
          next_attempt_at = now() + internal.food_stripe_job_delay(j.poll_count),
          updated_at = now()
      where id = j.id;
      return 'awaiting_refund';
    end if;
    if j.attempts >= j.max_attempts then
      perform internal.food_stripe_job_fail(j.id, coalesce(v_code, 'max_attempts_exceeded'));
      return 'failed';
    end if;
    update public.food_stripe_jobs
    set locked_until = null, last_error_code = v_code,
        next_attempt_at = now() + internal.food_stripe_job_delay(j.attempts),
        updated_at = now()
    where id = j.id;
    return 'queued';

  elsif p_outcome = 'failed' then
    perform internal.food_stripe_job_fail(j.id, coalesce(v_code, 'failed'));
    return 'failed';

  else -- needs_attention
    update public.food_stripe_jobs
    set status = 'needs_attention', last_error_code = coalesce(v_code, 'needs_attention'),
        locked_until = null, updated_at = now()
    where id = j.id;
    return 'needs_attention';
  end if;
end;
$$;
revoke all on function public.food_complete_stripe_job(uuid,text,text,text,boolean) from public, anon, authenticated;
grant execute on function public.food_complete_stripe_job(uuid,text,text,text,boolean) to service_role;

-- ------------------------------------------------------------
-- Cron key (Vault) + tick, same pattern as food-unpaid-timeout
-- ------------------------------------------------------------

do $$
begin
  if not exists (select 1 from vault.secrets where name='wynos_food_refund_worker_cron_key') then
    perform vault.create_secret(
      encode(gen_random_bytes(32),'hex'),
      'wynos_food_refund_worker_cron_key',
      'Authenticate the Food Stripe refund/expire worker'
    );
  end if;
end;
$$;

create or replace function public.food_refund_worker_cron_authorized(p_token text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_token is not null and exists (
    select 1 from vault.decrypted_secrets s
    where s.name='wynos_food_refund_worker_cron_key'
      and s.decrypted_secret = p_token
  )
$$;
revoke all on function public.food_refund_worker_cron_authorized(text) from public, anon, authenticated;
grant execute on function public.food_refund_worker_cron_authorized(text) to service_role;

-- The cron launcher only sends a signed request. Stripe calls and job
-- outcomes happen in the Edge worker, never in this function.
create or replace function internal.food_refund_worker_tick()
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
  where name='wynos_food_refund_worker_cron_key';
  select decrypted_secret into v_url from vault.decrypted_secrets
  where name='wynos_project_url';

  if nullif(v_token,'') is null or coalesce(v_url,'') !~ '^https://[a-z0-9-]+[.]supabase[.]co/?$' then
    raise exception 'food refund worker cron vault configuration missing';
  end if;

  select net.http_post(
    url := rtrim(v_url,'/') || '/functions/v1/food-stripe-refund-worker',
    headers := jsonb_build_object('Content-Type','application/json','x-wynos-cron-key',v_token),
    body := '{}'::jsonb,
    timeout_milliseconds := 25000
  ) into v_request_id;
  return v_request_id;
end;
$$;
revoke all on function internal.food_refund_worker_tick() from public, anon, authenticated;

-- ------------------------------------------------------------
-- Merchant retry (requeue only; the worker does the Stripe call)
-- ------------------------------------------------------------

create or replace function public.merchant_retry_stripe_refund(p_order_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.food_orders%rowtype;
  v_job uuid;
begin
  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found then raise exception 'order not found'; end if;
  if not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
  end if;
  if v_order.status <> 'cancelled' or v_order.payment_status <> 'paid'
     or v_order.payment_provider is distinct from 'stripe' then
    raise exception 'stripe_refund_not_eligible';
  end if;

  select j.id into v_job
  from public.food_stripe_jobs j
  where j.order_id = p_order_id and j.kind = 'refund'
    and j.reason <> 'duplicate_payment' and j.status = 'failed'
  order by j.created_at desc
  limit 1
  for update;
  if v_job is null then
    raise exception 'no_failed_refund';
  end if;

  update public.food_stripe_jobs
  set status = 'queued',
      attempts = 0,
      poll_count = 0,
      requeue_count = requeue_count + 1,
      next_attempt_at = now(),
      locked_until = null,
      completed_at = null,
      last_error_code = null,
      requeued_by = (select auth.uid()),
      requeued_at = now(),
      updated_at = now()
  where id = v_job;

  update public.food_orders
  set refund_status = 'pending',
      refund_updated_by = (select auth.uid())
  where id = p_order_id and refund_status = 'failed';

  insert into public.food_order_events(order_id, event_type, note, actor_id)
  values (p_order_id, 'refund_retry_requested', 'ร้านขอให้ระบบคืนเงินอีกครั้ง', (select auth.uid()));

  return 'queued';
end;
$$;
revoke all on function public.merchant_retry_stripe_refund(uuid) from public, anon;
grant execute on function public.merchant_retry_stripe_refund(uuid) to authenticated;

-- ------------------------------------------------------------
-- Public boolean RPCs for ZOKY (no Stripe ids, no account details)
-- ------------------------------------------------------------

create or replace function public.food_payment_policy_public()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select internal.food_stripe_only_active()
$$;
revoke all on function public.food_payment_policy_public() from public;
grant execute on function public.food_payment_policy_public() to anon, authenticated, service_role;

-- Per published store: can it take an order now, and which Stripe methods.
-- With the policy off every store keeps accepting orders (legacy behaviour).
create or replace function public.food_store_payment_options(p_store_ids uuid[])
returns table (store_id uuid, accepting_orders boolean, promptpay boolean, card boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_active boolean := internal.food_stripe_only_active();
begin
  if p_store_ids is null or cardinality(p_store_ids) = 0 then
    return;
  end if;
  if cardinality(p_store_ids) > 100 then
    raise exception 'too many stores';
  end if;

  return query
  select s.id,
         (not v_active) or coalesce(r.ready, false),
         coalesce(r.ready and r.promptpay_enabled, false),
         coalesce(r.ready, false)
  from public.food_stores s
  left join lateral (
    select (s.stripe_payments_enabled and a.status = 'ready'
            and a.details_submitted and a.charges_enabled) as ready,
           a.promptpay_enabled
    from public.food_stripe_accounts a
    where a.store_id = s.id
  ) r on true
  where s.id = any(p_store_ids)
    and s.is_published;
end;
$$;
revoke all on function public.food_store_payment_options(uuid[]) from public;
grant execute on function public.food_store_payment_options(uuid[]) to anon, authenticated, service_role;
