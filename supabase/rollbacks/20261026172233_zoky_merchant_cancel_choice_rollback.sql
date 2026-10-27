-- Removes only the added RPC; existing decisions and audit/evidence remain.
begin;
drop function public.food_store_cancel_order(uuid,boolean,text);
notify pgrst,'reload schema';
commit;
