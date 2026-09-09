-- WYN-145 / Phase 7: Experimentation & A/B Testing
-- Additive/idempotent. Creates no active experiment and changes no production weights.

-- WYNOS Experimentation & A/B Testing V1 (Phase 7)
-- ============================================================

create table if not exists public.feed_experiments (
  experiment_key text not null,
  version integer not null check(version > 0),
  status text not null default 'draft'
    check(status in ('draft','active','paused','completed')),
  start_at timestamptz not null,
  end_at timestamptz not null,
  allocation_basis_points integer not null default 0
    check(allocation_basis_points between 0 and 10000),
  eligible_maturity text[] not null default
    array['zero_history','sparse','learning','personalized'],
  primary_metric text,
  secondary_metrics text[] not null default array[]::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(experiment_key,version),
  check(start_at < end_at),
  check(eligible_maturity <@ array['zero_history','sparse','learning','personalized'])
);

create table if not exists public.feed_experiment_variants (
  experiment_key text not null,
  experiment_version integer not null,
  variant_key text not null,
  weight_basis_points integer not null check(weight_basis_points between 1 and 10000),
  config jsonb not null default '{}'::jsonb check(jsonb_typeof(config)='object'),
  primary key(experiment_key,experiment_version,variant_key),
  foreign key(experiment_key,experiment_version)
    references public.feed_experiments(experiment_key,version) on delete cascade
);

create table if not exists public.feed_experiment_exposures (
  id uuid primary key default gen_random_uuid(),
  experiment_key text not null,
  experiment_version integer not null,
  variant_key text not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  surface text not null check(surface in ('home')),
  exposure_date date not null default current_date,
  exposed_at timestamptz not null default now(),
  request_count integer not null default 1 check(request_count > 0),
  foreign key(experiment_key,experiment_version,variant_key)
    references public.feed_experiment_variants(
      experiment_key,experiment_version,variant_key),
  unique(experiment_key,experiment_version,user_id,surface,exposure_date)
);

create table if not exists public.feed_experiment_outcomes (
  exposure_id uuid not null references public.feed_experiment_exposures(id)
    on delete cascade,
  event_key text not null,
  outcome_type text not null check(outcome_type in (
    'qualified_view','long_view','fast_skip','like','save','comment','share',
    'profile_visit','follow_from_feed','hide','not_interested','report')),
  target_id uuid,
  occurred_at timestamptz not null,
  primary key(exposure_id,event_key)
);

create index if not exists feed_experiments_active_idx
  on public.feed_experiments(status,start_at,end_at);
create index if not exists feed_experiment_exposures_analysis_idx
  on public.feed_experiment_exposures(
    experiment_key,experiment_version,variant_key,exposed_at);
create index if not exists feed_experiment_outcomes_analysis_idx
  on public.feed_experiment_outcomes(exposure_id,outcome_type,occurred_at);

alter table public.feed_experiments enable row level security;
alter table public.feed_experiment_variants enable row level security;
alter table public.feed_experiment_exposures enable row level security;
alter table public.feed_experiment_outcomes enable row level security;
revoke all on public.feed_experiments,public.feed_experiment_variants,
  public.feed_experiment_exposures,public.feed_experiment_outcomes
  from authenticated,anon;

-- Stable across requests/deploys. Version is part of the input, intentionally
-- re-bucketing a materially new experiment. md5 is used only for distribution,
-- never for password/security decisions.
create or replace function internal.experiment_bucket(
  p_key text,p_version integer,p_user_id uuid,p_salt text default 'rollout'
)
returns integer language sql immutable parallel safe as $$
  select (('x'||substr(md5(p_key||':'||p_version||':'||p_user_id||':'||p_salt),1,8))
    ::bit(32)::bigint % 10000)::integer;
$$;
revoke all on function internal.experiment_bucket(text,integer,uuid,text)
  from public;

