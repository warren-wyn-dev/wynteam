-- WYNOS Phase 3: additive Trending to Top100 integration migration.
-- Safe after WYN-140; no user or engagement rows are deleted.

-- ============================================================
-- WYNOS Top100 Organic Ranking Engine V1 (Phase 3)
-- ============================================================

-- Top100 is a broader seven-day chart, precomputed independently from the
-- short-window Trending cache. The published Trending score is consumed only
-- as a capped momentum bonus; impressions, placements, fetches, and rank are
-- absent from both the refresh inputs and this table.
create table if not exists public.top100_scores (
  drop_id uuid primary key references public.drops (id) on delete cascade,
  content_type text not null default 'drop' check (content_type = 'drop'),
  creator_id uuid not null references public.profiles (id) on delete cascade,
  top100_score double precision not null check (top100_score >= 0),
  organic_score double precision not null check (organic_score >= 0),
  trend_bonus double precision not null check (trend_bonus >= 0),
  unique_engagers_7d integer not null default 0,
  likes_7d integer not null default 0,
  comments_7d integer not null default 0,
  shares_7d integer not null default 0,
  saves_7d integer not null default 0,
  qualified_views_7d integer not null default 0,
  current_rank integer,
  previous_rank integer,
  first_entered_at timestamptz not null,
  observed_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create index if not exists top100_scores_rank_idx
  on public.top100_scores (top100_score desc, organic_score desc,
    observed_at desc, drop_id);
create index if not exists top100_scores_public_rank_idx
  on public.top100_scores (current_rank, observed_at desc, drop_id);

alter table public.top100_scores enable row level security;
drop policy if exists "Top100 safe metadata is viewable by authenticated users"
  on public.top100_scores;
create policy "Top100 safe metadata is viewable by authenticated users"
  on public.top100_scores for select to authenticated using (true);
revoke all on public.top100_scores from authenticated, anon;
grant select (
  drop_id, creator_id, top100_score, current_rank, previous_rank,
  first_entered_at, observed_at
) on public.top100_scores to authenticated;

-- One authoritative score decomposition. Organic quality is broad-window and
-- log-normalized. Trending contributes only a multiplier in [1, 1.25], so its
-- bonus can be at most 25% of organic score (20% of the effective total). It
-- cannot create Top100 score from zero organic quality and does not re-add the
-- recent raw actions already represented in the broad aggregates.
create or replace function public.calculate_top100_score(
  p_likes integer,
  p_comments integer,
  p_shares integer,
  p_saves integer,
  p_qualified_views integer,
  p_unique_engagers integer,
  p_action_count integer,
  p_content_age_hours double precision,
  p_trend_score double precision,
  p_report_count integer,
  p_suspicious boolean
)
returns table (
  organic_score double precision,
  trend_bonus double precision,
  top100_score double precision
)
language sql
immutable
parallel safe
as $$
  with factors as (
    select
      case when p_unique_engagers <= 0 then 0.0 else
        ln(1.0
          + greatest(p_likes, 0) * 2.0
          + greatest(p_comments, 0) * 4.0
          + greatest(p_shares, 0) * 6.0
          + greatest(p_saves, 0) * 5.0
          + greatest(p_qualified_views, 0) * 0.1)
        * (0.70 + 0.30 * least(1.0,
            ln(1.0 + p_unique_engagers) / ln(101.0)))
        * greatest(0.30, least(1.0,
            p_unique_engagers * 4.0 / greatest(p_action_count, 1)))
        * (0.70 + 0.30 * power(0.5,
            greatest(p_content_age_hours, 0) / 168.0))
      end as raw_organic,
      least(0.25, ln(1.0 + greatest(p_trend_score, 0)) / 40.0)
        as trend_multiplier,
      power(0.20::double precision,
        greatest(p_report_count, 0)::double precision)
        * case when p_suspicious then 0.15 else 1.0 end as penalty
  ), scored as (
    select raw_organic * penalty as organic,
      raw_organic * trend_multiplier * penalty as bonus
    from factors
  )
  select organic, bonus, least(1000000.0, organic + bonus) from scored;
$$;

grant execute on function public.calculate_top100_score(
  integer, integer, integer, integer, integer, integer, integer,
  double precision, double precision, integer, boolean
) to authenticated;

create or replace function public.refresh_top100_scores(
  p_observed_at timestamptz default clock_timestamp()
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows integer;
begin
  -- Preserve real rank history before replacing this snapshot. Re-running with
  -- identical inputs changes neither candidate cardinality nor score rows.
  update public.top100_scores
  set previous_rank = current_rank
  where observed_at < p_observed_at;

  with raw_actions as (
    select dl.drop_id, dl.user_id as actor_id, 'like'::text as action_type,
      dl.created_at, 2.0::double precision as action_weight
    from public.drop_likes dl
    where dl.created_at >= p_observed_at - interval '7 days'
    union all
    select dc.drop_id, dc.author_id, 'comment', dc.created_at, 4.0
    from public.drop_comments dc
    where dc.created_at >= p_observed_at - interval '7 days'
    union all
    select r.drop_id, r.redropper_id, 'share', r.created_at, 6.0
    from public.redrops r
    where r.created_at >= p_observed_at - interval '7 days'
    union all
    select dv.drop_id, dv.viewer_id, 'view', dv.created_at, 0.1
    from public.drop_views dv
    where dv.created_at >= p_observed_at - interval '7 days'
    union all
    select s.content_id, s.user_id, 'save', s.created_at, 5.0
    from public.saves s
    where s.content_type = 'drop'
      and s.created_at >= p_observed_at - interval '7 days'
  ), organic as (
    select ra.*
    from raw_actions ra
    join public.drops d on d.id = ra.drop_id
    where ra.actor_id <> d.author_id and d.deleted_at is null
  ), identity_hours as (
    select drop_id, actor_id, action_type,
      date_bin(interval '1 hour', created_at,
        timestamptz '2000-01-01 00:00:00+00') as bucket_start,
      case when action_type = 'comment' then least(count(*), 2)::integer
           else 1 end as capped_actions
    from organic
    group by drop_id, actor_id, action_type,
      date_bin(interval '1 hour', created_at,
        timestamptz '2000-01-01 00:00:00+00')
  ), aggregates as (
    select ih.drop_id,
      count(distinct ih.actor_id)::integer as unique_engagers,
      sum(ih.capped_actions)::integer as action_count,
      coalesce(sum(ih.capped_actions) filter (
        where ih.action_type = 'like'), 0)::integer as likes,
      coalesce(sum(ih.capped_actions) filter (
        where ih.action_type = 'comment'), 0)::integer as comments,
      coalesce(sum(ih.capped_actions) filter (
        where ih.action_type = 'share'), 0)::integer as shares,
      coalesce(sum(ih.capped_actions) filter (
        where ih.action_type = 'save'), 0)::integer as saves,
      coalesce(sum(ih.capped_actions) filter (
        where ih.action_type = 'view'), 0)::integer as views,
      count(distinct ih.actor_id) filter (
        where engager.created_at >= p_observed_at - interval '24 hours')::integer
        as new_engagers
    from identity_hours ih
    join public.profiles engager on engager.id = ih.actor_id
    group by ih.drop_id
  ), reports as (
    select target_id as drop_id, count(*)::integer as report_count
    from public.reports
    where target_type = 'drop' and status in ('pending', 'reviewing', 'actioned')
    group by target_id
  ), candidate_ids as (
    -- Broad organic performers plus the published Phase 2 Trending candidates.
    -- UNION deduplicates the stable underlying Drop identity.
    select drop_id from aggregates
    union
    select drop_id from public.trending_scores
    where trend_score > 0
      and observed_at >= p_observed_at - interval '2 hours'
  ), candidate_data as (
    select d.id as drop_id, d.author_id,
      greatest(extract(epoch from (p_observed_at - d.created_at)) / 3600.0, 0)
        as age_hours,
      coalesce(a.likes, 0) as likes,
      coalesce(a.comments, 0) as comments,
      coalesce(a.shares, 0) as shares,
      coalesce(a.saves, 0) as saves,
      coalesce(a.views, 0) as views,
      coalesce(a.unique_engagers, 0) as unique_engagers,
      coalesce(a.action_count, 0) as action_count,
      coalesce(ts.trend_score, 0) as trend_score,
      coalesce(r.report_count, 0) as report_count,
      ((coalesce(a.action_count, 0) >= 50 and coalesce(a.unique_engagers, 0) <= 3)
        or (coalesce(a.unique_engagers, 0) >= 5
          and coalesce(a.new_engagers, 0)::double precision
            / greatest(a.unique_engagers, 1) >= 0.80)) as suspicious
    from candidate_ids candidate
    join public.drops d on d.id = candidate.drop_id
    left join aggregates a on a.drop_id = d.id
    left join public.trending_scores ts on ts.drop_id = d.id
    left join reports r on r.drop_id = d.id
    where d.deleted_at is null
      and not internal.is_posting_blocked(d.author_id)
  ), scored as (
    select data.*, components.*
    from candidate_data data
    cross join lateral public.calculate_top100_score(
      data.likes, data.comments, data.shares, data.saves, data.views,
      data.unique_engagers, data.action_count, data.age_hours,
      data.trend_score, data.report_count, data.suspicious
    ) components
  )
  insert into public.top100_scores (
    drop_id, creator_id, top100_score, organic_score, trend_bonus,
    unique_engagers_7d, likes_7d, comments_7d, shares_7d, saves_7d,
    qualified_views_7d, first_entered_at, observed_at, updated_at
  )
  select drop_id, author_id, top100_score, organic_score, trend_bonus,
    unique_engagers, likes, comments, shares, saves, views,
    p_observed_at, p_observed_at, clock_timestamp()
  from scored
  where top100_score > 0
  on conflict (drop_id) do update set
    creator_id = excluded.creator_id,
    top100_score = excluded.top100_score,
    organic_score = excluded.organic_score,
    trend_bonus = excluded.trend_bonus,
    unique_engagers_7d = excluded.unique_engagers_7d,
    likes_7d = excluded.likes_7d,
    comments_7d = excluded.comments_7d,
    shares_7d = excluded.shares_7d,
    saves_7d = excluded.saves_7d,
    qualified_views_7d = excluded.qualified_views_7d,
    observed_at = excluded.observed_at,
    updated_at = excluded.updated_at;
  get diagnostics v_rows = row_count;

  with ranked as (
    select drop_id, row_number() over (
      order by top100_score desc, organic_score desc, observed_at desc, drop_id desc
    )::integer as rank
    from public.top100_scores
    where observed_at = p_observed_at
  )
  update public.top100_scores score
  set current_rank = ranked.rank
  from ranked
  where score.drop_id = ranked.drop_id;

  return v_rows;
end;
$$;

revoke all on function public.refresh_top100_scores(timestamptz) from public;
revoke all on function public.refresh_top100_scores(timestamptz)
  from authenticated, anon;

create or replace function public.get_top100_candidates(p_limit integer default 100)
returns table (
  row_data jsonb,
  rank integer,
  previous_rank integer,
  first_entered_at timestamptz,
  observed_at timestamptz
)
language sql
stable
as $$
  select to_jsonb(hf.*), score.current_rank, score.previous_rank,
    score.first_entered_at, score.observed_at
  from public.top100_scores score
  join public.drops d on d.id = score.drop_id and d.deleted_at is null
  join public.home_feed hf
    on hf.id = score.drop_id and hf.content_type = 'drop' and hf.redrop_id is null
  where score.top100_score > 0
    and score.observed_at >= now() - interval '2 hours'
    and not exists (
      select 1 from public.feed_signals fs
      where fs.user_id = auth.uid() and fs.signal_type in ('hide', 'not_interested')
        and fs.target_id = score.drop_id
    )
    and not internal.is_posting_blocked(score.creator_id)
  -- current_rank was computed with the full private tie-break tuple during
  -- refresh; the read path needs only safe rank metadata.
  order by score.current_rank asc, score.observed_at desc, score.drop_id desc
  limit least(greatest(coalesce(p_limit, 100), 1), 100);
$$;

revoke all on function public.get_top100_candidates(integer) from public;
grant execute on function public.get_top100_candidates(integer) to authenticated;
