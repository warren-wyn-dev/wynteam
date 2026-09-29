-- Follow-up hardening after the base posting-loop rollout.
-- Keeps posting-restriction checks null-safe and separates engagement windows:
-- followed-post digests 09:00-17:00, posting nudges 17:00-18:00 local time.

create or replace function public.claim_posting_nudges(
  p_limit integer default 30
)
returns table (
  delivery_id uuid,
  user_id uuid,
  kind text,
  prompt_key text,
  language_preference text
)
language plpgsql
security definer
set search_path = ''
as $posting_nudge_claim$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 30), 100));
  v record;
  v_delivery uuid;
begin
  for v in
    with candidates as (
      select
        s.user_id,
        s.last_sent_at,
        p.created_at as account_created_at,
        wr.last_seen_at,
        lp.last_post_at,
        coalesce(up.language_preference, 'th') as lang,
        (now() at time zone tz.name) as local_now
      from public.posting_nudge_state s
      join public.profiles p on p.id = s.user_id
      join public.profile_private pp
        on pp.id = p.id
       and pp.onboarding_completed = true
      join public.web_reactivation_state wr
        on wr.user_id = p.id
       and wr.activated_at is not null
       and wr.last_seen_at >= now() - interval '3 days'
      join public.notification_settings ns
        on ns.user_id = p.id
       and ns.posting_prompts = true
       and ns.push_posting_prompts = true
       and ns.push_timezone_synced_at is not null
      join pg_timezone_names tz on tz.name = ns.push_timezone
      left join public.user_preferences up on up.user_id = p.id
      left join lateral (
        select max(d.created_at) as last_post_at
        from public.drops d
        where d.author_id = p.id
          and d.deleted_at is null
      ) lp on true
      where (s.lease_until is null or s.lease_until <= now())
        and not coalesce(internal.is_posting_blocked(p.id), false)
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
        and not exists (
          select 1
          from public.followed_post_digest_deliveries fd
          where fd.user_id = p.id
            and fd.status = 'sent'
            and fd.sent_at >= now() - interval '2 hours'
        )
      for update of s skip locked
    )
    select *
    from candidates c
    where c.local_now::time >= time '17:00'
      and c.local_now::time < time '18:00'
      and not exists (
        select 1
        from public.daily_follow_suggestion_deliveries df
        where df.user_id = c.user_id
          and df.status = 'sent'
          and df.local_date = c.local_now::date
      )
      and (
        (
          c.last_post_at is null
          and c.account_created_at <= now() - interval '12 hours'
          and (c.last_sent_at is null or c.last_sent_at <= now() - interval '3 days')
        )
        or
        (
          c.last_post_at is not null
          and c.last_post_at <= now() - interval '7 days'
          and (c.last_sent_at is null or c.last_sent_at <= now() - interval '7 days')
        )
      )
    order by c.user_id
    limit v_limit
  loop
    update public.posting_nudge_state
    set lease_until = now() + interval '10 minutes',
        updated_at = now()
    where posting_nudge_state.user_id = v.user_id;

    insert into public.posting_nudge_deliveries(user_id, kind)
    values (
      v.user_id,
      case when v.last_post_at is null then 'first_post' else 'return_post' end
    )
    returning id into v_delivery;

    delivery_id := v_delivery;
    user_id := v.user_id;
    kind := case when v.last_post_at is null then 'first_post' else 'return_post' end;
    prompt_key := case when v.last_post_at is null then 'first-intro' else 'daily' end;
    language_preference := case when v.lang = 'en' then 'en' else 'th' end;
    return next;
  end loop;
end;
$posting_nudge_claim$;

revoke all on function public.claim_posting_nudges(integer) from public, anon, authenticated;
grant execute on function public.claim_posting_nudges(integer) to service_role;

create or replace function public.claim_followed_post_digests(
  p_limit integer default 50
)
returns table (
  delivery_id uuid,
  user_id uuid,
  post_count integer,
  author_count integer,
  latest_drop_id uuid,
  latest_author_id uuid,
  language_preference text
)
language plpgsql
security definer
set search_path = ''
as $followed_digest_claim$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 150));
  v record;
  v_batch record;
  v_delivery uuid;