create or replace function internal.feed_experiment_is_valid(
  p_key text,p_version integer
)
returns boolean language plpgsql stable security definer set search_path=public as $$
declare v_total integer; v_invalid integer; v_mix jsonb;
begin
  select coalesce(sum(weight_basis_points),0),count(*) filter(where exists(
      select 1 from jsonb_object_keys(config) k(key)
      where k.key not in ('home.source_mix','fatigue.creator_factor',
        'fatigue.topic_factor','fatigue.content_type_factor',
        'fatigue.repetition_factor','similarity.enabled',
        'similarity.strength')))
    into v_total,v_invalid
  from public.feed_experiment_variants
  where experiment_key=p_key and experiment_version=p_version;
  if v_total<>10000 or v_invalid<>0 then return false; end if;

  if exists(select 1 from public.feed_experiment_variants v,
      lateral jsonb_each(v.config) c
      where v.experiment_key=p_key and v.experiment_version=p_version
        and c.key like 'fatigue.%'
        and (jsonb_typeof(c.value)<>'number'
          or (c.value#>>'{}')::double precision not between 0.1 and 1.0))
    then return false;
  end if;

  if exists(select 1 from public.feed_experiment_variants v
      where v.experiment_key=p_key and v.experiment_version=p_version
        and ((v.config ? 'similarity.enabled'
          and jsonb_typeof(v.config->'similarity.enabled')<>'boolean')
        or (v.config ? 'similarity.strength' and (
          jsonb_typeof(v.config->'similarity.strength')<>'number'
          or (v.config->>'similarity.strength')::double precision not between 0 and 0.25))))
    then return false;
  end if;

  for v_mix in select config->'home.source_mix'
    from public.feed_experiment_variants
    where experiment_key=p_key and experiment_version=p_version
      and config ? 'home.source_mix'
  loop
    if jsonb_typeof(v_mix)<>'object'
      or (select array_agg(keys.key order by keys.key)
          from jsonb_object_keys(v_mix) keys(key))
        <> array['club','exploration','following','latest','new_creator',
          'recommended','trending']
      or exists(select 1 from jsonb_each(v_mix) e
        where jsonb_typeof(e.value)<>'number'
          or (e.value#>>'{}')::double precision not between 0 and 100
          or (e.value#>>'{}')::double precision
            <> trunc((e.value#>>'{}')::double precision))
      or (select sum((value#>>'{}')::integer) from jsonb_each(v_mix))<>100
    then return false; end if;
  end loop;
  return true;
exception when others then return false;
end;
$$;
revoke all on function internal.feed_experiment_is_valid(text,integer)
  from public;

-- Active experiments exclusively own every config key. Independent keys may
-- coexist; overlapping active experiments are rejected rather than relying on
-- an invisible precedence rule.
create or replace function internal.validate_feed_experiment_activation()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='UPDATE' and exists(select 1 from public.feed_experiment_exposures
      where experiment_key=old.experiment_key
        and experiment_version=old.version)
    and (new.allocation_basis_points<>old.allocation_basis_points
      or new.start_at<>old.start_at or new.end_at<>old.end_at
      or new.eligible_maturity<>old.eligible_maturity) then
    raise exception 'Exposed experiment semantics are immutable; create a version';
  end if;
  if new.status='active' then
    if not internal.feed_experiment_is_valid(new.experiment_key,new.version)
      then raise exception 'Invalid experiment variants/configuration'; end if;
    if exists(
      select 1 from public.feed_experiments other
      join public.feed_experiment_variants ov
        on ov.experiment_key=other.experiment_key
        and ov.experiment_version=other.version
      join public.feed_experiment_variants nv
        on nv.experiment_key=new.experiment_key
        and nv.experiment_version=new.version
      join lateral jsonb_object_keys(ov.config) ok(key) on true
      join lateral jsonb_object_keys(nv.config) nk(key) on nk.key=ok.key
      where other.status='active'
        and (other.experiment_key,other.version)
          <>(new.experiment_key,new.version)
        and tstzrange(other.start_at,other.end_at,'[)')
          && tstzrange(new.start_at,new.end_at,'[)'))
      then raise exception 'Experiment config-key conflict'; end if;
  end if;
  new.updated_at=clock_timestamp();
  return new;
end;
$$;
revoke all on function internal.validate_feed_experiment_activation()
  from public;
drop trigger if exists feed_experiment_validate_activation on public.feed_experiments;
create trigger feed_experiment_validate_activation
  before insert or update on public.feed_experiments for each row
  execute function internal.validate_feed_experiment_activation();

create or replace function internal.prevent_active_variant_mutation()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_key text:=coalesce(new.experiment_key,old.experiment_key);
  v_version integer:=coalesce(new.experiment_version,old.experiment_version);
begin
  if exists(select 1 from public.feed_experiments where experiment_key=v_key
      and version=v_version and status='active')
    or exists(select 1 from public.feed_experiment_exposures
      where experiment_key=v_key and experiment_version=v_version) then
    raise exception 'Active experiment variants are immutable; create a version';
  end if;
  return case when tg_op='DELETE' then old else new end;
end;
$$;
revoke all on function internal.prevent_active_variant_mutation() from public;
drop trigger if exists feed_experiment_variants_immutable on public.feed_experiment_variants;
create trigger feed_experiment_variants_immutable
  before insert or update or delete on public.feed_experiment_variants
  for each row execute function internal.prevent_active_variant_mutation();

-- Resolution is read-only: assignment alone is not exposure. Home records the
-- server-verified assignment only after ranking/allocation succeeds.
create or replace function public.resolve_home_feed_experiments(
  p_surface text default 'home'
)
returns jsonb language plpgsql security definer set search_path=public as $$
declare e record; v record; v_bucket integer; v_running integer;
  v_found boolean;
  v_effective jsonb:='{}'; v_assignments jsonb:='[]'; v_keys text[]:=array[]::text[];
  v_maturity text;
begin
  if auth.uid() is null or p_surface<>'home' then return '{}'::jsonb; end if;
  select maturity_state into v_maturity
    from public.get_my_personalization_maturity();
  for e in select * from public.feed_experiments
    where status='active' and clock_timestamp()>=start_at
      and clock_timestamp()<end_at
      and v_maturity=any(eligible_maturity)
    order by experiment_key,version
  loop
    if not internal.feed_experiment_is_valid(e.experiment_key,e.version)
      or internal.experiment_bucket(e.experiment_key,e.version,auth.uid())
        >=e.allocation_basis_points then continue; end if;
    v_bucket:=internal.experiment_bucket(
      e.experiment_key,e.version,auth.uid(),'variant');
    v_running:=0; v_found:=false;
    for v in select * from public.feed_experiment_variants
      where experiment_key=e.experiment_key and experiment_version=e.version
      order by variant_key
    loop
      v_found:=true;
      v_running:=v_running+v.weight_basis_points;
      exit when v_bucket<v_running;
    end loop;
    if not v_found or exists(
      select 1 from jsonb_object_keys(v.config) keys(key)
      where keys.key=any(v_keys)) then continue; end if;
    v_effective:=v_effective||v.config;
    v_keys:=v_keys||array(select jsonb_object_keys(v.config));
    v_assignments:=v_assignments||jsonb_build_array(
      e.experiment_key||':v'||e.version||':'||v.variant_key);
  end loop;
  return v_effective||jsonb_build_object('_assignments',v_assignments);
exception when others then return '{}'::jsonb;
end;
$$;
revoke all on function public.resolve_home_feed_experiments(text) from public,anon;
grant execute on function public.resolve_home_feed_experiments(text) to authenticated;

create or replace function public.record_home_feed_experiment_exposures(
  p_assignments text[],p_surface text default 'home'
)
returns void language sql security definer set search_path=public as $$
  with maturity as (
    select maturity_state from public.get_my_personalization_maturity()
  ), weighted as (
    select e.experiment_key,e.version,v.variant_key,v.weight_basis_points,
      sum(v.weight_basis_points) over(partition by e.experiment_key,e.version
        order by v.variant_key) as upper_bucket,e.allocation_basis_points
    from public.feed_experiments e
    join public.feed_experiment_variants v on v.experiment_key=e.experiment_key
      and v.experiment_version=e.version
    cross join maturity m
    where auth.uid() is not null and p_surface='home'
      and cardinality(coalesce(p_assignments,array[]::text[])) between 1 and 8
      and e.status='active'
      and clock_timestamp()>=e.start_at and clock_timestamp()<e.end_at
      and m.maturity_state=any(e.eligible_maturity)
      and internal.feed_experiment_is_valid(e.experiment_key,e.version)
      and internal.experiment_bucket(e.experiment_key,e.version,auth.uid())
        <e.allocation_basis_points
  ), assigned as (
    select * from weighted w where
      internal.experiment_bucket(w.experiment_key,w.version,auth.uid(),'variant')
        >=w.upper_bucket-w.weight_basis_points
      and internal.experiment_bucket(
        w.experiment_key,w.version,auth.uid(),'variant')<w.upper_bucket
      and w.experiment_key||':v'||w.version||':'||w.variant_key
        =any(coalesce(p_assignments,array[]::text[]))
  )
  insert into public.feed_experiment_exposures(
    experiment_key,experiment_version,variant_key,user_id,surface)
  select experiment_key,version,variant_key,auth.uid(),p_surface from assigned
  on conflict(experiment_key,experiment_version,user_id,surface,exposure_date)
    do update set request_count=public.feed_experiment_exposures.request_count+1;
$$;
revoke all on function public.record_home_feed_experiment_exposures(text[],text)
  from public,anon;
grant execute on function public.record_home_feed_experiment_exposures(text[],text)
  to authenticated;

create or replace function internal.attribute_feed_experiment_outcome()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_user uuid; v_type text; v_target uuid; v_key text; v_at timestamptz;
begin
  if tg_table_name='feed_signals' then
    v_user:=new.user_id; v_type:=new.signal_type; v_target:=new.target_id;
    v_key:='feed_signal:'||new.id; v_at:=new.created_at;
  elsif tg_table_name='drop_likes' then
    v_user:=new.user_id; v_type:='like'; v_target:=new.drop_id;
    v_key:='like:'||new.drop_id||':'||new.user_id; v_at:=new.created_at;
  elsif tg_table_name='drop_comments' then
    v_user:=new.author_id; v_type:='comment'; v_target:=new.drop_id;
    v_key:='comment:'||new.id; v_at:=new.created_at;
  elsif tg_table_name='redrops' then
    v_user:=new.redropper_id; v_type:='share'; v_target:=new.drop_id;
    v_key:='share:'||new.id; v_at:=new.created_at;
  elsif tg_table_name='saves' and new.content_type='drop' then
    v_user:=new.user_id; v_type:='save'; v_target:=new.content_id;
    v_key:='save:'||new.user_id||':'||new.content_id; v_at:=new.created_at;
  elsif tg_table_name='reports' and new.target_type='drop' then
    v_user:=new.reporter_id; v_type:='report'; v_target:=new.target_id;
    v_key:='report:'||new.id; v_at:=new.created_at;
  else return new; end if;
  if v_type not in ('qualified_view','long_view','fast_skip','like','save',
    'comment','share','profile_visit','follow_from_feed','hide',
    'not_interested','report') then return new; end if;
  insert into public.feed_experiment_outcomes(
    exposure_id,event_key,outcome_type,target_id,occurred_at)
  select x.id,v_key,v_type,v_target,v_at
  from public.feed_experiment_exposures x
  join public.feed_experiments e on e.experiment_key=x.experiment_key
    and e.version=x.experiment_version
  where x.user_id=v_user and x.surface='home' and x.exposed_at<=v_at
    and x.exposure_date=v_at::date and v_at>=e.start_at and v_at<e.end_at
  on conflict do nothing;
  return new;
end;
$$;
revoke all on function internal.attribute_feed_experiment_outcome() from public;
drop trigger if exists feed_signals_experiment_outcome on public.feed_signals;
create trigger feed_signals_experiment_outcome after insert on public.feed_signals
  for each row execute function internal.attribute_feed_experiment_outcome();
drop trigger if exists drop_likes_experiment_outcome on public.drop_likes;
create trigger drop_likes_experiment_outcome after insert on public.drop_likes
  for each row execute function internal.attribute_feed_experiment_outcome();
drop trigger if exists drop_comments_experiment_outcome on public.drop_comments;
create trigger drop_comments_experiment_outcome after insert on public.drop_comments
  for each row execute function internal.attribute_feed_experiment_outcome();
drop trigger if exists redrops_experiment_outcome on public.redrops;
create trigger redrops_experiment_outcome after insert on public.redrops
  for each row execute function internal.attribute_feed_experiment_outcome();
drop trigger if exists saves_experiment_outcome on public.saves;
create trigger saves_experiment_outcome after insert on public.saves
  for each row execute function internal.attribute_feed_experiment_outcome();
drop trigger if exists reports_experiment_outcome on public.reports;
create trigger reports_experiment_outcome after insert on public.reports
  for each row execute function internal.attribute_feed_experiment_outcome();

-- Owner/service-role reporting only; no client grant and no automatic winner.
create or replace view internal.feed_experiment_variant_metrics as
with exposure_rollup as (
  select experiment_key,experiment_version,variant_key,
    count(distinct user_id) as unique_exposed_users,
    sum(request_count) as impressions,count(*) as exposure_days
  from public.feed_experiment_exposures
  group by experiment_key,experiment_version,variant_key
), outcome_rollup as (
  select x.experiment_key,x.experiment_version,x.variant_key,
    count(*) filter(where o.outcome_type='qualified_view') as qualified_views,
    count(*) filter(where o.outcome_type='long_view') as long_views,
    count(*) filter(where o.outcome_type='fast_skip') as fast_skips,
    count(*) filter(where o.outcome_type='like') as likes,
    count(*) filter(where o.outcome_type='save') as saves,
    count(*) filter(where o.outcome_type='share') as shares,
    count(*) filter(where o.outcome_type='comment') as comments,
    count(*) filter(where o.outcome_type='follow_from_feed') as follows,
    count(*) filter(where o.outcome_type='hide') as hides,
    count(*) filter(where o.outcome_type='not_interested') as not_interested,
    count(*) filter(where o.outcome_type='report') as reports
  from public.feed_experiment_exposures x
  join public.feed_experiment_outcomes o on o.exposure_id=x.id
  group by x.experiment_key,x.experiment_version,x.variant_key
)
select e.*,coalesce(o.qualified_views,0) as qualified_views,
  coalesce(o.long_views,0) as long_views,coalesce(o.fast_skips,0) as fast_skips,
  coalesce(o.likes,0) as likes,coalesce(o.saves,0) as saves,
  coalesce(o.shares,0) as shares,coalesce(o.comments,0) as comments,
  coalesce(o.follows,0) as follows,coalesce(o.hides,0) as hides,
  coalesce(o.not_interested,0) as not_interested,
  coalesce(o.reports,0) as reports,
  coalesce(o.qualified_views,0)::double precision/e.impressions
    as qualified_view_rate,
  coalesce(o.long_views,0)::double precision/e.impressions as long_view_rate,
  coalesce(o.fast_skips,0)::double precision/e.impressions as fast_skip_rate,
  coalesce(o.follows,0)::double precision/e.impressions as follow_from_feed_rate,
  coalesce(o.hides,0)::double precision/e.impressions as hide_rate,
  coalesce(o.not_interested,0)::double precision/e.impressions
    as not_interested_rate,
  coalesce(o.reports,0)::double precision/e.impressions as report_rate
from exposure_rollup e left join outcome_rollup o using(
  experiment_key,experiment_version,variant_key);
revoke all on internal.feed_experiment_variant_metrics from public,authenticated,anon;

-- ============================================================
