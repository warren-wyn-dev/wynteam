-- ZOKY Stripe jobs, OPT-IN backfill (CTO C3): queue one automatic full refund
-- for Stripe-paid orders that were cancelled BEFORE the jobs migration and
-- are still waiting for a refund (refund_status pending/failed) without a
-- refund job. Not applied automatically: run only through
-- food-apply-zoky-stripe-jobs.yml step `backfill`, after `jobs` and `cron`,
-- with its own Founder approval (review the preflight count first).
-- Money safety is the worker's: it lists refunds before creating one and
-- adopts any refund that already exists (legacy button, Dashboard), and it
-- never sends an amount (full refund only).
-- ROLLBACK: supabase/rollbacks/20261023100300_food_stripe_jobs_backfill_rollback.sql
-- (removes backfill jobs that have not been picked up yet).
-- Idempotent: the dedupe key matches the trigger's, so reruns add nothing.
do $$
begin
  if to_regclass('public.food_stripe_jobs') is null
     or to_regprocedure('public.food_complete_stripe_job(uuid,text,text,text,boolean,boolean)') is null then
    raise exception 'apply 20261023100000_food_stripe_jobs_auto_refund.sql first';
  end if;
end;
$$;

with candidates as (
  select o.id, o.store_id, o.stripe_checkout_session_id, o.stripe_payment_intent_id
  from public.food_orders o
  where o.status = 'cancelled'
    and o.payment_status = 'paid'
    and o.payment_provider = 'stripe'
    and o.refund_status in ('pending','failed')
    and not exists (
      select 1 from public.food_stripe_jobs j
      where j.order_id = o.id and j.kind = 'refund' and j.reason <> 'duplicate_payment'
    )
), queued as (
  insert into public.food_stripe_jobs(kind, order_id, store_id, dedupe_key, reason,
                                      checkout_session_id, payment_intent_id)
  select 'refund', c.id, c.store_id,
         'refund:' || c.id || ':' || coalesce(c.stripe_payment_intent_id, c.stripe_checkout_session_id, 'order'),
         'backfill', c.stripe_checkout_session_id, c.stripe_payment_intent_id
  from candidates c
  on conflict (dedupe_key) do nothing
  returning order_id
)
insert into public.food_order_events(order_id, event_type, note, actor_id)
select q.order_id, 'refund_auto_queued', 'ระบบจะคืนเงินผ่าน Stripe อัตโนมัติ (ออเดอร์ที่ยกเลิกก่อนเปิดระบบ)', null
from queued q;
