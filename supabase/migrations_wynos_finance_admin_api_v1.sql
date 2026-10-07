-- WYNOS Finance Control Center admin/merchant API.
-- All financial mutations are admin-only SECURITY DEFINER RPCs.
-- Direct table access remains denied by RLS/grants.

create or replace function public.admin_finance_control_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.food_finance_configs%rowtype;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can manage finance'; end if;
  c:=internal.food_finance_config_at(now());

  return jsonb_build_object(
    'config',to_jsonb(c)-'created_by',
    'flags',(
      select coalesce(jsonb_object_agg(x.flag_key,x.enabled),'{}'::jsonb)
      from (
        select distinct on (f.flag_key) f.flag_key,f.enabled
        from public.food_feature_flags f
        where f.effective_from<=now()
        order by f.flag_key,f.effective_from desc
      ) x
    ),
    'stores',(
      select coalesce(jsonb_agg(jsonb_build_object(
        'id',s.id,'name',s.name,'slug',s.slug,
        'gp_bps',g.gp_bps,'gp_source',g.gp_source,
        'override_id',g.override_id,'promotion_id',g.promotion_id,
        'payment_ready',s.stripe_payments_enabled,
        'payment_enabled',coalesce(o.payment_enabled,true),
        'payout_suspended',coalesce(o.payout_suspended,false),
        'promotion_eligible',coalesce(o.promotion_eligible,true)
      ) order by s.name),'[]'::jsonb)
      from public.food_stores s
      cross join lateral internal.food_effective_gp(s.id,now()) g
      left join lateral (
        select oo.* from public.food_store_finance_overrides oo
        where oo.store_id=s.id and oo.effective_from<=now()
        order by oo.effective_from desc limit 1
      ) o on true
    ),
    'gp_promotions',(
      select coalesce(jsonb_agg(to_jsonb(g) order by g.starts_at desc),'[]'::jsonb)
      from public.food_store_gp_promotions g
      where g.ends_at>now()
    ),
    'zone_pricing',(
      select coalesce(jsonb_agg(to_jsonb(z)-'created_by' order by z.priority,z.effective_from desc),'[]'::jsonb)
      from public.food_delivery_zone_pricing z
      where z.effective_from<=now() and (z.effective_to is null or z.effective_to>now())
    ),
    'settlements',(
      select coalesce(jsonb_agg(
        (to_jsonb(ms)-'created_by'-'paid_by') || jsonb_build_object('store_name',s.name)
        order by ms.created_at desc
      ),'[]'::jsonb)
      from public.food_merchant_settlements ms
      join public.food_stores s on s.id=ms.store_id
      where ms.created_at>=now()-interval '180 days'
    ),
    'riders',(
      select coalesce(jsonb_agg(jsonb_build_object(
        'id',r.id,'user_id',r.user_id,'status',r.status,'active',r.active,
        'service_area_code',r.service_area_code,'payout_suspended',r.payout_suspended,
        'approved_at',r.approved_at
      ) order by r.created_at desc),'[]'::jsonb)
      from public.food_riders r
    )
  );
end;
$$;

revoke all on function public.admin_finance_control_snapshot() from public, anon;
grant execute on function public.admin_finance_control_snapshot() to authenticated;

create or replace function public.admin_finance_dashboard(p_from timestamptz,p_to timestamptz)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can view finance'; end if;
  if p_from is null or p_to is null or p_to<=p_from then raise exception 'invalid date range'; end if;

  return jsonb_build_object(
    'from',p_from,'to',p_to,
    'orders',(
      select count(*) from public.food_orders o
      where o.created_at>=p_from and o.created_at<p_to and o.status<>'cancelled'
    ),
    'gross_order_value_satang',(
      select coalesce(sum(f.customer_total_satang),0)
      from public.food_order_financials f
      join public.food_orders o on o.id=f.order_id
      where f.priced_at>=p_from and f.priced_at<p_to and o.status<>'cancelled'
    ),
    'gp_revenue_satang',(
      select coalesce(sum(f.gp_amount_satang-f.gp_refunded_satang),0)
      from public.food_order_financials f
      join public.food_orders o on o.id=f.order_id
      where f.priced_at>=p_from and f.priced_at<p_to and o.status<>'cancelled'
    ),
    'delivery_revenue_satang',(
      select coalesce(sum(f.delivery_fee_satang),0)
      from public.food_order_financials f
      join public.food_orders o on o.id=f.order_id
      where f.priced_at>=p_from and f.priced_at<p_to and o.status<>'cancelled'
    ),
    'stripe_fees_satang',(
      select coalesce(sum(f.stripe_fee_satang),0)
      from public.food_order_financials f
      where f.priced_at>=p_from and f.priced_at<p_to
    ),
    'merchant_net_satang',(
      select coalesce(sum(f.merchant_net_satang),0)
      from public.food_order_financials f
      join public.food_orders o on o.id=f.order_id
      where f.priced_at>=p_from and f.priced_at<p_to and o.status<>'cancelled'
    ),
    'rider_earnings_satang',(
      select coalesce(sum(f.rider_earning_satang+f.rider_adjustment_satang),0)
      from public.food_order_financials f
      join public.food_orders o on o.id=f.order_id
      where f.priced_at>=p_from and f.priced_at<p_to and o.status<>'cancelled'
    ),
    'refunds_satang',(
      select coalesce(sum(r.amount_satang),0)
      from public.food_refunds r
      where r.status='succeeded' and r.updated_at>=p_from and r.updated_at<p_to
    ),
    'promotion_cost_satang',(
      select coalesce(sum(f.platform_discount_satang),0)
      from public.food_order_financials f
      where f.priced_at>=p_from and f.priced_at<p_to
    ),
    'net_platform_revenue_satang',(
      select coalesce(sum(f.platform_revenue_satang),0)
      from public.food_order_financials f
      join public.food_orders o on o.id=f.order_id
      where f.priced_at>=p_from and f.priced_at<p_to and o.status<>'cancelled'
    ),
    'legacy_orders_without_snapshot',(
      select count(*) from public.food_orders o
      where o.created_at>=p_from and o.created_at<p_to
        and not exists(select 1 from public.food_order_financials f where f.order_id=o.id)
    )
  );
