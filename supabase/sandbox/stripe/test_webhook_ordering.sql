-- WYNOS Stripe sandbox regression. Never apply to Production.
-- Uses a fake auth identity and temporary Stripe objects, then rolls everything back.
begin;
do $qa$
declare
 v_store uuid := gen_random_uuid();
 v_buyer uuid := gen_random_uuid();
 v_order uuid := gen_random_uuid();
 v_account text;
 v_event text := 'evt_sandbox_qa_'||replace(gen_random_uuid()::text,'-','');
 v_ok boolean;
begin
 v_account := 'acct_test_qa_'||replace(v_store::text,'-','');
 insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at)
 values(v_buyer,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
        replace(v_buyer::text,'-','')||'@sandbox.invalid','',now());
 insert into public.profiles(id,username) values(v_buyer,'qa_'||replace(v_buyer::text,'-','')) on conflict(id) do nothing;
 insert into public.food_stores(id,slug,name,is_open,is_published)
 values(v_store,'qa_'||replace(v_store::text,'-',''),'Sandbox Regression',true,false);
 insert into public.food_orders
 (id,store_id,buyer_id,created_by,order_number,recipient_name,recipient_phone,shipping_address,subtotal,delivery_fee,total)
 values(v_order,v_store,v_buyer,v_buyer,'QA-'||replace(v_order::text,'-',''),'Fake buyer','0000000000','Sandbox only',125.50,0,125.50);
 insert into public.food_stripe_accounts(store_id,stripe_account_id,status,details_submitted,charges_enabled,payouts_enabled,livemode)
 values(v_store,v_account,'ready',true,true,true,false);
 v_ok:=public.food_apply_stripe_event(v_event||'paid','checkout.session.completed',v_order,v_account,'cs_test_qa',
       'cs_test_qa','pi_test_qa',12550,'thb','paid','card');
 if v_ok is distinct from true then raise exception 'paid event failed'; end if;
 v_ok:=public.food_apply_stripe_event(v_event||'paid','checkout.session.completed',v_order,v_account,'cs_test_qa',
       'cs_test_qa','pi_test_qa',12550,'thb','paid','card');
 if v_ok is distinct from false then raise exception 'duplicate accepted'; end if;
 perform public.food_apply_stripe_event(v_event||'latefail','payment_intent.payment_failed',v_order,v_account,
       'pi_test_qa',null,'pi_test_qa',12550,'thb','failed','card');
 if (select status from public.food_stripe_payments where order_id=v_order) <> 'paid'
 then raise exception 'late failure regressed payment'; end if;
 perform public.food_apply_stripe_event(v_event||'refund','charge.refunded',v_order,v_account,
       'ch_test_qa',null,'pi_test_qa',12550,'thb','refunded','card',null,'re_test_qa');
 perform public.food_apply_stripe_event(v_event||'latepaid','checkout.session.completed',v_order,v_account,
       'cs_test_qa','cs_test_qa','pi_test_qa',12550,'thb','paid','card');
 if (select status from public.food_stripe_payments where order_id=v_order) <> 'refunded'
    or (select payment_status from public.food_orders where id=v_order) <> 'refunded'
 then raise exception 'refund status regressed'; end if;
end $qa$;
rollback;
select 'PASS: paid -> duplicate -> late failure -> refund -> late success; all fixtures rolled back' as result;
