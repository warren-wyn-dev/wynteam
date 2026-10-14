-- Privacy-minimized Food home telemetry. No user, IP, location, URL or device data.
-- Best-effort placement counts, never billing, ranking or unique-person metrics.
-- Raw receipts: at most 200000, valid for 48h; aggregates: rolling 90 UTC days.
-- Expired rows are pruned in bounded batches during ingestion. No content is published.
create table if not exists internal.food_home_placement_receipts (
  exposure_id uuid primary key,
  placement_kind text not null check (placement_kind in ('banner','featured')),
  placement_id uuid not null,
  created_at timestamptz not null default now(),
  clicked_at timestamptz
);
create index if not exists food_home_receipts_created_idx
  on internal.food_home_placement_receipts(created_at);
create table if not exists internal.food_home_placement_daily (
  day date not null,
  placement_kind text not null check (placement_kind in ('banner','featured')),
  placement_id uuid not null,
  impressions bigint not null default 0 check (impressions >= 0),
  clicks bigint not null default 0 check (clicks >= 0 and clicks <= impressions),
  primary key(day,placement_kind,placement_id)
);
create table if not exists internal.food_home_analytics_budget (
  singleton boolean primary key default true check (singleton),
  window_started_at timestamptz not null default date_trunc('minute',now()),
  used integer not null default 0 check (used >= 0),
  retained_receipts integer not null default 0 check (retained_receipts between 0 and 200000),
  maintained_at timestamptz not null default now(),
  last_limited_at timestamptz
);
insert into internal.food_home_analytics_budget(singleton) values(true) on conflict do nothing;
alter table internal.food_home_placement_receipts enable row level security;
alter table internal.food_home_placement_daily enable row level security;
alter table internal.food_home_analytics_budget enable row level security;
revoke all on internal.food_home_placement_receipts, internal.food_home_placement_daily,
  internal.food_home_analytics_budget from public,anon,authenticated;