end;
$$;

revoke all on function public.admin_finance_dashboard(timestamptz,timestamptz) from public, anon;
grant execute on function public.admin_finance_dashboard(timestamptz,timestamptz) to authenticated;

create or replace function public.admin_set_finance_config(
  p_patch jsonb,
  p_effective_from timestamptz,
  p_reason text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  c public.food_finance_configs%rowtype;
  v_json jsonb;
  v_id uuid:=gen_random_uuid();
  v_at timestamptz:=coalesce(p_effective_from,now());
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can manage finance'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;
  if v_at<now()-interval '1 minute' then raise exception 'financial configuration cannot be backdated'; end if;
  if p_patch is null or jsonb_typeof(p_patch)<>'object' then raise exception 'invalid configuration patch'; end if;

  perform pg_advisory_xact_lock(hashtext('wynos-finance-config'));
  c:=internal.food_finance_config_at(now());
  v_json:=to_jsonb(c)
    || (p_patch-array['id','effective_from','created_by','created_at','reason'])
    || jsonb_build_object(
      'id',v_id,'effective_from',v_at,'created_by',v_admin,
      'reason',left(btrim(p_reason),500),'created_at',now()
    );

  insert into public.food_finance_configs
  select * from jsonb_populate_record(null::public.food_finance_configs,v_json);

  perform internal.log_audit_event(v_admin,'admin_finance_config_changed',null,
    jsonb_build_object(
      'old_value',to_jsonb(c)-'created_by',
      'new_value',(v_json-'created_by'),
      'reason',left(btrim(p_reason),500),
      'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
  return v_id;
end;
$$;

revoke all on function public.admin_set_finance_config(jsonb,timestamptz,text,jsonb) from public, anon;
grant execute on function public.admin_set_finance_config(jsonb,timestamptz,text,jsonb) to authenticated;

create or replace function public.admin_set_feature_flag(
  p_flag_key text,
  p_enabled boolean,
  p_effective_from timestamptz,
  p_reason text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_at timestamptz:=coalesce(p_effective_from,now());
  v_old boolean;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can manage features'; end if;
  if coalesce(p_flag_key,'') !~ '^[a-z0-9_]{2,80}$' then raise exception 'invalid feature flag'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;
  if v_at<now()-interval '1 minute' then raise exception 'feature flag cannot be backdated'; end if;

  v_old:=internal.food_feature_enabled(p_flag_key,now());
  insert into public.food_feature_flags(flag_key,effective_from,enabled,created_by,reason)
  values(p_flag_key,v_at,p_enabled,v_admin,left(btrim(p_reason),500));

  perform internal.log_audit_event(v_admin,'admin_feature_flag_changed',null,
    jsonb_build_object(
      'flag',p_flag_key,'old_value',v_old,'new_value',p_enabled,
      'effective_from',v_at,'reason',left(btrim(p_reason),500),
      'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
end;
$$;

revoke all on function public.admin_set_feature_flag(text,boolean,timestamptz,text,jsonb) from public, anon;
grant execute on function public.admin_set_feature_flag(text,boolean,timestamptz,text,jsonb) to authenticated;

create or replace function public.admin_set_store_finance_override(
  p_store_id uuid,
  p_patch jsonb,
  p_effective_from timestamptz,
  p_reason text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  o public.food_store_finance_overrides%rowtype;
  v_json jsonb;
  v_id uuid:=gen_random_uuid();
  v_at timestamptz:=coalesce(p_effective_from,now());
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can manage store finance'; end if;
  if not exists(select 1 from public.food_stores where id=p_store_id) then raise exception 'store not found'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;
  if v_at<now()-interval '1 minute' then raise exception 'store configuration cannot be backdated'; end if;
  if p_patch is null or jsonb_typeof(p_patch)<>'object' then raise exception 'invalid store configuration patch'; end if;

  perform pg_advisory_xact_lock(hashtext('wynos-store-finance:'||p_store_id::text));
  o:=internal.food_store_finance_override_at(p_store_id,now());
  v_json:=coalesce(to_jsonb(o),'{}'::jsonb)
    || (p_patch-array['id','store_id','effective_from','created_by','created_at','reason'])
    || jsonb_build_object(
      'id',v_id,'store_id',p_store_id,'effective_from',v_at,'created_by',v_admin,
      'reason',left(btrim(p_reason),500),'created_at',now()
    );

  insert into public.food_store_finance_overrides
  select * from jsonb_populate_record(null::public.food_store_finance_overrides,v_json);

  perform internal.log_audit_event(v_admin,'admin_store_finance_changed',p_store_id,
    jsonb_build_object(
      'old_value',case when o.id is null then null else to_jsonb(o)-'created_by' end,
      'new_value',v_json-'created_by',
      'reason',left(btrim(p_reason),500),
      'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
  return v_id;
end;
$$;

revoke all on function public.admin_set_store_finance_override(uuid,jsonb,timestamptz,text,jsonb) from public, anon;
grant execute on function public.admin_set_store_finance_override(uuid,jsonb,timestamptz,text,jsonb) to authenticated;

create or replace function public.admin_create_store_gp_promotion(
  p_store_id uuid,
  p_gp_bps integer,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_reason text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_id uuid;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can manage GP promotions'; end if;
  if not exists(select 1 from public.food_stores where id=p_store_id) then raise exception 'store not found'; end if;
  if p_gp_bps not between 0 and 10000 then raise exception 'invalid GP'; end if;
  if p_starts_at<now()-interval '1 minute' then raise exception 'GP promotion cannot be backdated'; end if;
  if p_ends_at<=p_starts_at then raise exception 'invalid GP promotion period'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;

  insert into public.food_store_gp_promotions(store_id,gp_bps,starts_at,ends_at,created_by,reason)
  values(p_store_id,p_gp_bps,p_starts_at,p_ends_at,v_admin,left(btrim(p_reason),500))
  returning id into v_id;

  perform internal.log_audit_event(v_admin,'admin_store_gp_promotion_created',p_store_id,
    jsonb_build_object(
      'new_value',jsonb_build_object('gp_bps',p_gp_bps,'starts_at',p_starts_at,'ends_at',p_ends_at),
      'reason',left(btrim(p_reason),500),'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
  return v_id;
end;
$$;

revoke all on function public.admin_create_store_gp_promotion(uuid,integer,timestamptz,timestamptz,text,jsonb) from public, anon;
grant execute on function public.admin_create_store_gp_promotion(uuid,integer,timestamptz,timestamptz,text,jsonb) to authenticated;

create or replace function public.admin_set_delivery_zone_pricing(
  p_service_area_code text,
  p_province text,
  p_patch jsonb,
  p_effective_from timestamptz,
  p_effective_to timestamptz,
  p_priority integer,
  p_reason text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_id uuid:=gen_random_uuid();
  v_json jsonb;
  v_at timestamptz:=coalesce(p_effective_from,now());
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can manage delivery pricing'; end if;
  if p_service_area_code is null and nullif(btrim(coalesce(p_province,'')),'') is null then raise exception 'area is required'; end if;
  if p_service_area_code is not null and not exists(select 1 from public.food_service_areas where code=p_service_area_code) then raise exception 'service area not found'; end if;
  if v_at<now()-interval '1 minute' then raise exception 'zone pricing cannot be backdated'; end if;
  if p_effective_to is not null and p_effective_to<=v_at then raise exception 'invalid zone pricing period'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;

  v_json:=(coalesce(p_patch,'{}'::jsonb)-array['id','created_by','created_at','reason'])
    || jsonb_build_object(
      'id',v_id,'service_area_code',p_service_area_code,'province',nullif(btrim(coalesce(p_province,'')),''),
      'priority',coalesce(p_priority,100),'effective_from',v_at,'effective_to',p_effective_to,
      'created_by',v_admin,'reason',left(btrim(p_reason),500),'created_at',now()
    );
  insert into public.food_delivery_zone_pricing
  select * from jsonb_populate_record(null::public.food_delivery_zone_pricing,v_json);

  perform internal.log_audit_event(v_admin,'admin_delivery_zone_pricing_changed',null,
    jsonb_build_object('new_value',v_json-'created_by','reason',left(btrim(p_reason),500),'metadata',coalesce(p_metadata,'{}'::jsonb))
  );
  return v_id;
end;
$$;

revoke all on function public.admin_set_delivery_zone_pricing(text,text,jsonb,timestamptz,timestamptz,integer,text,jsonb) from public, anon;
grant execute on function public.admin_set_delivery_zone_pricing(text,text,jsonb,timestamptz,timestamptz,integer,text,jsonb) to authenticated;

create or replace function public.admin_add_finance_adjustment(
  p_order_id uuid,
  p_store_id uuid,
  p_rider_id uuid,
  p_applies_to text,
  p_amount_satang bigint,
  p_reason text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_id uuid;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can create finance adjustments'; end if;
  if p_applies_to not in ('merchant','platform','rider') then raise exception 'invalid adjustment target'; end if;
  if p_amount_satang=0 then raise exception 'adjustment cannot be zero'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;

  insert into public.food_financial_adjustments(order_id,store_id,rider_id,applies_to,amount_satang,reason,created_by)
  values(p_order_id,p_store_id,p_rider_id,p_applies_to,p_amount_satang,left(btrim(p_reason),500),v_admin)
  returning id into v_id;

  if p_order_id is not null then
    if not exists(select 1 from public.food_order_financials where order_id=p_order_id) then raise exception 'financial snapshot missing'; end if;
    if p_applies_to='merchant' then
      update public.food_order_financials set merchant_adjustment_satang=merchant_adjustment_satang+p_amount_satang where order_id=p_order_id;
    elsif p_applies_to='platform' then
      update public.food_order_financials set platform_adjustment_satang=platform_adjustment_satang+p_amount_satang where order_id=p_order_id;
    else
      update public.food_order_financials set rider_adjustment_satang=rider_adjustment_satang+p_amount_satang where order_id=p_order_id;
    end if;
    perform internal.food_recompute_order_financials(p_order_id);
  end if;

  perform internal.log_audit_event(v_admin,'admin_finance_adjustment_created',p_order_id,
    jsonb_build_object(
      'adjustment_id',v_id,'store_id',p_store_id,'rider_id',p_rider_id,
      'applies_to',p_applies_to,'amount_satang',p_amount_satang,
      'reason',left(btrim(p_reason),500),'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
  return v_id;
end;
$$;

revoke all on function public.admin_add_finance_adjustment(uuid,uuid,uuid,text,bigint,text,jsonb) from public, anon;
grant execute on function public.admin_add_finance_adjustment(uuid,uuid,uuid,text,bigint,text,jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Merchant settlement engine
-- ---------------------------------------------------------------------------

create or replace function internal.food_merchant_settlement_rows(
  p_store_id uuid,p_from timestamptz,p_to timestamptz
)
returns table(
  order_id uuid,gross_sales_satang bigint,merchant_discount_satang bigint,
  gp_satang bigint,payment_fees_satang bigint,refunds_satang bigint,
  adjustments_satang bigint,net_satang bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select f.order_id,f.subtotal_satang,f.merchant_discount_satang,
         f.gp_amount_satang-f.gp_refunded_satang,
         f.stripe_fee_merchant_satang,f.merchant_refund_cost_satang,
         f.merchant_adjustment_satang,f.merchant_net_satang
  from public.food_order_financials f
  join public.food_orders o on o.id=f.order_id
  where f.store_id=p_store_id
    and o.status='delivered'
    and o.payment_status='paid'
    and f.priced_at>=p_from and f.priced_at<p_to
    and not exists(
      select 1 from public.food_merchant_settlement_lines l where l.order_id=f.order_id
    )
  order by f.priced_at,f.order_id
$$;

revoke all on function internal.food_merchant_settlement_rows(uuid,timestamptz,timestamptz) from public, anon, authenticated;

create or replace function public.admin_merchant_settlement_preview(
  p_store_id uuid,p_from timestamptz,p_to timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can manage settlements'; end if;
  return (
    select jsonb_build_object(
      'store_id',p_store_id,'from',p_from,'to',p_to,
      'order_count',count(*),
      'gross_sales_satang',coalesce(sum(gross_sales_satang),0),
      'merchant_discount_satang',coalesce(sum(merchant_discount_satang),0),
      'gp_satang',coalesce(sum(gp_satang),0),
      'payment_fees_satang',coalesce(sum(payment_fees_satang),0),
      'refunds_satang',coalesce(sum(refunds_satang),0),
      'adjustments_satang',coalesce(sum(adjustments_satang),0),
      'net_satang',coalesce(sum(net_satang),0)
    )
    from internal.food_merchant_settlement_rows(p_store_id,p_from,p_to)
  );
end;
$$;

revoke all on function public.admin_merchant_settlement_preview(uuid,timestamptz,timestamptz) from public, anon;
grant execute on function public.admin_merchant_settlement_preview(uuid,timestamptz,timestamptz) to authenticated;

create or replace function public.admin_create_merchant_settlement(
  p_store_id uuid,p_from timestamptz,p_to timestamptz,
  p_expected_order_count integer,p_expected_net_satang bigint,
  p_note text,p_reason text,p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_id uuid;
  v_count integer;
  v_net bigint;
  v_gross bigint;
  v_discount bigint;
  v_gp bigint;
  v_fees bigint;
  v_refunds bigint;
  v_adjustments bigint;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can manage settlements'; end if;
  if p_to<=p_from then raise exception 'invalid settlement period'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;
  perform pg_advisory_xact_lock(hashtext('merchant-settlement:'||p_store_id::text));

  select count(*)::integer,
         coalesce(sum(gross_sales_satang),0),coalesce(sum(merchant_discount_satang),0),
         coalesce(sum(gp_satang),0),coalesce(sum(payment_fees_satang),0),
         coalesce(sum(refunds_satang),0),coalesce(sum(adjustments_satang),0),coalesce(sum(net_satang),0)
    into v_count,v_gross,v_discount,v_gp,v_fees,v_refunds,v_adjustments,v_net
  from internal.food_merchant_settlement_rows(p_store_id,p_from,p_to);

  if v_count=0 then raise exception 'nothing to settle'; end if;
  if p_expected_order_count is distinct from v_count or p_expected_net_satang is distinct from v_net then
    raise exception 'settlement amount changed, reload and check before recording';
  end if;

  insert into public.food_merchant_settlements(
    store_id,period_from,period_to,status,order_count,gross_sales_satang,
    merchant_discount_satang,gp_satang,payment_fees_satang,refunds_satang,
    adjustments_satang,net_satang,note,created_by
  ) values (
    p_store_id,p_from,p_to,'pending',v_count,v_gross,v_discount,v_gp,v_fees,v_refunds,
    v_adjustments,v_net,nullif(left(btrim(coalesce(p_note,'')),500),''),v_admin
  ) returning id into v_id;

  insert into public.food_merchant_settlement_lines(
    settlement_id,order_id,gross_sales_satang,merchant_discount_satang,gp_satang,
    payment_fees_satang,refunds_satang,adjustments_satang,net_satang
  )
  select v_id,r.order_id,r.gross_sales_satang,r.merchant_discount_satang,r.gp_satang,
         r.payment_fees_satang,r.refunds_satang,r.adjustments_satang,r.net_satang
  from internal.food_merchant_settlement_rows(p_store_id,p_from,p_to) r;

  if (select count(*) from public.food_merchant_settlement_lines where settlement_id=v_id)<>v_count then
    raise exception 'settlement source changed';
  end if;

  perform internal.log_audit_event(v_admin,'admin_merchant_settlement_created',p_store_id,
    jsonb_build_object(
      'settlement_id',v_id,'order_count',v_count,'net_satang',v_net,
      'from',p_from,'to',p_to,'reason',left(btrim(p_reason),500),
      'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
  return v_id;
end;
$$;

revoke all on function public.admin_create_merchant_settlement(uuid,timestamptz,timestamptz,integer,bigint,text,text,jsonb) from public, anon;
grant execute on function public.admin_create_merchant_settlement(uuid,timestamptz,timestamptz,integer,bigint,text,text,jsonb) to authenticated;

create or replace function public.admin_mark_merchant_settlement_paid(
  p_settlement_id uuid,p_reference text,p_reason text,p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  s public.food_merchant_settlements%rowtype;
  o public.food_store_finance_overrides%rowtype;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can manage settlements'; end if;
  if not internal.food_feature_enabled('merchant_payout_enabled',now()) then raise exception 'merchant payout feature is disabled'; end if;
  if coalesce(char_length(btrim(p_reference)),0)=0 then raise exception 'payout reference is required'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;

  select * into s from public.food_merchant_settlements where id=p_settlement_id for update;
  if not found then raise exception 'settlement not found'; end if;
  if s.status<>'pending' then raise exception 'settlement is not pending'; end if;
  o:=internal.food_store_finance_override_at(s.store_id,now());
  if coalesce(o.payout_suspended,false) then raise exception 'merchant payout is suspended'; end if;

  update public.food_merchant_settlements
  set status='paid',reference=left(btrim(p_reference),160),paid_by=v_admin,paid_at=now()
  where id=p_settlement_id;

  perform internal.log_audit_event(v_admin,'admin_merchant_settlement_paid',s.store_id,
    jsonb_build_object(
      'settlement_id',p_settlement_id,'net_satang',s.net_satang,
      'reference',left(btrim(p_reference),160),'reason',left(btrim(p_reason),500),
      'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
end;
$$;

revoke all on function public.admin_mark_merchant_settlement_paid(uuid,text,text,jsonb) from public, anon;
grant execute on function public.admin_mark_merchant_settlement_paid(uuid,text,text,jsonb) to authenticated;

create or replace function public.merchant_finance_summary(
  p_store_id uuid,p_from timestamptz,p_to timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.food_has_merchant_access(p_store_id) then raise exception 'merchant access required'; end if;
  return jsonb_build_object(
    'gross_sales_satang',(
      select coalesce(sum(f.subtotal_satang),0) from public.food_order_financials f
      join public.food_orders o on o.id=f.order_id
      where f.store_id=p_store_id and f.priced_at>=p_from and f.priced_at<p_to and o.status<>'cancelled'
    ),
    'discounts_satang',(
      select coalesce(sum(f.merchant_discount_satang),0) from public.food_order_financials f
      where f.store_id=p_store_id and f.priced_at>=p_from and f.priced_at<p_to
    ),
    'gp_satang',(
      select coalesce(sum(f.gp_amount_satang-f.gp_refunded_satang),0) from public.food_order_financials f
      where f.store_id=p_store_id and f.priced_at>=p_from and f.priced_at<p_to
    ),
    'payment_fees_satang',(
      select coalesce(sum(f.stripe_fee_merchant_satang),0) from public.food_order_financials f
      where f.store_id=p_store_id and f.priced_at>=p_from and f.priced_at<p_to
    ),
    'refunds_satang',(
      select coalesce(sum(f.merchant_refund_cost_satang),0) from public.food_order_financials f
      where f.store_id=p_store_id and f.priced_at>=p_from and f.priced_at<p_to
    ),
    'adjustments_satang',(
      select coalesce(sum(f.merchant_adjustment_satang),0) from public.food_order_financials f
      where f.store_id=p_store_id and f.priced_at>=p_from and f.priced_at<p_to
    ),
    'net_revenue_satang',(
      select coalesce(sum(f.merchant_net_satang),0) from public.food_order_financials f
      join public.food_orders o on o.id=f.order_id
      where f.store_id=p_store_id and f.priced_at>=p_from and f.priced_at<p_to and o.status<>'cancelled'
    ),
    'paid_out_satang',(
      select coalesce(sum(s.net_satang),0) from public.food_merchant_settlements s
      where s.store_id=p_store_id and s.status='paid'
    ),
    'pending_payout_satang',(
      select coalesce(sum(s.net_satang),0) from public.food_merchant_settlements s
      where s.store_id=p_store_id and s.status='pending'
    ),
    'settlements',(
      select coalesce(jsonb_agg(to_jsonb(s)-'created_by'-'paid_by' order by s.created_at desc),'[]'::jsonb)
      from public.food_merchant_settlements s where s.store_id=p_store_id
    )
  );
end;
$$;

revoke all on function public.merchant_finance_summary(uuid,timestamptz,timestamptz) from public, anon;
grant execute on function public.merchant_finance_summary(uuid,timestamptz,timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- Rider admin controls. The rider feature remains OFF until QA enables it.
-- ---------------------------------------------------------------------------

create or replace function public.admin_set_rider_status(
  p_user_id uuid,p_status text,p_active boolean,p_service_area_code text,
  p_payout_suspended boolean,p_reason text,p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_id uuid;
  v_old jsonb;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can manage riders'; end if;
  if p_status not in ('pending','approved','suspended','inactive') then raise exception 'invalid rider status'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;
  if p_service_area_code is not null and not exists(select 1 from public.food_service_areas where code=p_service_area_code) then raise exception 'service area not found'; end if;

  select to_jsonb(r),r.id into v_old,v_id from public.food_riders r where r.user_id=p_user_id for update;
  if v_id is null then
    insert into public.food_riders(
      user_id,status,active,service_area_code,payout_suspended,
      approved_by,approved_at,suspended_reason
    ) values(
      p_user_id,p_status,p_active,p_service_area_code,coalesce(p_payout_suspended,false),
      case when p_status='approved' then v_admin end,
      case when p_status='approved' then now() end,
      case when p_status='suspended' then left(btrim(p_reason),500) end
    ) returning id into v_id;
  else
    update public.food_riders
    set status=p_status,active=p_active,service_area_code=p_service_area_code,
        payout_suspended=coalesce(p_payout_suspended,false),
        approved_by=case when p_status='approved' and approved_by is null then v_admin else approved_by end,
        approved_at=case when p_status='approved' and approved_at is null then now() else approved_at end,
        suspended_reason=case when p_status='suspended' then left(btrim(p_reason),500) else null end,
        updated_at=now()
    where id=v_id;
  end if;

  perform internal.log_audit_event(v_admin,'admin_rider_status_changed',p_user_id,
    jsonb_build_object(
      'rider_id',v_id,'old_value',v_old,
      'new_value',jsonb_build_object('status',p_status,'active',p_active,'service_area_code',p_service_area_code,'payout_suspended',p_payout_suspended),
      'reason',left(btrim(p_reason),500),'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
  return v_id;
end;
$$;

revoke all on function public.admin_set_rider_status(uuid,text,boolean,text,boolean,text,jsonb) from public, anon;
grant execute on function public.admin_set_rider_status(uuid,text,boolean,text,boolean,text,jsonb) to authenticated;

create or replace function public.admin_add_rider_adjustment(
  p_rider_id uuid,p_order_id uuid,p_amount_satang bigint,p_reason text,p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_id uuid;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then raise exception 'Only admins can manage rider earnings'; end if;
  if p_amount_satang=0 then raise exception 'adjustment cannot be zero'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;
  if not exists(select 1 from public.food_riders where id=p_rider_id) then raise exception 'rider not found'; end if;

  insert into public.food_rider_adjustments(rider_id,order_id,amount_satang,reason,created_by)
  values(p_rider_id,p_order_id,p_amount_satang,left(btrim(p_reason),500),v_admin)
  returning id into v_id;

  if p_order_id is not null then
    update public.food_order_financials
    set rider_adjustment_satang=rider_adjustment_satang+p_amount_satang,updated_at=now()
    where order_id=p_order_id;
    perform internal.food_recompute_order_financials(p_order_id);
  end if;

  perform internal.log_audit_event(v_admin,'admin_rider_adjustment_created',p_order_id,
    jsonb_build_object(
      'rider_id',p_rider_id,'adjustment_id',v_id,'amount_satang',p_amount_satang,
      'reason',left(btrim(p_reason),500),'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
  return v_id;
end;
$$;

revoke all on function public.admin_add_rider_adjustment(uuid,uuid,bigint,text,jsonb) from public, anon;
grant execute on function public.admin_add_rider_adjustment(uuid,uuid,bigint,text,jsonb) to authenticated;


-- ---------------------------------------------------------------------------
-- Rider payout engine. Safe to ship while rider_enabled=false.
-- ---------------------------------------------------------------------------

create or replace function internal.food_rider_payout_rows(
  p_rider_id uuid,p_from timestamptz,p_to timestamptz
)
returns table(
  job_id uuid,order_id uuid,gross_satang bigint,bonus_satang bigint,
  adjustment_satang bigint,net_satang bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select j.id,j.order_id,j.gross_earning_satang,j.bonus_satang,
         j.adjustment_satang,
         j.net_earning_satang
  from public.food_rider_jobs j
  where j.rider_id=p_rider_id
    and j.status='delivered'
    and coalesce(j.completed_at,j.assigned_at)>=p_from
    and coalesce(j.completed_at,j.assigned_at)<p_to
    and not exists(
      select 1
      from public.food_rider_payout_jobs x
      join public.food_rider_payouts p on p.id=x.payout_id
      where x.job_id=j.id and p.status in ('pending','paid')
    )
  order by coalesce(j.completed_at,j.assigned_at),j.id
$$;

revoke all on function internal.food_rider_payout_rows(uuid,timestamptz,timestamptz)
  from public,anon,authenticated;

create table if not exists public.food_rider_payout_jobs (
  payout_id uuid not null references public.food_rider_payouts(id) on delete cascade,
  job_id uuid not null references public.food_rider_jobs(id) on delete restrict,
  primary key(payout_id,job_id),
  unique(job_id)
);

alter table public.food_rider_payout_jobs enable row level security;
revoke all on table public.food_rider_payout_jobs from public,anon,authenticated;

create or replace function public.admin_rider_payout_preview(
  p_rider_id uuid,p_from timestamptz,p_to timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage rider payouts';
  end if;
  if p_to<=p_from then raise exception 'invalid payout period'; end if;
  return (
    select jsonb_build_object(
      'rider_id',p_rider_id,'from',p_from,'to',p_to,
      'jobs',count(*)::integer,
      'gross_earnings_satang',coalesce(sum(gross_satang),0),
      'bonus_satang',coalesce(sum(bonus_satang),0),
      'adjustments_satang',coalesce(sum(adjustment_satang),0),
      'amount_satang',coalesce(sum(net_satang),0)
    )
    from internal.food_rider_payout_rows(p_rider_id,p_from,p_to)
  );
end;
$$;

revoke all on function public.admin_rider_payout_preview(uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.admin_rider_payout_preview(uuid,timestamptz,timestamptz) to authenticated;

create or replace function public.admin_create_rider_payout(
  p_rider_id uuid,p_from timestamptz,p_to timestamptz,
  p_expected_jobs integer,p_expected_amount_satang bigint,
  p_reason text,p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_id uuid;
  v_jobs integer;
  v_gross bigint;
  v_bonus bigint;
  v_adjustments bigint;
  v_amount bigint;
  r public.food_riders%rowtype;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage rider payouts';
  end if;
  if not internal.food_feature_enabled('rider_enabled',now()) then
    raise exception 'rider feature is disabled';
  end if;
  if p_to<=p_from then raise exception 'invalid payout period'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;

  select * into r from public.food_riders where id=p_rider_id for update;
  if not found then raise exception 'rider not found'; end if;
  if r.payout_suspended then raise exception 'rider payout is suspended'; end if;

  perform pg_advisory_xact_lock(hashtext('rider-payout:'||p_rider_id::text));

  select count(*)::integer,coalesce(sum(gross_satang),0),coalesce(sum(bonus_satang),0),
         coalesce(sum(adjustment_satang),0),coalesce(sum(net_satang),0)
    into v_jobs,v_gross,v_bonus,v_adjustments,v_amount
  from internal.food_rider_payout_rows(p_rider_id,p_from,p_to);

  if v_jobs=0 then raise exception 'nothing to pay'; end if;
  if p_expected_jobs is distinct from v_jobs or p_expected_amount_satang is distinct from v_amount then
    raise exception 'payout amount changed, reload and check before recording';
  end if;

  insert into public.food_rider_payouts(
    rider_id,period_from,period_to,gross_earnings_satang,bonus_satang,
    adjustments_satang,amount_satang,status,created_by
  ) values(
    p_rider_id,p_from,p_to,v_gross,v_bonus,v_adjustments,v_amount,'pending',v_admin
  ) returning id into v_id;

  insert into public.food_rider_payout_jobs(payout_id,job_id)
  select v_id,x.job_id from internal.food_rider_payout_rows(p_rider_id,p_from,p_to) x;

  if (select count(*) from public.food_rider_payout_jobs where payout_id=v_id)<>v_jobs then
    raise exception 'payout source changed';
  end if;

  perform internal.log_audit_event(v_admin,'admin_rider_payout_changed',null,
    jsonb_build_object(
      'payout_id',v_id,'rider_id',p_rider_id,'status','pending',
      'jobs',v_jobs,'amount_satang',v_amount,'from',p_from,'to',p_to,
      'reason',left(btrim(p_reason),500),'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
  return v_id;
end;
$$;

revoke all on function public.admin_create_rider_payout(uuid,timestamptz,timestamptz,integer,bigint,text,jsonb)
  from public,anon;
grant execute on function public.admin_create_rider_payout(uuid,timestamptz,timestamptz,integer,bigint,text,jsonb)
  to authenticated;

create or replace function public.admin_mark_rider_payout_paid(
  p_payout_id uuid,p_reference text,p_reason text,p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  p public.food_rider_payouts%rowtype;
  r public.food_riders%rowtype;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage rider payouts';
  end if;
  if not internal.food_feature_enabled('rider_enabled',now()) then
    raise exception 'rider feature is disabled';
  end if;
  if coalesce(char_length(btrim(p_reference)),0)=0 then raise exception 'payout reference is required'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;

  select * into p from public.food_rider_payouts where id=p_payout_id for update;
  if not found then raise exception 'payout not found'; end if;
  if p.status<>'pending' then raise exception 'payout is not pending'; end if;
  select * into r from public.food_riders where id=p.rider_id;
  if r.payout_suspended then raise exception 'rider payout is suspended'; end if;

  update public.food_rider_payouts
  set status='paid',reference=left(btrim(p_reference),160),paid_by=v_admin,paid_at=now()
  where id=p_payout_id;

  perform internal.log_audit_event(v_admin,'admin_rider_payout_changed',null,
    jsonb_build_object(
      'payout_id',p_payout_id,'rider_id',p.rider_id,'status','paid',
      'amount_satang',p.amount_satang,'reference',left(btrim(p_reference),160),
      'reason',left(btrim(p_reason),500),'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
end;
$$;

revoke all on function public.admin_mark_rider_payout_paid(uuid,text,text,jsonb) from public,anon;
grant execute on function public.admin_mark_rider_payout_paid(uuid,text,text,jsonb) to authenticated;

create or replace function public.admin_finance_order_detail(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text:=coalesce(internal.current_platform_role(),'');
begin
  if v_role<>'admin' then raise exception 'Only admins can view order finance'; end if;
  return jsonb_build_object(
    'financial',(
      select to_jsonb(f) from public.food_order_financials f where f.order_id=p_order_id
    ),
    'payment',(
      select to_jsonb(p)-'buyer_id' from public.food_stripe_payments p where p.order_id=p_order_id
    ),
    'refunds',(
      select coalesce(jsonb_agg(to_jsonb(r)-'requested_by' order by r.created_at desc),'[]'::jsonb)
      from public.food_refunds r where r.order_id=p_order_id
    ),
    'settlement',(
      select to_jsonb(s)-'created_by'-'paid_by'
      from public.food_merchant_settlement_lines l
      join public.food_merchant_settlements s on s.id=l.settlement_id
      where l.order_id=p_order_id
      limit 1
    )
  );
end;
$$;

revoke all on function public.admin_finance_order_detail(uuid) from public,anon;
grant execute on function public.admin_finance_order_detail(uuid) to authenticated;
