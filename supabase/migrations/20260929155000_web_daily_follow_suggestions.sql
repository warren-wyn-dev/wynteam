-- WYNOS Web — Daily Follow Suggestions
-- One Web Push per eligible user per local day, around 19:00 local time.
-- Reuses the existing social graph/privacy rules while adding rotation,
-- anti-spam, quiet-hours and delivery/open tracking.

alter table public.notification_settings
  add column if not exists suggestions boolean not null default true,
  add column if not exists push_suggestions boolean not null default true;

create or replace function internal.notification_enabled(
  p_user_id uuid,
  p_category text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_category is null or p_category not in
      ('likes', 'comments', 'follows', 'messages', 'club', 'trending', 'system', 'suggestions') then
    raise exception 'internal.notification_enabled: unknown category %', p_category;
  end if;

  return coalesce(
    (
      select case p_category
        when 'likes' then likes
        when 'comments' then comments
        when 'follows' then follows
        when 'messages' then messages
        when 'club' then club
        when 'trending' then trending
        when 'system' then system
        when 'suggestions' then suggestions
      end
      from public.notification_settings
      where user_id = p_user_id
    ),
    true
  );
end;
$$;

create table if not exists public.daily_follow_suggestion_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  local_date date not null,
  profile_ids uuid[] not null,
  status text not null default 'claimed'
    check (status in ('claimed', 'sent', 'failed')),
  lease_until timestamptz,
  sent_at timestamptz,
  opened_at timestamptz,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint daily_follow_suggestion_profile_count
    check (cardinality(profile_ids) between 3 and 5),
  constraint daily_follow_suggestion_user_day_unique
    unique (user_id, local_date)
);

create index if not exists daily_follow_suggestion_user_sent_idx
  on public.daily_follow_suggestion_deliveries(user_id, sent_at desc);

create index if not exists daily_follow_suggestion_profiles_gin_idx
  on public.daily_follow_suggestion_deliveries using gin(profile_ids);

alter table public.daily_follow_suggestion_deliveries enable row level security;

revoke all on table public.daily_follow_suggestion_deliveries
  from public, anon, authenticated;
grant select on table public.daily_follow_suggestion_deliveries to authenticated;

drop policy if exists "Users can view their own daily follow suggestions"
  on public.daily_follow_suggestion_deliveries;
