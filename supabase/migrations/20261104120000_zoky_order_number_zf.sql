-- ZOKY order numbers ZF-0036 (Founder 2026-11-04: "เลขออเดอร์ คือ ZF-0000").
-- New orders only: the same sequence continues with the ZF- prefix, so
-- numbers stay unique and in order. Past orders keep their WF0035 numbers
-- (old notifications, LINE messages and slips still point at them).
-- At least 4 digits; past 9999 the number grows instead of being cut.
-- Ship send-push-notification (accepts WF and ZF-) before this, or ZF-
-- order pushes would be routed to the wrong app.
-- Rollback: supabase/rollbacks/20261104120000_zoky_order_number_zf_rollback.sql
create or replace function public.food_next_order_number()
returns text
language sql
volatile
set search_path = public
as $$
  select 'ZF-' || lpad(n, greatest(4, length(n)), '0')
  from (select nextval('public.food_order_number_seq')::text as n) s;
$$;
revoke all on function public.food_next_order_number() from public, anon, authenticated;
