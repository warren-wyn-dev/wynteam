-- Production release gate: apply ONLY after the Food timeout DB schema,
-- food-unpaid-timeout Edge worker, and updated food-stripe-checkout are live.
-- Schedule once per minute. This migration enables cancellation for new
-- Food customer orders only; existing NULL payment_due_at rows are excluded.
-- Rollback: select cron.unschedule(jobid) from cron.job
--   where jobname='wynos-food-unpaid-timeout'; (Founder-approved only).

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
