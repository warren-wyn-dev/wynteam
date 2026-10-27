-- Merchant cancellation/no-show decision for contract v2.1. No legacy refund
-- path is removed: the Founder's documented temporary risk acceptance remains.
begin;
set local lock_timeout='5s';
do $$ begin
 if to_regprocedure('public.food_complete_pickup(uuid,text)') is null then
   raise exception 'apply ZOKY-FULFILL-001 v2 before merchant cancellation choices';
 end if;
end $$;
create or replace function public.food_store_cancel_order(p_order_id uuid,p_refund boolean,p_note text default null)
returns void language plpgsql security definer set search_path='' as $$
declare o public.food_orders%rowtype; prev text:=current_setting('wyn.food_cancel_refund',true);
begin
 select * into o from public.food_orders where id=p_order_id for update;
 if auth.uid() is null or not found or not public.merchant_has_store_role(o.store_id,array['owner','admin','manager','orders']) then
   raise exception 'order management role required';
 end if;
 if p_refund is null then raise exception 'refund decision required'; end if;
 if char_length(btrim(coalesce(p_note,''))) not between 3 and 1000 then raise exception 'cancellation reason required'; end if;
 if o.status in ('cancelled','delivered') then raise exception 'order is closed'; end if;
 if p_refund and o.payment_status<>'paid' then raise exception 'only paid orders can be refunded'; end if;
 perform set_config('wyn.food_cancel_refund',case when p_refund then 'pending' else 'none' end,true);
 perform public.food_transition_order(p_order_id,'cancelled',null,p_note);
 perform set_config('wyn.food_cancel_refund',coalesce(prev,''),true);
 update public.food_orders set cancel_requested_at=null where id=p_order_id;
 insert into public.food_order_events(order_id,event_type,note,actor_id)
 values(p_order_id,case when p_refund then 'merchant_cancelled_refund' else 'merchant_cancelled_no_refund' end,p_note,auth.uid());
exception when others then
 perform set_config('wyn.food_cancel_refund',coalesce(prev,''),true); raise;
end;
$$;
revoke all on function public.food_store_cancel_order(uuid,boolean,text) from public,anon;
grant execute on function public.food_store_cancel_order(uuid,boolean,text) to authenticated;
notify pgrst,'reload schema';
commit;
