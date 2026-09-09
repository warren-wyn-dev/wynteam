-- WYN-146 / Phases 8-10: WYNOS Feed Algorithm v1 Production Candidate
-- Additive, non-destructive, and no traffic/experiment activation.

-- WYNOS Feed Algorithm v1: Observability, Similarity & Hardening (Phases 8-10)
-- ============================================================
create table if not exists public.feed_algorithm_config (
  algorithm_version integer primary key check(algorithm_version=1),
  candidate_limit integer not null check(candidate_limit between 50 and 500),
  similarity_neighbor_limit integer not null check(similarity_neighbor_limit between 1 and 50),
  similarity_candidate_limit integer not null check(similarity_candidate_limit between 1 and 100),
  similarity_strength double precision not null check(similarity_strength between 0 and 0.25),
  updated_at timestamptz not null default now()
);
insert into public.feed_algorithm_config values(1,200,20,50,0.10,now())
on conflict(algorithm_version) do nothing;
alter table public.feed_algorithm_config enable row level security;
revoke all on public.feed_algorithm_config from authenticated,anon;

create table if not exists public.feed_impressions (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  event_key text not null, session_key text not null check(length(session_key) between 8 and 128),
  content_id uuid not null, feed_source text not null check(feed_source in ('following','recommended','trending','latest','club','new_creator','exploration')),
  rank_position integer not null check(rank_position between 1 and 200),
  maturity_state text not null check(maturity_state in ('zero_history','sparse','learning','personalized')),
  content_type text not null, topic text, reason_code text, candidate_origin text not null default 'direct',
  algorithm_version integer not null default 1 check(algorithm_version=1),
  latency_ms integer check(latency_ms between 0 and 120000), fallback_used boolean not null default false,
  experiment_assignments text[] not null default array[]::text[], created_at timestamptz not null default now(),
  unique(user_id,event_key)
);
create index if not exists feed_impressions_rollup_idx on public.feed_impressions(created_at,feed_source,maturity_state);
create index if not exists feed_impressions_attribution_idx on public.feed_impressions(user_id,content_id,created_at desc);
alter table public.feed_impressions enable row level security;
revoke all on public.feed_impressions from authenticated,anon;

create table if not exists public.feed_observability_rollups (
  bucket_start timestamptz not null, window_kind text not null check(window_kind in ('hour','day')),
  feed_source text not null, maturity_state text not null, candidate_origin text not null,
  impressions bigint not null, unique_viewers bigint not null, unique_creators bigint not null,
  unique_topics bigint not null, avg_rank double precision, p50_latency_ms double precision,
  p95_latency_ms double precision,p99_latency_ms double precision,fallback_count bigint not null,
  qualified_views bigint not null,long_views bigint not null,fast_skips bigint not null,likes bigint not null,
  comments bigint not null,saves bigint not null,shares bigint not null,profile_visits bigint not null,
  follows bigint not null,hides bigint not null,not_interested bigint not null,reports bigint not null,
  algorithm_version integer not null default 1,updated_at timestamptz not null default now(),
  primary key(bucket_start,window_kind,feed_source,maturity_state,candidate_origin,algorithm_version)
);
alter table public.feed_observability_rollups enable row level security;
revoke all on public.feed_observability_rollups from authenticated,anon;

create table if not exists public.topic_similarities(
 source_topic text not null,target_topic text not null,similarity_score double precision not null check(similarity_score between 0 and 1),
 support_count integer not null,confidence double precision not null check(confidence between 0 and 1),neighbor_rank integer not null check(neighbor_rank between 1 and 20),computed_at timestamptz not null,
 primary key(source_topic,target_topic));
create table if not exists public.creator_similarities(
 source_creator uuid not null references public.profiles(id) on delete cascade,target_creator uuid not null references public.profiles(id) on delete cascade,
 similarity_score double precision not null check(similarity_score between 0 and 1),support_count integer not null,
 confidence double precision not null check(confidence between 0 and 1),neighbor_rank integer not null check(neighbor_rank between 1 and 20),computed_at timestamptz not null,
 primary key(source_creator,target_creator));
create table if not exists public.content_similarities(
 source_content uuid not null references public.drops(id) on delete cascade,target_content uuid not null references public.drops(id) on delete cascade,
 similarity_score double precision not null check(similarity_score between 0 and 1),support_count integer not null,
 confidence double precision not null check(confidence between 0 and 1),neighbor_rank integer not null check(neighbor_rank between 1 and 20),computed_at timestamptz not null,
 primary key(source_content,target_content));
