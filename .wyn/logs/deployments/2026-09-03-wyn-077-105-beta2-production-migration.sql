-- ============================================================
-- Wynos Beta2 production migration (WYN-077 through WYN-105)
-- ============================================================

-- ---- WYN-079: Undo for "hide post" ----
drop policy if exists "Users can delete their own feed signals" on public.feed_signals;
create policy "Users can delete their own feed signals"
  on public.feed_signals
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- ---- WYN-083: view counting -- drop dedup, count from first view,
-- include author, uncapped. Restructures drop_views from a
-- (drop_id, viewer_id) composite-PK dedup ledger into a plain
-- append-only event log. Existing rows are preserved -- only the
-- primary key changes shape, not the data itself.
alter table public.drop_views drop constraint if exists drop_views_pkey;
alter table public.drop_views add column if not exists id uuid not null default gen_random_uuid();
alter table public.drop_views add constraint drop_views_pkey primary key (id);

create index if not exists drop_views_drop_id_idx
  on public.drop_views (drop_id);

create or replace function public.record_drop_view(p_drop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_drop record;
  v_account_recent_count bigint;
  v_drop_recent_count bigint;
begin
  select * into v_drop from public.drops where id = p_drop_id;

  if v_drop is null or v_drop.deleted_at is not null then
    return;
  end if;

  select count(*) into v_account_recent_count
  from public.drop_views
  where viewer_id = v_me and created_at > now() - interval '60 seconds';
  if v_account_recent_count >= 20 then
    return;
  end if;

  select count(*) into v_drop_recent_count
  from public.drop_views
  where drop_id = p_drop_id and created_at > now() - interval '10 seconds';
  if v_drop_recent_count >= 50 then
    return;
  end if;

  insert into public.drop_views (drop_id, viewer_id)
  values (p_drop_id, v_me);
end;
$$;

-- ---- WYN-093: dynamic-height feed images ----
alter table public.drops add column if not exists image_width integer;
alter table public.drops add column if not exists image_height integer;
alter table public.drop_images add column if not exists image_width integer;
alter table public.drop_images add column if not exists image_height integer;

-- ---- WYN-103: image count limit 10 -> 9 (defense-in-depth at the DB,
-- matching the app's own _maxImages = 9) ----
--
-- Production incident (2026-09-03): applying these two constraints
-- without `not valid` failed with 23514 -- real production has
-- drops/club_posts predating the app's 9-image limit that already have
-- 9+/10 images. `not valid` enforces the constraint on every new
-- insert/update from here on (the actual goal, defense-in-depth for
-- new posts) without retroactively validating -- and therefore without
-- touching or rejecting -- any pre-existing row. No user data is
-- read, modified, or deleted by this constraint either way.
alter table public.club_posts drop constraint if exists club_posts_image_urls_length;
alter table public.club_posts
  add constraint club_posts_image_urls_length
  check (image_urls is null or array_length(image_urls, 1) between 1 and 9) not valid;

alter table public.drop_images drop constraint if exists drop_images_position_max_9;
alter table public.drop_images
  add constraint drop_images_position_max_9 check (position >= 0 and position < 9) not valid;

-- ---- WYN-097: Post Audience Selector + "friends" (mutual follow) +
-- Close Friends ----
alter table public.drops
  add column if not exists audience text not null default 'everyone'
  check (audience in ('everyone', 'friends', 'friends_except', 'close_friends', 'only_me'));

create or replace function internal.is_mutual_follow(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.follows where follower_id = a and following_id = b)
     and exists (select 1 from public.follows where follower_id = b and following_id = a);
$$;

create table if not exists public.close_friends (
  owner_id uuid not null references public.profiles (id) on delete cascade,
  friend_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, friend_id),
  constraint close_friends_no_self check (owner_id <> friend_id)
);

alter table public.close_friends enable row level security;

drop policy if exists "Owner views their own close friends list" on public.close_friends;
create policy "Owner views their own close friends list"
  on public.close_friends
  for select
  to authenticated
  using (auth.uid() = owner_id);

drop policy if exists "Owner adds a mutual follow as a close friend" on public.close_friends;
create policy "Owner adds a mutual follow as a close friend"
  on public.close_friends
  for insert
  to authenticated
  with check (auth.uid() = owner_id and internal.is_mutual_follow(owner_id, friend_id));

drop policy if exists "Owner removes a close friend" on public.close_friends;
create policy "Owner removes a close friend"
  on public.close_friends
  for delete
  to authenticated
  using (auth.uid() = owner_id);

create table if not exists public.drop_audience_exclusions (
  drop_id uuid not null references public.drops (id) on delete cascade,
  excluded_user_id uuid not null references public.profiles (id) on delete cascade,
  primary key (drop_id, excluded_user_id)
);

alter table public.drop_audience_exclusions enable row level security;

drop policy if exists "Drop author manages their own audience exclusions" on public.drop_audience_exclusions;
create policy "Drop author manages their own audience exclusions"
  on public.drop_audience_exclusions
  for all
  to authenticated
  using (auth.uid() = (select author_id from public.drops where id = drop_id))
  with check (auth.uid() = (select author_id from public.drops where id = drop_id));

create or replace function internal.can_view_drop_audience(p_viewer uuid, p_drop public.drops)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_drop.author_id = p_viewer
    or p_drop.audience = 'everyone'
    or (p_drop.audience = 'friends' and internal.is_mutual_follow(p_viewer, p_drop.author_id))
    or (p_drop.audience = 'friends_except'
        and internal.is_mutual_follow(p_viewer, p_drop.author_id)
        and not exists (
          select 1 from public.drop_audience_exclusions
          where drop_id = p_drop.id and excluded_user_id = p_viewer
        ))
    or (p_drop.audience = 'close_friends'
        and exists (
          select 1 from public.close_friends
          where owner_id = p_drop.author_id and friend_id = p_viewer
        ));
$$;

drop policy if exists "Drops are viewable by authenticated users, excluding blocked, deleted, and locked-private authors" on public.drops;
drop policy if exists "Drops are viewable by authenticated users, excluding blocked, deleted, locked-private authors, and out-of-audience" on public.drops;
create policy "Drops are viewable by authenticated users, excluding blocked, deleted, locked-private authors, and out-of-audience"
  on public.drops
  for select
  to authenticated
  using (
    not internal.is_blocked_either_way(auth.uid(), author_id)
    and (deleted_at is null or auth.uid() = author_id)
    and internal.can_view_author_content(auth.uid(), author_id)
    and internal.can_view_drop_audience(auth.uid(), drops.*)
  );

create or replace function public.get_poll_results(p_poll_ids uuid[])
returns table(
  poll_id uuid,
  visible boolean,
  total_votes bigint,
  option_counts bigint[]
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select
    dp.id as poll_id,
    v.is_visible,
    case when v.is_visible
      then (select count(*) from public.drop_poll_votes dpv where dpv.poll_id = dp.id)
      else null end as total_votes,
    case when v.is_visible
      then (
        select array_agg(cnt order by idx)
        from (
          select gs as idx, count(pv.id) as cnt
          from generate_series(0, array_length(dp.options, 1) - 1) as gs
          left join public.drop_poll_votes pv
            on pv.poll_id = dp.id and pv.option_index = gs
          group by gs
        ) counted
      )
      else null end as option_counts
  from public.drop_polls dp
  join public.drops d on d.id = dp.drop_id
  cross join lateral (
    select
      dp.expires_at <= now()
      or d.author_id = v_me
      or exists (
        select 1 from public.drop_poll_votes dpv2
        where dpv2.poll_id = dp.id and dpv2.voter_id = v_me
      ) as is_visible
  ) v
  where dp.id = any(p_poll_ids)
    and not internal.is_blocked_either_way(v_me, d.author_id)
    and internal.can_view_author_content(v_me, d.author_id)
    and internal.can_view_drop_audience(v_me, d);
end;
$$;

create or replace function public.fetch_mutual_follows(p_page int default 0)
returns setof public.profiles
language sql
stable
security invoker
set search_path = public
as $$
  select p.*
  from public.profiles p
  where internal.is_mutual_follow(auth.uid(), p.id)
  order by p.username
  offset greatest(p_page, 0) * 30 limit 30;
$$;

grant execute on function public.fetch_mutual_follows(int) to authenticated;

-- ---- WYN-099: Likes Tab Privacy ----
alter table public.profiles
  add column if not exists likes_visibility text not null default 'everyone'
  check (likes_visibility in ('everyone', 'friends', 'only_me'));

create or replace function internal.can_view_likes(p_viewer uuid, p_target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_viewer = p_target
    or (select likes_visibility from public.profiles where id = p_target) = 'everyone'
    or (
      (select likes_visibility from public.profiles where id = p_target) = 'friends'
      and internal.is_mutual_follow(p_viewer, p_target)
    );
$$;

create or replace function public.can_view_likes(p_target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select internal.can_view_likes(auth.uid(), p_target);
$$;

grant execute on function public.can_view_likes(uuid) to authenticated;

create or replace function public.fetch_liked_drop_ids(p_target_user_id uuid, p_page int default 0)
returns table(drop_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select dl.drop_id
  from public.drop_likes dl
  join public.drops d on d.id = dl.drop_id
  where dl.user_id = p_target_user_id
    and internal.can_view_likes(auth.uid(), p_target_user_id)
    and not internal.is_blocked_either_way(auth.uid(), d.author_id)
    and (d.deleted_at is null or auth.uid() = d.author_id)
    and internal.can_view_author_content(auth.uid(), d.author_id)
    and internal.can_view_drop_audience(auth.uid(), d)
  order by dl.created_at desc
  offset greatest(p_page, 0) * 21 limit 21;
$$;

grant execute on function public.fetch_liked_drop_ids(uuid, int) to authenticated;

create or replace function public.fetch_liked_pop_ids(p_target_user_id uuid, p_page int default 0)
returns table(pop_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select pl.pop_id
  from public.pop_likes pl
  join public.pops p on p.id = pl.pop_id
  where pl.user_id = p_target_user_id
    and internal.can_view_likes(auth.uid(), p_target_user_id)
    and not internal.is_blocked_either_way(auth.uid(), p.author_id)
  order by pl.created_at desc
  offset greatest(p_page, 0) * 21 limit 21;
$$;

grant execute on function public.fetch_liked_pop_ids(uuid, int) to authenticated;

-- ---- WYN-098: Location Check-in (LocationIQ) ----
alter table public.drops add column if not exists location_lat double precision;
alter table public.drops add column if not exists location_lon double precision;
alter table public.drops add column if not exists location_place_id text;

alter table public.drops drop constraint if exists drops_location_lat_lon_together;
alter table public.drops
  add constraint drops_location_lat_lon_together
  check ((location_lat is null) = (location_lon is null));

alter table public.drops drop constraint if exists drops_location_place_id_needs_name;
alter table public.drops
  add constraint drops_location_place_id_needs_name
  check (location_place_id is null or location is not null);

create table if not exists public.location_search_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  requested_at timestamptz not null default now()
);

alter table public.location_search_requests enable row level security;

create index if not exists location_search_requests_user_id_requested_at_idx
  on public.location_search_requests (user_id, requested_at desc);

-- create_poll_drop -- final signature (audience + location together;
-- this single CREATE OR REPLACE supersedes the WYN-097-only
-- intermediate version, so only the final one needs to be applied).
create or replace function public.create_poll_drop(
  p_caption text,
  p_options text[],
  p_duration_days int,
  p_mentioned_user_ids uuid[] default '{}',
  p_audience text default 'everyone',
  p_excluded_friend_ids uuid[] default '{}',
  p_location text default null,
  p_location_lat double precision default null,
  p_location_lon double precision default null,
  p_location_place_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid := auth.uid();
  v_drop_id uuid;
  v_options text[];
begin
  if v_author is null then
    raise exception 'Not authenticated';
  end if;

  if internal.is_posting_blocked(v_author) then
    raise exception 'Account is posting-restricted';
  end if;

  if p_caption is null or length(trim(p_caption)) = 0 then
    raise exception 'Poll question is required';
  end if;

  select array_agg(trim(o)) into v_options from unnest(p_options) as o;

  if not public.valid_poll_options(v_options) then
    raise exception 'Poll must have 2-4 non-empty, non-duplicate options (max 80 characters each)';
  end if;

  if p_duration_days not in (1, 3, 7) then
    raise exception 'Poll duration must be 1, 3, or 7 days';
  end if;

  if p_audience not in ('everyone', 'friends', 'friends_except', 'close_friends', 'only_me') then
    raise exception 'Invalid audience';
  end if;

  insert into public.drops (
    author_id, image_url, caption, audience,
    location, location_lat, location_lon, location_place_id
  )
  values (
    v_author, null, trim(p_caption), p_audience,
    p_location, p_location_lat, p_location_lon, p_location_place_id
  )
  returning id into v_drop_id;

  insert into public.drop_polls (drop_id, options, expires_at)
  values (v_drop_id, v_options, now() + make_interval(days => p_duration_days));

  if p_audience = 'friends_except' then
    insert into public.drop_audience_exclusions (drop_id, excluded_user_id)
    select v_drop_id, u
    from unnest(p_excluded_friend_ids) as u;
  end if;

  insert into public.drop_mentions (drop_id, mentioned_user_id)
  select v_drop_id, m
  from unnest(p_mentioned_user_ids) as m
  where not internal.is_blocked_either_way(v_author, m)
    and internal.mention_allowed(m, v_author);

  return v_drop_id;
end;
$$;

-- ---- Final home_feed redefinition (supersedes every earlier one --
-- adds image_width, image_height, audience, location, image_count as
-- the trailing 5 columns; every existing column/branch is otherwise
-- byte-for-byte identical to production's current definition) ----
create or replace view public.home_feed
  with (security_invoker = true) as
select
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  prof.is_verified as author_is_verified,
  d.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  public.drop_view_count(d.id) as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', lp.id,
      'username', lp.username,
      'display_name', lp.display_name,
      'avatar_url', lp.avatar_url
    ) order by dl.created_at desc), '[]'::jsonb)
    from (
      select user_id, created_at from public.drop_likes
      where drop_id = d.id
      order by created_at desc
      limit 3
    ) dl
    join public.profiles lp on lp.id = dl.user_id
  ) as liked_by,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  (
    select jsonb_build_object(
      'author_username', tr.author_username,
      'author_display_name', tr.author_display_name,
      'text', tr.text_content
    )
    from (
      select
        c.text_content,
        cp.username as author_username,
        cp.display_name as author_display_name,
        c.created_at,
        (select count(*) from public.drop_comment_likes dcl where dcl.comment_id = c.id) as like_count
      from public.drop_comments c
      join public.profiles cp on cp.id = c.author_id
      where c.drop_id = d.id and c.parent_comment_id is null
    ) tr
    where tr.like_count > 0
    order by tr.like_count desc, tr.created_at desc
    limit 1
  ) as top_reply,
  (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
  null::uuid as redrop_id,
  null::uuid as redropper_id,
  null::text as redropper_username,
  null::text as redropper_display_name,
  null::text as redropper_avatar_url,
  null::boolean as redropper_is_verified,
  null::text as quote_text,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at,
  d.image_width,
  d.image_height,
  d.audience,
  d.location,
  (select count(*) from public.drop_images where drop_id = d.id) as image_count
from public.drops d
join public.profiles prof on prof.id = d.author_id
left join public.drop_polls dp on dp.drop_id = d.id
where not exists (
  select 1 from public.mutes where muter_id = auth.uid() and muted_id = d.author_id
)
union all
select
  p.id,
  'pop'::text as content_type,
  p.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  prof.is_verified as author_is_verified,
  p.created_at,
  p.caption,
  null::text as image_url,
  p.video_url,
  p.thumbnail_url,
  p.duration_seconds,
  p.view_count,
  (select count(*) from public.pop_likes where pop_id = p.id) as like_count,
  (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', lp.id,
      'username', lp.username,
      'display_name', lp.display_name,
      'avatar_url', lp.avatar_url
    ) order by pl.created_at desc), '[]'::jsonb)
    from (
      select user_id, created_at from public.pop_likes
      where pop_id = p.id
      order by created_at desc
      limit 3
    ) pl
    join public.profiles lp on lp.id = pl.user_id
  ) as liked_by,
  (select count(*) from public.pop_comments where pop_id = p.id) as comment_count,
  (
    select jsonb_build_object(
      'author_username', tr.author_username,
      'author_display_name', tr.author_display_name,
      'text', tr.text_content
    )
    from (
      select
        c.text_content,
        cp.username as author_username,
        cp.display_name as author_display_name,
        c.created_at,
        (select count(*) from public.pop_comment_likes dcl where dcl.comment_id = c.id) as like_count
      from public.pop_comments c
      join public.profiles cp on cp.id = c.author_id
      where c.pop_id = p.id and c.parent_comment_id is null
    ) tr
    where tr.like_count > 0
    order by tr.like_count desc, tr.created_at desc
    limit 1
  ) as top_reply,
  null::bigint as redrop_count,
  null::uuid as redrop_id,
  null::uuid as redropper_id,
  null::text as redropper_username,
  null::text as redropper_display_name,
  null::text as redropper_avatar_url,
  null::boolean as redropper_is_verified,
  null::text as quote_text,
  null::uuid as poll_id,
  null::text[] as poll_options,
  null::timestamptz as poll_expires_at,
  null::integer as image_width,
  null::integer as image_height,
  'everyone'::text as audience,
  null::text as location,
  null::bigint as image_count
from public.pops p
join public.profiles prof on prof.id = p.author_id
where not exists (
  select 1 from public.mutes where muter_id = auth.uid() and muted_id = p.author_id
)
union all
select
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  prof.is_verified as author_is_verified,
  r.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  public.drop_view_count(d.id) as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', lp.id,
      'username', lp.username,
      'display_name', lp.display_name,
      'avatar_url', lp.avatar_url
    ) order by dl.created_at desc), '[]'::jsonb)
    from (
      select user_id, created_at from public.drop_likes
      where drop_id = d.id
      order by created_at desc
      limit 3
    ) dl
    join public.profiles lp on lp.id = dl.user_id
  ) as liked_by,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  (
    select jsonb_build_object(
      'author_username', tr.author_username,
      'author_display_name', tr.author_display_name,
      'text', tr.text_content
    )
    from (
      select
        c.text_content,
        cp.username as author_username,
        cp.display_name as author_display_name,
        c.created_at,
        (select count(*) from public.drop_comment_likes dcl where dcl.comment_id = c.id) as like_count
      from public.drop_comments c
      join public.profiles cp on cp.id = c.author_id
      where c.drop_id = d.id and c.parent_comment_id is null
    ) tr
    where tr.like_count > 0
    order by tr.like_count desc, tr.created_at desc
    limit 1
  ) as top_reply,
  (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
  r.id as redrop_id,
  r.redropper_id,
  redropper.username as redropper_username,
  redropper.display_name as redropper_display_name,
  redropper.avatar_url as redropper_avatar_url,
  redropper.is_verified as redropper_is_verified,
  r.quote_text,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at,
  d.image_width,
  d.image_height,
  d.audience,
  d.location,
  (select count(*) from public.drop_images where drop_id = d.id) as image_count
from public.redrops r
join public.drops d on d.id = r.drop_id
join public.profiles prof on prof.id = d.author_id
join public.profiles redropper on redropper.id = r.redropper_id
left join public.drop_polls dp on dp.drop_id = d.id
where not exists (
  select 1 from public.mutes
  where muter_id = auth.uid() and muted_id in (d.author_id, r.redropper_id)
);

grant select on public.home_feed to authenticated;

select 'MIGRATION APPLIED OK' as status;
