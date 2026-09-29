alter table public.notification_settings
  add column if not exists push_timezone_synced_at timestamptz;

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
        tz.name as tz_name,
        (now() at time zone tz.name) as local_now,
        coalesce(up.language_preference, 'th') as lang
      from public.profiles p
      join public.profile_private pp
        on pp.id = p.id
       and pp.onboarding_completed = true
      join public.notification_settings ns
        on ns.user_id = p.id
       and ns.push_timezone_synced_at is not null
      join pg_timezone_names tz
        on tz.name = ns.push_timezone
      left join public.user_preferences up on up.user_id = p.id
      where ns.suggestions
        and ns.push_suggestions
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
        user_id, local_date, profile_ids, status, lease_until
      )
      values (
        v_user.uid, v_user.due_date, v_profiles, 'claimed', now() + interval '10 minutes'
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
