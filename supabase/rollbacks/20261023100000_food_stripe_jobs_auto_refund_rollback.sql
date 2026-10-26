-- Rollback for 20261023100000_food_stripe_jobs_auto_refund.sql (and the two
-- follow-ups). Founder approval required. Order: stop the worker schedule,
-- return to legacy payment behaviour, then remove the triggers so no new jobs
-- are queued. Tables, job history, functions and the Vault key are kept for
-- audit/reconciliation (dropping them is a separate, destructive change).
-- The food_orders.refund_awaiting_customer column is also kept (additive,
-- default false; nothing writes it once the worker stops).
-- The food_stripe_jobs failed_notified_at / attention_notified_at notice
-- markers are kept too (additive, nullable).
-- Refund jobs still queued are NOT executed after this; reconcile them with
--   select id, order_id, kind, status, last_error_code from public.food_stripe_jobs
--   where status in ('queued','awaiting_refund');
-- and use merchant-stripe-refund (legacy button) where needed.
-- food_requeue_stripe_refund_jobs (ZOKY-156) stays callable by service_role:
-- stripe-webhook calls it on succeeded refunds, and a revoke would make
-- those events fail; with no worker the requeued jobs only wait (queued).
do $$
declare v_job bigint;
begin
  if exists (select 1 from pg_extension where extname='pg_cron') then
    for v_job in select jobid from cron.job where jobname='wynos-food-stripe-refund-worker' loop
      perform cron.unschedule(v_job);
    end loop;
  end if;
end;
$$;

update public.food_payment_policy set stripe_only_from = null, updated_at = now() where id;

drop trigger if exists food_orders_require_stripe_ready on public.food_orders;
drop trigger if exists food_orders_payment_jobs on public.food_orders;
drop trigger if exists food_orders_payment_guard on public.food_orders;
drop trigger if exists food_stripe_payments_keep_first on public.food_stripe_payments;

-- With the worker and triggers gone, a merchant retry would requeue a failed
-- refund that nothing executes and show the order as refunding again.
-- Re-applying 20261023100000 grants it back.
revoke execute on function public.merchant_retry_stripe_refund(uuid) from authenticated;
