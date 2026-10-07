-- WYNOS Finance Control Center v1 (admin/control RPCs)
-- Depends on migrations_wynos_finance_control_core_v1.sql.

create or replace function public.admin_finance_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_config public.food_finance_config_versions%rowtype;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage finance';
  end if;
  select * into v_config
  from public.food_finance_config_versions
  where id=internal.food_active_finance_config_id(now());

  return jsonb_build_object(
    'config',to_jsonb(v_config),
    'features',(select coalesce(jsonb_object_agg(key,enabled order by key),'{}'::jsonb) from public.platform_feature_flags),
    'merchant_count',(select count(*) from public.food_stores),
    'rider_count',(select count(*) from public.food_riders)
  );
end;
$$;
revoke all on function public.admin_finance_settings() from public, anon;
grant execute on function public.admin_finance_settings() to authenticated;

create or replace function public.admin_finance_overview(
  p_from timestamptz,
  p_to timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can view finance';
  end if;
  if p_from is null or p_to is null or p_to <= p_from then
    raise exception 'invalid finance range';
  end if;

  return jsonb_build_object(
    'gross_order_value_satang',coalesce((select sum(o.customer_total_satang) from public.food_orders o where o.created_at>=p_from and o.created_at<p_to),0),
    'orders',coalesce((select count(*) from public.food_orders o where o.created_at>=p_from and o.created_at<p_to),0),
    'gp_revenue_satang',coalesce((select sum(o.gp_amount_satang) from public.food_orders o where o.created_at>=p_from and o.created_at<p_to),0),
    'delivery_revenue_satang',coalesce((select sum(o.delivery_fee_satang) from public.food_orders o where o.created_at>=p_from and o.created_at<p_to),0),
    'stripe_fees_satang',coalesce((select sum(p.stripe_fee_satang) from public.food_stripe_payments p where p.created_at>=p_from and p.created_at<p_to),0),
    'merchant_net_satang',coalesce((select sum(o.merchant_net_satang) from public.food_orders o where o.created_at>=p_from and o.created_at<p_to),0),
    'rider_earnings_satang',coalesce((select sum(o.rider_earning_satang) from public.food_orders o where o.created_at>=p_from and o.created_at<p_to),0),
    'refunds_satang',coalesce((select sum(r.amount_satang) from public.food_refunds r where r.status='succeeded' and r.created_at>=p_from and r.created_at<p_to),0),
    'promotion_cost_satang',coalesce((select sum(o.platform_discount_satang) from public.food_orders o where o.created_at>=p_from and o.created_at<p_to),0),
    'net_platform_revenue_satang',coalesce((select sum(o.platform_revenue_satang) from public.food_orders o where o.created_at>=p_from and o.created_at<p_to),0)
  );
end;
$$;
revoke all on function public.admin_finance_overview(timestamptz,timestamptz) from public, anon;
grant execute on function public.admin_finance_overview(timestamptz,timestamptz) to authenticated;

create or replace function public.admin_update_finance_config(
  p_patch jsonb,
  p_reason text,
  p_effective_from timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_current public.food_finance_config_versions%rowtype;
  v_id uuid;
  v_reason text := left(btrim(coalesce(p_reason,'')),500);
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage finance';
  end if;
  if v_reason='' then raise exception 'change reason is required'; end if;
  if p_effective_from < now() - interval '1 minute' then raise exception 'effective time cannot be in the past'; end if;
  if p_patch is null or jsonb_typeof(p_patch)<>'object' then raise exception 'invalid finance patch'; end if;

  if exists (
    select 1 from jsonb_object_keys(p_patch) k
    where k not in (
      'default_gp_bps','base_delivery_satang','included_distance_meters','delivery_per_km_satang',
      'minimum_delivery_satang','maximum_delivery_satang','distance_rounding','free_delivery_threshold_satang',
      'long_distance_threshold_meters','long_distance_surcharge_satang','peak_surcharge_satang','rain_surcharge_satang',
      'rider_base_pay_satang','rider_pay_per_km_satang','rider_min_earning_satang','rider_long_distance_bonus_satang',
      'rider_peak_bonus_satang','rider_rain_bonus_satang','rider_platform_fee_bps','rider_incentive_jobs',
      'rider_incentive_bonus_satang','service_fee_mode','service_fee_value','service_fee_min_satang',
      'service_fee_max_satang','small_order_threshold_satang','small_order_fee_satang','surge_fee_mode',
      'surge_fee_value','surge_fee_min_satang','surge_fee_max_satang','stripe_fee_bearer',
      'stripe_fee_merchant_share_bps','tax_enabled','vat_registered','vat_bps'
    )
  ) then
    raise exception 'unsupported finance setting';
  end if;

  select * into v_current
  from public.food_finance_config_versions
  where id=internal.food_active_finance_config_id(now())
  for update;
  if not found then raise exception 'finance configuration unavailable'; end if;

  insert into public.food_finance_config_versions(
    effective_from,
    default_gp_bps,
    base_delivery_satang,included_distance_meters,delivery_per_km_satang,minimum_delivery_satang,maximum_delivery_satang,distance_rounding,
    free_delivery_threshold_satang,long_distance_threshold_meters,long_distance_surcharge_satang,peak_surcharge_satang,rain_surcharge_satang,
    rider_base_pay_satang,rider_pay_per_km_satang,rider_min_earning_satang,rider_long_distance_bonus_satang,rider_peak_bonus_satang,rider_rain_bonus_satang,
    rider_platform_fee_bps,rider_incentive_jobs,rider_incentive_bonus_satang,
    service_fee_mode,service_fee_value,service_fee_min_satang,service_fee_max_satang,
    small_order_threshold_satang,small_order_fee_satang,
    surge_fee_mode,surge_fee_value,surge_fee_min_satang,surge_fee_max_satang,
    stripe_fee_bearer,stripe_fee_merchant_share_bps,tax_enabled,vat_registered,vat_bps,
    created_by,reason
  ) values (
    p_effective_from,
    coalesce((p_patch->>'default_gp_bps')::integer,v_current.default_gp_bps),
    coalesce((p_patch->>'base_delivery_satang')::bigint,v_current.base_delivery_satang),
    coalesce((p_patch->>'included_distance_meters')::integer,v_current.included_distance_meters),
    coalesce((p_patch->>'delivery_per_km_satang')::bigint,v_current.delivery_per_km_satang),
    coalesce((p_patch->>'minimum_delivery_satang')::bigint,v_current.minimum_delivery_satang),
    case when p_patch ? 'maximum_delivery_satang' then nullif(p_patch->>'maximum_delivery_satang','')::bigint else v_current.maximum_delivery_satang end,
    coalesce(p_patch->>'distance_rounding',v_current.distance_rounding),
    case when p_patch ? 'free_delivery_threshold_satang' then nullif(p_patch->>'free_delivery_threshold_satang','')::bigint else v_current.free_delivery_threshold_satang end,
    case when p_patch ? 'long_distance_threshold_meters' then nullif(p_patch->>'long_distance_threshold_meters','')::integer else v_current.long_distance_threshold_meters end,
    coalesce((p_patch->>'long_distance_surcharge_satang')::bigint,v_current.long_distance_surcharge_satang),
    coalesce((p_patch->>'peak_surcharge_satang')::bigint,v_current.peak_surcharge_satang),
    coalesce((p_patch->>'rain_surcharge_satang')::bigint,v_current.rain_surcharge_satang),
    coalesce((p_patch->>'rider_base_pay_satang')::bigint,v_current.rider_base_pay_satang),
    coalesce((p_patch->>'rider_pay_per_km_satang')::bigint,v_current.rider_pay_per_km_satang),
    coalesce((p_patch->>'rider_min_earning_satang')::bigint,v_current.rider_min_earning_satang),
    coalesce((p_patch->>'rider_long_distance_bonus_satang')::bigint,v_current.rider_long_distance_bonus_satang),
    coalesce((p_patch->>'rider_peak_bonus_satang')::bigint,v_current.rider_peak_bonus_satang),
    coalesce((p_patch->>'rider_rain_bonus_satang')::bigint,v_current.rider_rain_bonus_satang),
    coalesce((p_patch->>'rider_platform_fee_bps')::integer,v_current.rider_platform_fee_bps),
    case when p_patch ? 'rider_incentive_jobs' then nullif(p_patch->>'rider_incentive_jobs','')::integer else v_current.rider_incentive_jobs end,
    coalesce((p_patch->>'rider_incentive_bonus_satang')::bigint,v_current.rider_incentive_bonus_satang),
    coalesce(p_patch->>'service_fee_mode',v_current.service_fee_mode),
    coalesce((p_patch->>'service_fee_value')::bigint,v_current.service_fee_value),
    case when p_patch ? 'service_fee_min_satang' then nullif(p_patch->>'service_fee_min_satang','')::bigint else v_current.service_fee_min_satang end,
    case when p_patch ? 'service_fee_max_satang' then nullif(p_patch->>'service_fee_max_satang','')::bigint else v_current.service_fee_max_satang end,
    case when p_patch ? 'small_order_threshold_satang' then nullif(p_patch->>'small_order_threshold_satang','')::bigint else v_current.small_order_threshold_satang end,
    coalesce((p_patch->>'small_order_fee_satang')::bigint,v_current.small_order_fee_satang),
    coalesce(p_patch->>'surge_fee_mode',v_current.surge_fee_mode),
    coalesce((p_patch->>'surge_fee_value')::bigint,v_current.surge_fee_value),
    case when p_patch ? 'surge_fee_min_satang' then nullif(p_patch->>'surge_fee_min_satang','')::bigint else v_current.surge_fee_min_satang end,
    case when p_patch ? 'surge_fee_max_satang' then nullif(p_patch->>'surge_fee_max_satang','')::bigint else v_current.surge_fee_max_satang end,
    coalesce(p_patch->>'stripe_fee_bearer',v_current.stripe_fee_bearer),
    coalesce((p_patch->>'stripe_fee_merchant_share_bps')::integer,v_current.stripe_fee_merchant_share_bps),
    coalesce((p_patch->>'tax_enabled')::boolean,v_current.tax_enabled),
    coalesce((p_patch->>'vat_registered')::boolean,v_current.vat_registered),
    coalesce((p_patch->>'vat_bps')::integer,v_current.vat_bps),
    v_admin,v_reason
  ) returning id into v_id;

  update public.food_finance_config_versions
  set effective_to=p_effective_from
  where id=v_current.id and p_effective_from > v_current.effective_from;

  perform internal.log_audit_event(
    v_admin,'admin_finance_config_changed',v_id,
    jsonb_build_object(
      'entity_type','finance_config',
      'old_value',to_jsonb(v_current),
      'new_value',(select to_jsonb(c) from public.food_finance_config_versions c where c.id=v_id),
      'reason',v_reason
    )
  );
  return v_id;
end;
$$;
revoke all on function public.admin_update_finance_config(jsonb,text,timestamptz) from public, anon;
grant execute on function public.admin_update_finance_config(jsonb,text,timestamptz) to authenticated;

create or replace function public.admin_set_feature_flag(
  p_key text,
  p_enabled boolean,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_old boolean;
  v_reason text:=left(btrim(coalesce(p_reason,'')),500);
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage finance';
  end if;
  if v_reason='' then raise exception 'change reason is required'; end if;

  select enabled into v_old
  from public.platform_feature_flags
  where key=p_key
  for update;
  if not found then raise exception 'unknown feature flag'; end if;

  update public.platform_feature_flags
  set enabled=p_enabled,effective_from=now(),updated_by=v_admin,reason=v_reason,updated_at=now()
  where key=p_key;

  perform internal.log_audit_event(
    v_admin,'admin_feature_flag_changed',null,
    jsonb_build_object(
      'entity_type','feature_flag','entity_id',p_key,
      'old_value',v_old,'new_value',p_enabled,'reason',v_reason
    )
  );
end;
$$;
revoke all on function public.admin_set_feature_flag(text,boolean,text) from public, anon;
grant execute on function public.admin_set_feature_flag(text,boolean,text) to authenticated;

create or replace function public.admin_set_merchant_gp(
  p_store_id uuid,
  p_gp_bps integer,
  p_rule_type text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_id uuid;
  v_old integer;
  v_reason text:=left(btrim(coalesce(p_reason,'')),500);
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage finance';
  end if;
  if p_rule_type not in ('custom','temporary') then raise exception 'invalid GP rule type'; end if;
  if p_gp_bps not between 0 and 10000 then raise exception 'invalid GP'; end if;
  if p_ends_at is not null and p_ends_at <= coalesce(p_starts_at,now()) then raise exception 'invalid GP dates'; end if;
  if v_reason='' then raise exception 'change reason is required'; end if;
  if not exists(select 1 from public.food_stores where id=p_store_id) then raise exception 'store not found'; end if;

  v_old:=internal.food_effective_gp_bps(p_store_id,now());
  insert into public.food_merchant_gp_rules(store_id,rule_type,gp_bps,starts_at,ends_at,reason,created_by)
  values(p_store_id,p_rule_type,p_gp_bps,coalesce(p_starts_at,now()),p_ends_at,v_reason,v_admin)
  returning id into v_id;

  perform internal.log_audit_event(
    v_admin,'admin_merchant_gp_changed',p_store_id,
    jsonb_build_object(
      'entity_type','merchant_gp','entity_id',v_id,
      'old_value',v_old,'new_value',p_gp_bps,
      'rule_type',p_rule_type,'starts_at',coalesce(p_starts_at,now()),
      'ends_at',p_ends_at,'reason',v_reason
    )
  );
  return v_id;
end;
$$;
revoke all on function public.admin_set_merchant_gp(uuid,integer,text,timestamptz,timestamptz,text) from public, anon;
grant execute on function public.admin_set_merchant_gp(uuid,integer,text,timestamptz,timestamptz,text) to authenticated;

create or replace function public.admin_finance_merchants(p_query text default null)
returns table(
  store_id uuid,
  store_name text,
  gp_bps integer,
  gp_percent numeric,
  gp_source text,
  payments_enabled boolean,
  payout_suspended boolean,
  promotion_eligible boolean,
  stripe_ready boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can view finance';
  end if;

  return query
  select s.id,s.name,
    internal.food_effective_gp_bps(s.id,now()),
    round(internal.food_effective_gp_bps(s.id,now())::numeric/100,2),
    case
      when exists(
        select 1 from public.food_merchant_gp_rules r
        where r.store_id=s.id and r.active and r.rule_type='temporary'
          and r.starts_at<=now() and (r.ends_at is null or r.ends_at>now())
      ) then 'temporary'
      when exists(
        select 1 from public.food_merchant_gp_rules r
        where r.store_id=s.id and r.active and r.rule_type='custom'
          and r.starts_at<=now() and (r.ends_at is null or r.ends_at>now())
      ) then 'custom'
      else 'default'
    end,
    coalesce(c.payments_enabled,s.stripe_payments_enabled),
    coalesce(c.payout_suspended,false),
    coalesce(c.promotion_eligible,true),
    coalesce(a.status='ready' and a.promptpay_enabled,false)
  from public.food_stores s
  left join public.food_merchant_finance_controls c on c.store_id=s.id
  left join public.food_stripe_accounts a on a.store_id=s.id
  where p_query is null or btrim(p_query)='' or
    s.name ilike '%'||replace(replace(btrim(p_query),'%','\%'),'_','\_')||'%' escape '\'
  order by s.name;
end;
$$;
revoke all on function public.admin_finance_merchants(text) from public, anon;
grant execute on function public.admin_finance_merchants(text) to authenticated;

create or replace function public.admin_set_merchant_finance_controls(
  p_store_id uuid,
  p_payments_enabled boolean,
  p_payout_suspended boolean,
  p_promotion_eligible boolean,
  p_delivery_override_enabled boolean,
  p_base_delivery_satang bigint,
  p_included_distance_meters integer,
  p_delivery_per_km_satang bigint,
  p_minimum_delivery_satang bigint,
  p_maximum_delivery_satang bigint,
  p_distance_rounding text,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_old jsonb;
  v_reason text:=left(btrim(coalesce(p_reason,'')),500);
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage finance';
  end if;
  if v_reason='' then raise exception 'change reason is required'; end if;
  if not exists(select 1 from public.food_stores where id=p_store_id) then raise exception 'store not found'; end if;

  select to_jsonb(c) into v_old
  from public.food_merchant_finance_controls c
  where c.store_id=p_store_id;

  insert into public.food_merchant_finance_controls(
    store_id,payments_enabled,payout_suspended,promotion_eligible,delivery_override_enabled,
    base_delivery_satang,included_distance_meters,delivery_per_km_satang,
    minimum_delivery_satang,maximum_delivery_satang,distance_rounding,
    updated_by,reason,updated_at
  ) values (
    p_store_id,p_payments_enabled,coalesce(p_payout_suspended,false),coalesce(p_promotion_eligible,true),
    coalesce(p_delivery_override_enabled,false),p_base_delivery_satang,p_included_distance_meters,
    p_delivery_per_km_satang,p_minimum_delivery_satang,p_maximum_delivery_satang,p_distance_rounding,
    v_admin,v_reason,now()
  )
  on conflict(store_id) do update set
    payments_enabled=excluded.payments_enabled,
    payout_suspended=excluded.payout_suspended,
    promotion_eligible=excluded.promotion_eligible,
    delivery_override_enabled=excluded.delivery_override_enabled,
    base_delivery_satang=excluded.base_delivery_satang,
    included_distance_meters=excluded.included_distance_meters,
    delivery_per_km_satang=excluded.delivery_per_km_satang,
    minimum_delivery_satang=excluded.minimum_delivery_satang,
    maximum_delivery_satang=excluded.maximum_delivery_satang,
    distance_rounding=excluded.distance_rounding,
    updated_by=v_admin,reason=v_reason,updated_at=now();

  perform internal.log_audit_event(
    v_admin,'admin_merchant_finance_control_changed',p_store_id,
    jsonb_build_object(
      'entity_type','merchant_finance_control',
      'old_value',v_old,
      'new_value',(select to_jsonb(c) from public.food_merchant_finance_controls c where c.store_id=p_store_id),
      'reason',v_reason
    )
  );
end;
$$;
revoke all on function public.admin_set_merchant_finance_controls(uuid,boolean,boolean,boolean,boolean,bigint,integer,bigint,bigint,bigint,text,text)
  from public, anon;
grant execute on function public.admin_set_merchant_finance_controls(uuid,boolean,boolean,boolean,boolean,bigint,integer,bigint,bigint,bigint,text,text)
  to authenticated;

create or replace function public.admin_riders()
returns table(
  rider_id uuid,user_id uuid,username text,status text,active boolean,service_area_codes text[],
  payout_suspended boolean,gross_earnings_satang bigint,paid_satang bigint,pending_payout_satang bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can view riders';
  end if;
  return query
  select r.id,r.user_id,p.username,r.status,r.active,r.service_area_codes,r.payout_suspended,
    coalesce(sum(e.gross_earning_satang),0)::bigint,
    coalesce(sum(e.paid_satang),0)::bigint,
    coalesce(sum(greatest(e.payable_satang-e.paid_satang,0)),0)::bigint
  from public.food_riders r
  left join public.profiles p on p.id=r.user_id
  left join public.food_rider_order_earnings e on e.rider_id=r.id
  group by r.id,p.username
  order by r.created_at desc;
end;
$$;
revoke all on function public.admin_riders() from public, anon;
grant execute on function public.admin_riders() to authenticated;

create or replace function public.admin_set_rider_status(
  p_rider_id uuid,
  p_status text,
  p_active boolean,
  p_service_area_codes text[],
  p_payout_suspended boolean,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_old jsonb;
  v_reason text:=left(btrim(coalesce(p_reason,'')),500);
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage riders';
  end if;
  if p_status not in ('pending','approved','suspended','rejected') then raise exception 'invalid rider status'; end if;
  if v_reason='' then raise exception 'change reason is required'; end if;

  select to_jsonb(r) into v_old
  from public.food_riders r where r.id=p_rider_id for update;
  if v_old is null then raise exception 'rider not found'; end if;

  update public.food_riders
  set status=p_status,
      active=coalesce(p_active,false),
      service_area_codes=coalesce(p_service_area_codes,'{}'),
      payout_suspended=coalesce(p_payout_suspended,false),
      approved_by=case when p_status='approved' then v_admin else approved_by end,
      approved_at=case when p_status='approved' then coalesce(approved_at,now()) else approved_at end,
      suspended_reason=case when p_status='suspended' then v_reason else null end,
      updated_at=now()
  where id=p_rider_id;

  perform internal.log_audit_event(
    v_admin,'admin_rider_status_changed',p_rider_id,
    jsonb_build_object(
      'entity_type','rider','old_value',v_old,
      'new_value',(select to_jsonb(r) from public.food_riders r where r.id=p_rider_id),
      'reason',v_reason
    )
  );
end;
$$;
revoke all on function public.admin_set_rider_status(uuid,text,boolean,text[],boolean,text) from public, anon;
grant execute on function public.admin_set_rider_status(uuid,text,boolean,text[],boolean,text) to authenticated;

create or replace function public.admin_add_rider_adjustment(
  p_rider_id uuid,
  p_order_id uuid,
  p_amount_satang bigint,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_id uuid;
  v_reason text:=left(btrim(coalesce(p_reason,'')),500);
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage riders';
  end if;
  if v_reason='' then raise exception 'change reason is required'; end if;
  if not exists(select 1 from public.food_riders where id=p_rider_id) then raise exception 'rider not found'; end if;

  insert into public.food_rider_adjustments(rider_id,order_id,amount_satang,reason,created_by)
  values(p_rider_id,p_order_id,p_amount_satang,v_reason,v_admin)
  returning id into v_id;

  if p_order_id is not null then
    update public.food_rider_order_earnings
    set adjustment_satang=adjustment_satang+p_amount_satang,
        payable_satang=greatest(payable_satang+p_amount_satang,0),
        updated_at=now()
    where order_id=p_order_id and rider_id=p_rider_id;
  end if;

  perform internal.log_audit_event(
    v_admin,'admin_rider_adjustment_created',p_rider_id,
    jsonb_build_object(
      'entity_type','rider_adjustment','entity_id',v_id,
      'order_id',p_order_id,'amount_satang',p_amount_satang,'reason',v_reason
    )
  );
  return v_id;
end;
$$;
revoke all on function public.admin_add_rider_adjustment(uuid,uuid,bigint,text) from public, anon;
grant execute on function public.admin_add_rider_adjustment(uuid,uuid,bigint,text) to authenticated;

create or replace function public.merchant_order_financial_breakdown(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  o public.food_orders%rowtype;
begin
  select * into o from public.food_orders where id=p_order_id;
  if not found then raise exception 'order not found'; end if;
  if not public.food_has_merchant_access(o.store_id)
     and coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Not authorized';
  end if;

  return jsonb_build_object(
    'order_id',o.id,'order_number',o.order_number,
    'gross_sales_satang',o.subtotal_satang,
    'merchant_discount_satang',o.merchant_discount_satang,
    'platform_discount_satang',o.platform_discount_satang,
    'gp_bps',o.gp_bps,'gp_satang',o.gp_amount_satang,
    'payment_fee_satang',coalesce(
      (select p.stripe_fee_satang from public.food_stripe_payments p where p.order_id=o.id),
      o.stripe_fee_satang,0
    ),
    'merchant_net_satang',coalesce(
      (select p.merchant_net_satang from public.food_stripe_payments p where p.order_id=o.id),
      o.merchant_net_satang,0
    ),
    'customer_total_satang',o.customer_total_satang,
    'config_version_id',o.finance_config_version_id
  );
end;
$$;
revoke all on function public.merchant_order_financial_breakdown(uuid) from public, anon;
grant execute on function public.merchant_order_financial_breakdown(uuid) to authenticated;

create or replace function public.admin_create_merchant_settlement(
  p_store_id uuid,
  p_period_start timestamptz,
  p_period_end timestamptz,
  p_idempotency_key text,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid:=auth.uid();
  v_id uuid;
  v_hold boolean:=false;
  v_gross bigint:=0;
  v_discounts bigint:=0;
  v_gp bigint:=0;
  v_fees bigint:=0;
  v_refunds bigint:=0;
  v_net bigint:=0;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can create settlements';
  end if;
  if not internal.food_feature_enabled('merchant_payout_enabled',now()) then
    raise exception 'merchant payout feature is disabled';
  end if;
  if p_period_end<=p_period_start then raise exception 'invalid settlement period'; end if;
  if char_length(btrim(coalesce(p_idempotency_key,'')))<8 then raise exception 'idempotency key required'; end if;
  if char_length(btrim(coalesce(p_reason,'')))<3 then raise exception 'change reason is required'; end if;

  perform pg_advisory_xact_lock(hashtext('merchant-settlement:'||p_store_id::text));

  if exists(select 1 from public.food_merchant_settlements where idempotency_key=p_idempotency_key) then
    select id into v_id from public.food_merchant_settlements where idempotency_key=p_idempotency_key;
    return v_id;
  end if;

  select coalesce(c.payout_suspended,false) into v_hold
  from public.food_merchant_finance_controls c where c.store_id=p_store_id;
  v_hold:=coalesce(v_hold,false);

  select
    coalesce(sum(o.subtotal_satang),0),
    coalesce(sum(o.merchant_discount_satang),0),
    coalesce(sum(o.gp_amount_satang),0),
    coalesce(sum(case
      when p.stripe_fee_bearer='merchant' then coalesce(p.stripe_fee_satang,0)
      when p.stripe_fee_bearer='shared'
        then (coalesce(p.stripe_fee_satang,0)*coalesce(p.stripe_fee_merchant_share_bps,0)+5000)/10000
      else 0 end),0),
    coalesce(sum((
      select coalesce(sum(r.amount_satang),0)
      from public.food_refunds r where r.order_id=o.id and r.status='succeeded'
    )),0),
    coalesce(sum(coalesce(p.merchant_net_satang,o.merchant_net_satang,0)),0)
  into v_gross,v_discounts,v_gp,v_fees,v_refunds,v_net
  from public.food_orders o
  left join public.food_stripe_payments p on p.order_id=o.id
  where o.store_id=p_store_id
    and o.created_at>=p_period_start and o.created_at<p_period_end
    and o.status='delivered'
    and not exists(
      select 1 from public.food_merchant_settlement_items i where i.order_id=o.id
    );

  if v_gross=0 then raise exception 'nothing to settle'; end if;

  insert into public.food_merchant_settlements(
    store_id,period_start,period_end,gross_sales_satang,discounts_satang,gp_satang,payment_fees_satang,
    refunds_satang,net_revenue_satang,paid_out_satang,pending_payout_satang,status,
    idempotency_key,payout_suspended_snapshot,created_by
  ) values(
    p_store_id,p_period_start,p_period_end,v_gross,v_discounts,v_gp,v_fees,v_refunds,
    greatest(v_net-v_refunds,0),0,greatest(v_net-v_refunds,0),
    case when v_hold then 'held' else 'approved' end,
    p_idempotency_key,v_hold,v_admin
  ) returning id into v_id;

  insert into public.food_merchant_settlement_items(
    settlement_id,order_id,merchant_net_satang,refund_satang,adjustment_satang
  )
  select v_id,o.id,coalesce(p.merchant_net_satang,o.merchant_net_satang,0),
    (
      select coalesce(sum(r.amount_satang),0)
      from public.food_refunds r where r.order_id=o.id and r.status='succeeded'
    ),0
  from public.food_orders o
  left join public.food_stripe_payments p on p.order_id=o.id
  where o.store_id=p_store_id
    and o.created_at>=p_period_start and o.created_at<p_period_end
    and o.status='delivered'
    and not exists(
      select 1 from public.food_merchant_settlement_items i where i.order_id=o.id
    );

  perform internal.log_audit_event(
    v_admin,'admin_merchant_settlement_created',v_id,
    jsonb_build_object(
      'entity_type','merchant_settlement','store_id',p_store_id,
      'period_start',p_period_start,'period_end',p_period_end,
      'net_satang',greatest(v_net-v_refunds,0),'held',v_hold,'reason',p_reason
    )
  );
  return v_id;
end;
$$;
revoke all on function public.admin_create_merchant_settlement(uuid,timestamptz,timestamptz,text,text) from public, anon;
grant execute on function public.admin_create_merchant_settlement(uuid,timestamptz,timestamptz,text,text) to authenticated;

-- Audit log is append-only for ordinary clients. Existing privileged
-- internal.log_audit_event() remains the write path.
drop policy if exists wyn157_permanent_insert on public.audit_log;
drop policy if exists wyn157_permanent_update on public.audit_log;
drop policy if exists wyn157_permanent_delete on public.audit_log;
revoke insert, update, delete on public.audit_log from anon, authenticated;

do $$
declare
  v_def text;
  v_types text[];
begin
  select pg_get_constraintdef(c.oid) into v_def
  from pg_constraint c
  where c.conname='audit_log_event_type_check'
    and c.conrelid='public.audit_log'::regclass;

  select coalesce(array_agg(distinct t),'{}') into v_types
  from regexp_matches(coalesce(v_def,''),'''([^'']*)''','g') as m,
       unnest(string_to_array(btrim(m[1],'{}'),',')) as raw,
       btrim(raw,' "') as t
  where t ~ '^[a-z0-9_]+$';

  select array_agg(distinct t order by t) into v_types
  from unnest(v_types || array[
    'admin_finance_config_changed',
    'admin_feature_flag_changed',
    'admin_merchant_gp_changed',
    'admin_merchant_finance_control_changed',
    'admin_rider_status_changed',
    'admin_rider_adjustment_created',
    'admin_merchant_settlement_created',
    'admin_refund_requested'
  ]) t;

  alter table public.audit_log drop constraint if exists audit_log_event_type_check;
  execute format(
    'alter table public.audit_log add constraint audit_log_event_type_check check (event_type = any (%L::text[]))',
    v_types
  );
end $$;

-- Seed requested defaults only once. No historical orders are touched.
insert into public.food_finance_config_versions(
  effective_from,default_gp_bps,
  base_delivery_satang,included_distance_meters,delivery_per_km_satang,
  minimum_delivery_satang,distance_rounding,
  stripe_fee_bearer,stripe_fee_merchant_share_bps,
  tax_enabled,vat_registered,vat_bps,
  reason
)
select now(),1000,2500,2000,700,0,'ceil_km','wynos',0,false,false,700,
  'Initial WYNOS Finance Control Center defaults'
where not exists(select 1 from public.food_finance_config_versions);

-- Preserve each currently pinned store's pre-control-center delivery pricing.
insert into public.food_merchant_finance_controls(
  store_id,delivery_override_enabled,base_delivery_satang,included_distance_meters,
  delivery_per_km_satang,minimum_delivery_satang,distance_rounding,reason
)
select s.id,true,round(s.delivery_fee*100)::bigint,
       round(s.delivery_base_km*1000)::integer,
       round(s.delivery_fee_per_km*100)::bigint,
       0,'ceil_km','Preserve pre-control-center delivery pricing'
from public.food_stores s
where s.latitude is not null
on conflict(store_id) do nothing;
