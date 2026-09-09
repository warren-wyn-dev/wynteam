-- WYN-147: Home Feed Repetition Control
-- Additive/non-destructive. Apply after WYN-146.
--
-- Goal: keep For You personalized while making refreshes feel fresh. We do not
-- randomize the feed globally. Instead, content delivered recently to the
-- viewer gets a bounded score multiplier, then a tiny deterministic 15-minute
-- jitter breaks near-ties. Existing pre-WYN147 impression rows are ignored so
-- the old "record all 200 candidates" telemetry cannot suppress the catalog.

create table if not exists public.feed_repetition_config (
  algorithm_version integer primary key check (algorithm_version = 1),
  started_at timestamptz not null,
  hard_cooldown_minutes integer not null check (hard_cooldown_minutes between 5 and 180),
  medium_cooldown_minutes integer not null check (medium_cooldown_minutes between 60 and 720),
  soft_cooldown_minutes integer not null check (soft_cooldown_minutes between 360 and 2880),
  hard_factor double precision not null check (hard_factor between 0 and 1),
  medium_factor double precision not null check (medium_factor between 0 and 1),
  soft_factor double precision not null check (soft_factor between 0 and 1),
  jitter_strength double precision not null check (jitter_strength between 0 and 3),
  updated_at timestamptz not null default now(),
  check (hard_cooldown_minutes < medium_cooldown_minutes),
  check (medium_cooldown_minutes < soft_cooldown_minutes),
  check (hard_factor <= medium_factor and medium_factor <= soft_factor)
);

insert into public.feed_repetition_config (
  algorithm_version, started_at, hard_cooldown_minutes,
  medium_cooldown_minutes, soft_cooldown_minutes,
  hard_factor, medium_factor, soft_factor, jitter_strength
) values (1, clock_timestamp(), 60, 360, 1440, 0.05, 0.40, 0.75, 1.25)
on conflict (algorithm_version) do nothing;

alter table public.feed_repetition_config enable row level security;
revoke all on public.feed_repetition_config from authenticated, anon;

-- The client currently sends the full 200-row ranked window once when page 0
-- is built. Those are ranking candidates, not 200 posts the user actually saw.
-- From WYN-147 onward, retain only the first delivered page (10 rows) as the
-- conservative server-side repetition signal. This fixes refresh repetition
-- without falsely marking the rest of the candidate window as consumed.
create or replace function public.record_feed_impressions(
  p_session_key text,
  p_items jsonb,
  p_latency_ms integer default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v_count integer;
begin
  if auth.uid() is null
    or length(p_session_key) not between 8 and 128
    or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) > 200 then
    return 0;
  end if;

  insert into public.feed_impressions(
    user_id,event_key,session_key,content_id,feed_source,rank_position,
    maturity_state,content_type,topic,reason_code,candidate_origin,latency_ms,
    fallback_used,experiment_assignments
  )
  select auth.uid(),
    p_session_key||':'||left(coalesce(x->>'renderKey',x->>'contentId'),100),
    p_session_key,(x->>'contentId')::uuid,x->>'feedSource',
    (x->>'rankPosition')::int,
    coalesce((select maturity_state from public.get_my_personalization_maturity()),
      'zero_history'),
    coalesce(x->>'contentType','drop'),left(x->>'topic',80),
    left(x->>'reasonCode',80),coalesce(left(x->>'candidateOrigin',40),'direct'),
    p_latency_ms,coalesce((x->>'fallbackUsed')::boolean,false),
    array(select jsonb_array_elements_text(coalesce(x->'experiments','[]')) limit 8)
  from jsonb_array_elements(p_items) x
  where x->>'feedSource' in (
      'following','recommended','trending','latest','club','new_creator','exploration')
    and (x->>'rankPosition')::int between 1 and 10
  on conflict(user_id,event_key) do nothing;

  get diagnostics v_count=row_count;
  return v_count;
exception when others then
  return 0;
end;
$$;
revoke all on function public.record_feed_impressions(text,jsonb,integer)
  from public,anon;
grant execute on function public.record_feed_impressions(text,jsonb,integer)
  to authenticated;

create index if not exists feed_impressions_recent_user_idx
  on public.feed_impressions(user_id,created_at desc,content_id);

