-- WYN-151 / BUG-004 follow-up: restore the documented Discovery semantics.
--
-- WYN-146 describes Discovery as a genuinely new-to-you creator: someone the
-- viewer does not follow and has no recorded creator affinity toward. Its
-- implementation used aggregate affinity_raw, which also includes topic and
-- content-type affinity. That makes an unrelated creator stop being Discovery
-- merely because the viewer likes the same content type (for example images).
-- Keep WYN-147 repetition control intact and recompute only the public
-- is_discovery flag from creator affinity at the final wrapper boundary.

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

revoke all on function public.get_wynos_ranked_feed() from public,anon;
grant execute on function public.get_wynos_ranked_feed() to authenticated;
