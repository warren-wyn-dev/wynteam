-- WYNOS Finance QA catalog-level security regression; rollback-only, no data mutation.
-- Refuse non-QA project; never apply on WYNOS Production.
BEGIN;
DO $$
DECLARE
  p record;
  v_count int:=0;
  v_private int:=0;
  v_rows int:=0;
  v_def text;
BEGIN
  if not exists (
    select 1 from public.food_orders o
    join public.food_stripe_payments pay on pay.order_id=o.id
    where o.order_number='WF000005' and o.payment_status='paid'
      and o.refund_status='none' and pay.payment_method='promptpay' and pay.livemode=false
  ) then
    raise exception 'Not authorized QA fixture: refusing Finance privilege audit';
  end if;

  for p in
    select pr.*, n.nspname from pg_proc pr
    join pg_namespace n on n.oid=pr.pronamespace
    where n.nspname='public' and pr.proname = any(array[
      'admin_food_finance_buckets_v2_qa','admin_food_finance_order_details_v2_qa',
      'admin_food_finance_events_qa','admin_food_finance_order_qa',
      'admin_food_finance_refunds_qa','admin_food_finance_report_qa',
      'merchant_food_finance_buckets_v2_qa','merchant_food_finance_order_details_v2_qa',
      'merchant_food_finance_events_qa','merchant_food_finance_report_qa'
    ])
  loop
    v_count:=v_count+1;
    v_def:=pg_get_functiondef(p.oid);
    if not p.prosecdef or
      not exists (select 1 from unnest(p.proconfig) conf where conf like 'search_path=%')
      or has_function_privilege('anon',p.oid,'EXECUTE')
      or not has_function_privilege('authenticated',p.oid,'EXECUTE')
      or not has_function_privilege('service_role',p.oid,'EXECUTE')
    then
      raise exception 'Finance wrapper grants/definer/search_path unsafe: %',p.proname;
    end if;

    if p.proname like 'admin_%' and strpos(v_def,'public.wynos_gp_qa_is_admin()')=0 then
      raise exception 'Admin allowlist check absent: %',p.proname;
    elsif p.proname like 'merchant_%' and (
      strpos(v_def,'public.merchant_has_store_role(')=0
      or strpos(v_def,'auth.uid()')=0 or strpos(v_def,'''owner''')=0
    ) then
      raise exception 'Merchant owner check absent: %',p.proname;
    end if;
  end loop;
  if v_count<>10 then raise exception 'Expected 10 Finance client wrappers; found %',v_count;end if;

  for p in
    select pr.*,n.nspname from pg_proc pr
    join pg_namespace n on n.oid=pr.pronamespace
    where n.nspname='wynos_finance_qa_private'
    and pr.proname = any(array[
      'food_finance_report_core_qa','food_finance_events_core_qa',
      'food_finance_buckets_core_v2_qa','food_finance_order_core_v2_qa'
    ])
  loop
    v_private:=v_private+1;
    if p.prosecdef or has_function_privilege('anon',p.oid,'EXECUTE')
     or has_function_privilege('authenticated',p.oid,'EXECUTE')
     or not has_function_privilege('service_role',p.oid,'EXECUTE')
     or has_schema_privilege('anon',p.pronamespace,'USAGE')
     or has_schema_privilege('authenticated',p.pronamespace,'USAGE')
    then
      raise exception 'Internal Finance read core leaked or not invoker: %',p.proname;
    end if;
  end loop;
  if v_private<>4 then raise exception 'Expected 4 internal read cores, got %',v_private;end if;

  for p in
    select c.* from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'
    and c.relname=any(array[
      'food_gp_store_rates','food_gp_rate_audit','food_gp_order_snapshots',
      'food_gp_admin_allowlist','food_finance_order_projections_qa',
      'food_finance_projection_lines_qa','food_finance_refund_adjustments_qa',
      'food_finance_refund_lines_qa'
    ])
  loop
    v_rows:=v_rows+1;
    if not p.relrowsecurity or
       has_table_privilege('anon',p.oid,'SELECT') or
       has_table_privilege('authenticated',p.oid,'SELECT') or
       has_table_privilege('authenticated',p.oid,'INSERT') or
       has_table_privilege('authenticated',p.oid,'UPDATE') or
       has_table_privilege('authenticated',p.oid,'DELETE')
    then
      raise exception 'Finance/GP private table policy/grant unsafe: %',p.relname;
    end if;
  end loop;
  if v_rows<>8 then raise exception 'Expected 8 private Finance/GP tables, got %',v_rows;end if;

  if has_function_privilege('anon',
    'public.food_finance_append_refund_qa(uuid,text,bigint,bigint,text)','EXECUTE')
   or has_function_privilege('authenticated',
    'public.food_finance_append_refund_qa(uuid,text,bigint,bigint,text)','EXECUTE')
  then raise exception 'Refund simulation mutation exposed to client';end if;

  raise notice 'PASS: Finance QA authorization catalog: 10 guarded client RPCs, 4 invoker private cores, 8 denied tables, refund mutation unavailable to user roles';
END;
$$;
ROLLBACK;