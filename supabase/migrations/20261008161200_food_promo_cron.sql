-- Food Promotions: secure pg_cron -> Edge via dedicated Vault secret.
-- The job is deliberately INACTIVE until the service is deployed and QA passes.
do $$
begin
  if not exists (select 1 from vault.secrets where name='wynos_food_promo_cron_key') then
    perform vault.create_secret(
      encode(gen_random_bytes(32),'hex'),
      'wynos_food_promo_cron_key',
      'WYNOS Food promotional notification scheduler'
    );
  end if;
end;
$$;

create or replace function public.verify_food_promo_cron_key(p_key text)
returns boolean language sql stable security definer set search_path='' as $fn$
  select p_key is not null and length(p_key) >= 32
    and exists (
      select 1 from vault.decrypted_secrets s
      where s.name='wynos_food_promo_cron_key'
        and s.decrypted_secret=p_key
    )
$fn$;
revoke all on function public.verify_food_promo_cron_key(text) from public, anon, authenticated;
grant execute on function public.verify_food_promo_cron_key(text) to service_role;

do $$
declare v_job bigint;
begin
  if not exists(select 1 from pg_extension where extname='pg_cron')
    or not exists(select 1 from pg_extension where extname='pg_net') then
    raise exception 'Food promotion scheduling requires pg_cron and pg_net';
  end if;
  for v_job in select jobid from cron.job where jobname='wynos-food-promotions-5min' loop
    perform cron.unschedule(v_job);
  end loop;
  perform cron.schedule(
    'wynos-food-promotions-5min','*/5 * * * *',
    $job$
      select net.http_post(
        url := (
          select decrypted_secret from vault.decrypted_secrets
          where name='wynos_project_url' limit 1
        ) || '/functions/v1/send-food-promotion',
        headers := jsonb_build_object(
          'Content-Type','application/json',
          'X-Wynos-Food-Promo-Key',(
            select decrypted_secret from vault.decrypted_secrets
            where name='wynos_food_promo_cron_key' limit 1
          )
        ),
        body := '{"source":"pg_cron"}'::jsonb,
        timeout_milliseconds := 20000
      );
    $job$
  );
  perform cron.alter_job(
    job_id := (select jobid from cron.job where jobname='wynos-food-promotions-5min' limit 1),
    active := false
  );
end;
$$;
