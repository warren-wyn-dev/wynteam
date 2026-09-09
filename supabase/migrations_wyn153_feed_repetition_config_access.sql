-- WYN-153 / BUG-004 follow-up: keep repetition configuration private while
-- allowing the SECURITY INVOKER Home feed wrapper to apply repetition control.
--
-- WYN-147 intentionally revoked direct authenticated access to
-- public.feed_repetition_config, but its public feed wrapper selected that table
-- directly. Under SECURITY INVOKER that makes the RPC fail for real clients.
-- Isolate only the config lookup behind a narrow SECURITY DEFINER helper, just
-- like WYN-147 already does for private feed-impression telemetry. The public
-- feed wrapper remains SECURITY INVOKER so all candidate/RLS visibility remains
-- evaluated as the signed-in viewer.

create or replace function internal.current_feed_repetition_config()
returns table (
  algorithm_version integer,
  started_at timestamptz,
  hard_cooldown_minutes integer,
  medium_cooldown_minutes integer,
  soft_cooldown_minutes integer,
  hard_factor double precision,
  medium_factor double precision,
  soft_factor double precision,
  jitter_strength double precision,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.algorithm_version,
    c.started_at,
    c.hard_cooldown_minutes,
    c.medium_cooldown_minutes,
    c.soft_cooldown_minutes,
    c.hard_factor,
    c.medium_factor,
    c.soft_factor,
    c.jitter_strength,
    c.updated_at
  from public.feed_repetition_config c
  where c.algorithm_version = 1;
$$;

revoke all on function internal.current_feed_repetition_config()
  from public, anon;
grant execute on function internal.current_feed_repetition_config()
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
    select * from internal.current_feed_repetition_config()
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
      is_following
    from weighted
  )
  select
    adjusted_row_data,
    adjusted_score,
    is_following,
    (
      not is_following
      and not exists (
        select 1
        from public.my_effective_affinities a
        where a.dimension_type = 'creator'
          and a.dimension_key = adjusted_row_data->>'author_id'
      )
    ) as is_discovery
  from adjusted
  order by adjusted_score desc,
    adjusted_row_data->>'created_at' desc,
    adjusted_row_data->>'id' desc;
$$;

revoke all on function public.get_wynos_ranked_feed() from public, anon;
grant execute on function public.get_wynos_ranked_feed() to authenticated;
