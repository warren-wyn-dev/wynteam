-- WYNOS Finance Control Center v1 hardening
-- Additive follow-up: province pricing runtime, finance-audit immutability,
-- and rider payout/admin reporting. Depends on the three finance migrations.

alter table public.food_service_areas
  add column if not exists province text;

update public.food_service_areas
set province = 'มหาสารคาม'
where code = 'maha_sarakham' and province is null;

-- Store override > service-area rule > province rule > platform default.
create or replace function internal.food_delivery_fee(
  p_store_id uuid,
  p_latitude double precision,
  p_longitude double precision
)
returns table(distance_km numeric, delivery_fee numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s public.food_stores%rowtype;
  c public.food_finance_configs%rowtype;
  o public.food_store_finance_overrides%rowtype;
  z public.food_delivery_zone_pricing%rowtype;
  v_distance numeric;
  v_distance_m integer;
  v_base bigint;
  v_base_m integer;
  v_per_km bigint;
  v_min bigint;
  v_max bigint;
  v_round_m integer;
  v_extra_m integer;
  v_billable_m integer;
  v_fee bigint;
  v_area text;
  v_province text;
  v_developer boolean := exists (
    select 1 from public.developer_accounts d where d.user_id=(select auth.uid())
  );
begin
  select * into s from public.food_stores where id=p_store_id;
  if not found then raise exception 'store is not accepting orders'; end if;

  if not v_developer and not internal.food_in_service_area(s.latitude,s.longitude) then
    raise exception 'store is outside the service area';
  end if;

  c := internal.food_finance_config_at(now());
  if c.id is null then raise exception 'finance configuration missing'; end if;
  o := internal.food_store_finance_override_at(p_store_id,now());

  if p_latitude is not null and p_longitude is not null then
    v_area := internal.food_service_area_code(p_latitude,p_longitude);
    select a.province into v_province
    from public.food_service_areas a
    where a.code=v_area;

    select * into z
    from public.food_delivery_zone_pricing r
    where r.effective_from <= now()
      and (r.effective_to is null or r.effective_to > now())
      and (
        (r.service_area_code is not null and r.service_area_code=v_area)
        or (
          r.service_area_code is null
          and nullif(btrim(coalesce(r.province,'')),'') is not null
          and lower(btrim(r.province))=lower(btrim(coalesce(v_province,'')))
        )
      )
    order by
      case when r.service_area_code is not null then 0 else 1 end,
      r.priority asc,
      r.effective_from desc
    limit 1;
  end if;

  v_base := coalesce(o.delivery_base_fee_satang,z.base_fee_satang,c.delivery_base_fee_satang);
  v_base_m := coalesce(o.delivery_base_distance_m,z.base_distance_m,c.delivery_base_distance_m);
  v_per_km := coalesce(o.delivery_per_km_satang,z.per_km_satang,c.delivery_per_km_satang);
  v_min := coalesce(o.delivery_min_fee_satang,z.min_fee_satang,c.delivery_min_fee_satang,0);
  v_max := coalesce(o.delivery_max_fee_satang,z.max_fee_satang,c.delivery_max_fee_satang);
  v_round_m := greatest(1,coalesce(o.delivery_rounding_m,z.rounding_m,c.delivery_rounding_m,1000));

  if s.latitude is null then
    v_fee := greatest(v_base,v_min);
    if v_max is not null then v_fee := least(v_fee,v_max); end if;
    return query select null::numeric,(v_fee::numeric/100);
    return;
  end if;

  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'delivery location required';
  end if;
  if not v_developer and not internal.food_in_service_area(p_latitude,p_longitude) then
    raise exception 'outside service area';
  end if;

  v_distance := internal.food_distance_km(s.latitude,s.longitude,p_latitude,p_longitude);
  if v_distance > s.delivery_radius_km then raise exception 'outside delivery area'; end if;

  v_distance_m := greatest(0,round(v_distance*1000)::integer);
  v_extra_m := greatest(v_distance_m-v_base_m,0);
  v_billable_m := case
    when v_extra_m=0 then 0
    else ((v_extra_m+v_round_m-1)/v_round_m)*v_round_m
  end;
  v_fee := v_base + ((v_billable_m::bigint*v_per_km)+999)/1000;

  if internal.food_feature_enabled('peak_pricing_enabled',now()) then
    v_fee := v_fee + c.peak_surcharge_satang;
  end if;
  if internal.food_feature_enabled('rain_surcharge_enabled',now()) then
    v_fee := v_fee + c.rain_surcharge_satang;
  end if;
  if c.long_distance_threshold_m is not null and v_distance_m > c.long_distance_threshold_m then
    v_fee := v_fee + c.long_distance_surcharge_satang;
  end if;

  v_fee := greatest(v_fee,v_min);
  if v_max is not null then v_fee := least(v_fee,v_max); end if;

  return query select v_distance,(v_fee::numeric/100);
end;
$$;

revoke all on function internal.food_delivery_fee(uuid,double precision,double precision)
  from public,anon,authenticated;

-- Financial audit entries are append-only through ordinary API roles.
-- This deliberately leaves legacy non-finance audit behavior untouched.
create or replace function internal.food_finance_audit_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated','anon')
     and old.event_type = any(array[
       'admin_finance_config_changed',
       'admin_feature_flag_changed',
       'admin_store_finance_changed',
       'admin_store_gp_promotion_created',
       'admin_delivery_zone_pricing_changed',
       'admin_finance_adjustment_created',
       'admin_merchant_settlement_created',
       'admin_merchant_settlement_paid',
       'admin_refund_requested',
       'admin_rider_status_changed',
       'admin_rider_adjustment_created',
       'admin_rider_payout_changed'
     ]) then
    raise exception 'financial audit log is immutable';
  end if;
  return case when tg_op='DELETE' then old else new end;
end;
$$;

revoke all on function internal.food_finance_audit_immutable()
  from public,anon,authenticated;

drop trigger if exists audit_log_finance_immutable on public.audit_log;
create trigger audit_log_finance_immutable
before update or delete on public.audit_log
for each row execute function internal.food_finance_audit_immutable();

create or replace function internal.food_rider_unpaid_rows(
  p_rider_id uuid,
  p_from timestamptz,
  p_to timestamptz
)
returns table(
  job_id uuid,
  order_id uuid,
  gross_satang bigint,
  bonus_satang bigint,
  adjustment_satang bigint,
  net_satang bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select j.id,j.order_id,j.gross_earning_satang,j.bonus_satang,
         j.adjustment_satang,j.net_earning_satang
  from public.food_rider_jobs j
  where j.rider_id=p_rider_id
    and j.status='delivered'
    and coalesce(j.completed_at,j.assigned_at)>=p_from
    and coalesce(j.completed_at,j.assigned_at)<p_to
    and not exists (
      select 1
      from public.food_rider_payouts p
      where p.rider_id=p_rider_id
        and p.status in ('pending','paid')
        and coalesce(j.completed_at,j.assigned_at)>=p.period_from
        and coalesce(j.completed_at,j.assigned_at)<p.period_to
    )
  order by coalesce(j.completed_at,j.assigned_at),j.id
$$;

revoke all on function internal.food_rider_unpaid_rows(uuid,timestamptz,timestamptz)
  from public,anon,authenticated;

create or replace function public.admin_rider_finance()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can view rider finance';
  end if;

  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'rider_id',r.id,
      'user_id',r.user_id,
      'username',p.username,
      'display_name',p.display_name,
      'status',r.status,
      'active',r.active,
      'service_area_code',r.service_area_code,
      'payout_suspended',r.payout_suspended,
      'gross_earnings_satang',coalesce(x.gross,0),
      'bonus_satang',coalesce(x.bonus,0),
      'adjustments_satang',coalesce(x.adjustments,0),
      'paid_satang',coalesce(x.paid,0),
      'pending_payout_satang',greatest(coalesce(x.net,0)-coalesce(x.paid,0),0),
      'jobs',coalesce(x.jobs,0)
    ) order by r.created_at desc),'[]'::jsonb)
    from public.food_riders r
    left join public.profiles p on p.id=r.user_id
    left join lateral (
      select
        count(*)::integer jobs,
        coalesce(sum(j.gross_earning_satang),0)::bigint gross,
        coalesce(sum(j.bonus_satang),0)::bigint bonus,
        coalesce(sum(j.adjustment_satang),0)::bigint adjustments,
        coalesce(sum(j.net_earning_satang),0)::bigint net,
        coalesce((
          select sum(po.amount_satang)
          from public.food_rider_payouts po
          where po.rider_id=r.id and po.status='paid'
        ),0)::bigint paid
      from public.food_rider_jobs j
      where j.rider_id=r.id and j.status='delivered'
    ) x on true
  );
