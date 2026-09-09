-- WYNOS Phase 4: additive Personalization & Learning Signals migration.
-- Safe after WYN-141; no existing user/content/engagement rows are deleted.

-- ============================================================
-- WYNOS Personalization & Learning Signals V1 (Phase 4)
-- ============================================================

-- Extend the existing private signal stream with bounded consumption intent.
-- Impressions are deliberately absent: visibility alone is not preference.
do $$
declare v_constraint text;
begin
  select conname into v_constraint from pg_constraint
  where conrelid = 'public.feed_signals'::regclass
    and contype = 'c' and pg_get_constraintdef(oid) like '%signal_type%';
  if v_constraint is not null then
    execute format('alter table public.feed_signals drop constraint %I', v_constraint);
  end if;
end
$$;
alter table public.feed_signals add constraint feed_signals_signal_type_check
  check (signal_type in (
    'profile_visit', 'hide', 'not_interested', 'fast_skip', 'short_view',
    'qualified_view', 'long_view', 'follow_from_feed'
  ));

create table if not exists public.user_affinities (
  user_id uuid not null references public.profiles (id) on delete cascade,
  dimension_type text not null
    check (dimension_type in ('topic', 'creator', 'content_type')),
  dimension_key text not null,
  recent_score double precision not null default 0,
  long_term_score double precision not null default 0,
  signal_count integer not null default 0,
  updated_at timestamptz not null,
  personalization_version integer not null default 1,
  primary key (user_id, dimension_type, dimension_key)
);

-- The primary key is the request-path index for user + dimension + key; no
-- redundant secondary index is needed.
alter table public.user_affinities enable row level security;
revoke all on public.user_affinities from authenticated, anon;

-- Minimal idempotency ledger: only an event identity, never event payload or
-- private content. A trigger retry/replay cannot apply affinity twice.
create table if not exists public.personalization_processed_events (
  event_key text primary key,
  processed_at timestamptz not null default now()
);
alter table public.personalization_processed_events enable row level security;
revoke all on public.personalization_processed_events from authenticated, anon;

-- Safe normalized view. Raw recent/long-term values remain inaccessible;
-- authenticated users can only read their own bounded [-1,1] effective score.
create or replace view public.my_effective_affinities
with (security_barrier = true) as
select dimension_type, dimension_key,
  tanh((
    0.65 * recent_score * power(0.5,
      extract(epoch from (now() - updated_at)) / 3600.0 / 168.0)
    + 0.35 * long_term_score * power(0.5,
      extract(epoch from (now() - updated_at)) / 3600.0 / 2160.0)
  ) / 10.0) as effective_score,
  personalization_version,
  updated_at
from public.user_affinities
where user_id = auth.uid();

revoke all on public.my_effective_affinities from public, anon;
grant select on public.my_effective_affinities to authenticated;