begin
  for v in
    select
      s.user_id,
      s.cursor_at,
      s.last_sent_at,
      coalesce(up.language_preference, 'th') as lang,
      (now() at time zone tz.name) as local_now
    from public.followed_post_digest_state s
    join public.profile_private pp
      on pp.id = s.user_id
     and pp.onboarding_completed = true
    join public.notification_settings ns
      on ns.user_id = s.user_id
     and ns.post_updates = true
     and ns.push_post_updates = true
     and ns.push_timezone_synced_at is not null
    join pg_timezone_names tz on tz.name = ns.push_timezone
    left join public.user_preferences up on up.user_id = s.user_id
    where (s.lease_until is null or s.lease_until <= now())
      and (s.last_sent_at is null or s.last_sent_at <= now() - interval '3 hours')
      and exists (
        select 1
        from public.push_tokens pt
        where pt.user_id = s.user_id
          and pt.platform = 'web'
      )
      and not internal.daily_follow_quiet_now(s.user_id)
      and not exists (
        select 1
        from public.notifications n
        where n.recipient_id = s.user_id
          and n.created_at >= now() - interval '90 minutes'
      )
      and not exists (
        select 1
        from public.posting_nudge_deliveries pn
        where pn.user_id = s.user_id
          and pn.status = 'sent'
          and pn.sent_at >= now() - interval '2 hours'
      )
      and not exists (
        select 1
        from public.daily_follow_suggestion_deliveries df
        where df.user_id = s.user_id
          and df.status = 'sent'
          and df.sent_at >= now() - interval '90 minutes'
      )
      and (now() at time zone tz.name)::time >= time '09:00'
      and (now() at time zone tz.name)::time < time '17:00'
    order by s.user_id
    for update of s skip locked
    limit v_limit
  loop
    select
      count(*)::integer as post_count,
      count(distinct d.author_id)::integer as author_count,
      max(d.created_at) as latest_at,
      (array_agg(d.id order by d.created_at desc, d.id desc))[1] as latest_drop_id,
      (array_agg(d.author_id order by d.created_at desc, d.id desc))[1] as latest_author_id
    into v_batch
    from public.follows f
    join public.drops d
      on d.author_id = f.following_id
     and d.deleted_at is null
     and d.audience = 'everyone'
    where f.follower_id = v.user_id
      and d.created_at > v.cursor_at
      and not internal.is_blocked_either_way(v.user_id, d.author_id)
      and not coalesce(internal.is_posting_blocked(d.author_id), false)
      and not exists (
        select 1
        from public.mutes m
        where m.muter_id = v.user_id
          and m.muted_id = d.author_id
      );

    if coalesce(v_batch.post_count, 0) = 0 or v_batch.latest_at is null then
      continue;
    end if;

    update public.followed_post_digest_state
    set lease_until = now() + interval '10 minutes',
        pending_cursor_at = v_batch.latest_at,
        updated_at = now()
    where followed_post_digest_state.user_id = v.user_id;

    insert into public.followed_post_digest_deliveries(
      user_id, post_count, author_count, latest_drop_id, latest_author_id
    )
    values (
      v.user_id,
      v_batch.post_count,
      v_batch.author_count,
      v_batch.latest_drop_id,
      v_batch.latest_author_id
    )
    returning id into v_delivery;

    delivery_id := v_delivery;
    user_id := v.user_id;
    post_count := v_batch.post_count;
    author_count := v_batch.author_count;
    latest_drop_id := v_batch.latest_drop_id;
    latest_author_id := v_batch.latest_author_id;
    language_preference := case when v.lang = 'en' then 'en' else 'th' end;
    return next;
  end loop;
end;
$followed_digest_claim$;

revoke all on function public.claim_followed_post_digests(integer) from public, anon, authenticated;
grant execute on function public.claim_followed_post_digests(integer) to service_role;
