-- Run only for an explicitly authorized rollback, after hiding the two pages.
-- No operational orders, payments, events or customer data are deleted.
drop function if exists public.admin_food_customer_history(uuid,text,integer,integer);
drop function if exists public.admin_food_payment_monitor(text,text,text,date,date,integer,integer);
drop function if exists internal.admin_food_payment_rows(timestamptz,timestamptz,text,text);
drop index if exists public.food_stripe_webhook_events_order_received_idx;
drop index if exists public.food_orders_admin_created_id_idx;
notify pgrst, 'reload schema';