create policy "Users can view their own daily follow suggestions"
  on public.daily_follow_suggestion_deliveries
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function internal.daily_follow_quiet_now(
  p_user_id uuid,
  p_at timestamptz default now()
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_enabled boolean := false;
  v_start time := '22:00'::time;
  v_end time := '08:00'::time;
  v_timezone text := 'UTC';
  v_local time;
begin
  select
    coalesce(n.push_quiet_enabled, false),
    coalesce(n.push_quiet_start, '22:00'::time),
    coalesce(n.push_quiet_end, '08:00'::time),
    coalesce(tz.name, 'UTC')
  into v_enabled, v_start, v_end, v_timezone
  from public.notification_settings n
  left join pg_timezone_names tz on tz.name = n.push_timezone
  where n.user_id = p_user_id;

  if not coalesce(v_enabled, false) or v_start = v_end then
    return false;
  end if;

  v_local := (p_at at time zone v_timezone)::time;

  if v_start < v_end then
    return v_local >= v_start and v_local < v_end;
  end if;
  return v_local >= v_start or v_local < v_end;
end;
$$;

create or replace function internal.daily_follow_candidate_allowed(
  p_user_id uuid,
  p_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $
  select exists (
    select 1
    from public.profiles p
    join public.profile_private pp
      on pp.id = p.id
     and pp.onboarding_completed = true
    where p.id = p_profile_id
      and p.id <> p_user_id
      and p.username is not null
      and btrim(p.username) <> ''
      and not internal.is_blocked_either_way(p_user_id, p.id)
      and not coalesce(internal.is_posting_blocked(p.id), false)
      and not exists (
        select 1
        from public.follows f
        where f.follower_id = p_user_id
          and f.following_id = p.id
      )
      and not exists (
        select 1
        from public.follow_requests fr
        where fr.requester_id = p_user_id
          and fr.target_id = p.id
      )
      and not exists (
        select 1
        from public.mutes m
        where m.muter_id = p_user_id
          and m.muted_id = p.id
      )
      and not exists (
        select 1
        from public.profile_recommendation_dismissals rd
        where rd.user_id = p_user_id
          and rd.dismissed_profile_id = p.id
      )
      and not exists (
        select 1
        from public.daily_follow_suggestion_deliveries h7
        where h7.user_id = p_user_id
          and h7.status = 'sent'
          and h7.sent_at >= now() - interval '7 days'
          and p.id = any(h7.profile_ids)
      )
  );
$;

create or replace function public.claim_daily_follow_suggestions(
  p_limit integer default 50
)
returns table (
  delivery_id uuid,
  user_id uuid,
  profile_ids uuid[],
  language_preference text,
  local_date date
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 200));
  v_user record;
  v_existing public.daily_follow_suggestion_deliveries%rowtype;
  v_profiles uuid[];
  v_delivery_id uuid;
begin
  for v_user in
    with eligible as (
      select
        p.id as uid,
        coalesce(tz.name, 'UTC') as tz_name,
        (now() at time zone coalesce(tz.name, 'UTC')) as local_now,
        coalesce(up.language_preference, 'th') as lang
      from public.profiles p
      join public.profile_private pp
        on pp.id = p.id
       and pp.onboarding_completed = true
      left join public.notification_settings ns on ns.user_id = p.id
      left join pg_timezone_names tz on tz.name = ns.push_timezone
      left join public.user_preferences up on up.user_id = p.id
      where coalesce(ns.suggestions, true)
        and coalesce(ns.push_suggestions, true)
        and exists (
          select 1
          from public.push_tokens pt
          where pt.user_id = p.id
            and pt.platform = 'web'
        )
        and not internal.daily_follow_quiet_now(p.id)
        and not exists (
          select 1
          from public.notifications n
          where n.recipient_id = p.id
            and n.created_at >= now() - interval '90 minutes'
        )
      -- Serialize claims for the same account without locking unrelated
      -- users. A concurrent cron/manual invocation skips an already-claimed
      -- profile instead of racing the unique (user_id, local_date) insert.
      for update of p skip locked
    )
    select
      uid,
      tz_name,
      local_now,
      local_now::date as due_date,
      lang
    from eligible
    where local_now::time >= time '19:00'
      and local_now::time < time '22:00'
    order by local_now::date, uid
    limit v_limit
  loop
    select *
    into v_existing
    from public.daily_follow_suggestion_deliveries d
    where d.user_id = v_user.uid
      and d.local_date = v_user.due_date
    for update;

    if found then
      if v_existing.status = 'sent' then
        continue;
      end if;
      if v_existing.status = 'claimed'
         and v_existing.lease_until is not null
         and v_existing.lease_until > now() then
        continue;
      end if;

      -- A failed/expired claim can be retried later the same evening. Reuse
      -- the exact set only while every account is still eligible; if the user
      -- followed, requested, blocked, muted or dismissed anyone meanwhile,
      -- rebuild the set before sending.
      select case
        when count(*) = cardinality(v_existing.profile_ids)
         and bool_and(internal.daily_follow_candidate_allowed(v_user.uid, candidate_id))
        then v_existing.profile_ids
        else null
      end
      into v_profiles
      from unnest(v_existing.profile_ids) as candidate_id;
    else
      v_profiles := null;
    end if;

    if v_profiles is null then
      select array_agg(candidate.profile_id order by candidate.rank_order)
      into v_profiles
      from (
        select
          p2.id as profile_id,
          row_number() over (
            order by
              case when exists (
                select 1
                from public.daily_follow_suggestion_deliveries h30
                where h30.user_id = v_user.uid
                  and h30.status = 'sent'
                  and h30.sent_at >= now() - interval '30 days'
                  and p2.id = any(h30.profile_ids)
              ) then 1 else 0 end,
              (
                select count(*)
                from public.follows mine
                join public.follows theirs
                  on theirs.follower_id = mine.following_id
                 and theirs.following_id = p2.id
                where mine.follower_id = v_user.uid
              ) desc,
              (
                select count(*)
                from public.follows fc
                where fc.following_id = p2.id
              ) desc,
              md5(p2.id::text || '|' || v_user.due_date::text || '|' || v_user.uid::text)
          ) as rank_order
        from public.profiles p2
        where internal.daily_follow_candidate_allowed(v_user.uid, p2.id)
        order by
          case when exists (
            select 1
            from public.daily_follow_suggestion_deliveries h30
            where h30.user_id = v_user.uid
              and h30.status = 'sent'
              and h30.sent_at >= now() - interval '30 days'
              and p2.id = any(h30.profile_ids)
          ) then 1 else 0 end,
          (
            select count(*)
            from public.follows mine
            join public.follows theirs
              on theirs.follower_id = mine.following_id
             and theirs.following_id = p2.id
            where mine.follower_id = v_user.uid
          ) desc,
          (
            select count(*)
            from public.follows fc
            where fc.following_id = p2.id
          ) desc,
          md5(p2.id::text || '|' || v_user.due_date::text || '|' || v_user.uid::text)
        limit 5
      ) candidate;

      if coalesce(cardinality(v_profiles), 0) < 3 then
        continue;
      end if;
    end if;

    if v_existing.id is null then
      insert into public.daily_follow_suggestion_deliveries (
        user_id,
        local_date,
        profile_ids,
        status,
        lease_until
      )
      values (
        v_user.uid,
        v_user.due_date,
        v_profiles,
        'claimed',
        now() + interval '10 minutes'
      )
      returning id into v_delivery_id;
    else
      update public.daily_follow_suggestion_deliveries d
      set status = 'claimed',
          lease_until = now() + interval '10 minutes',
          error = null,
          updated_at = now()
      where d.id = v_existing.id
      returning d.id into v_delivery_id;
    end if;

    delivery_id := v_delivery_id;
    user_id := v_user.uid;
    profile_ids := v_profiles;
    language_preference := case when v_user.lang = 'en' then 'en' else 'th' end;
    local_date := v_user.due_date;
    return next;

    v_existing := null;
    v_profiles := null;
    v_delivery_id := null;
  end loop;
end;
$$;

revoke all on function public.claim_daily_follow_suggestions(integer)
  from public, anon, authenticated;
grant execute on function public.claim_daily_follow_suggestions(integer)
  to service_role;

create or replace function public.finish_daily_follow_suggestion(
  p_delivery_id uuid,
  p_success boolean,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.daily_follow_suggestion_deliveries
  set status = case when p_success then 'sent' else 'failed' end,
      sent_at = case when p_success then now() else sent_at end,
      lease_until = null,
      error = case when p_success then null else left(coalesce(p_error, 'unknown'), 300) end,
      updated_at = now()
  where id = p_delivery_id
    and status = 'claimed';
end;
$$;

revoke all on function public.finish_daily_follow_suggestion(uuid, boolean, text)
  from public, anon, authenticated;
grant execute on function public.finish_daily_follow_suggestion(uuid, boolean, text)
  to service_role;

create or replace function public.mark_daily_follow_suggestion_opened(
  p_delivery_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  update public.daily_follow_suggestion_deliveries
  set opened_at = coalesce(opened_at, now()),
      updated_at = now()
  where id = p_delivery_id
    and user_id = v_uid
    and status = 'sent';

  return found;
end;
$$;

revoke all on function public.mark_daily_follow_suggestion_opened(uuid)
  from public, anon;
grant execute on function public.mark_daily_follow_suggestion_opened(uuid)
  to authenticated;

create or replace function public.verify_daily_follow_suggestion_cron_key(
  p_key text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_key is not null
     and length(p_key) >= 32
     and exists (
       select 1
       from vault.decrypted_secrets
       where name = 'wynos_daily_follow_cron_key'
         and decrypted_secret = p_key
     );
$$;

revoke all on function public.verify_daily_follow_suggestion_cron_key(text)
  from public, anon, authenticated;
grant execute on function public.verify_daily_follow_suggestion_cron_key(text)
  to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_extension where extname = 'pg_net') then
    perform cron.schedule(
      'wynos-daily-follow-suggestions',
      '27 * * * *',
      $job$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'wynos_project_url'
          limit 1
        ) || '/functions/v1/send-daily-follow-suggestions',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'X-Wynos-Cron-Key', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'wynos_daily_follow_cron_key'
            limit 1
          )
        ),
        body := '{"source":"pg_cron"}'::jsonb,
        timeout_milliseconds := 10000
      );
      $job$
    );

    -- Keep delivery off until the matching web route/service worker is live.
    perform cron.alter_job(
      job_id := (
        select jobid
        from cron.job
        where jobname = 'wynos-daily-follow-suggestions'
        limit 1
      ),
      active := false
    );
  end if;
end
$$;
