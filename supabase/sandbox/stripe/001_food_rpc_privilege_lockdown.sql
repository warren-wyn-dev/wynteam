-- Sandbox-only function privilege lockdown while composing staged Food migrations.
revoke execute on function public.food_next_order_number() from public, anon, authenticated;
revoke execute on function public.food_touch_updated_at() from public, anon, authenticated;
revoke execute on function public.food_create_manual_order(uuid,text,text,text,text,jsonb,text) from public, anon, authenticated;
revoke execute on function public.food_create_order(uuid,text,text,text,text,jsonb) from public, anon, authenticated;
revoke execute on function public.food_submit_payment(uuid,text) from public, anon, authenticated;
revoke execute on function public.food_set_payment_status(uuid,text,text) from public, anon, authenticated;
revoke execute on function public.food_can_view_order(uuid) from public, anon, authenticated;
revoke execute on function public.food_can_manage_order(uuid) from public, anon, authenticated;
grant execute on function public.food_create_order(uuid,text,text,text,text,jsonb) to authenticated;
grant execute on function public.food_submit_payment(uuid,text) to authenticated;
grant execute on function public.food_set_payment_status(uuid,text,text) to authenticated;
grant execute on function public.food_can_view_order(uuid) to authenticated;
grant execute on function public.food_can_manage_order(uuid) to authenticated;
