-- Rollback for 20261023100100_food_stripe_jobs_enable_cron.sql (Founder approval
-- required). Stops the worker schedule only; jobs keep queueing and run again
-- when the schedule is re-enabled.
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
