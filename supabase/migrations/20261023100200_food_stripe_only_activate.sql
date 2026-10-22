-- ZOKY Stripe-only cut-over (Founder D11: immediate). From now on:
--   * new source='app' orders need a ready Stripe account (food_orders_require_stripe_ready);
--   * slip submission and manual paid/issue are refused on source='app' orders,
--     except legacy slips submitted before this moment (food_orders_payment_guard).
-- Manual merchant orders (source='manual') are unaffected (D7).
-- Production gate: the last rollout step; needs its own Founder approval after
-- the worker, the jobs migration, cron, EDGE and PHASE are live and verified.
-- ROLLBACK: supabase/rollbacks/20261023100200_food_stripe_only_activate_rollback.sql
-- Idempotent: rerunning keeps the original cut-over time.
do $$
begin
  if to_regclass('public.food_payment_policy') is null
     or (select count(*) from pg_trigger
         where tgrelid = 'public.food_orders'::regclass and not tgisinternal
           and tgname in ('food_orders_payment_guard','food_orders_payment_jobs','food_orders_require_stripe_ready')) <> 3 then
    raise exception 'apply 20261023100000_food_stripe_jobs_auto_refund.sql first';
  end if;
end;
$$;

update public.food_payment_policy
set stripe_only_from = now(), updated_at = now()
where id and stripe_only_from is null;
