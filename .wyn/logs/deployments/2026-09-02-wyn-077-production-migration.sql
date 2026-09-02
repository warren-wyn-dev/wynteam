-- WYN-077 production migration
-- Run this in Supabase Dashboard -> SQL Editor for project kqokpocajhfbidcxpvhh
-- (the real WYNOS production project) BEFORE the app/admin code deploy.
--
-- Verified 2026-09-02: applied cleanly against a local throwaway
-- Postgres database seeded with the exact schema state schema.sql had
-- immediately before this block (i.e. simulating current production),
-- and admin_dashboard_metrics() returns correctly-shaped empty-state
-- data (0s and an empty [] for top_sources) with zero analytics_events
-- rows present -- see .wyn/logs/deployments/2026-09-02-wyn-077-real-deploy.md.
--
-- Purely additive: one new table (analytics_events), one function
-- dropped and recreated with more OUT columns than before. Nothing
-- existing is removed, renamed, or has its behavior changed for any
-- caller that only reads the 14 original admin_dashboard_metrics()
-- columns.
--
-- Mechanically extracted from supabase/schema.sql (not hand-typed) --
-- if this ever needs to change, edit schema.sql and re-extract, don't
-- hand-edit this file.

-- WYN-077: Basic Product Analytics (Go-To-Market instrumentation)
-- ============================================================
-- See .wyn/tasks/active/WYN-077-basic-product-analytics.md and
-- .wyn/docs/design/wyn-077-basic-product-analytics.md. First-party
-- only (Founder chose this over a third-party tool like PostHog/
-- Firebase Analytics on 2026-09-02, see .wyn/company/DECISIONS.md, to
-- keep user data from leaving this project at all) -- a flat event log
-- the app writes to directly, read back only in aggregate by
-- admin_dashboard_metrics() below (extended, not duplicated).
create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  -- References auth.users, not public.profiles: signup_started fires
  -- right after a brand-new account's auth session exists but *before*
  -- acceptMandatoryDocuments() has created that user's profiles stub
  -- row (see auth_repository.dart/platform_document_repository.dart) --
  -- a profiles FK would reject that first event with a foreign-key
  -- violation.
  user_id uuid not null references auth.users (id) on delete cascade,
  event_type text not null check (
    event_type in ('signup_started', 'signup_completed', 'first_core_action', 'session_start')
  ),
  -- UTM/referral source, captured only on signup_started (Flutter Web
  -- reads it from the browser URL's query string, e.g. ?utm_source=...
  -- -- see AnalyticsRepository.currentWebSource() in
  -- app/lib/features/analytics/data/analytics_repository.dart). Null
  -- for every other event_type and for native/no-UTM signups alike --
  -- admin_dashboard_metrics() below reports those as "ไม่ระบุที่มา".
  source text,
  created_at timestamptz not null default now()
);

-- admin_dashboard_metrics()'s new Growth section queries always filter
-- by event_type + a created_at window (this index), and its
-- conversion/activation/retention cohort calcs additionally correlate
-- one user's own rows across event types (the second index) -- see
-- that function's WYN-077 additions below.
create index if not exists analytics_events_type_created_idx
  on public.analytics_events (event_type, created_at);
create index if not exists analytics_events_user_type_idx
  on public.analytics_events (user_id, event_type, created_at);

alter table public.analytics_events enable row level security;