create or replace function internal.apply_affinity_signal(
  p_user_id uuid,
  p_dimension_type text,
  p_dimension_key text,
  p_weight double precision,
  p_occurred_at timestamptz
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.user_affinities (
    user_id, dimension_type, dimension_key, recent_score, long_term_score,
    signal_count, updated_at
  ) values (
    p_user_id, p_dimension_type, lower(p_dimension_key),
    greatest(-50.0, least(50.0, p_weight)),
    greatest(-50.0, least(50.0, p_weight * 0.40)), 1, p_occurred_at
  )
  on conflict (user_id, dimension_type, dimension_key) do update set
    recent_score = greatest(-50.0, least(50.0,
      public.user_affinities.recent_score * power(0.5,
        greatest(extract(epoch from
          (excluded.updated_at - public.user_affinities.updated_at)), 0)
          / 3600.0 / 168.0)
      + excluded.recent_score * power(0.5,
        greatest(extract(epoch from
          (public.user_affinities.updated_at - excluded.updated_at)), 0)
          / 3600.0 / 168.0))),
    long_term_score = greatest(-50.0, least(50.0,
      public.user_affinities.long_term_score * power(0.5,
        greatest(extract(epoch from
          (excluded.updated_at - public.user_affinities.updated_at)), 0)
          / 3600.0 / 2160.0)
      + excluded.long_term_score * power(0.5,
        greatest(extract(epoch from
          (public.user_affinities.updated_at - excluded.updated_at)), 0)
          / 3600.0 / 2160.0))),
    signal_count = public.user_affinities.signal_count + 1,
    updated_at = greatest(public.user_affinities.updated_at, excluded.updated_at),
    personalization_version = 1;
$$;

revoke all on function internal.apply_affinity_signal(
  uuid, text, text, double precision, timestamptz) from public;

create or replace function internal.learn_from_drop(
  p_event_key text,
  p_user_id uuid,
  p_drop_id uuid,
  p_weight double precision,
  p_occurred_at timestamptz,
  p_format_override text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_drop record;
  v_topic text[];
  v_format text;
begin
  insert into public.personalization_processed_events(event_key)
  values (p_event_key) on conflict do nothing;
  if not found then return; end if;

  select d.author_id, d.caption, d.image_url,
    exists(select 1 from public.drop_polls dp where dp.drop_id = d.id) as is_poll
  into v_drop from public.drops d where d.id = p_drop_id;
  if v_drop is null or v_drop.author_id = p_user_id then return; end if;

  perform internal.apply_affinity_signal(
    p_user_id, 'creator', v_drop.author_id::text, p_weight, p_occurred_at);
  v_format := coalesce(p_format_override,
    case when v_drop.is_poll then 'poll'
         when v_drop.image_url is not null then 'image' else 'text' end);
  perform internal.apply_affinity_signal(
    p_user_id, 'content_type', v_format, p_weight * 0.50, p_occurred_at);

  for v_topic in
    select regexp_matches(lower(coalesce(v_drop.caption, '')),
      '#([[:alnum:]_]+)', 'g')
  loop
    perform internal.apply_affinity_signal(
      p_user_id, 'topic', v_topic[1], p_weight, p_occurred_at);
  end loop;
end;
$$;

revoke all on function internal.learn_from_drop(
  text, uuid, uuid, double precision, timestamptz, text) from public;

-- Trigger adapter derives weights and trusted target metadata server-side.
create or replace function internal.capture_personalization_signal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_weight double precision;
  v_event_key text;
begin
  if tg_table_name = 'drop_likes' then
    perform internal.learn_from_drop('like:' || new.drop_id || ':' || new.user_id
      || ':' || new.created_at, new.user_id, new.drop_id, 2.0, new.created_at);
  elsif tg_table_name = 'drop_comments' then
    perform internal.learn_from_drop('comment:' || new.id, new.author_id,
      new.drop_id, 3.0, new.created_at);
  elsif tg_table_name = 'redrops' then
    perform internal.learn_from_drop('redrop:' || new.id, new.redropper_id,
      new.drop_id, 5.0, new.created_at,
      case when new.quote_text is null then null else 'quote' end);
  elsif tg_table_name = 'saves' and new.content_type = 'drop' then
    perform internal.learn_from_drop('save:' || new.content_id || ':' || new.user_id
      || ':' || new.created_at, new.user_id, new.content_id, 4.0, new.created_at);
  elsif tg_table_name = 'follows' then
    v_event_key := 'follow:' || new.follower_id || ':' || new.following_id
      || ':' || new.created_at;
    insert into public.personalization_processed_events(event_key)
    values(v_event_key) on conflict do nothing;
    if found then
      perform internal.apply_affinity_signal(new.follower_id, 'creator',
        new.following_id::text, 8.0, new.created_at);
    end if;
  elsif tg_table_name = 'feed_signals' then
    v_weight := case new.signal_type
      when 'profile_visit' then 1.0 when 'hide' then -6.0
      when 'not_interested' then -10.0 when 'fast_skip' then -1.0
      when 'short_view' then 0.25 when 'qualified_view' then 1.0
      when 'long_view' then 4.0 when 'follow_from_feed' then 2.0
      else 0.0 end;
    if new.target_type = 'drop' then
      perform internal.learn_from_drop('feed_signal:' || new.id, new.user_id,
        new.target_id, v_weight, new.created_at);
    elsif new.target_type = 'profile' and new.target_id <> new.user_id
      and exists(select 1 from public.profiles where id = new.target_id) then
      insert into public.personalization_processed_events(event_key)
      values('feed_signal:' || new.id) on conflict do nothing;
      if found then
        perform internal.apply_affinity_signal(new.user_id, 'creator',
          new.target_id::text, v_weight, new.created_at);
      end if;
    end if;
  elsif tg_table_name = 'reports' and new.target_type = 'drop' then
    perform internal.learn_from_drop('report:' || new.id, new.reporter_id,
      new.target_id, -12.0, new.created_at);
  elsif tg_table_name = 'blocks' or tg_table_name = 'mutes' then
    v_event_key := tg_table_name || ':'
      || case when tg_table_name = 'blocks' then new.blocker_id else new.muter_id end
      || ':' || case when tg_table_name = 'blocks' then new.blocked_id else new.muted_id end
      || ':' || new.created_at;
    insert into public.personalization_processed_events(event_key)
    values(v_event_key) on conflict do nothing;
    if found then
      perform internal.apply_affinity_signal(
        case when tg_table_name = 'blocks' then new.blocker_id else new.muter_id end,
        'creator',
        (case when tg_table_name = 'blocks' then new.blocked_id else new.muted_id end)::text,
        case when tg_table_name = 'blocks' then -20.0 else -8.0 end,
        new.created_at);
    end if;
  end if;
  return new;
end;
$$;

revoke all on function internal.capture_personalization_signal() from public;

create trigger drop_likes_personalization after insert on public.drop_likes
  for each row execute function internal.capture_personalization_signal();
create trigger drop_comments_personalization after insert on public.drop_comments
  for each row execute function internal.capture_personalization_signal();
create trigger redrops_personalization after insert on public.redrops
  for each row execute function internal.capture_personalization_signal();
create trigger saves_personalization after insert on public.saves
  for each row execute function internal.capture_personalization_signal();
create trigger follows_personalization after insert on public.follows
  for each row execute function internal.capture_personalization_signal();
create trigger feed_signals_personalization after insert on public.feed_signals
  for each row execute function internal.capture_personalization_signal();
create trigger reports_personalization after insert on public.reports
  for each row execute function internal.capture_personalization_signal();
create trigger blocks_personalization after insert on public.blocks
  for each row execute function internal.capture_personalization_signal();
create trigger mutes_personalization after insert on public.mutes
  for each row execute function internal.capture_personalization_signal();

-- Clients choose only a bounded intent label and target. Weight, author,
-- format, and topics are derived by the trigger; arbitrary score input is
-- impossible. Existing Hide/Profile Visit writes remain backward compatible.
create or replace function public.record_feed_learning_signal(
  p_signal_type text,
  p_target_type text,
  p_target_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_signal_type not in (
    'fast_skip', 'short_view', 'qualified_view', 'long_view',
    'not_interested', 'follow_from_feed'
  ) then raise exception 'Invalid learning signal'; end if;
  if p_target_type not in ('drop', 'profile') then
    raise exception 'Invalid learning target';
  end if;
  if p_target_type = 'drop' and not exists (
    select 1 from public.drops where id = p_target_id
  ) then raise exception 'Drop not found'; end if;
  if p_target_type = 'profile' and not exists (
    select 1 from public.profiles where id = p_target_id
  ) then raise exception 'Profile not found'; end if;
  insert into public.feed_signals(user_id, signal_type, target_type, target_id)
  values(auth.uid(), p_signal_type, p_target_type, p_target_id);
end;
$$;

revoke all on function public.record_feed_learning_signal(text, text, uuid)
  from public, anon;
grant execute on function public.record_feed_learning_signal(text, text, uuid)
  to authenticated;

-- Replace the existing ranked-feed function so it joins bounded, precomputed
-- affinities instead of scanning interaction history on every Home request.
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
    from final, weights
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
      - 'nonpersonal_score')
    || jsonb_build_object(
      'feed_is_trending', base_ranked.precomputed_trend_score > 0,
      'feed_is_latest', base_ranked.age_hours <= 24,
      'feed_is_club', base_ranked.is_club_flag,
      'feed_is_new_creator',
        (base_ranked.author_created_at >= now() - interval '30 days'
          or (base_ranked.age_hours <= 24 and base_ranked.engagement_raw <= 10)),
      'feed_topic', base_ranked.candidate_topic,
      'feed_source_scores', jsonb_build_object(
        'following', base_ranked.base_score
          + base_ranked.creator_affinity * 12 + base_ranked.topic_affinity * 6
          + base_ranked.content_type_affinity * 2,
        'recommended', base_ranked.base_score + base_ranked.affinity_raw * 20,
        'trending', base_ranked.nonpersonal_score
          + base_ranked.affinity_raw * 5,
        'latest', base_ranked.nonpersonal_score
          + base_ranked.affinity_raw * 3,
        'club', base_ranked.base_score
          + base_ranked.creator_affinity * 8 + base_ranked.topic_affinity * 5,
        'new_creator', base_ranked.nonpersonal_score
          + base_ranked.topic_affinity * 10
          + base_ranked.content_type_affinity * 4,
        'exploration', base_ranked.nonpersonal_score
          + (1 - abs(base_ranked.topic_affinity)) * 5
      ),
      'feed_reason_code', case
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