create index if not exists topic_similarities_lookup_idx on public.topic_similarities(source_topic,neighbor_rank,computed_at desc);
create index if not exists creator_similarities_lookup_idx on public.creator_similarities(source_creator,neighbor_rank,computed_at desc);
create index if not exists content_similarities_lookup_idx on public.content_similarities(source_content,neighbor_rank,computed_at desc);
alter table public.topic_similarities enable row level security; alter table public.creator_similarities enable row level security; alter table public.content_similarities enable row level security;
revoke all on public.topic_similarities,public.creator_similarities,public.content_similarities from authenticated,anon;

create or replace function public.refresh_feed_similarities(p_computed_at timestamptz default clock_timestamp()) returns integer
language plpgsql security definer set search_path=public as $$ declare v_rows integer:=0; v_part integer;
begin
 with positive as (select user_id,dimension_key topic,least(signal_count,10) weight from public.user_affinities where dimension_type='topic' and recent_score>0),
 pairs as (select a.topic source,b.topic target,count(distinct a.user_id)::int support,sum(least(a.weight,b.weight)) score from positive a join positive b on a.user_id=b.user_id and a.topic<>b.topic group by a.topic,b.topic),
 norms as (select *,score/sqrt(sum(score) over(partition by source)*sum(score) over(partition by target)) raw from pairs where support>=2),
 ranked as (select *,row_number() over(partition by source order by raw*support/(support+5.0) desc,target) rn from norms)
 insert into public.topic_similarities select source,target,least(1.0,raw*support/(support+5.0)),support,least(1.0,support/10.0),rn,p_computed_at from ranked where rn<=20
 on conflict(source_topic,target_topic) do update set similarity_score=excluded.similarity_score,support_count=excluded.support_count,confidence=excluded.confidence,neighbor_rank=excluded.neighbor_rank,computed_at=excluded.computed_at;
 get diagnostics v_part=row_count; v_rows:=v_rows+v_part;
 with positive as (select user_id,dimension_key::uuid creator,least(signal_count,10) weight from public.user_affinities where dimension_type='creator' and recent_score>0),
 pairs as (select a.creator source,b.creator target,count(distinct a.user_id)::int support,sum(least(a.weight,b.weight)) score from positive a join positive b on a.user_id=b.user_id and a.creator<>b.creator group by a.creator,b.creator),
 norms as (select *,score/sqrt(sum(score) over(partition by source)*sum(score) over(partition by target)) raw from pairs where support>=2),
 ranked as (select *,row_number() over(partition by source order by raw*support/(support+5.0) desc,target) rn from norms)
 insert into public.creator_similarities select source,target,least(1.0,raw*support/(support+5.0)),support,least(1.0,support/10.0),rn,p_computed_at from ranked where rn<=20
 on conflict(source_creator,target_creator) do update set similarity_score=excluded.similarity_score,support_count=excluded.support_count,confidence=excluded.confidence,neighbor_rank=excluded.neighbor_rank,computed_at=excluded.computed_at;
 get diagnostics v_part=row_count; v_rows:=v_rows+v_part;
 with tagged as (select id,lower(substring(caption from '#([[:alnum:]_]+)')) topic from public.drops where deleted_at is null and created_at>=p_computed_at-interval '30 days'),
 ranked as (select a.id source,b.id target,row_number() over(partition by a.id order by b.created_at desc,b.id) rn from tagged a join public.drops b on lower(substring(b.caption from '#([[:alnum:]_]+)'))=a.topic and b.id<>a.id where a.topic is not null and b.deleted_at is null)
 insert into public.content_similarities select source,target,0.5,2,0.2,rn,p_computed_at from ranked where rn<=20
 on conflict(source_content,target_content) do update set similarity_score=excluded.similarity_score,support_count=excluded.support_count,confidence=excluded.confidence,neighbor_rank=excluded.neighbor_rank,computed_at=excluded.computed_at;
 get diagnostics v_part=row_count; return v_rows+v_part;
end $$;
revoke all on function public.refresh_feed_similarities(timestamptz) from public,authenticated,anon;

create or replace function internal.my_similarity_candidates() returns table(drop_id uuid,similarity_score double precision,candidate_origin text)
language sql stable security definer set search_path=public as $$
 with experiment as (select public.resolve_home_feed_experiments('home') config),
 cfg as (select c.*,
   coalesce((e.config->>'similarity.enabled')::boolean,true) similarity_enabled,
   coalesce((e.config->>'similarity.strength')::double precision,c.similarity_strength) effective_similarity_strength
   from public.feed_algorithm_config c cross join experiment e where algorithm_version=1),
 creator_edges as (select d.id,cs.similarity_score,'related_creator'::text origin from public.my_effective_affinities a join public.creator_similarities cs on a.dimension_type='creator' and cs.source_creator=a.dimension_key::uuid join public.drops d on d.author_id=cs.target_creator cross join cfg where cfg.similarity_enabled and a.effective_score>0 and cs.neighbor_rank<=cfg.similarity_neighbor_limit and cs.computed_at>=now()-interval '48 hours' and d.deleted_at is null),
 topic_edges as (select d.id,ts.similarity_score,'related_topic'::text origin from public.my_effective_affinities a join public.topic_similarities ts on a.dimension_type='topic' and ts.source_topic=a.dimension_key join public.drops d on lower(substring(d.caption from '#([[:alnum:]_]+)'))=ts.target_topic cross join cfg where cfg.similarity_enabled and a.effective_score>0 and ts.neighbor_rank<=cfg.similarity_neighbor_limit and ts.computed_at>=now()-interval '48 hours' and d.deleted_at is null),
 combined as (select * from creator_edges union all select * from topic_edges), ranked as (select id,max(similarity_score) score,min(origin) origin from combined group by id order by score desc,id limit (select similarity_candidate_limit from cfg))
 select id,score*(select effective_similarity_strength from cfg),origin from ranked;
