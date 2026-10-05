-- WYNOS Merchant readiness hardening v1
-- The public storefront uses server-authoritative schedule checks and shared
-- client logic; anonymous callers do not need direct access to this helper RPC.

revoke execute on function public.food_store_open_status(uuid) from anon;
grant execute on function public.food_store_open_status(uuid) to authenticated;
