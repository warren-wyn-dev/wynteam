-- Rollback for 20261028090000_zoky_billing_001.sql.
-- Invoices are financial records: export food_billing_invoices,
-- food_billing_price_history and food_store_billing before running this.
-- Turning billing off in ZOKY Admin (billing_enabled = false) already stops new
-- invoices and reminders; use this only to remove the feature entirely.
-- Slip files under food-private/billing/ are left in storage, and the three
-- billing audit event types stay in audit_log_event_type_check (harmless).

do $$
declare v_job bigint;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    for v_job in select jobid from cron.job where jobname = 'zoky-billing-daily' loop
      perform cron.unschedule(v_job);
    end loop;
  end if;
end;
$$;

drop policy if exists "Food billing slips upload by store owner/admin" on storage.objects;
drop policy if exists "Food billing slips readable by store owner/admin" on storage.objects;
drop trigger if exists food_stores_billing_published on public.food_stores;

drop function if exists public.admin_waive_billing_invoice(uuid, text);
drop function if exists public.admin_review_billing_invoice(uuid, boolean, text);
drop function if exists public.admin_update_billing_settings(boolean, numeric, integer, text, text, text, text, text, text, text, text);
drop function if exists public.admin_billing_overview();
drop function if exists public.merchant_billing_receipt(uuid);
drop function if exists public.merchant_submit_billing_slip(uuid, text);
drop function if exists public.merchant_billing(uuid);
drop function if exists public.food_billing_slip_upload_allowed(uuid, uuid);
drop function if exists internal.food_billing_run(date);
drop function if exists internal.food_billing_store_published();
drop function if exists internal.food_billing_backfill(date);
drop function if exists internal.food_billing_notify(uuid, text);
drop function if exists internal.food_billing_next_cycle(date, date);
drop function if exists internal.food_billing_cycle_start(date, date);
drop function if exists internal.food_billing_today();

drop table if exists public.food_billing_reminders;
drop table if exists public.food_billing_skipped_cycles;
drop table if exists public.food_billing_invoices;
drop sequence if exists public.food_billing_receipt_seq;
drop table if exists public.food_store_billing;
drop table if exists public.food_billing_price_history;
drop table if exists public.food_billing_settings;