$$;
revoke all on function internal.my_similarity_candidates() from public; grant execute on function internal.my_similarity_candidates() to authenticated;

create or replace function public.record_feed_impressions(p_session_key text,p_items jsonb,p_latency_ms integer default null) returns integer
language plpgsql security definer set search_path=public as $$ declare v_count integer;
begin
 if auth.uid() is null or length(p_session_key) not between 8 and 128 or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)>200 then return 0; end if;
 insert into public.feed_impressions(user_id,event_key,session_key,content_id,feed_source,rank_position,maturity_state,content_type,topic,reason_code,candidate_origin,latency_ms,fallback_used,experiment_assignments)
 select auth.uid(),p_session_key||':'||left(coalesce(x->>'renderKey',x->>'contentId'),100),p_session_key,(x->>'contentId')::uuid,x->>'feedSource',(x->>'rankPosition')::int,
 coalesce((select maturity_state from public.get_my_personalization_maturity()),'zero_history'),coalesce(x->>'contentType','drop'),left(x->>'topic',80),left(x->>'reasonCode',80),coalesce(left(x->>'candidateOrigin',40),'direct'),p_latency_ms,coalesce((x->>'fallbackUsed')::boolean,false),array(select jsonb_array_elements_text(coalesce(x->'experiments','[]')) limit 8)
 from jsonb_array_elements(p_items) x
 where x->>'feedSource' in ('following','recommended','trending','latest','club','new_creator','exploration') and (x->>'rankPosition')::int between 1 and 200
 on conflict(user_id,event_key) do nothing;
 get diagnostics v_count=row_count; return v_count;
exception when others then return 0; end $$;
revoke all on function public.record_feed_impressions(text,jsonb,integer) from public,anon; grant execute on function public.record_feed_impressions(text,jsonb,integer) to authenticated;

create or replace function public.admin_feed_algorithm_dashboard(p_hours integer default 24)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_result jsonb;
begin
 if coalesce(internal.current_platform_role(),'') not in ('admin','moderator') then raise exception 'Not authorized'; end if;
 if p_hours not in (1,24,168,720) then raise exception 'Invalid time window'; end if;
 with scoped as (select * from public.feed_impressions where created_at>=now()-make_interval(hours=>p_hours)),
 source_metrics as (select feed_source,count(*) impressions,count(distinct user_id) unique_viewers,
   count(distinct content_id) unique_content,count(distinct topic) unique_topics,avg(rank_position) avg_rank,
   percentile_cont(.5) within group(order by latency_ms) p50_latency_ms,
   percentile_cont(.95) within group(order by latency_ms) p95_latency_ms,
   percentile_cont(.99) within group(order by latency_ms) p99_latency_ms,
   count(*) filter(where fallback_used) fallback_count,count(*) filter(where candidate_origin<>'direct') similarity_impressions
   from scoped group by feed_source),
 maturity as (select maturity_state,count(*) impressions,count(distinct user_id) unique_viewers from scoped group by maturity_state),
 trend_diag as (select count(*) candidate_count,avg(content_age_hours) avg_age_hours,avg(unique_engagers_1h) avg_unique_engagers,max(extract(epoch from(now()-updated_at))) max_staleness_seconds from public.trending_scores),
 top_diag as (select count(*) candidate_count,count(distinct creator_id) creators,max(extract(epoch from(now()-updated_at))) max_staleness_seconds from public.top100_scores),
 overlap as (select count(*) overlap_top20 from (select drop_id from public.trending_scores order by trend_score desc limit 20)t join (select drop_id from public.top100_scores order by current_rank limit 20)q using(drop_id))
 select jsonb_build_object('algorithmVersion',1,'windowHours',p_hours,
  'sources',coalesce((select jsonb_agg(to_jsonb(source_metrics)) from source_metrics),'[]'),
  'maturity',coalesce((select jsonb_agg(to_jsonb(maturity)) from maturity),'[]'),
  'trending',(select to_jsonb(trend_diag) from trend_diag),'top100',(select to_jsonb(top_diag) from top_diag),
  'trendingTop100',(select to_jsonb(overlap) from overlap),
  'experiments',coalesce((select jsonb_agg(to_jsonb(m)) from internal.feed_experiment_variant_metrics m),'[]')) into v_result;
 return v_result;