-- Isolate privileged telemetry lookup from the invoker-mode feed RPC. The feed
-- itself must continue running with the viewer's RLS permissions; only this
-- narrow helper reads the private impression table and only for auth.uid().
create or replace function internal.my_recent_feed_deliveries()
returns table(content_id uuid,last_delivered_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select i.content_id,max(i.created_at) as last_delivered_at
  from public.feed_impressions i
  join public.feed_repetition_config c on c.algorithm_version=1
  where auth.uid() is not null
    and i.user_id=auth.uid()
    and i.created_at>=c.started_at
    and i.created_at>=now()-make_interval(mins=>c.soft_cooldown_minutes)
  group by i.content_id;
$$;
revoke all on function internal.my_recent_feed_deliveries() from public,anon;
grant execute on function internal.my_recent_feed_deliveries() to authenticated;

-- Transform all per-source scores together so source allocation cannot undo
-- repetition control. The same small jitter is added to every source score for
-- a content item, preserving its source preference while breaking near-ties.
create or replace function internal.repetition_adjust_source_scores(
  p_scores jsonb,p_factor double precision,p_jitter double precision
)
returns jsonb
language sql
immutable
parallel safe
as $$
  select coalesce(
    jsonb_object_agg(e.key,
      to_jsonb((e.value#>>'{}')::double precision*p_factor+p_jitter)),
    '{}'::jsonb)
  from jsonb_each(coalesce(p_scores,'{}'::jsonb)) e;
$$;
revoke all on function internal.repetition_adjust_source_scores(
  jsonb,double precision,double precision) from public;
grant execute on function internal.repetition_adjust_source_scores(
  jsonb,double precision,double precision) to authenticated;

-- Preserve the WYN-146 scorer as the authoritative base and wrap it. Moving
-- the base into internal keeps the public RPC name stable for existing clients
-- without copying/re-forking the large ranking SQL.
do $$
begin
  if to_regprocedure('internal.get_wynos_ranked_feed_base_v1()') is null
    and to_regprocedure('public.get_wynos_ranked_feed()') is not null then
    alter function public.get_wynos_ranked_feed()
      rename to get_wynos_ranked_feed_base_v1;
    alter function public.get_wynos_ranked_feed_base_v1()
      set schema internal;
  end if;
end
$$;

grant execute on function internal.get_wynos_ranked_feed_base_v1()
  to authenticated;

create or replace function public.get_wynos_ranked_feed()
returns table (
  row_data jsonb,
  wynos_score double precision,
  is_following boolean,
  is_discovery boolean
)
language sql
stable
security invoker
as $$
  with cfg as (
    select * from public.feed_repetition_config where algorithm_version=1
  ), recent as (
    select * from internal.my_recent_feed_deliveries()
  ), base as (
    select * from internal.get_wynos_ranked_feed_base_v1()
  ), weighted as (
    select b.*,
      case
        when r.last_delivered_at is null then 1.0
        when r.last_delivered_at >= now()-make_interval(
          mins=>c.hard_cooldown_minutes) then c.hard_factor
        when r.last_delivered_at >= now()-make_interval(
          mins=>c.medium_cooldown_minutes) then c.medium_factor
        when r.last_delivered_at >= now()-make_interval(
          mins=>c.soft_cooldown_minutes) then c.soft_factor
        else 1.0
      end as repetition_factor,
      (
        (abs(mod(hashtextextended(
          coalesce(b.row_data->>'id','')||':'||
          floor(extract(epoch from now())/900)::bigint::text,0),1000))
          ::double precision/1000.0)-0.5
      )*2.0*c.jitter_strength as score_jitter
    from base b
    cross join cfg c
    left join recent r on r.content_id=(b.row_data->>'id')::uuid
  ), adjusted as (
    select
      jsonb_set(
        row_data,
        '{feed_source_scores}',
        internal.repetition_adjust_source_scores(
          row_data->'feed_source_scores',repetition_factor,score_jitter),
        false
      ) || jsonb_build_object(
        'feed_repetition_factor',repetition_factor
      ) as adjusted_row_data,
      wynos_score*repetition_factor+score_jitter as adjusted_score,
      is_following,is_discovery
    from weighted
  )
  select adjusted_row_data,adjusted_score,is_following,is_discovery
  from adjusted
  order by adjusted_score desc,
    adjusted_row_data->>'created_at' desc,
    adjusted_row_data->>'id' desc;
$$;

revoke all on function public.get_wynos_ranked_feed() from public,anon;
grant execute on function public.get_wynos_ranked_feed() to authenticated;
