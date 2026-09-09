-- WYNOS Phase 2: additive Trending Velocity Engine migration.
-- Safe to apply after the Phase 1 schema; no user rows are deleted.

-- ============================================================
-- WYNOS Trending Velocity Engine V1 (Phase 2)
-- ============================================================

-- One row per Drop, refreshed out-of-band. Home/Discovery reads this bounded
-- cache and never aggregates raw engagement in the request path. Scores may be
-- a few minutes stale by design; refresh_trending_scores() is idempotent and
-- ready for a future Supabase Cron invocation without requiring new services.
create table if not exists public.trending_scores (
  drop_id uuid primary key references public.drops (id) on delete cascade,
  content_type text not null default 'drop' check (content_type = 'drop'),
  creator_id uuid not null references public.profiles (id) on delete cascade,
  trend_score double precision not null check (trend_score >= 0),
  observed_at timestamptz not null,
  observation_window interval not null default interval '6 hours',
  content_age_hours double precision not null,
  likes_1h integer not null default 0,
  comments_1h integer not null default 0,
  shares_1h integer not null default 0,
  saves_1h integer not null default 0,
  qualified_views_1h integer not null default 0,
  unique_engagers_1h integer not null default 0,
  weighted_velocity_15m double precision not null default 0,
  weighted_velocity_1h double precision not null default 0,
  previous_velocity_1h double precision not null default 0,
  growth_factor double precision not null default 1,
  report_penalty double precision not null default 1,
  manipulation_penalty double precision not null default 1,
  updated_at timestamptz not null default now()
);

create index if not exists trending_scores_rank_idx
  on public.trending_scores (trend_score desc, observed_at desc, drop_id);

alter table public.trending_scores enable row level security;
drop policy if exists "Trending aggregates are viewable by authenticated users"
  on public.trending_scores;
create policy "Trending aggregates are viewable by authenticated users"
  on public.trending_scores for select to authenticated using (true);

-- Request functions run as the viewer so home_feed RLS remains authoritative.
-- Grant only the Phase 3-safe aggregate contract, not report/manipulation or
-- formula-intermediate columns that could reveal moderation internals.
revoke all on public.trending_scores from authenticated, anon;
grant select (
  drop_id, creator_id, trend_score, observed_at, observation_window,
  unique_engagers_1h
) on public.trending_scores to authenticated;

-- Time-first covering indexes serve the six-hour refresh scan. Existing
-- content-first primary keys remain optimal for the interactive action paths.
create index if not exists drop_likes_trending_window_idx
  on public.drop_likes (created_at, drop_id, user_id);
create index if not exists drop_comments_trending_window_idx
  on public.drop_comments (created_at, drop_id, author_id);
create index if not exists redrops_trending_window_idx
  on public.redrops (created_at, drop_id, redropper_id);
create index if not exists saves_trending_window_idx
  on public.saves (created_at, content_id, user_id)
  where content_type = 'drop';

-- The single authoritative formula. Inputs are already organic, self-excluded,
-- identity-capped aggregates. Growth is smoothed and bounded [0.5, 3], views
-- have a small weight before reaching this function, and any score is capped to
-- prevent numeric explosions. Freshness cannot create a score when velocity or
-- unique engagement is zero.
create or replace function public.calculate_trend_score(
  p_velocity_15m double precision,
  p_velocity_1h double precision,
  p_velocity_6h double precision,
  p_previous_velocity_1h double precision,
  p_unique_engagers integer,
  p_action_count integer,
  p_report_count integer,
  p_content_age_hours double precision,
  p_suspicious boolean
)
returns double precision
language sql
immutable
parallel safe
as $$
  select case
    when p_unique_engagers <= 0
      or greatest(p_velocity_15m, 0) + greatest(p_velocity_1h, 0) <= 0
      then 0.0
    else least(1000000.0,
      (greatest(p_velocity_15m, 0) * 0.60
        + greatest(p_velocity_1h, 0) * 0.30
        + greatest(p_velocity_6h, 0) * 0.10)
      * least(3.0, greatest(0.5,
          (greatest(p_velocity_1h, 0) + 2.0)
          / (greatest(p_previous_velocity_1h, 0) + 2.0)))
      * least(1.5, 0.5 + ln(1.0 + p_unique_engagers) / ln(11.0))
      * least(1.0, p_unique_engagers / 3.0)
      * (0.20 + 0.80 * power(0.5, greatest(p_content_age_hours, 0) / 48.0))
      * greatest(0.25, least(1.0,
          p_unique_engagers * 3.0 / greatest(p_action_count, 1)))
      * power(0.20::double precision,
          greatest(p_report_count, 0)::double precision)
      * case when p_suspicious then 0.15 else 1.0 end
    )
  end;