end $$;
revoke all on function public.admin_feed_algorithm_dashboard(integer) from public,anon;
grant execute on function public.admin_feed_algorithm_dashboard(integer) to authenticated;

-- ============================================================

-- Replace Home RPC to batch similarity expansion and emit safe origin/version metadata.
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
  with similarity_candidates as (
    select * from internal.my_similarity_candidates()
  ), recent as (
    select hf.*
    from public.home_feed hf
    where not exists (
      select 1 from public.feed_signals fs
      where fs.user_id = auth.uid()
        and fs.signal_type in ('hide', 'not_interested')
        and fs.target_id = hf.id
    )
    order by (exists(select 1 from similarity_candidates sc
      where sc.drop_id=hf.id)) desc,hf.created_at desc
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
  quality_factors as (
    select * from internal.content_quality_factors(
      (select coalesce(array_agg(id),array[]::uuid[]) from candidates)
    )
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
      coalesce(fq.quality_score, 1.0) as home_quality_score,
      coalesce(sim.similarity_score,0.0) as similarity_score,
      coalesce(sim.candidate_origin,'direct') as candidate_origin,
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
    left join quality_factors fq on fq.drop_id = c.id
    left join similarity_candidates sim on sim.drop_id=c.id
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
      - 'top100_quality_bonus' - 'maturity_state' - 'home_quality_score'
      - 'similarity_score')
    || jsonb_build_object(
      'feed_is_trending', base_ranked.precomputed_trend_score > 0,
      'feed_is_latest', base_ranked.age_hours <= 24,
      'feed_is_club', base_ranked.is_club_flag,
      'feed_is_new_creator',
        (base_ranked.author_created_at >= now() - interval '30 days'
          or (base_ranked.age_hours <= 24 and base_ranked.engagement_raw <= 10)),
      'feed_topic', base_ranked.candidate_topic,
      'feed_maturity_state', base_ranked.maturity_state,
      'feed_algorithm_version', 1,
      'feed_candidate_origin', base_ranked.candidate_origin,
      'feed_source_scores', jsonb_build_object(
        'following', base_ranked.nonpersonal_score
          + base_ranked.personalization_confidence * (
            base_ranked.base_score - base_ranked.nonpersonal_score
            + base_ranked.creator_affinity * 12
            + base_ranked.topic_affinity * 6
            + base_ranked.content_type_affinity * 2)
          - (1 - base_ranked.home_quality_score) * 8,
        'recommended', base_ranked.nonpersonal_score
          + base_ranked.top100_quality_bonus
          + (case when base_ranked.age_hours <= 24 then 5 else 0 end)
          + base_ranked.personalization_confidence * (
            base_ranked.base_score - base_ranked.nonpersonal_score
            + base_ranked.affinity_raw * 20)
          + base_ranked.similarity_score * 100
          - (1 - base_ranked.home_quality_score) * 25,
        'trending', base_ranked.nonpersonal_score
          + base_ranked.personalization_confidence * base_ranked.affinity_raw * 5
          - (1 - base_ranked.home_quality_score) * 20,
        'latest', base_ranked.nonpersonal_score
          + (case when base_ranked.age_hours <= 24 then 5 else 0 end)
          + base_ranked.personalization_confidence * base_ranked.affinity_raw * 3
          - (1 - base_ranked.home_quality_score) * 6,
        'club', base_ranked.nonpersonal_score
          + base_ranked.personalization_confidence * (
            base_ranked.base_score - base_ranked.nonpersonal_score
            + base_ranked.creator_affinity * 8
            + base_ranked.topic_affinity * 5)
          - (1 - base_ranked.home_quality_score) * 10,
        'new_creator', base_ranked.nonpersonal_score
          + (case when base_ranked.age_hours <= 24 then 5 else 0 end)
          + base_ranked.personalization_confidence * (
            base_ranked.topic_affinity * 10
            + base_ranked.content_type_affinity * 4)
          - (1 - base_ranked.home_quality_score) * 6,
        'exploration', base_ranked.nonpersonal_score
          + (1 - base_ranked.personalization_confidence)
            * (case when abs(base_ranked.topic_affinity) < 0.2 then 5 else 0 end)
          + base_ranked.personalization_confidence
            * (1 - abs(base_ranked.topic_affinity)) * 5
          + base_ranked.similarity_score * 50
          - (1 - base_ranked.home_quality_score) * 10
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
