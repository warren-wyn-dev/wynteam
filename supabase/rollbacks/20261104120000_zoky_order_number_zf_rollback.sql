-- Rollback for 20261104120000_zoky_order_number_zf.sql: new orders are
-- numbered WF0036 again (migrations_wynos_push_app_routing_v1.sql). Orders
-- already numbered ZF- keep their numbers.
create or replace function public.food_next_order_number()
returns text
language sql
volatile
set search_path = public
as $$
  select 'WF' || lpad(n, greatest(4, length(n)), '0')
  from (select nextval('public.food_order_number_seq')::text as n) s;
$$;
revoke all on function public.food_next_order_number() from public, anon, authenticated;
