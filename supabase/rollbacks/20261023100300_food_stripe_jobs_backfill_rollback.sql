-- Rollback for 20261023100300_food_stripe_jobs_backfill.sql (Founder approval
-- required). Removes only backfill jobs the worker has not picked up yet
-- (no attempt, no Stripe refund). Jobs already sent to Stripe are kept: a
-- refund that exists at Stripe cannot be undone here; reconcile with
--   select id, order_id, status, stripe_refund_id, last_error_code
--   from public.food_stripe_jobs where reason = 'backfill';
-- Orders are not changed by the backfill until the worker runs, so nothing
-- else needs restoring.
delete from public.food_stripe_jobs
where reason = 'backfill' and status = 'queued' and attempts = 0
  and stripe_refund_id is null;
