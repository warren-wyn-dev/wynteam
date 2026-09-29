-- WYNOS Web — Posting Activation Loop
-- Humane activation surfaces + two low-frequency Web Push loops:
-- 1) posting nudges for recently active people who have not posted
-- 2) batched updates when followed accounts publish new public posts
--
-- Release-gated: the cron is created inactive. Enable only after the matching
-- Web composer/service-worker/settings build is live and smoke-tested.

alter table public.notification_settings
  add column if not exists post_updates boolean not null default true,
  add column if not exists posting_prompts boolean not null default true,
  add column if not exists push_post_updates boolean not null default true,
  add column if not exists push_posting_prompts boolean not null default true;

create table if not exists public.posting_nudge_state (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  last_sent_at timestamptz,
  last_kind text check (last_kind in ('first_post','return_post')),
  lease_until timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.posting_nudge_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('first_post','return_post')),
  status text not null default 'claimed' check (status in ('claimed','sent','failed')),
  sent_at timestamptz,
  error text,
  created_at timestamptz not null default now()
);

create index if not exists posting_nudge_deliveries_user_created_idx
  on public.posting_nudge_deliveries(user_id, created_at desc);

create table if not exists public.followed_post_digest_state (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  cursor_at timestamptz not null default now(),
  last_sent_at timestamptz,
  lease_until timestamptz,
  pending_cursor_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.followed_post_digest_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_count integer not null check (post_count >= 1),
  author_count integer not null check (author_count >= 1),
  latest_drop_id uuid references public.drops(id) on delete set null,
  latest_author_id uuid references public.profiles(id) on delete set null,
  status text not null default 'claimed' check (status in ('claimed','sent','failed')),
  sent_at timestamptz,
  error text,
  created_at timestamptz not null default now()
);

create index if not exists followed_post_digest_deliveries_user_created_idx
  on public.followed_post_digest_deliveries(user_id, created_at desc);

alter table public.posting_nudge_state enable row level security;
alter table public.posting_nudge_deliveries enable row level security;
alter table public.followed_post_digest_state enable row level security;
alter table public.followed_post_digest_deliveries enable row level security;

revoke all on table public.posting_nudge_state from public, anon, authenticated;
revoke all on table public.posting_nudge_deliveries from public, anon, authenticated;
revoke all on table public.followed_post_digest_state from public, anon, authenticated;
revoke all on table public.followed_post_digest_deliveries from public, anon, authenticated;

insert into public.posting_nudge_state (user_id)
select id from public.profiles
on conflict (user_id) do nothing;

insert into public.followed_post_digest_state (user_id, cursor_at)
select id, now() from public.profiles
on conflict (user_id) do nothing;

create or replace function internal.enroll_posting_activity_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $posting_activity_enroll$
begin
  insert into public.posting_nudge_state(user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into public.followed_post_digest_state(user_id, cursor_at)
  values (new.id, now())
  on conflict (user_id) do nothing;

  return new;
end;
$posting_activity_enroll$;

revoke all on function internal.enroll_posting_activity_state() from public, anon, authenticated;

drop trigger if exists profiles_enroll_posting_activity on public.profiles;
create trigger profiles_enroll_posting_activity
after insert on public.profiles
for each row execute function internal.enroll_posting_activity_state();

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
        and not internal.is_posting_blocked(p.id)
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

create or replace function public.finish_posting_nudge(
  p_delivery_id uuid,
  p_success boolean,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $posting_nudge_finish$
declare
  v_user_id uuid;
  v_kind text;
begin
  select user_id, kind
  into v_user_id, v_kind
  from public.posting_nudge_deliveries
  where id = p_delivery_id
    and status = 'claimed'
  for update;

  if not found then return; end if;

  update public.posting_nudge_deliveries
  set status = case when p_success then 'sent' else 'failed' end,
      sent_at = case when p_success then now() else sent_at end,
      error = case when p_success then null else left(coalesce(p_error, 'unknown'), 300) end
  where id = p_delivery_id;

  update public.posting_nudge_state
  set last_sent_at = case when p_success then now() else last_sent_at end,
      last_kind = case when p_success then v_kind else last_kind end,
      lease_until = null,
      updated_at = now()
  where user_id = v_user_id;
end;
$posting_nudge_finish$;

revoke all on function public.finish_posting_nudge(uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.finish_posting_nudge(uuid, boolean, text) to service_role;

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
      and not internal.is_posting_blocked(d.author_id)
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

create or replace function public.finish_followed_post_digest(
  p_delivery_id uuid,
  p_success boolean,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $followed_digest_finish$
declare
  v_user_id uuid;
  v_pending_cursor timestamptz;
begin
  select d.user_id, s.pending_cursor_at
  into v_user_id, v_pending_cursor
  from public.followed_post_digest_deliveries d
  join public.followed_post_digest_state s on s.user_id = d.user_id
  where d.id = p_delivery_id
    and d.status = 'claimed'
  for update of d, s;

  if not found then return; end if;

  update public.followed_post_digest_deliveries
  set status = case when p_success then 'sent' else 'failed' end,
      sent_at = case when p_success then now() else sent_at end,
      error = case when p_success then null else left(coalesce(p_error, 'unknown'), 300) end
  where id = p_delivery_id;

  update public.followed_post_digest_state
  set cursor_at = case
        when p_success and v_pending_cursor is not null then greatest(cursor_at, v_pending_cursor)
        else cursor_at
      end,
      last_sent_at = case when p_success then now() else last_sent_at end,
      lease_until = null,
      pending_cursor_at = null,
      updated_at = now()
  where user_id = v_user_id;
end;
$followed_digest_finish$;

revoke all on function public.finish_followed_post_digest(uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.finish_followed_post_digest(uuid, boolean, text) to service_role;

create or replace function public.verify_posting_activity_cron_key(
  p_key text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $posting_activity_verify$
  select p_key is not null
     and length(p_key) >= 32
     and exists (
       select 1
       from vault.decrypted_secrets
       where name = 'wynos_posting_activity_cron_key'
         and decrypted_secret = p_key
     );
$posting_activity_verify$;

revoke all on function public.verify_posting_activity_cron_key(text) from public, anon, authenticated;
grant execute on function public.verify_posting_activity_cron_key(text) to service_role;

do $posting_activity_cron$
declare
  v_existing bigint;
  v_job bigint;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_extension where extname = 'pg_net') then
    select jobid into v_existing
    from cron.job
    where jobname = 'wynos-posting-activity'
    limit 1;

    if v_existing is not null then
      perform cron.unschedule(v_existing);
    end if;

    select cron.schedule(
      'wynos-posting-activity',
      '7,37 * * * *',
      $job$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'wynos_project_url'
          limit 1
        ) || '/functions/v1/send-posting-activity',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'X-Wynos-Cron-Key', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'wynos_posting_activity_cron_key'
            limit 1
          )
        ),
        body := '{"source":"pg_cron"}'::jsonb,
        timeout_milliseconds := 10000
      );
      $job$
    ) into v_job;

    perform cron.alter_job(job_id := v_job, active := false);
  end if;
end
$posting_activity_cron$;