$$;

grant execute on function public.calculate_trend_score(
  double precision, double precision, double precision, double precision,
  integer, integer, integer, double precision, boolean
) to authenticated;

create or replace function public.refresh_trending_scores(
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
  with raw_actions as (
    select dl.drop_id, dl.user_id as actor_id, 'like'::text as action_type,
      dl.created_at, 2.0::double precision as action_weight
    from public.drop_likes dl
    where dl.created_at >= p_observed_at - interval '6 hours'
    union all
    select dc.drop_id, dc.author_id, 'comment', dc.created_at, 3.0
    from public.drop_comments dc
    where dc.created_at >= p_observed_at - interval '6 hours'
    union all
    select r.drop_id, r.redropper_id, 'share', r.created_at, 5.0
    from public.redrops r
    where r.created_at >= p_observed_at - interval '6 hours'
    union all
    select dv.drop_id, dv.viewer_id, 'view', dv.created_at, 0.1
    from public.drop_views dv
    where dv.created_at >= p_observed_at - interval '6 hours'
    union all
    select s.content_id, s.user_id, 'save', s.created_at, 4.0
    from public.saves s
    where s.content_type = 'drop'
      and s.created_at >= p_observed_at - interval '6 hours'
  ), organic as (
    select ra.*
    from raw_actions ra
    join public.drops d on d.id = ra.drop_id
    where ra.actor_id <> d.author_id and d.deleted_at is null
  ), identity_buckets as (
    select drop_id, actor_id, action_type,
      date_bin(interval '15 minutes', created_at,
        timestamptz '2000-01-01 00:00:00+00') as bucket_start,
      max(created_at) as occurred_at,
      max(action_weight) as action_weight,
      case when action_type = 'comment' then least(count(*), 2)::integer
           else 1 end as capped_actions
    from organic
    group by drop_id, actor_id, action_type,
      date_bin(interval '15 minutes', created_at,
        timestamptz '2000-01-01 00:00:00+00')
  ), aggregates as (
    select drop_id,
      coalesce(sum(capped_actions * action_weight) filter (
        where occurred_at >= p_observed_at - interval '15 minutes'), 0) * 4
        as velocity_15m,
      coalesce(sum(capped_actions * action_weight) filter (
        where occurred_at >= p_observed_at - interval '1 hour'), 0)
        as velocity_1h,
      coalesce(sum(capped_actions * action_weight), 0) / 6.0 as velocity_6h,
      coalesce(sum(capped_actions * action_weight) filter (
        where occurred_at >= p_observed_at - interval '2 hours'
          and occurred_at < p_observed_at - interval '1 hour'), 0)
        as previous_velocity_1h,
      count(distinct actor_id) filter (
        where occurred_at >= p_observed_at - interval '1 hour')::integer
        as unique_engagers_1h,
      count(distinct actor_id) filter (
        where occurred_at >= p_observed_at - interval '15 minutes')::integer
        as unique_engagers_15m,
      count(distinct actor_id) filter (
        where occurred_at >= p_observed_at - interval '1 hour'
          and engager.created_at >= p_observed_at - interval '24 hours')::integer
        as new_engagers_1h,
      coalesce(sum(capped_actions) filter (
        where occurred_at >= p_observed_at - interval '1 hour'), 0)::integer
        as actions_1h,
      coalesce(sum(capped_actions) filter (
        where occurred_at >= p_observed_at - interval '15 minutes'), 0)::integer
        as actions_15m,
      coalesce(sum(capped_actions) filter (where action_type = 'like'
        and occurred_at >= p_observed_at - interval '1 hour'), 0)::integer as likes_1h,
      coalesce(sum(capped_actions) filter (where action_type = 'comment'
        and occurred_at >= p_observed_at - interval '1 hour'), 0)::integer as comments_1h,
      coalesce(sum(capped_actions) filter (where action_type = 'share'
        and occurred_at >= p_observed_at - interval '1 hour'), 0)::integer as shares_1h,
      coalesce(sum(capped_actions) filter (where action_type = 'save'
        and occurred_at >= p_observed_at - interval '1 hour'), 0)::integer as saves_1h,
      coalesce(sum(capped_actions) filter (where action_type = 'view'
        and occurred_at >= p_observed_at - interval '1 hour'), 0)::integer as views_1h
    from identity_buckets
    join public.profiles engager on engager.id = identity_buckets.actor_id
    group by drop_id
  ), report_counts as (
    select target_id as drop_id, count(*)::integer as report_count
    from public.reports
    where target_type = 'drop' and status in ('pending', 'reviewing', 'actioned')
    group by target_id
  ), candidate_ids as (
    -- Bootstrap all new content, plus any older post with organic activity in
    -- the bounded six-hour observation window. This permits genuine
    -- resurgence without scanning/scoring every historical Drop.
    select id as drop_id from public.drops
    where created_at >= p_observed_at - interval '7 days'
    union
    select drop_id from aggregates
  ), scored as (
    select d.id as drop_id, d.author_id,
      greatest(extract(epoch from (p_observed_at - d.created_at)) / 3600.0, 0)
        as age_hours,
      coalesce(a.velocity_15m, 0) as velocity_15m,
      coalesce(a.velocity_1h, 0) as velocity_1h,
      coalesce(a.velocity_6h, 0) as velocity_6h,
      coalesce(a.previous_velocity_1h, 0) as previous_velocity_1h,
      coalesce(a.unique_engagers_1h, 0) as unique_engagers_1h,
      coalesce(a.actions_1h, 0) as actions_1h,
      coalesce(a.likes_1h, 0) as likes_1h,
      coalesce(a.comments_1h, 0) as comments_1h,
      coalesce(a.shares_1h, 0) as shares_1h,
      coalesce(a.saves_1h, 0) as saves_1h,
      coalesce(a.views_1h, 0) as views_1h,
      coalesce(rc.report_count, 0) as report_count,
      ((coalesce(a.actions_15m, 0) >= 20
        and coalesce(a.unique_engagers_15m, 0) <= 2)
      or (coalesce(a.unique_engagers_1h, 0) >= 5
        and coalesce(a.new_engagers_1h, 0)::double precision
          / greatest(a.unique_engagers_1h, 1) >= 0.80)) as suspicious
    from candidate_ids candidate
    join public.drops d on d.id = candidate.drop_id
    left join aggregates a on a.drop_id = d.id
    left join report_counts rc on rc.drop_id = d.id
    where d.deleted_at is null
      and not internal.is_posting_blocked(d.author_id)
  )
  insert into public.trending_scores (
    drop_id, creator_id, trend_score, observed_at, content_age_hours,
    likes_1h, comments_1h, shares_1h, saves_1h, qualified_views_1h,
    unique_engagers_1h, weighted_velocity_15m, weighted_velocity_1h,
    previous_velocity_1h, growth_factor, report_penalty,
    manipulation_penalty, updated_at
  )
  select drop_id, author_id,
    public.calculate_trend_score(
      velocity_15m, velocity_1h, velocity_6h, previous_velocity_1h,
      unique_engagers_1h, actions_1h, report_count, age_hours, suspicious),
    p_observed_at, age_hours, likes_1h, comments_1h, shares_1h, saves_1h,
    views_1h, unique_engagers_1h, velocity_15m, velocity_1h,
    previous_velocity_1h,
    least(3.0, greatest(0.5,
      (velocity_1h + 2.0) / (previous_velocity_1h + 2.0))),
    power(0.20::double precision, report_count::double precision),
    case when suspicious then 0.15 else 1.0 end,
    clock_timestamp()
  from scored
  on conflict (drop_id) do update set
    creator_id = excluded.creator_id,
    trend_score = excluded.trend_score,
    observed_at = excluded.observed_at,
    content_age_hours = excluded.content_age_hours,
    likes_1h = excluded.likes_1h,
    comments_1h = excluded.comments_1h,
    shares_1h = excluded.shares_1h,
    saves_1h = excluded.saves_1h,
    qualified_views_1h = excluded.qualified_views_1h,
    unique_engagers_1h = excluded.unique_engagers_1h,
    weighted_velocity_15m = excluded.weighted_velocity_15m,
    weighted_velocity_1h = excluded.weighted_velocity_1h,
    previous_velocity_1h = excluded.previous_velocity_1h,
    growth_factor = excluded.growth_factor,
    report_penalty = excluded.report_penalty,
    manipulation_penalty = excluded.manipulation_penalty,
    updated_at = excluded.updated_at;
  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;

revoke all on function public.refresh_trending_scores(timestamptz) from public;
revoke all on function public.refresh_trending_scores(timestamptz)
  from authenticated, anon;

-- Phase 3-ready read contract. The function exposes aggregate diagnostics but
-- never user identities or formula internals. RLS on home_feed still handles
-- blocks/privacy; per-viewer Hide remains a hard exclusion here.
create or replace function public.get_trending_candidates(p_limit integer default 30)
returns table (
  row_data jsonb,
  trend_score double precision,
  observed_at timestamptz,
  observation_window interval,
  unique_engagers integer
)
language sql
stable
as $$
  select to_jsonb(hf.*), ts.trend_score, ts.observed_at,
    ts.observation_window, ts.unique_engagers_1h
  from public.trending_scores ts
  join public.drops d on d.id = ts.drop_id and d.deleted_at is null
  join public.home_feed hf
    on hf.id = ts.drop_id and hf.content_type = 'drop' and hf.redrop_id is null
  where ts.trend_score > 0
    and not exists (
      select 1 from public.feed_signals fs
      where fs.user_id = auth.uid() and fs.signal_type in ('hide', 'not_interested')
        and fs.target_id = ts.drop_id
    )
    and not internal.is_posting_blocked(ts.creator_id)
  order by ts.trend_score desc, ts.observed_at desc, ts.drop_id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

grant execute on function public.get_trending_candidates(integer) to authenticated;

-- The Wynos Score ranking function (WYNOS Unified Home Feed Algorithm
-- V1.0) -- backend-computed per the Product spec's explicit "Client ->
-- Request Feed / Backend -> Retrieve Candidates / Backend -> Calculate
-- Ranking Score / Backend -> Return Ranked Feed" flow, replacing
-- WYN-018's client-side rankingScore()/fetchRankedFeed() sort for
-- Home's "สำหรับคุณ" tab specifically. WYN-018's rankingScore() itself
-- (still used by DropFeedScreen's own "For You" tab), and
-- fetchTopContent() remains cumulative and intentionally separate. Phase 2
-- replaces fetchTrending() with the precomputed velocity contract above.
--
-- Returns the SAME bounded top-200-by-recency candidate window
-- WYN-018 already established (same trade-off, same reasoning: still
-- a small enough catalog that "the 200 most recent posts, re-ranked"
-- covers what a personalized feed needs -- see wyn-018-home-feed-
-- ranking.md), now scored server-side and handed back already sorted
-- by wynos_score descending (ties broken by created_at then id, both
-- descending, so the ordering -- and therefore which page a given
-- item falls on when the caller slices pages out of it -- is fully
-- deterministic across repeated calls against the same underlying
-- data, which is what makes duplicate-free pagination possible without
-- a stateful server-side cursor). The caller
-- (HomeRepository.fetchRankedFeed) slices pages out of this same full
-- ordered list and applies Feed Diversity re-ordering client-side --
-- see feed_diversity.dart's own doc comment for why that one step, and
-- only that step, stays a pure, unit-tested Dart function instead of
-- more SQL: it's a cheap re-sort of an already-scored ~200-row list
-- already sitting in memory, not the "heavy" data-dependent
-- computation the Product spec's Performance section is actually
-- concerned about (candidate retrieval, personalization signal
-- aggregation, engagement/trending scoring -- all of which stay here,
-- server-side).
--
-- `row_data` carries every public.home_feed column as-is (via
-- to_jsonb, not a hand-typed 25-column RETURNS TABLE list) specifically
-- so HomeFeedItem.fromMap can keep reading it exactly like it already
-- reads a plain home_feed row -- HomeRepository never needed a new
-- HomeFeedItem field for this task. wynos_score/is_following/
-- is_discovery ride alongside as their own typed columns purely for
-- the Dart diversity pass to read before being discarded (never stored
-- on HomeFeedItem itself). Every intermediate column this function
-- computes along the way (age_hours, affinity_raw, save_count, ...)
-- rides along inside row_data too, harmlessly ignored by fromMap.
--
-- Not SECURITY DEFINER -- runs as the calling user on purpose, so
-- every visibility rule public.home_feed/drop_views/saves/
-- feed_signals' own RLS already enforces (mutes, blocks, "only see
-- your own hide list") applies automatically, the same way it already
-- does for every other PostgREST query this app makes. The one
-- exception (posting-blocked authors, which needs moderation_actions
-- access ordinary users don't have) is delegated to the existing
-- authors_posting_blocked() SECURITY DEFINER wrapper (WYN-041) rather
-- than reimplemented here.
create or replace function public.get_wynos_ranked_feed()
returns table (
  row_data jsonb,
  wynos_score double precision,
  is_following boolean,
  is_discovery boolean
)
language sql
stable
as $$
  with recent as (
    select hf.*
    from public.home_feed hf
    where not exists (
      select 1 from public.feed_signals fs
      where fs.user_id = auth.uid()
        and fs.signal_type = 'hide'
        and fs.target_id = hf.id
    )
    order by hf.created_at desc
    limit 200
  ),
  candidates as (
    select r.*,
      greatest(extract(epoch from (now() - r.created_at)) / 3600.0, 0.0) as age_hours
    from recent r
    where r.author_id not in (
      select author_id from public.authors_posting_blocked(
        (select coalesce(array_agg(distinct author_id), array[]::uuid[]) from recent)
      )
    )
  ),
  -- Every signal the *current viewer* has ever produced toward each
  -- candidate's author, unioned into one (author_id, weight,
  -- created_at) stream so author_affinity below can sum them with a
  -- single group by -- mirrors engagementScore()'s own "one source of
  -- truth, not inlined per-caller" reasoning (WYN-041), just for
  -- personalization instead of public engagement. Weights (Like=2,
  -- Comment=3, Save=4, View=1, Profile Visit=2) are Product's own
  -- starting numbers, same "no real traffic data yet, adjust freely"
  -- caveat as engagementScore's _viewWeight -- unlike the 6 top-level
  -- Wynos Score weights, these aren't in feed_ranking_config since
  -- they're an internal detail of computing *one* of those 6 factors
  -- (Personalized Interest), not something the Product spec calls out
  -- as independently tunable.
  my_interactions as (
    select d.author_id, 2.0::double precision as weight, dl.created_at
    from public.drop_likes dl
    join public.drops d on d.id = dl.drop_id
    where dl.user_id = auth.uid()
    union all
    select p.author_id, 2.0::double precision, pl.created_at
    from public.pop_likes pl
    join public.pops p on p.id = pl.pop_id
    where pl.user_id = auth.uid()
    union all
    select d.author_id, 3.0::double precision, dc.created_at
    from public.drop_comments dc
    join public.drops d on d.id = dc.drop_id
    where dc.author_id = auth.uid()
    union all
    select p.author_id, 3.0::double precision, pc.created_at
    from public.pop_comments pc
    join public.pops p on p.id = pc.pop_id
    where pc.author_id = auth.uid()
    union all
    select d.author_id, 4.0::double precision, s.created_at
    from public.saves s
    join public.drops d on d.id = s.content_id
    where s.user_id = auth.uid() and s.content_type = 'drop'
    union all
    select p.author_id, 4.0::double precision, s.created_at
    from public.saves s
    join public.pops p on p.id = s.content_id
    where s.user_id = auth.uid() and s.content_type = 'pop'
    union all
    select d.author_id, 1.0::double precision, dv.created_at
    from public.drop_views dv
    join public.drops d on d.id = dv.drop_id
    where dv.viewer_id = auth.uid()
    union all
    select fs.target_id, 2.0::double precision, fs.created_at
    from public.feed_signals fs
    where fs.user_id = auth.uid() and fs.signal_type = 'profile_visit'
  ),
  -- 30-day lookback -- old interactions shouldn't keep boosting an
  -- author forever (a Product/Design decision this task's own scope
  -- didn't need to litigate further; a real recency-weighted decay on
  -- top of this window is a natural future refinement, not required
  -- for a V1 rule-based system).
  author_affinity as (
    select author_id, sum(weight) as affinity_raw
    from my_interactions
    where created_at > now() - interval '30 days'
    group by author_id
  ),
  scored as (
    select
      c.*,
      coalesce(aa.affinity_raw, 0.0) as affinity_raw,
      (f.follower_id is not null) as is_following_flag,
      p.created_at as author_created_at,
      coalesce(ts.trend_score, 0.0) as precomputed_trend_score,
      exists (
        select 1
        from public.club_members mine
        join public.club_members theirs on theirs.club_id = mine.club_id
        where mine.user_id = auth.uid() and mine.status = 'approved'
          and theirs.user_id = c.author_id and theirs.status = 'approved'
      ) as is_club_flag,
      public.content_save_count(c.id) as save_count
    from candidates c
    left join author_affinity aa on aa.author_id = c.author_id
    left join public.follows f
      on f.follower_id = auth.uid() and f.following_id = c.author_id
    left join public.trending_scores ts on ts.drop_id = c.id
    join public.profiles p on p.id = c.author_id
  ),
  -- Same like*2 + comment*3 + view*0.1 shape as engagementScore()
  -- (WYN-041), plus save*4 (a Save is a stronger intent signal than a
  -- Like or Comment -- deliberate action to keep something, per
  -- Product's "Save" signal) which the client-side engagementScore()
  -- never had access to (saves' own RLS made a true total uncountable
  -- from the client -- see content_save_count()'s own comment).
  scored_engagement as (
    select
      s.*,
      (s.like_count * 2 + s.comment_count * 3 + s.save_count * 4
        + case when s.content_type = 'drop' then s.view_count * 0.1 else 0 end
      ) as engagement_raw
    from scored s
  ),
  final as (
    select
      se.*,
      -- Trending = engagement earned *per hour of the post's life* --
      -- Product's own example (500 Likes in 30 minutes beating 2,000
      -- Likes over 3 days): a plain engagement sum can't tell those
      -- apart, dividing by age can. Floors the denominator at 0.5h so
      -- a just-posted item with any early engagement doesn't produce
      -- an inflated/unstable velocity from dividing by a near-zero age.
      -- Phase 2: authoritative Trending is the precomputed velocity score.
      -- A stale/missing refresh contributes zero and lets Phase 1 fallback
      -- allocation fill the slot; request-time raw aggregation is forbidden.
      se.precomputed_trend_score as trending_velocity,
      -- A candidate counts as "Discovery" when the viewer neither
      -- follows this author nor has any recorded affinity toward them
      -- at all -- i.e. a genuinely new-to-you creator, not just "an
      -- author you follow less than others."
      (not se.is_following_flag and se.affinity_raw = 0) as is_discovery_flag,
      -- Linear 7-day decay, identical shape to WYN-018's own
      -- recencyScore, just rescaled to a 0-100 percentage (168 hours
      -- = 7 days = the same window rankingScore() already uses) so it
      -- combines with the other 0-100-scaled factors below on equal
      -- footing.
      least(greatest(168.0 - se.age_hours, 0.0), 168.0) / 168.0 * 100 as recency_pct,
      -- Personalized Interest, Engagement, and Trending are all
      -- unbounded raw magnitudes (a single viral post could be 100x
      -- any other candidate's engagement) -- percent_rank() converts
      -- each to "this candidate's relative standing within *this*
      -- batch" (0-100), which is naturally comparable to the already-
      -- bounded Following/Recency/Discovery terms and, unlike min-max
      -- normalization, isn't skewed by one extreme outlier.
      percent_rank() over (order by se.affinity_raw) * 100 as pr_interest,
      percent_rank() over (order by se.engagement_raw) * 100 as pr_engagement,
      percent_rank() over (
        order by se.precomputed_trend_score
      ) * 100 as pr_trending
    from scored_engagement se
  ),
  weights as (
    select
      max(weight) filter (where key = 'personalized_interest') as w_personalized,
      max(weight) filter (where key = 'following') as w_following,
      max(weight) filter (where key = 'engagement') as w_engagement,
      max(weight) filter (where key = 'trending') as w_trending,
      max(weight) filter (where key = 'recency') as w_recency,
      max(weight) filter (where key = 'discovery') as w_discovery
    from public.feed_ranking_config
  )
  -- coalesce(..., <Founder's own starting weight>) covers the
  -- pathological case of feed_ranking_config having been emptied out
  -- entirely -- the feed degrades to the documented V1.0 defaults
  -- rather than every wynos_score collapsing to null/0 and the whole
  -- ranked feed silently going empty-looking.
  select
    (to_jsonb(final.*) - 'precomputed_trend_score') || jsonb_build_object(
      'feed_is_trending', final.precomputed_trend_score > 0,
      'feed_is_latest', final.age_hours <= 24,
      'feed_is_club', final.is_club_flag,
      'feed_is_new_creator',
        (final.author_created_at >= now() - interval '30 days'
          or (final.age_hours <= 24 and final.engagement_raw <= 10)),
      'feed_topic', nullif(lower(substring(final.caption from '#([[:alnum:]_]+)')), '')
    ) as row_data,
    (
      coalesce(weights.w_personalized, 0.35) * final.pr_interest
      + coalesce(weights.w_following, 0.25) * (case when final.is_following_flag then 100.0 else 0.0 end)
      + coalesce(weights.w_engagement, 0.15) * final.pr_engagement
      + coalesce(weights.w_trending, 0.10) * final.pr_trending
      + coalesce(weights.w_recency, 0.10) * final.recency_pct
      + coalesce(weights.w_discovery, 0.05) * (case when final.is_discovery_flag then 100.0 else 0.0 end)
    ) as wynos_score,
    final.is_following_flag as is_following,
    final.is_discovery_flag as is_discovery
  from final, weights
  order by wynos_score desc, final.created_at desc, final.id desc;
$$;

grant execute on function public.get_wynos_ranked_feed() to authenticated;
