-- ZOKY Stripe jobs: run food-stripe-refund-worker once per minute.
-- Production gate: apply ONLY after (1) the food-stripe-refund-worker Edge
-- Function is deployed and (2) 20261023100000_food_stripe_jobs_auto_refund.sql
-- is applied and verified. Each step needs its own Founder approval.
-- Same pattern as 20261008113001_food_unpaid_payment_timeout_enable_cron.sql.
-- ROLLBACK: supabase/rollbacks/20261023100100_food_stripe_jobs_enable_cron_rollback.sql
-- Idempotent when rerun.
do $$
declare v_job bigint;
begin
  if to_regprocedure('internal.food_refund_worker_tick()') is null then
    raise exception 'apply 20261023100000_food_stripe_jobs_auto_refund.sql first';
  end if;
  if exists (select 1 from pg_extension where extname='pg_cron')
     and exists (select 1 from pg_extension where extname='pg_net') then
    for v_job in select jobid from cron.job
      where jobname='wynos-food-stripe-refund-worker' loop
      perform cron.unschedule(v_job);
    end loop;
    perform cron.schedule('wynos-food-stripe-refund-worker','* * * * *',
      'select internal.food_refund_worker_tick();');
  else
    raise exception 'pg_cron and pg_net required to run the refund worker';
  end if;
end;
$$;