-- Insert-only, no SELECT policy at all -- unlike feed_signals (WYN's
-- other "record the user's own signal" table above, which does let a
-- user read their own rows back), a growth-analytics event has no
-- legitimate reason for any client to ever read it back, not even the
-- row's own author. Reading aggregates only happens through
-- admin_dashboard_metrics() below (SECURITY DEFINER, admin/moderator-
-- gated, returns counts/percentages only, never a raw row -- same
-- posture WYN-050 already established for every other metric in that
-- function).
create policy "Users can record their own analytics events"
  on public.analytics_events
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- ============================================================
-- WYN-050: WYN Admin Dashboard metrics
-- ============================================================
-- See .wyn/tasks/backlog/WYN-050-admin-dashboard.md and
-- .wyn/docs/design/wyn-050-admin-dashboard.md. One RPC, one round
-- trip, admin/moderator-only, returns aggregate counts only (never a
-- raw per-user row) -- this is deliberately how WYN Admin sees
-- cross-user data without a service-role client anywhere in the app
-- (WYN-049's decision, extended here rather than reopened). 11 of the
-- 14 metrics Master Spec section 37 lists; Storage/Errors/Server
-- Health are out of scope this round -- no Supabase Management API
-- access, no error-tracking tool, and no concept of "a server" in a
-- Vercel+Supabase serverless architecture, respectively (see the
-- Product spec's Requirement 1 for the full reasoning per metric).
--
-- WYN-077 extended this function (rather than adding a second RPC) with
-- an 8-column "Growth" block, sourced from the new analytics_events
-- table above -- keeps the Dashboard's "one RPC, one round trip"
-- property intact. Adding columns to a RETURNS TABLE function's OUT
-- parameters is a signature change `create or replace function` cannot
-- make (Postgres rejects it) -- drop and recreate instead.
drop function if exists public.admin_dashboard_metrics();

create function public.admin_dashboard_metrics()
returns table (
  new_users_today bigint,
  dau bigint,
  wau bigint,
  mau bigint,
  drops_today bigint,
  views_today bigint,
  clubs_total bigint,
  clubs_new_today bigint,
  likes_today bigint,
  comments_today bigint,
  redrops_today bigint,
  messages_today bigint,
  reports_total bigint,
  reports_pending bigint,
  -- WYN-077 additions below -- see
  -- .wyn/docs/design/wyn-077-basic-product-analytics.md's stat card
  -- table for what each one renders as.
  signup_started_24h bigint,
  signup_completed_24h bigint,
  signup_conversion_pct numeric,
  activation_pct_24h numeric,
  activation_count_24h bigint,
  retention_d1_pct numeric,
  retention_d7_pct numeric,
  top_sources jsonb
)
language plpgsql
security definer
set search_path = public
as $$
begin
  -- coalesce() is load-bearing, not decoration: current_platform_role()
  -- returns NULL for a caller with no `profiles` row at all, and
  -- `NULL not in (...)` evaluates to NULL, which PL/pgSQL's `if`
  -- treats as false (branch skipped, exception never raised) -- see
  -- set_club_member_role()'s own comment on this exact trap and
  -- .wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md
  -- for how this one was found (QA reproduced a real bypass before
  -- this fix existed).
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not permitted to view admin dashboard metrics';
  end if;

  return query
  -- DAU/WAU/MAU proxy: distinct actors across every "did something"
  -- table in the schema, not literal app-open sessions -- there is no
  -- session/analytics tracking system in this project at all (see the
  -- Product spec's Requirement 1). Creating a Drop counts as an
  -- action here too, alongside liking/commenting/ReDropping/
  -- messaging.
  with actions as (
    select user_id as actor_id, created_at from public.drop_likes
    union all
    select user_id, created_at from public.pop_likes
    union all
    select user_id, created_at from public.club_post_likes
    union all
    select author_id, created_at from public.drop_comments
    union all
    select author_id, created_at from public.pop_comments
    union all
    select author_id, created_at from public.club_post_comments
    union all
    select redropper_id, created_at from public.redrops
    union all
    select sender_id, created_at from public.messages where deleted_at is null
    union all
    select author_id, created_at from public.drops
  ),
  -- WYN-077 additions below -- each analytics_events event_type pulled
  -- into its own CTE once, reused by every cohort calc that needs it
  -- instead of re-querying the table per column.
  signup_started_rows as (
    select user_id, created_at, source
    from public.analytics_events
    where event_type = 'signup_started'
  ),
  signup_completed_rows as (
    select user_id, created_at
    from public.analytics_events
    where event_type = 'signup_completed'
  ),
  -- Only the earliest first_core_action per user matters for the
  -- "within 24h of signup" activation check below -- collapsed here so
  -- that check is a single timestamp comparison per cohort user rather
  -- than a correlated EXISTS over every row a repeat poster generates.
  core_action_rows as (
    select user_id, min(created_at) as first_at
    from public.analytics_events
    where event_type = 'first_core_action'
    group by user_id
  ),
  session_rows as (
    select user_id, created_at
    from public.analytics_events
    where event_type = 'session_start'
  ),
  -- Conversion: of users whose signup_started fell in the last 24h, what
  -- share have a signup_completed row at all (any time, not just within
  -- that same window -- onboarding is a matter of minutes for a real
  -- user, so this doesn't need its own time cap). OAuth sign-ins
  -- (Google/Apple) never emit signup_started this round (see
  -- AnalyticsRepository's doc comment for why), so this ratio only
  -- reflects the email/password signup funnel -- known scope limit, not
  -- a bug.
  conversion_calc as (
    select
      count(*) as started_count,
      count(*) filter (
        where exists (
          select 1 from signup_completed_rows sc where sc.user_id = s.user_id
        )
      ) as completed_count
    from signup_started_rows s
    where s.created_at >= now() - interval '1 day'
  ),
  -- Activation: of users whose signup_completed (onboarding finished --
  -- see the Design spec) fell in the last 24h, what share did their
  -- first core action (Drop post, per this round's scope) within 24h of
  -- that.
  activation_calc as (
    select
      count(*) as cohort_count,
      count(*) filter (
        where exists (
          select 1 from core_action_rows ca
          where ca.user_id = c.user_id
            and ca.first_at <= c.created_at + interval '1 day'
        )
      ) as activated_count
    from signup_completed_rows c
    where c.created_at >= now() - interval '1 day'
  ),
  -- D1 retention cohort: users who completed signup in the [2, 3) days-
  -- ago bucket -- old enough that their "day 1 after signup" window has
  -- fully closed, so this never undercounts a cohort that's still
  -- in-progress. Retained = has a session_start in [+1 day, +2 days)
  -- after their signup_completed.
  d1_cohort as (
    select * from signup_completed_rows
    where created_at >= now() - interval '3 days' and created_at < now() - interval '2 days'
  ),
  d1_calc as (
    select
      count(*) as cohort_count,
      count(*) filter (
        where exists (
          select 1 from session_rows sr
          where sr.user_id = d.user_id
            and sr.created_at >= d.created_at + interval '1 day'
            and sr.created_at < d.created_at + interval '2 days'
        )
      ) as retained_count
    from d1_cohort d
  ),
  -- D7 retention: same shape as D1, 7 days out instead of 1.
  d7_cohort as (
    select * from signup_completed_rows
    where created_at >= now() - interval '9 days' and created_at < now() - interval '8 days'
  ),
  d7_calc as (
    select
      count(*) as cohort_count,
      count(*) filter (
        where exists (
          select 1 from session_rows sr
          where sr.user_id = d.user_id
            and sr.created_at >= d.created_at + interval '7 days'
            and sr.created_at < d.created_at + interval '8 days'
        )
      ) as retained_count
    from d7_cohort d
  ),
  -- Top 5 signup sources over the last 7 days -- null source (no UTM
  -- param present, or a native/non-web signup) collapses to one
  -- "ไม่ระบุที่มา" bucket rather than showing as a blank row.
  top_sources_calc as (
    select coalesce(source, 'ไม่ระบุที่มา') as source, count(*) as cnt
    from signup_started_rows
    where created_at >= now() - interval '7 days'
    group by coalesce(source, 'ไม่ระบุที่มา')
    order by count(*) desc
    limit 5
  )
  select
    (select count(*) from public.profiles where created_at >= now() - interval '1 day'),
    (select count(distinct actor_id) from actions where created_at >= now() - interval '1 day'),
    (select count(distinct actor_id) from actions where created_at >= now() - interval '7 days'),
    (select count(distinct actor_id) from actions where created_at >= now() - interval '30 days'),
    (select count(*) from public.drops where created_at >= now() - interval '1 day'),
    (select count(*) from public.drop_views where created_at >= now() - interval '1 day'),
    (select count(*) from public.clubs),
    (select count(*) from public.clubs where created_at >= now() - interval '1 day'),
    (select count(*) from public.drop_likes where created_at >= now() - interval '1 day')
      + (select count(*) from public.pop_likes where created_at >= now() - interval '1 day')
      + (select count(*) from public.club_post_likes where created_at >= now() - interval '1 day'),
    (select count(*) from public.drop_comments where created_at >= now() - interval '1 day')
      + (select count(*) from public.pop_comments where created_at >= now() - interval '1 day')
      + (select count(*) from public.club_post_comments where created_at >= now() - interval '1 day'),
    (select count(*) from public.redrops where created_at >= now() - interval '1 day'),
    (select count(*) from public.messages where deleted_at is null and created_at >= now() - interval '1 day'),
    (select count(*) from public.reports),
    (select count(*) from public.reports where status = 'pending'),
    (select started_count from conversion_calc),
    -- signup_completed_24h is an absolute daily count (every
    -- signup_completed event in the last 24h), independent of when
    -- each of those users started -- not conversion_calc's
    -- completed_count, which is scoped to *today's started cohort*
    -- specifically (see signup_conversion_pct's own comment). The two
    -- can legitimately differ: a user who started 3 days ago and
    -- completed onboarding today counts here but not there.
    (select cohort_count from activation_calc),
    case when (select started_count from conversion_calc) = 0 then null
      else round((select completed_count from conversion_calc)::numeric
        / (select started_count from conversion_calc) * 100, 1)
    end,
    case when (select cohort_count from activation_calc) = 0 then null
      else round((select activated_count from activation_calc)::numeric
        / (select cohort_count from activation_calc) * 100, 1)
    end,
    (select activated_count from activation_calc),
    case when (select cohort_count from d1_calc) = 0 then null
      else round((select retained_count from d1_calc)::numeric
        / (select cohort_count from d1_calc) * 100, 1)
    end,
    case when (select cohort_count from d7_calc) = 0 then null
      else round((select retained_count from d7_calc)::numeric
        / (select cohort_count from d7_calc) * 100, 1)
    end,
    (select coalesce(jsonb_agg(jsonb_build_object('source', source, 'count', cnt)), '[]'::jsonb)
      from top_sources_calc);
end;
$$;

grant execute on function public.admin_dashboard_metrics() to authenticated;