create or replace function public.food_record_home_placement_event(
  p_placement_kind text, p_placement_id uuid, p_exposure_id uuid, p_event_type text
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_today date := (v_now at time zone 'UTC')::date;
  v_receipt internal.food_home_placement_receipts%rowtype;
  v_budget internal.food_home_analytics_budget%rowtype;
  v_deleted integer := 0;
  v_day date;
begin
  if p_placement_kind is null or p_placement_kind not in ('banner','featured')
     or p_event_type is null or p_event_type not in ('impression','click')
     or p_placement_id is null or p_exposure_id is null then
    return jsonb_build_object('recorded',false,'reason','invalid');
  end if;
  -- Reuse the authoritative public selection, including its rank limit. No geo,
  -- ranking or publication rules are added by analytics.
  if p_placement_kind='banner' then
    if not exists(select 1 from jsonb_array_elements(public.food_active_home_banners()) b
      where b->>'id'=p_placement_id::text
        and (p_event_type<>'click' or b->>'destination_store_id' is not null)) then
      return jsonb_build_object('recorded',false,'reason','invalid');
    end if;
  elsif not exists(select 1 from jsonb_array_elements(public.food_active_featured_stores()) f
    where f->>'store_id'=p_placement_id::text) then
    return jsonb_build_object('recorded',false,'reason','invalid');
  end if;

  -- A global lock/budget bounds anonymous writes without collecting identity.
  -- UUID dedupe alone is not a bot check. Saturation drops telemetry, never UI.
  -- Telemetry is optional: drop contention instead of queueing anonymous writes.
  if not pg_try_advisory_xact_lock(1142,1) then
    return jsonb_build_object('recorded',false,'reason','limited');
  end if;
  -- Refresh after eligibility checks so a delayed request never rewinds the bucket.
  v_now := clock_timestamp();
  v_today := (v_now at time zone 'UTC')::date;
  select * into strict v_budget from internal.food_home_analytics_budget where singleton for update;
  if v_budget.maintained_at < v_now-interval '1 minute' then
    delete from internal.food_home_placement_receipts where exposure_id in (
      select exposure_id from internal.food_home_placement_receipts
      where created_at < v_now-interval '48 hours' order by created_at limit 1000
    );
    get diagnostics v_deleted = row_count;
    v_budget.retained_receipts := greatest(0,v_budget.retained_receipts-v_deleted);
    delete from internal.food_home_placement_daily where (day,placement_kind,placement_id) in (
      select day,placement_kind,placement_id from internal.food_home_placement_daily
      where day < v_today-89 order by day limit 1000
    );
    v_budget.maintained_at := v_now;
  end if;
  if v_budget.window_started_at < date_trunc('minute',v_now) then
    v_budget.window_started_at := date_trunc('minute',v_now);
    v_budget.used := 0;
  end if;
  -- Persist maintenance even when a later event is rejected.
  update internal.food_home_analytics_budget set
    retained_receipts=v_budget.retained_receipts, maintained_at=v_budget.maintained_at,
    window_started_at=v_budget.window_started_at, used=v_budget.used where singleton;
  select * into v_receipt from internal.food_home_placement_receipts where exposure_id=p_exposure_id;
  if found then
    if v_receipt.placement_kind<>p_placement_kind or v_receipt.placement_id<>p_placement_id
       or v_receipt.created_at < v_now-interval '48 hours' then
      return jsonb_build_object('recorded',false,'reason','invalid');
    end if;
    if p_event_type='impression' or v_receipt.clicked_at is not null then
      return jsonb_build_object('recorded',false,'reason','duplicate');
    end if;
  elsif p_event_type='click' then
    return jsonb_build_object('recorded',false,'reason','missing_impression');
  end if;
  if v_budget.used>=3000 or (p_event_type='impression' and v_budget.retained_receipts>=200000) then
    update internal.food_home_analytics_budget set last_limited_at=v_now where singleton;
    return jsonb_build_object('recorded',false,'reason','limited');
  end if;
  if p_event_type='impression' then
    insert into internal.food_home_placement_receipts(exposure_id,placement_kind,placement_id,created_at)
      values(p_exposure_id,p_placement_kind,p_placement_id,v_now);
    insert into internal.food_home_placement_daily(day,placement_kind,placement_id,impressions)
      values(v_today,p_placement_kind,p_placement_id,1)
      on conflict(day,placement_kind,placement_id) do update
        set impressions=internal.food_home_placement_daily.impressions+1;
    v_budget.retained_receipts := v_budget.retained_receipts+1;
  else
    update internal.food_home_placement_receipts set clicked_at=v_now where exposure_id=p_exposure_id;
    -- Attribute clicks to their impression's UTC day, including midnight crossing.
    v_day := (v_receipt.created_at at time zone 'UTC')::date;
    update internal.food_home_placement_daily set clicks=clicks+1
      where day=v_day and placement_kind=p_placement_kind and placement_id=p_placement_id;
  end if;
  update internal.food_home_analytics_budget set used=v_budget.used+1,
    retained_receipts=v_budget.retained_receipts where singleton;
  return jsonb_build_object('recorded',true);
end;
$$;
revoke all on function public.food_record_home_placement_event(text,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.food_record_home_placement_event(text,uuid,uuid,text) to anon,authenticated;

create or replace function public.admin_food_home_placement_analytics(p_placement_kind text,p_days integer default 30)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  v_today date := (now() at time zone 'UTC')::date;
  v_items jsonb;
  v_impressions bigint;
  v_clicks bigint;
begin
  if (select auth.uid()) is null or not internal.has_admin_permission('food','view') then
    raise exception 'Not authorized' using errcode='42501';
  end if;
  if p_placement_kind is null or p_placement_kind not in ('banner','featured')
     or p_days is null or p_days not in (7,30,90) then
    raise exception 'Invalid analytics range' using errcode='22023';
  end if;
  with totals as (
    select placement_id,sum(impressions)::bigint as impressions,sum(clicks)::bigint as clicks
    from internal.food_home_placement_daily
    where placement_kind=p_placement_kind and day between v_today-(p_days-1) and v_today
    group by placement_id
  ), configured as (
    select b.id as id,b.title as label from public.food_home_banners b where p_placement_kind='banner'
    union all
    select f.store_id,s.name from public.food_featured_stores f join public.food_stores s on s.id=f.store_id
      where p_placement_kind='featured'
  ), rows as (
    select coalesce(c.id,t.placement_id) as id,coalesce(c.label,'รายการที่ถูกลบ') as label,
      coalesce(t.impressions,0) as impressions,coalesce(t.clicks,0) as clicks
    from configured c full join totals t on t.placement_id=c.id
  )
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',label,'impressions',impressions,'clicks',clicks,
    'ctr_pct',case when impressions>0 then round(100.0*clicks/impressions,2) else null end)
    order by impressions desc,label,id),'[]'::jsonb),coalesce(sum(impressions),0),coalesce(sum(clicks),0)
    into v_items,v_impressions,v_clicks from rows;
  return jsonb_build_object('placement_kind',p_placement_kind,'days',p_days,
    'starts_on',v_today-(p_days-1),'ends_on',v_today,'impressions',v_impressions,'clicks',v_clicks,
    'ctr_pct',case when v_impressions>0 then round(100.0*v_clicks/v_impressions,2) else null end,
    'items',v_items,'last_limited_at',(select last_limited_at from internal.food_home_analytics_budget where singleton));
end;
$$;
revoke all on function public.admin_food_home_placement_analytics(text,integer) from public,anon,authenticated;
grant execute on function public.admin_food_home_placement_analytics(text,integer) to authenticated;
