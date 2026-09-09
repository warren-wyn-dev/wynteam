-- WYN-143 / Phase 5: Cold Start & New User Feed
-- Additive/idempotent migration. Apply after WYN-142. No user data is reset.

-- One authoritative, bounded maturity calculation. Account age and feed
-- impressions are intentionally absent: confidence represents meaningful
-- evidence, not how long an account has existed or how often WYN distributed
-- content. The curve starts adapting after a few actions but needs diverse
-- evidence before Phase 4 personalization becomes dominant.
create or replace function public.get_my_personalization_maturity()
returns table (
  maturity_state text,
  confidence double precision,
  evidence_count bigint,
  follow_count bigint,
  topic_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with affinity_stats as (
    select
      coalesce(sum(least(signal_count, 20)), 0)::bigint as evidence_count,
      count(*) filter (
        where dimension_type = 'topic' and signal_count > 0
      )::bigint as topic_count
    from public.user_affinities
    where user_id = auth.uid()
  ), follow_stats as (
    select count(*)::bigint as follow_count
    from public.follows
    where follower_id = auth.uid()
  ), bounded as (
    select a.evidence_count, f.follow_count, a.topic_count,
      least(1.0,
        least(a.evidence_count, 40)::double precision / 40.0 * 0.70
        + least(f.follow_count, 5)::double precision / 5.0 * 0.20
        + least(a.topic_count, 5)::double precision / 5.0 * 0.10
      ) as confidence
    from affinity_stats a cross join follow_stats f
  )
  select case
      when evidence_count = 0 and follow_count = 0 then 'zero_history'
      when confidence < 0.25 then 'sparse'
      when confidence < 0.70 then 'learning'
      else 'personalized'
    end,
    confidence, evidence_count, follow_count, topic_count
  from bounded
  where auth.uid() is not null;
$$;

revoke all on function public.get_my_personalization_maturity() from public, anon;
grant execute on function public.get_my_personalization_maturity() to authenticated;

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
      greatest(extract(epoch from (now() - r.created_at)) / 3600.0, 0.0) as age_hours,
      nullif(lower(substring(r.caption from '#([[:alnum:]_]+)')), '')
        as candidate_topic,
      case when r.content_type = 'pop' then 'video'
           when r.redrop_id is not null and r.quote_text is not null then 'quote'
           when r.poll_id is not null then 'poll'
           when r.image_url is not null then 'image' else 'text' end
        as candidate_content_type
    from recent r
    where r.author_id not in (
      select author_id from public.authors_posting_blocked(
        (select coalesce(array_agg(distinct author_id), array[]::uuid[]) from recent)
      )
    )
  ),
  -- Precomputed affinity lookup replaces the former request-time scan across
  -- every historical Like/Comment/Save/View. Three indexed joins cover the
  -- whole 200-candidate batch without per-post network/database queries.
  effective_affinities as (
    select dimension_type, dimension_key, effective_score
    from public.my_effective_affinities
  ),
  maturity as (
    select * from public.get_my_personalization_maturity()
  ),
  scored as (
    select
      c.*,
      (coalesce(topic_aff.effective_score, 0.0) * 0.45
        + coalesce(creator_aff.effective_score, 0.0) * 0.40
        + coalesce(type_aff.effective_score, 0.0) * 0.15) as affinity_raw,
      coalesce(topic_aff.effective_score, 0.0) as topic_affinity,
      coalesce(creator_aff.effective_score, 0.0) as creator_affinity,
      coalesce(type_aff.effective_score, 0.0) as content_type_affinity,
      (f.follower_id is not null) as is_following_flag,
      p.created_at as author_created_at,
      coalesce(ts.trend_score, 0.0) as precomputed_trend_score,
      -- Top100 is quality evidence only: rank is mapped to a bounded 0..10
      -- bonus. Its raw formula is never duplicated here and it cannot replace
      -- Recommended or reward impressions/distribution.
      coalesce(greatest(0.0, (101 - t100.current_rank) / 10.0), 0.0)
        as top100_quality_bonus,
      exists (
        select 1
        from public.club_members mine
        join public.club_members theirs on theirs.club_id = mine.club_id
        where mine.user_id = auth.uid() and mine.status = 'approved'
          and theirs.user_id = c.author_id and theirs.status = 'approved'
      ) as is_club_flag,
      public.content_save_count(c.id) as save_count
    from candidates c
    left join effective_affinities creator_aff
      on creator_aff.dimension_type = 'creator'
      and creator_aff.dimension_key = c.author_id::text
    left join effective_affinities topic_aff
      on topic_aff.dimension_type = 'topic'
      and topic_aff.dimension_key = c.candidate_topic
    left join effective_affinities type_aff
      on type_aff.dimension_type = 'content_type'
      and type_aff.dimension_key = c.candidate_content_type
    left join public.follows f
      on f.follower_id = auth.uid() and f.following_id = c.author_id
    left join public.trending_scores ts on ts.drop_id = c.id
    left join public.top100_scores t100 on t100.drop_id = c.id
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
  ),
  base_ranked as (
    select final.*,
      maturity.maturity_state,
      maturity.confidence as personalization_confidence,
      (coalesce(weights.w_personalized, 0.35) * final.pr_interest
        + coalesce(weights.w_following, 0.25)
          * (case when final.is_following_flag then 100.0 else 0.0 end)
        + coalesce(weights.w_engagement, 0.15) * final.pr_engagement
        + coalesce(weights.w_trending, 0.10) * final.pr_trending
        + coalesce(weights.w_recency, 0.10) * final.recency_pct
        + coalesce(weights.w_discovery, 0.05)
          * (case when final.is_discovery_flag then 100.0 else 0.0 end)
      ) as base_score,
      (coalesce(weights.w_following, 0.25)
          * (case when final.is_following_flag then 100.0 else 0.0 end)
        + coalesce(weights.w_engagement, 0.15) * final.pr_engagement
        + coalesce(weights.w_trending, 0.10) * final.pr_trending
        + coalesce(weights.w_recency, 0.10) * final.recency_pct
        + coalesce(weights.w_discovery, 0.05)
          * (case when final.is_discovery_flag then 100.0 else 0.0 end)
      ) as nonpersonal_score
    from final, weights, maturity
  )
  -- coalesce(..., <Founder's own starting weight>) covers the
  -- pathological case of feed_ranking_config having been emptied out
  -- entirely -- the feed degrades to the documented V1.0 defaults
  -- rather than every wynos_score collapsing to null/0 and the whole
  -- ranked feed silently going empty-looking.
  select
    (to_jsonb(base_ranked.*)
      - 'precomputed_trend_score' - 'affinity_raw' - 'topic_affinity'
      - 'creator_affinity' - 'content_type_affinity' - 'base_score'
      - 'nonpersonal_score' - 'personalization_confidence'
      - 'top100_quality_bonus' - 'maturity_state')
    || jsonb_build_object(
      'feed_is_trending', base_ranked.precomputed_trend_score > 0,
      'feed_is_latest', base_ranked.age_hours <= 24,
      'feed_is_club', base_ranked.is_club_flag,
      'feed_is_new_creator',
        (base_ranked.author_created_at >= now() - interval '30 days'
          or (base_ranked.age_hours <= 24 and base_ranked.engagement_raw <= 10)),
      'feed_topic', base_ranked.candidate_topic,
      'feed_maturity_state', base_ranked.maturity_state,
      'feed_source_scores', jsonb_build_object(
        'following', base_ranked.nonpersonal_score
          + base_ranked.personalization_confidence * (
            base_ranked.base_score - base_ranked.nonpersonal_score
            + base_ranked.creator_affinity * 12
            + base_ranked.topic_affinity * 6
            + base_ranked.content_type_affinity * 2),
        'recommended', base_ranked.nonpersonal_score
          + base_ranked.top100_quality_bonus
          + (case when base_ranked.age_hours <= 24 then 5 else 0 end)
          + base_ranked.personalization_confidence * (
            base_ranked.base_score - base_ranked.nonpersonal_score
            + base_ranked.affinity_raw * 20),
        'trending', base_ranked.nonpersonal_score
          + base_ranked.personalization_confidence * base_ranked.affinity_raw * 5,
        'latest', base_ranked.nonpersonal_score
          + (case when base_ranked.age_hours <= 24 then 5 else 0 end)
          + base_ranked.personalization_confidence * base_ranked.affinity_raw * 3,
        'club', base_ranked.nonpersonal_score
          + base_ranked.personalization_confidence * (
            base_ranked.base_score - base_ranked.nonpersonal_score
            + base_ranked.creator_affinity * 8
            + base_ranked.topic_affinity * 5),
        'new_creator', base_ranked.nonpersonal_score
          + (case when base_ranked.age_hours <= 24 then 5 else 0 end)
          + base_ranked.personalization_confidence * (
            base_ranked.topic_affinity * 10
            + base_ranked.content_type_affinity * 4),
        'exploration', base_ranked.nonpersonal_score
          + (1 - base_ranked.personalization_confidence)
            * (case when abs(base_ranked.topic_affinity) < 0.2 then 5 else 0 end)
          + base_ranked.personalization_confidence
            * (1 - abs(base_ranked.topic_affinity)) * 5
      ),
      'feed_reason_code', case
        when base_ranked.maturity_state = 'zero_history'
          and base_ranked.precomputed_trend_score > 0 then 'popular_now'
        when base_ranked.maturity_state = 'zero_history'
          and base_ranked.age_hours <= 24 then 'fresh_content'
        when base_ranked.maturity_state = 'zero_history'
          and base_ranked.top100_quality_bonus > 0 then 'high_quality_content'
        when base_ranked.maturity_state = 'zero_history' then 'broad_discovery'
        when base_ranked.topic_affinity >= greatest(
          base_ranked.creator_affinity, base_ranked.content_type_affinity, 0.2)
          then 'interested_in_topic'
        when base_ranked.creator_affinity >= greatest(
          base_ranked.content_type_affinity, 0.2) then 'often_engages_creator'
        when base_ranked.content_type_affinity >= 0.2 then 'preferred_content_type'
        else 'general_quality' end
    ) as row_data,
    base_ranked.base_score as wynos_score,
    base_ranked.is_following_flag as is_following,
    base_ranked.is_discovery_flag as is_discovery
  from base_ranked
  order by wynos_score desc, base_ranked.created_at desc, base_ranked.id desc;
$$;

grant execute on function public.get_wynos_ranked_feed() to authenticated;