end;
$$;

revoke all on function public.admin_rider_finance() from public,anon;
grant execute on function public.admin_rider_finance() to authenticated;

create or replace function public.admin_rider_payout_preview(
  p_rider_id uuid,
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
    raise exception 'Only admins can manage rider payouts';
  end if;
  if p_to<=p_from then raise exception 'invalid payout period'; end if;

  return (
    select jsonb_build_object(
      'rider_id',p_rider_id,
      'from',p_from,
      'to',p_to,
      'jobs',count(*),
      'gross_earnings_satang',coalesce(sum(gross_satang),0),
      'bonus_satang',coalesce(sum(bonus_satang),0),
      'adjustments_satang',coalesce(sum(adjustment_satang),0),
      'amount_satang',coalesce(sum(net_satang),0)
    )
    from internal.food_rider_unpaid_rows(p_rider_id,p_from,p_to)
  );
end;
$$;

revoke all on function public.admin_rider_payout_preview(uuid,timestamptz,timestamptz)
  from public,anon;
grant execute on function public.admin_rider_payout_preview(uuid,timestamptz,timestamptz)
  to authenticated;

create or replace function public.admin_create_rider_payout(
  p_rider_id uuid,
  p_from timestamptz,
  p_to timestamptz,
  p_expected_jobs integer,
  p_expected_amount_satang bigint,
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
  v_rider public.food_riders%rowtype;
  v_jobs integer;
  v_gross bigint;
  v_bonus bigint;
  v_adjust bigint;
  v_amount bigint;
  v_id uuid;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage rider payouts';
  end if;
  if not internal.food_feature_enabled('rider_enabled',now()) then
    raise exception 'rider feature is disabled';
  end if;
  if p_to<=p_from then raise exception 'invalid payout period'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;

  select * into v_rider from public.food_riders where id=p_rider_id for update;
  if not found then raise exception 'rider not found'; end if;
  if v_rider.payout_suspended then raise exception 'rider payout is suspended'; end if;

  perform pg_advisory_xact_lock(hashtext('rider-payout:'||p_rider_id::text));

  select count(*)::integer,
         coalesce(sum(gross_satang),0),
         coalesce(sum(bonus_satang),0),
         coalesce(sum(adjustment_satang),0),
         coalesce(sum(net_satang),0)
    into v_jobs,v_gross,v_bonus,v_adjust,v_amount
  from internal.food_rider_unpaid_rows(p_rider_id,p_from,p_to);

  if v_jobs=0 then raise exception 'nothing to payout'; end if;
  if p_expected_jobs is distinct from v_jobs
     or p_expected_amount_satang is distinct from v_amount then
    raise exception 'rider payout amount changed, reload and check before recording';
  end if;

  insert into public.food_rider_payouts(
    rider_id,period_from,period_to,gross_earnings_satang,bonus_satang,
    adjustments_satang,amount_satang,status,created_by
  ) values(
    p_rider_id,p_from,p_to,v_gross,v_bonus,v_adjust,v_amount,'pending',v_admin
  ) returning id into v_id;

  perform internal.log_audit_event(
    v_admin,'admin_rider_payout_changed',v_rider.user_id,
    jsonb_build_object(
      'payout_id',v_id,'status','pending','jobs',v_jobs,'amount_satang',v_amount,
      'from',p_from,'to',p_to,'reason',left(btrim(p_reason),500),
      'metadata',coalesce(p_metadata,'{}'::jsonb)
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
  p_payout_id uuid,
  p_reference text,
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
  v_payout public.food_rider_payouts%rowtype;
  v_rider public.food_riders%rowtype;
begin
  if coalesce(internal.current_platform_role(),'') <> 'admin' then
    raise exception 'Only admins can manage rider payouts';
  end if;
  if coalesce(char_length(btrim(p_reference)),0)=0 then raise exception 'payout reference is required'; end if;
  if coalesce(char_length(btrim(p_reason)),0)=0 then raise exception 'reason is required'; end if;

  select * into v_payout from public.food_rider_payouts where id=p_payout_id for update;
  if not found then raise exception 'rider payout not found'; end if;
  if v_payout.status<>'pending' then raise exception 'rider payout is not pending'; end if;
  select * into v_rider from public.food_riders where id=v_payout.rider_id;
  if not found then raise exception 'rider not found'; end if;
  if v_rider.payout_suspended then raise exception 'rider payout is suspended'; end if;

  update public.food_rider_payouts
  set status='paid',reference=left(btrim(p_reference),160),paid_by=v_admin,paid_at=now()
  where id=p_payout_id;

  perform internal.log_audit_event(
    v_admin,'admin_rider_payout_changed',v_rider.user_id,
    jsonb_build_object(
      'payout_id',p_payout_id,'status','paid','amount_satang',v_payout.amount_satang,
      'reference',left(btrim(p_reference),160),'reason',left(btrim(p_reason),500),
      'metadata',coalesce(p_metadata,'{}'::jsonb)
    )
  );
end;
$$;

revoke all on function public.admin_mark_rider_payout_paid(uuid,text,text,jsonb)
  from public,anon;
grant execute on function public.admin_mark_rider_payout_paid(uuid,text,text,jsonb)
  to authenticated;
