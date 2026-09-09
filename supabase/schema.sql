-- WYN V0.1 — profiles table (WYN-002 Authentication & Onboarding)
-- Run this in the Supabase SQL editor (or via `supabase db push`) for every
-- environment (dev/staging/prod) before the app can authenticate users.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text unique,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Usernames are public within WYN once set, so any authenticated user can
-- read any profile row (needed for the username-availability check).
create policy "Profiles are viewable by authenticated users"
  on public.profiles
  for select
  to authenticated
  using (true);

-- A user may only create their own profile row.
create policy "Users can insert their own profile"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

-- A user may only update their own profile row.
create policy "Users can update their own profile"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id);

-- WYN-003 (User Profile) — display name, bio, avatar
-- Run once per environment after the WYN-002 statements above.

alter table public.profiles
  add column if not exists display_name text,
  add column if not exists bio text,
  add column if not exists avatar_url text;

alter table public.profiles
  add constraint profiles_display_name_length
  check (display_name is null or char_length(display_name) between 1 and 50);

alter table public.profiles
  add constraint profiles_bio_length
  check (bio is null or char_length(bio) <= 160);

-- Avatar images: public bucket (usernames/avatars are public within WYN),
-- but each user may only write to their own folder ({user_id}/...).
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "Avatar images are publicly accessible"
  on storage.objects
  for select
  using (bucket_id = 'avatars');

create policy "Users can upload their own avatar"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their own avatar"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- WYN-005 (Drop) — drops, drop_likes, drop_comments, saves
-- Run once per environment after the WYN-002/003 statements above.
--
-- author_id references public.profiles (not auth.users directly) so
-- PostgREST can embed author info in one query (e.g.
-- `.select('*, author:profiles(username, display_name, avatar_url)')`)
-- instead of doing a separate profile lookup per row -- image_url is
-- required (not null) -- a Drop is always a photo, per the Product spec.

create table if not exists public.drops (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  image_url text not null,
  caption text,
  -- WYN-019: free-text location, not a structured place lookup -- no UI
  -- reads or writes this column yet, schema-only prep per the Founder's
  -- "เตรียมโครงสร้างไว้สำหรับอนาคต" request.
  location text,
  created_at timestamptz not null default now(),
  constraint drops_caption_length
    check (caption is null or char_length(caption) between 1 and 500)
);

alter table public.drops enable row level security;

create policy "Drops are viewable by authenticated users"
  on public.drops
  for select
  to authenticated
  using (true);

create policy "Users can create their own drops"
  on public.drops
  for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Users can delete their own drops"
  on public.drops
  for delete
  to authenticated
  using (auth.uid() = author_id);

create table if not exists public.drop_likes (
  drop_id uuid not null references public.drops (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (drop_id, user_id)
);

alter table public.drop_likes enable row level security;

create policy "Drop likes are viewable by authenticated users"
  on public.drop_likes
  for select
  to authenticated
  using (true);

create policy "Users can like drops as themselves"
  on public.drop_likes
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can remove their own drop likes"
  on public.drop_likes
  for delete
  to authenticated
  using (auth.uid() = user_id);

create table if not exists public.drop_comments (
  id uuid primary key default gen_random_uuid(),
  drop_id uuid not null references public.drops (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  text_content text not null,
  created_at timestamptz not null default now(),
  -- WYN-022: null = top-level comment, set = a reply to that comment.
  -- Depth capped at 1 level by prevent_nested_drop_comment_reply below
  -- (a CHECK can't run the self-referencing subquery that needs).
  parent_comment_id uuid references public.drop_comments (id) on delete cascade,
  constraint drop_comments_text_content_length
    check (char_length(text_content) between 1 and 500)
);

alter table public.drop_comments enable row level security;

create policy "Drop comments are viewable by authenticated users"
  on public.drop_comments
  for select
  to authenticated
  using (true);

create policy "Users can comment on drops as themselves"
  on public.drop_comments
  for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Users can delete their own drop comments"
  on public.drop_comments
  for delete
  to authenticated
  using (auth.uid() = author_id);

create table if not exists public.drop_comment_likes (
  comment_id uuid not null references public.drop_comments (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

alter table public.drop_comment_likes enable row level security;

create policy "Drop comment likes are viewable by authenticated users"
  on public.drop_comment_likes
  for select
  to authenticated
  using (true);

create policy "Users can like drop comments as themselves"
  on public.drop_comment_likes
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can remove their own drop comment likes"
  on public.drop_comment_likes
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- Saved content: shared across content types (drops now, pops later per
-- WYN-011, club posts per WYN-014) via content_type + content_id instead
-- of a per-type FK, so adding a new content type never needs another
-- migration. Unlike likes/comments, a user's saved list is private
-- (Instagram/Twitter convention) -- select is restricted to your own
-- rows, not select-all-authenticated.
create table if not exists public.saves (
  user_id uuid not null references public.profiles (id) on delete cascade,
  content_type text not null check (content_type in ('drop', 'pop', 'club_post')),
  content_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (user_id, content_type, content_id)
);

alter table public.saves enable row level security;

create policy "Users can view their own saves"
  on public.saves
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can save content as themselves"
  on public.saves
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can remove their own saves"
  on public.saves
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- Drop images: public bucket, each user may only write to their own
-- folder ({user_id}/...), same pattern as the avatars bucket.
insert into storage.buckets (id, name, public)
values ('drop-images', 'drop-images', true)
on conflict (id) do nothing;

create policy "Drop images are publicly accessible"
  on storage.objects
  for select
  using (bucket_id = 'drop-images');

create policy "Users can upload their own drop images"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'drop-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- WYN-006 (Pop) — pops, pop_likes, pop_comments, pop_comment_likes
-- Run once per environment after the WYN-005 statements above.
--
-- Same shape as drops/drop_likes/drop_comments/drop_comment_likes
-- (including comment likes and comment ownership-based delete from the
-- start -- WYN-005 shipped without those twice and failed QA twice for
-- it, see .wyn/learning/MISTAKES.md). video_url is required (not null)
-- the same way image_url is required for drops -- a Pop is always a
-- video. view_count is a simple counter column (no per-user dedup in
-- this round, see .wyn/tasks/active/WYN-006-pop-short-video.md Risks).

create table if not exists public.pops (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  video_url text not null,
  thumbnail_url text,
  caption text,
  duration_seconds integer not null,
  view_count bigint not null default 0,
  created_at timestamptz not null default now(),
  constraint pops_caption_length
    check (caption is null or char_length(caption) between 1 and 500),
  constraint pops_duration_seconds_range
    check (duration_seconds > 0 and duration_seconds <= 60)
);

alter table public.pops enable row level security;

create policy "Pops are viewable by authenticated users"
  on public.pops
  for select
  to authenticated
  using (true);

create policy "Users can create their own pops"
  on public.pops
  for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Users can delete their own pops"
  on public.pops
  for delete
  to authenticated
  using (auth.uid() = author_id);

-- No update policy for view_count -- incrementing views goes through the
-- increment_pop_view_count() function below (security definer), not a
-- direct client update, so a user can't set an arbitrary view_count.
create or replace function public.increment_pop_view_count(pop_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.pops set view_count = view_count + 1 where id = pop_id;
$$;

create table if not exists public.pop_likes (
  pop_id uuid not null references public.pops (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (pop_id, user_id)
);

alter table public.pop_likes enable row level security;

create policy "Pop likes are viewable by authenticated users"
  on public.pop_likes
  for select
  to authenticated
  using (true);

create policy "Users can like pops as themselves"
  on public.pop_likes
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can remove their own pop likes"
  on public.pop_likes
  for delete
  to authenticated
  using (auth.uid() = user_id);

create table if not exists public.pop_comments (
  id uuid primary key default gen_random_uuid(),
  pop_id uuid not null references public.pops (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  text_content text not null,
  created_at timestamptz not null default now(),
  -- WYN-022: same reply-depth-1 design as drop_comments.parent_comment_id.
  parent_comment_id uuid references public.pop_comments (id) on delete cascade,
  constraint pop_comments_text_content_length
    check (char_length(text_content) between 1 and 500)
);

alter table public.pop_comments enable row level security;

create policy "Pop comments are viewable by authenticated users"
  on public.pop_comments
  for select
  to authenticated
  using (true);

create policy "Users can comment on pops as themselves"
  on public.pop_comments
  for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Users can delete their own pop comments"
  on public.pop_comments
  for delete
  to authenticated
  using (auth.uid() = author_id);

create table if not exists public.pop_comment_likes (
  comment_id uuid not null references public.pop_comments (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

alter table public.pop_comment_likes enable row level security;

create policy "Pop comment likes are viewable by authenticated users"
  on public.pop_comment_likes
  for select
  to authenticated
  using (true);

create policy "Users can like pop comments as themselves"
  on public.pop_comment_likes
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can remove their own pop comment likes"
  on public.pop_comment_likes
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- Pop videos: public bucket, each user may only write to their own
-- folder ({user_id}/...), same pattern as drop-images. Thumbnails share
-- the same bucket under a {user_id}/thumb_... naming convention rather
-- than a separate bucket -- same RLS shape either way, no need for a
-- second bucket just to split video bytes from a JPEG.
insert into storage.buckets (id, name, public)
values ('pop-videos', 'pop-videos', true)
on conflict (id) do nothing;

create policy "Pop videos are publicly accessible"
  on storage.objects
  for select
  using (bucket_id = 'pop-videos');

create policy "Users can upload their own pop videos"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'pop-videos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- WYN-007 (Home) — home_feed view
-- Run once per environment after the WYN-006 statements above.
--
-- Home needs one chronologically-paginatable result set spanning both
-- drops and pops. Fetching a page of each separately and merging/sorting
-- them client-side breaks pagination correctness across multiple pages
-- (two independent cursors can't be combined into one consistent "page
-- N" without re-deriving it every time) -- see
-- .wyn/tasks/backlog/WYN-007-home-feed.md, Risks. A single UNION ALL
-- view lets the client paginate with one order()/range() call, same as
-- every other feed in the app.
--
-- security_invoker = true makes the view respect the querying user's own
-- RLS instead of running with the view owner's privileges (Postgres 15+).
-- Functionally this doesn't currently change what's visible -- both
-- drops and pops already select-all-authenticated -- but it's the
-- correct default for a view over RLS-protected tables and avoids
-- silently depending on owner-bypasses-RLS behavior.
--
-- Like/comment counts are correlated subqueries per row rather than a
-- join, since each half of the union needs a different pair of count
-- tables (drop_likes/drop_comments vs pop_likes/pop_comments) -- fine at
-- V0.1 scale, revisit if the feed ever needs to paginate over a very
-- large N.
create or replace view public.home_feed
  with (security_invoker = true) as
select
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  d.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  null::bigint as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count
from public.drops d
join public.profiles prof on prof.id = d.author_id
union all
select
  p.id,
  'pop'::text as content_type,
  p.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  p.created_at,
  p.caption,
  null::text as image_url,
  p.video_url,
  p.thumbnail_url,
  p.duration_seconds,
  p.view_count,
  (select count(*) from public.pop_likes where pop_id = p.id) as like_count,
  (select count(*) from public.pop_comments where pop_id = p.id) as comment_count
from public.pops p
join public.profiles prof on prof.id = p.author_id;

grant select on public.home_feed to authenticated;

-- WYN-008 (Follow system) -- follows a user (not content), shared by
-- both Drop and Pop per the Founder's confirmation that Follow is one
-- system, not per-content-type. See .wyn/tasks/approved/WYN-008-follow-system.md.
create table if not exists public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  following_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint follows_no_self_follow check (follower_id <> following_id)
);

alter table public.follows enable row level security;

create policy "Follows are viewable by authenticated users"
  on public.follows
  for select
  to authenticated
  using (true);

create policy "Users can follow others as themselves"
  on public.follows
  for insert
  to authenticated
  with check (auth.uid() = follower_id);

create policy "Users can remove their own follows"
  on public.follows
  for delete
  to authenticated
  using (auth.uid() = follower_id);

-- WYN-013 (Profile V2) -- unifies a user's saved Drop/Pop into one
-- chronologically-orderable result set, sorted by *when it was saved*
-- (saves.created_at), not when the content itself was posted. Mirrors
-- home_feed's UNION ALL approach (WYN-007) for the same reason: naive
-- client-side merging of two paginated queries breaks pagination
-- correctness across multiple pages. security_invoker = true matters
-- here specifically -- saves.select is already restricted to
-- auth.uid() = user_id, and the view must keep enforcing that (a
-- user's Saved tab must never be visible to anyone else), not run with
-- the view owner's RLS-bypassing privileges.
create or replace view public.saved_feed
  with (security_invoker = true) as
select
  s.user_id,
  s.created_at as saved_at,
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  d.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  null::bigint as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count
from public.saves s
join public.drops d on d.id = s.content_id and s.content_type = 'drop'
join public.profiles prof on prof.id = d.author_id
union all
select
  s.user_id,
  s.created_at as saved_at,
  p.id,
  'pop'::text as content_type,
  p.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  p.created_at,
  p.caption,
  null::text as image_url,
  p.video_url,
  p.thumbnail_url,
  p.duration_seconds,
  p.view_count,
  (select count(*) from public.pop_likes where pop_id = p.id) as like_count,
  (select count(*) from public.pop_comments where pop_id = p.id) as comment_count
from public.saves s
join public.pops p on p.id = s.content_id and s.content_type = 'pop'
join public.profiles prof on prof.id = p.author_id;

grant select on public.saved_feed to authenticated;

-- WYN-012 (Notification) -- a real table populated by triggers, not a
-- derived view like home_feed/saved_feed. Those views work because they
-- only ever represent "current state of the world" -- nothing to read is
-- ever mutated per-viewer. A notification is different: it's a historical
-- record that needs its own durable per-row state (is_read) alongside it,
-- which a view has nowhere to store. Triggers (rather than having each
-- Flutter repository insert a notification row itself after the action it
-- performs) guarantee a notification is created every time the underlying
-- event happens, regardless of which client code path caused it --
-- there's no way for a future change to DropRepository/PopRepository/
-- FollowRepository to forget the notification side-effect, because the
-- side-effect isn't the client's job at all.
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  -- Nullable (WYN-029 fix, see .wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md):
  -- every other notification type always supplies a real actor, but
  -- apply_moderation_action()'s Warning/Remove Content effects
  -- deliberately insert NULL here -- the reviewing moderator's identity
  -- must never be reachable by the target, and RLS on this table is
  -- row-level (auth.uid() = recipient_id), not column-level, so there is
  -- no way to hide one column of an otherwise-visible row via policy.
  -- The real reviewer identity stays correctly recorded, client-
  -- unreachable, in moderation_actions.reviewer_id.
  actor_id uuid references public.profiles (id) on delete cascade,
  type text not null
    check (type in (
      'like_drop', 'like_pop', 'comment_drop', 'comment_pop', 'follow',
      -- WYN-015: club_join_request/club_join_approved reference the
      -- club itself (club_id); club_post_like/club_post_comment
      -- reference the post (club_post_id), same as drop_id/pop_id do
      -- for their respective types.
      'club_join_request', 'club_join_approved', 'club_post_like', 'club_post_comment'
    )),
  drop_id uuid references public.drops (id) on delete cascade,
  pop_id uuid references public.pops (id) on delete cascade,
  -- club_id/club_post_id are added later via `alter table` (WYN-015,
  -- see below `public.club_posts`) instead of being declared inline
  -- here, because `public.clubs`/`public.club_posts` don't exist yet
  -- at this point in the file -- see SCHEMA-001 bug report.
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- Supports both the notification list's own pagination (recipient_id,
-- created_at) and the unread-count badge query (recipient_id, is_read),
-- which is called every time Home opens -- see
-- .wyn/tasks/backlog/WYN-012-notification.md, Risks.
create index if not exists notifications_recipient_created_idx
  on public.notifications (recipient_id, created_at desc);
create index if not exists notifications_recipient_unread_idx
  on public.notifications (recipient_id, is_read);

alter table public.notifications enable row level security;

-- Private to the recipient only -- same "select is restricted to your
-- own rows" shape as saves (WYN-005), not select-all-authenticated like
-- drops/pops/follows.
create policy "Users can view their own notifications"
  on public.notifications
  for select
  to authenticated
  using (auth.uid() = recipient_id);

-- The only client-initiated write: mark-all-as-read (WYN-012's Design
-- spec, Screen 2) flips is_read, nothing else.
create policy "Users can mark their own notifications as read"
  on public.notifications
  for update
  to authenticated
  using (auth.uid() = recipient_id)
  with check (auth.uid() = recipient_id);

-- Deliberately no insert/delete policy for clients -- rows are only ever
-- created by the security-definer trigger functions below (which bypass
-- RLS the same way increment_pop_view_count, WYN-006, does) and removed
-- automatically via on delete cascade when the underlying content/user
-- is deleted. A client attempting to insert or delete a notification
-- directly is rejected by RLS since no policy grants it.

create or replace function public.notify_drop_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  select author_id into v_author_id from public.drops where id = new.drop_id;
  -- Liking your own Drop is normal and allowed -- it just shouldn't
  -- notify you about your own action.
  if v_author_id is not null and v_author_id <> new.user_id
     and internal.notification_enabled(v_author_id, 'likes') then
    insert into public.notifications (recipient_id, actor_id, type, drop_id)
    values (v_author_id, new.user_id, 'like_drop', new.drop_id);
  end if;
  return new;
end;
$$;

create trigger drop_likes_notify
  after insert on public.drop_likes
  for each row execute function public.notify_drop_like();

create or replace function public.notify_pop_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  select author_id into v_author_id from public.pops where id = new.pop_id;
  if v_author_id is not null and v_author_id <> new.user_id
     and internal.notification_enabled(v_author_id, 'likes') then
    insert into public.notifications (recipient_id, actor_id, type, pop_id)
    values (v_author_id, new.user_id, 'like_pop', new.pop_id);
  end if;
  return new;
end;
$$;

create trigger pop_likes_notify
  after insert on public.pop_likes
  for each row execute function public.notify_pop_like();

create or replace function public.notify_drop_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  select author_id into v_author_id from public.drops where id = new.drop_id;
  if v_author_id is not null and v_author_id <> new.author_id
     and internal.notification_enabled(v_author_id, 'comments') then
    insert into public.notifications (recipient_id, actor_id, type, drop_id)
    values (v_author_id, new.author_id, 'comment_drop', new.drop_id);
  end if;
  return new;
end;
$$;

create trigger drop_comments_notify
  after insert on public.drop_comments
  for each row execute function public.notify_drop_comment();

create or replace function public.notify_pop_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  select author_id into v_author_id from public.pops where id = new.pop_id;
  if v_author_id is not null and v_author_id <> new.author_id
     and internal.notification_enabled(v_author_id, 'comments') then
    insert into public.notifications (recipient_id, actor_id, type, pop_id)
    values (v_author_id, new.author_id, 'comment_pop', new.pop_id);
  end if;
  return new;
end;
$$;

create trigger pop_comments_notify
  after insert on public.pop_comments
  for each row execute function public.notify_pop_comment();

-- No self-notification guard needed here (unlike the four triggers
-- above) -- follows_no_self_follow (WYN-008) already makes
-- follower_id = following_id impossible to insert in the first place,
-- so this trigger can never fire with new.follower_id = new.following_id.
create or replace function public.notify_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if internal.notification_enabled(new.following_id, 'follows') then
    insert into public.notifications (recipient_id, actor_id, type)
    values (new.following_id, new.follower_id, 'follow');
  end if;
  return new;
end;
$$;

create trigger follows_notify
  after insert on public.follows
  for each row execute function public.notify_follow();

-- WYN-014 (Club Core) — clubs, club_members, club_posts,
-- club_post_likes, club_post_comments
-- Run once per environment after all statements above.
--
-- This is the project's first role-based permission system (Follow, by
-- contrast, is a plain boolean relationship with no role concept).
-- club_members.role/status need durable per-row mutable state that
-- only a real table (not a view) can hold, and every role/status
-- transition (approve/reject/set-role/remove/ban) is funneled through
-- security-definer RPC functions rather than raw UPDATE RLS -- the
-- permission graph (who can act on whom, at what role) is complex
-- enough that encoding it as WITH CHECK clauses would need deeply
-- nested EXISTS subqueries per action, which is hard for QA to verify
-- and easy to get subtly wrong. See club_role() and the five RPC
-- functions below (same security-definer-RPC-over-raw-RLS pattern as
-- increment_pop_view_count, WYN-006).

create table if not exists public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  rules text,
  icon_url text,
  cover_url text,
  -- Nullable: the Design spec (Screen 2) treats Category the same as
  -- Description/Cover/Icon -- optional at creation, only Name + Privacy
  -- are required.
  category text,
  privacy text not null check (privacy in ('public', 'private')),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint clubs_name_length check (char_length(name) between 1 and 50),
  constraint clubs_description_length
    check (description is null or char_length(description) <= 500),
  constraint clubs_rules_length
    check (rules is null or char_length(rules) <= 2000)
);

-- Ownership transfer is out of scope this round (see the Product spec's
-- Risks section), so owner_id must never change after creation --
-- otherwise an Owner/Admin using the "Edit Club Info" update policy
-- below could silently reassign ownership to themselves via a normal
-- client-side update() call. Enforced with a trigger rather than a
-- WITH CHECK clause because RLS's default WITH CHECK (falling back to
-- USING when unspecified) only re-checks club_role() against the row's
-- id, not whether owner_id itself was tampered with.
create or replace function public.clubs_prevent_owner_id_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id <> old.owner_id then
    raise exception 'Changing club owner_id directly is not supported';
  end if;
  return new;
end;
$$;

create trigger clubs_prevent_owner_id_change
  before update on public.clubs
  for each row execute function public.clubs_prevent_owner_id_change();

create table if not exists public.club_members (
  club_id uuid not null references public.clubs (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner', 'admin', 'moderator', 'member')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'banned')),
  created_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

-- Hybrid Home source generation starts from the viewer and finds their
-- approved clubs before joining other approved members. The primary key has
-- club_id first, so this inverse lookup needs its own index to avoid scanning
-- all memberships on every feed refresh.
create index if not exists club_members_user_status_club_idx
  on public.club_members (user_id, status, club_id);

-- Single reusable authorization primitive for every Club RLS policy
-- below (clubs, club_members, club_posts, club_post_likes,
-- club_post_comments, and the club-media storage policies): returns
-- the caller's role for a club if they have an approved membership
-- row, else null. security definer + table-owner-bypasses-RLS (the
-- same mechanism the notify_* trigger functions above already rely on
-- to write into notifications despite no insert policy existing) lets
-- this run from *inside* club_members' own SELECT policies without
-- the self-referential-subquery recursion a raw EXISTS-against-
-- club_members-from-within-club_members'-own-policy would cause.
create or replace function public.club_role(p_club_id uuid, p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.club_members
  where club_id = p_club_id and user_id = p_user_id and status = 'approved';
$$;

alter table public.clubs enable row level security;

create policy "Clubs are viewable by authenticated users"
  on public.clubs
  for select
  to authenticated
  using (true);

create policy "Users can create clubs as themselves"
  on public.clubs
  for insert
  to authenticated
  with check (auth.uid() = owner_id);

create policy "Club owners and admins can update club info"
  on public.clubs
  for update
  to authenticated
  using (public.club_role(id, auth.uid()) in ('owner', 'admin'));

alter table public.club_members enable row level security;

-- Three SELECT policies (RLS OR's every matching policy together):
-- (1) your own row is always visible regardless of status, so a
-- pending requester can see their own "รออนุมัติ" state; (2) other
-- approved members' rows are visible to any approved member of the
-- same club (Members tab); (3) pending rows belonging to *other*
-- people are visible only to that club's owner/admin (the "คำขอเข้าร่วม"
-- section on the Members tab).
create policy "Users can view their own membership row"
  on public.club_members
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Approved members can view other approved members"
  on public.club_members
  for select
  to authenticated
  using (
    status = 'approved'
    and public.club_role(club_id, auth.uid()) is not null
  );

create policy "Club owners and admins can view pending requests"
  on public.club_members
  for select
  to authenticated
  using (
    status = 'pending'
    and public.club_role(club_id, auth.uid()) in ('owner', 'admin')
  );

-- Self-insert only, always role = 'member' (Owner's membership is
-- created exclusively by the clubs_add_owner_membership trigger below,
-- and Admin/Moderator are only ever granted via set_club_member_role(),
-- never at insert time). status is cross-checked against the target
-- club's actual privacy so a client can't insert itself pre-approved
-- into a Private club: approved only if the club is public, pending
-- only if the club is private. A previously banned user re-attempting
-- to join collides with their existing (club_id, user_id) primary key
-- and is rejected by the unique constraint, not by this policy.
create policy "Users can request or join clubs as themselves"
  on public.club_members
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and role = 'member'
    and (
      (status = 'approved' and exists (
        select 1 from public.clubs where id = club_id and privacy = 'public'
      ))
      or
      (status = 'pending' and exists (
        select 1 from public.clubs where id = club_id and privacy = 'private'
      ))
    )
  );

-- Self-leave only, and the Owner may not leave (no ownership transfer
-- or club deletion in scope this round, so a leaving Owner would strand
-- the club with no one able to manage it).
create policy "Members can leave a club themselves"
  on public.club_members
  for delete
  to authenticated
  using (auth.uid() = user_id and role <> 'owner');

-- Deliberately no UPDATE policy at all: every role/status transition
-- (approve/reject/set-role/remove/ban) goes through the security
-- definer RPC functions below instead, so a client can never issue a
-- raw PostgREST update() against club_members no matter what values it
-- sends.

create or replace function public.clubs_add_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.club_members (club_id, user_id, role, status)
  values (new.id, new.owner_id, 'owner', 'approved');
  return new;
end;
$$;

create trigger clubs_add_owner_membership
  after insert on public.clubs
  for each row execute function public.clubs_add_owner_membership();

-- Five RPC functions cover every club_members role/status mutation.
-- Each re-derives the caller's role via club_role() itself (never
-- trusts a role/status passed in from the client) and blocks
-- self-targeting and owner-targeting up front. NULL-safety note: every
-- permission check below either (a) branches on a positive role match
-- with a trailing `else raise exception` (NULL never matches a
-- positive branch, so it always falls through to the raise), or (b)
-- explicitly coalesces club_role()'s possible NULL before a `not in`
-- check -- `null not in (...)` evaluates to NULL, not true, which would
-- silently skip the exception and let a total stranger through.

create or replace function public.approve_club_member(
  p_club_id uuid,
  p_target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(public.club_role(p_club_id, auth.uid()), '') not in ('owner', 'admin') then
    raise exception 'Not permitted to approve members for this club';
  end if;

  update public.club_members
  set status = 'approved'
  where club_id = p_club_id
    and user_id = p_target_user_id
    and status = 'pending';

  if not found then
    raise exception 'No pending request found for this member';
  end if;
end;
$$;

create or replace function public.reject_club_member(
  p_club_id uuid,
  p_target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(public.club_role(p_club_id, auth.uid()), '') not in ('owner', 'admin') then
    raise exception 'Not permitted to reject members for this club';
  end if;

  delete from public.club_members
  where club_id = p_club_id
    and user_id = p_target_user_id
    and status = 'pending';

  if not found then
    raise exception 'No pending request found for this member';
  end if;
end;
$$;

-- Owner: may set admin/moderator/member on any non-owner approved
-- member. Admin: may set moderator/member only, and only on targets
-- who are not themselves currently Admin (an Admin can never touch
-- another Admin, and can never grant Admin -- both Owner-only per the
-- Product spec).
create or replace function public.set_club_member_role(
  p_club_id uuid,
  p_target_user_id uuid,
  p_new_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_target_role text;
begin
  if p_target_user_id = auth.uid() then
    raise exception 'Cannot change your own role';
  end if;

  if p_new_role not in ('admin', 'moderator', 'member') then
    raise exception 'Invalid role';
  end if;

  v_caller_role := public.club_role(p_club_id, auth.uid());

  select role into v_target_role
  from public.club_members
  where club_id = p_club_id and user_id = p_target_user_id and status = 'approved';

  if v_target_role is null then
    raise exception 'Target is not an approved member of this club';
  end if;

  if v_target_role = 'owner' then
    raise exception 'Cannot change the role of the club owner';
  end if;

  if v_caller_role = 'owner' then
    null;
  elsif v_caller_role = 'admin'
      and v_target_role <> 'admin'
      and p_new_role <> 'admin' then
    null;
  else
    raise exception 'Not permitted to change this member''s role';
  end if;

  update public.club_members
  set role = p_new_role
  where club_id = p_club_id and user_id = p_target_user_id;
end;
$$;

-- Shared permission boundary for remove/ban: Owner/Admin may act on
-- Moderator/Member (but Admin may never act on another Admin);
-- Moderator may act only on plain Members. Both always block
-- self-targeting and owner-targeting.
create or replace function public.remove_club_member(
  p_club_id uuid,
  p_target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_target_role text;
begin
  if p_target_user_id = auth.uid() then
    raise exception 'Cannot remove yourself -- leave the club instead';
  end if;

  v_caller_role := public.club_role(p_club_id, auth.uid());

  select role into v_target_role
  from public.club_members
  where club_id = p_club_id and user_id = p_target_user_id and status = 'approved';

  if v_target_role is null then
    raise exception 'Target is not an approved member of this club';
  end if;

  if v_target_role = 'owner' then
    raise exception 'Cannot remove the club owner';
  end if;

  if v_caller_role in ('owner', 'admin') and v_target_role <> 'admin' then
    null;
  elsif v_caller_role = 'moderator' and v_target_role = 'member' then
    null;
  else
    raise exception 'Not permitted to remove this member';
  end if;

  delete from public.club_members
  where club_id = p_club_id and user_id = p_target_user_id;
end;
$$;

create or replace function public.ban_club_member(
  p_club_id uuid,
  p_target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_target_role text;
begin
  if p_target_user_id = auth.uid() then
    raise exception 'Cannot ban yourself';
  end if;

  v_caller_role := public.club_role(p_club_id, auth.uid());

  select role into v_target_role
  from public.club_members
  where club_id = p_club_id and user_id = p_target_user_id and status = 'approved';

  if v_target_role is null then
    raise exception 'Target is not an approved member of this club';
  end if;

  if v_target_role = 'owner' then
    raise exception 'Cannot ban the club owner';
  end if;

  if v_caller_role in ('owner', 'admin') and v_target_role <> 'admin' then
    null;
  elsif v_caller_role = 'moderator' and v_target_role = 'member' then
    null;
  else
    raise exception 'Not permitted to ban this member';
  end if;

  update public.club_members
  set status = 'banned'
  where club_id = p_club_id and user_id = p_target_user_id;
end;
$$;

create table if not exists public.club_posts (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  content text,
  image_urls text[],
  link_url text,
  pinned boolean not null default false,
  created_at timestamptz not null default now(),
  constraint club_posts_content_length
    check (content is null or char_length(content) between 1 and 2000),
  -- WYN-103 (Wynos V1.0.0 Beta2, item 15, 2026-09-02): was "between 1
  -- and 10" -- lowered to 9 to match _maxImages everywhere a post can
  -- carry images (CreateDropScreen already used 9; this table's own
  -- limit was the one place still inconsistent). Production still has
  -- the old "between 1 and 10" constraint until AI Deploy & DevOps
  -- applies the matching `alter table public.club_posts drop
  -- constraint club_posts_image_urls_length, add constraint
  -- club_posts_image_urls_length check (image_urls is null or
  -- array_length(image_urls, 1) between 1 and 9);` -- safe to apply
  -- any time since the UI has capped this at 10 (soon 9) for every row
  -- that could ever have been inserted, so no existing row can violate
  -- the tighter bound.
  constraint club_posts_image_urls_length
    check (image_urls is null or array_length(image_urls, 1) between 1 and 9),
  -- A club post needs at least one of text, images, or a link -- no
  -- completely empty post allowed.
  constraint club_posts_have_content
    check (content is not null or image_urls is not null or link_url is not null)
);

alter table public.club_posts enable row level security;

create policy "Approved club members can view club posts"
  on public.club_posts
  for select
  to authenticated
  using (public.club_role(club_id, auth.uid()) is not null);

create policy "Approved club members can create club posts as themselves"
  on public.club_posts
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and public.club_role(club_id, auth.uid()) is not null
  );

create policy "Post authors and club staff can delete club posts"
  on public.club_posts
  for delete
  to authenticated
  using (
    auth.uid() = author_id
    or public.club_role(club_id, auth.uid()) in ('owner', 'admin', 'moderator')
  );

-- Pin/unpin is the only client-facing mutation on an existing club
-- post. Not column-restricted at the RLS level (this project doesn't
-- do column-level RLS anywhere -- see posts/drops/pops), so this
-- policy technically permits club staff to update any column on any
-- post in the club, not just `pinned`; the client only ever sends a
-- `pinned` patch.
create policy "Club staff can pin or unpin club posts"
  on public.club_posts
  for update
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin', 'moderator'));

create table if not exists public.club_post_likes (
  club_post_id uuid not null references public.club_posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (club_post_id, user_id)
);

alter table public.club_post_likes enable row level security;

create policy "Approved club members can view club post likes"
  on public.club_post_likes
  for select
  to authenticated
  using (
    exists (
      select 1 from public.club_posts cp
      where cp.id = club_post_id
        and public.club_role(cp.club_id, auth.uid()) is not null
    )
  );

create policy "Approved club members can like club posts as themselves"
  on public.club_post_likes
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.club_posts cp
      where cp.id = club_post_id
        and public.club_role(cp.club_id, auth.uid()) is not null
    )
  );

create policy "Users can remove their own club post likes"
  on public.club_post_likes
  for delete
  to authenticated
  using (auth.uid() = user_id);

create table if not exists public.club_post_comments (
  id uuid primary key default gen_random_uuid(),
  club_post_id uuid not null references public.club_posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  text_content text not null,
  created_at timestamptz not null default now(),
  -- WYN-022: same reply-depth-1 design as drop_comments.parent_comment_id.
  parent_comment_id uuid references public.club_post_comments (id) on delete cascade,
  constraint club_post_comments_text_content_length
    check (char_length(text_content) between 1 and 500)
);

alter table public.club_post_comments enable row level security;

create policy "Approved club members can view club post comments"
  on public.club_post_comments
  for select
  to authenticated
  using (
    exists (
      select 1 from public.club_posts cp
      where cp.id = club_post_id
        and public.club_role(cp.club_id, auth.uid()) is not null
    )
  );

create policy "Approved club members can comment on club posts as themselves"
  on public.club_post_comments
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and exists (
      select 1 from public.club_posts cp
      where cp.id = club_post_id
        and public.club_role(cp.club_id, auth.uid()) is not null
    )
  );

create policy "Users can delete their own club post comments"
  on public.club_post_comments
  for delete
  to authenticated
  using (auth.uid() = author_id);

-- Club media: unlike avatars/drop-images/pop-videos (all
-- public buckets), club-media must be non-public -- club posts are
-- members-only-visible at the DB layer (club_posts select policy
-- above), and a fully public bucket would let anyone with a
-- guessed/leaked URL bypass that privacy boundary entirely (a gap
-- Drop/Pop never had, since their content has no privacy boundary to
-- begin with). Path shape: {club_id}/cover.*, {club_id}/icon.*
-- (1 folder segment -- visible to any authenticated user, matching the
-- Design spec's non-member Club Page preview) vs
-- {club_id}/posts/{user_id}-{timestamp}-{n}.* (>1 folder segment --
-- visible only to approved members; the exact nested path only needs to
-- be >1 segment deep, the middle segment's contents don't matter to
-- these policies).
--
-- Also unlike the public buckets, cover_url/icon_url/image_urls store
-- storage *paths* in their DB columns, not display URLs -- the Dart
-- repository layer (ClubRepository/ClubPostRepository) mints a fresh
-- signed URL per read instead, since a stable public URL would bypass
-- the RLS checks below entirely once cached/shared.
insert into storage.buckets (id, name, public)
values ('club-media', 'club-media', false)
on conflict (id) do nothing;

create policy "Club cover and icon images are visible to authenticated users"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'club-media'
    and array_length(storage.foldername(name), 1) = 1
  );

create policy "Club post images are visible to approved club members"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'club-media'
    and array_length(storage.foldername(name), 1) > 1
    and public.club_role(((storage.foldername(name))[1])::uuid, auth.uid()) is not null
  );

create policy "Club owners and admins can upload cover and icon images"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'club-media'
    and array_length(storage.foldername(name), 1) = 1
    and public.club_role(((storage.foldername(name))[1])::uuid, auth.uid()) in ('owner', 'admin')
  );

create policy "Approved club members can upload post images"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'club-media'
    and array_length(storage.foldername(name), 1) > 1
    and public.club_role(((storage.foldername(name))[1])::uuid, auth.uid()) is not null
  );

-- WYN-015 (Club Discovery & Integration) — 4 new notification types
-- reusing the `notifications` table from WYN-012. Must be declared
-- after clubs/club_members/club_posts/club_post_likes/
-- club_post_comments exist (unlike the WYN-012 trigger functions,
-- which only ever needed drops/pops/follows).
--
-- club_id/club_post_id themselves are added here via `alter table`
-- rather than back in the original `create table public.notifications`
-- block (WYN-012, far above) for the same reason: `public.clubs`/
-- `public.club_posts` don't exist yet at that point in the file.
-- Running schema.sql top-to-bottom against a genuinely empty database
-- previously failed at the `notifications` table with
-- `relation "public.clubs" does not exist` because those columns were
-- declared inline instead -- see SCHEMA-001 bug report. No index or
-- check constraint was ever attached to these columns, so nothing else
-- needs to move alongside them.
alter table public.notifications
  add column if not exists club_id uuid references public.clubs (id) on delete cascade;
alter table public.notifications
  add column if not exists club_post_id uuid references public.club_posts (id) on delete cascade;

-- Unlike every other notification trigger in the project (which always
-- inserts exactly one row -- one actor acting on one piece of content
-- owned by one person), a join request needs to reach *every*
-- Owner/Admin of the club, not just one recipient. Guards the requester
-- out of the recipient list explicitly for defense-in-depth, even
-- though structurally impossible today (an approved owner/admin
-- already has a club_members row and couldn't insert a second, so
-- cm.user_id can never equal new.user_id here in practice).
create or replace function public.notify_club_join_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (recipient_id, actor_id, type, club_id)
  select cm.user_id, new.user_id, 'club_join_request', new.club_id
  from public.club_members cm
  where cm.club_id = new.club_id
    and cm.role in ('owner', 'admin')
    and cm.status = 'approved'
    and cm.user_id <> new.user_id
    and internal.notification_enabled(cm.user_id, 'club');
  return new;
end;
$$;

create trigger club_members_notify_join_request
  after insert on public.club_members
  for each row
  when (new.status = 'pending')
  execute function public.notify_club_join_request();

-- Fires on the pending->approved transition made by approve_club_member()
-- (WYN-014). The actor here is whoever called that RPC (the
-- approver), not a column on the club_members row itself (the row's
-- own user_id is the *requester*, the notification's recipient) --
-- auth.uid() still resolves to the original calling user inside this
-- trigger even though approve_club_member() runs as security definer,
-- since that only changes the executing role, not the request-scoped
-- JWT claims auth.uid() reads from.
create or replace function public.notify_club_join_approved()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if internal.notification_enabled(new.user_id, 'club') then
    insert into public.notifications (recipient_id, actor_id, type, club_id)
    values (new.user_id, auth.uid(), 'club_join_approved', new.club_id);
  end if;
  return new;
end;
$$;

create trigger club_members_notify_join_approved
  after update on public.club_members
  for each row
  when (old.status = 'pending' and new.status = 'approved')
  execute function public.notify_club_join_approved();

-- Same shape as notify_drop_like/notify_pop_like (WYN-012). Also
-- denormalizes club_id onto the notification row (not just
-- club_post_id) so the Dart layer can embed the club's name with a
-- single-level join (`club:clubs(name)`) the same way for every WYN-015
-- notification type, instead of needing a two-hop
-- notifications->club_posts->clubs embed just for these two types.
create or replace function public.notify_club_post_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
  v_club_id uuid;
begin
  select author_id, club_id into v_author_id, v_club_id
  from public.club_posts where id = new.club_post_id;
  if v_author_id is not null and v_author_id <> new.user_id
     and internal.notification_enabled(v_author_id, 'club') then
    insert into public.notifications (recipient_id, actor_id, type, club_post_id, club_id)
    values (v_author_id, new.user_id, 'club_post_like', new.club_post_id, v_club_id);
  end if;
  return new;
end;
$$;

create trigger club_post_likes_notify
  after insert on public.club_post_likes
  for each row execute function public.notify_club_post_like();

-- Same shape as notify_drop_comment/notify_pop_comment (WYN-012), same
-- club_id denormalization reasoning as notify_club_post_like above.
create or replace function public.notify_club_post_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
  v_club_id uuid;
begin
  select author_id, club_id into v_author_id, v_club_id
  from public.club_posts where id = new.club_post_id;
  if v_author_id is not null and v_author_id <> new.author_id
     and internal.notification_enabled(v_author_id, 'club') then
    insert into public.notifications (recipient_id, actor_id, type, club_post_id, club_id)
    values (v_author_id, new.author_id, 'club_post_comment', new.club_post_id, v_club_id);
  end if;
  return new;
end;
$$;

create trigger club_post_comments_notify
  after insert on public.club_post_comments
  for each row execute function public.notify_club_post_comment();

-- ============================================================
-- WYN-016: Push Notification
-- ============================================================
-- One row per signed-in device -- the client upserts here (see
-- PushTokenRepository, both apps) whenever it obtains/refreshes an FCM
-- token, independent of the `notifications` table this feeds off of.
-- `token` is globally unique (not per-user-unique): the common upsert
-- case is the *same* user re-registering the *same* token (app
-- relaunch, defensive re-sync) -- RLS's update policy below allows
-- that because the existing row's user_id already matches auth.uid().
-- It deliberately does NOT allow a *different* user's upsert to
-- retarget someone else's still-present row to themselves (the
-- policy's `using` clause checks the pre-existing row's owner, which
-- would still be the old user) -- that would let one account silently
-- claim another's device-token row via RLS, which is exactly the kind
-- of cross-user write RLS exists to prevent. A shared/reused device
-- whose FCM token outlives a sign-out is handled by the client
-- deleting its own token row on sign-out (allowed -- the deleting user
-- still owns it at that point), so the next user's plain insert never
-- conflicts. See .wyn/docs/design/wyn-016-push-notifications.md.
--
-- Delivery itself (notifications INSERT -> Edge Function -> FCM) is
-- wired via a Supabase Database Webhook configured in the Dashboard,
-- deliberately not a SQL trigger in this file -- `supabase_functions.
-- http_request()` (the mechanism behind Database Webhooks) doesn't
-- exist on a plain Postgres instance, which would break this file's
-- "verified by running against a real local Postgres" QA guarantee
-- that's held for every other section. See that same design doc for
-- the one-time Dashboard setup step this requires from the Founder.
create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists push_tokens_user_id_idx on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;

-- No public/authenticated-wide select -- only the owner can even see
-- their own registered devices (device tokens are sensitive, unlike
-- almost everything else in this schema which defaults to select-all-
-- authenticated). The Edge Function reads across all users' tokens via
-- the service-role key, which bypasses RLS entirely, same as every
-- other security-definer-adjacent server-side path in this file.
create policy "Users can view their own push tokens"
  on public.push_tokens
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can register their own push tokens"
  on public.push_tokens
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Covers the "same token, different account now signed in" retarget
-- case described above -- an upsert on the `token` unique constraint
-- becomes an UPDATE, which needs its own policy distinct from insert.
create policy "Users can update their own push tokens"
  on public.push_tokens
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their own push tokens"
  on public.push_tokens
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- ============================================================
-- WYN-021: Mention System
-- ============================================================
-- Unlike hashtags (WYN-020, which stayed ILIKE-only because a false
-- positive there is harmless), a mention notification firing at the
-- wrong person is a real, visible mistake -- so this needs a real
-- entity table recording exactly who was mentioned, not a substring
-- match. Populated by the client right after the drops/club_posts
-- insert succeeds, from MentionInput's already-resolved user-id set
-- (not re-parsed from the caption server-side). See
-- .wyn/docs/design/wyn-021-mention-system.md.
create table if not exists public.drop_mentions (
  id uuid primary key default gen_random_uuid(),
  drop_id uuid not null references public.drops (id) on delete cascade,
  mentioned_user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint drop_mentions_unique unique (drop_id, mentioned_user_id)
);

alter table public.drop_mentions enable row level security;

create policy "Mentions are viewable by authenticated users"
  on public.drop_mentions
  for select
  to authenticated
  using (true);

-- Only the Drop's own author can record a mention against it -- the
-- client sends this immediately after creating the Drop it belongs to.
create policy "Drop authors can mention users in their own drops"
  on public.drop_mentions
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.drops
      where drops.id = drop_id and drops.author_id = auth.uid()
    )
  );

create table if not exists public.club_post_mentions (
  id uuid primary key default gen_random_uuid(),
  club_post_id uuid not null references public.club_posts (id) on delete cascade,
  mentioned_user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint club_post_mentions_unique unique (club_post_id, mentioned_user_id)
);

alter table public.club_post_mentions enable row level security;

-- WYN-021 bug fix (see .wyn/tasks/bugs/WYN-021-club-post-mentions-rls-gap.md):
-- unlike drop_mentions above (correctly `using (true)`, because drops
-- themselves have no privacy boundary), club_post_mentions must be
-- gated by club membership -- club_posts are members-only-visible at
-- the DB layer (WYN-014's invariant), and this policy originally
-- shipped as `using (true)`, letting any authenticated user read a
-- private Club post's id and who was mentioned in it without ever
-- being a member. Mirrors club_post_likes'/club_post_comments' select
-- policy shape exactly.
create policy "Approved club members can view club post mentions"
  on public.club_post_mentions
  for select
  to authenticated
  using (
    exists (
      select 1 from public.club_posts cp
      where cp.id = club_post_id
        and public.club_role(cp.club_id, auth.uid()) is not null
    )
  );

create policy "Club post authors can mention users in their own posts"
  on public.club_post_mentions
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.club_posts
      where club_posts.id = club_post_id and club_posts.author_id = auth.uid()
    )
  );

-- Same dynamic-constraint-name lookup as every prior notifications.type
-- widening in this file -- never hardcode a guessed constraint name.
do $$
declare
  v_constraint_name text;
begin
  select tc.constraint_name into v_constraint_name
  from information_schema.table_constraints tc
  join information_schema.constraint_column_usage ccu
    on ccu.constraint_name = tc.constraint_name
   and ccu.constraint_schema = tc.constraint_schema
  where tc.table_schema = 'public'
    and tc.table_name = 'notifications'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'type'
  limit 1;

  if v_constraint_name is not null then
    execute format('alter table public.notifications drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'like_drop', 'like_pop', 'comment_drop', 'comment_pop', 'follow',
    'club_join_request', 'club_join_approved', 'club_post_like', 'club_post_comment',
    'mention_drop', 'mention_club_post'
  ));

-- Actor is the post's author (they wrote the mention); recipient is the
-- mentioned user. Mirrors notify_drop_like()'s exact shape, including
-- the self-notification guard (mentioning yourself is a harmless no-op,
-- not blocked, just silent).
create or replace function public.notify_drop_mention()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  select author_id into v_author_id from public.drops where id = new.drop_id;
  if v_author_id is not null and new.mentioned_user_id <> v_author_id
     and internal.notification_enabled(new.mentioned_user_id, 'comments') then
    insert into public.notifications (recipient_id, actor_id, type, drop_id)
    values (new.mentioned_user_id, v_author_id, 'mention_drop', new.drop_id);
  end if;
  return new;
end;
$$;

create trigger drop_mentions_notify
  after insert on public.drop_mentions
  for each row execute function public.notify_drop_mention();

-- club_id is denormalized onto the notification row the same way
-- notify_club_post_like/notify_club_post_comment already do (see those
-- two functions above) -- NotificationRepository joins club:clubs(name)
-- through this column, and mentionClubPost's message text needs the
-- club name.
create or replace function public.notify_club_post_mention()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
  v_club_id uuid;
begin
  select author_id, club_id into v_author_id, v_club_id
  from public.club_posts where id = new.club_post_id;
  if v_author_id is not null and new.mentioned_user_id <> v_author_id
     and internal.notification_enabled(new.mentioned_user_id, 'club') then
    insert into public.notifications (recipient_id, actor_id, type, club_post_id, club_id)
    values (new.mentioned_user_id, v_author_id, 'mention_club_post', new.club_post_id, v_club_id);
  end if;
  return new;
end;
$$;

create trigger club_post_mentions_notify
  after insert on public.club_post_mentions
  for each row execute function public.notify_club_post_mention();

-- ============================================================
-- WYN-022: Comment Reply
-- ============================================================
-- parent_comment_id itself was added inline on each comment table's own
-- `create table` above (self-referencing FK, no forward-reference
-- issue). These three triggers are the actual depth-1 enforcement -- a
-- CHECK constraint can't run the self-referencing subquery needed to
-- ask "does my parent already have a parent". See
-- .wyn/docs/design/wyn-022-comment-reply.md.
create or replace function public.prevent_nested_drop_comment_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_is_reply boolean;
begin
  if new.parent_comment_id is not null then
    select parent_comment_id is not null into v_parent_is_reply
    from public.drop_comments where id = new.parent_comment_id;
    if v_parent_is_reply then
      raise exception 'Cannot reply to a reply -- only one level of nesting is allowed';
    end if;
  end if;
  return new;
end;
$$;

create trigger drop_comments_prevent_nested_reply
  before insert on public.drop_comments
  for each row execute function public.prevent_nested_drop_comment_reply();

create or replace function public.prevent_nested_pop_comment_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_is_reply boolean;
begin
  if new.parent_comment_id is not null then
    select parent_comment_id is not null into v_parent_is_reply
    from public.pop_comments where id = new.parent_comment_id;
    if v_parent_is_reply then
      raise exception 'Cannot reply to a reply -- only one level of nesting is allowed';
    end if;
  end if;
  return new;
end;
$$;

create trigger pop_comments_prevent_nested_reply
  before insert on public.pop_comments
  for each row execute function public.prevent_nested_pop_comment_reply();

create or replace function public.prevent_nested_club_post_comment_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_is_reply boolean;
begin
  if new.parent_comment_id is not null then
    select parent_comment_id is not null into v_parent_is_reply
    from public.club_post_comments where id = new.parent_comment_id;
    if v_parent_is_reply then
      raise exception 'Cannot reply to a reply -- only one level of nesting is allowed';
    end if;
  end if;
  return new;
end;
$$;

create trigger club_post_comments_prevent_nested_reply
  before insert on public.club_post_comments
  for each row execute function public.prevent_nested_club_post_comment_reply();

-- ============================================================
-- WYN-026: Report System
-- ============================================================
-- Universal report table (User/Drop/Comment/Club/Club Post today,
-- Message reserved for WYN-031/032 Phase 2 -- see the Product spec's
-- Requirements). target_id is polymorphic (no FK -- the referenced
-- table depends on target_type), so integrity is enforced entirely by
-- submit_report() below rather than at the column level. See
-- .wyn/docs/design/wyn-026-report-system.md.
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null
    check (target_type in (
      'user', 'drop', 'drop_comment', 'club', 'club_post',
      'club_post_comment', 'message'
    )),
  target_id uuid not null,
  category text not null
    check (category in (
      'spam', 'scam', 'harassment', 'hate', 'sexual_content', 'violence',
      'privacy', 'illegal_content', 'copyright', 'other'
    )),
  detail text,
  status text not null default 'pending'
    check (status in ('pending', 'reviewing', 'actioned', 'dismissed')),
  created_at timestamptz not null default now(),
  -- "Other" requires a written reason; every other category leaves it
  -- optional (Product spec, Requirements > ขั้นตอนรายงาน).
  constraint reports_other_requires_detail
    check (category <> 'other' or (detail is not null and length(trim(detail)) > 0))
);

-- One open case per (reporter, target) at a time. A plain UNIQUE
-- constraint would block re-reporting forever once a case closes, so
-- this is a partial index scoped to the still-open statuses instead --
-- matches the Product spec's "1 target ต่อ 1 reporter ส่งได้ครั้งเดียว
-- จนกว่าจะถูกปิดเคส" rule.
create unique index if not exists reports_reporter_target_open_unique
  on public.reports (reporter_id, target_type, target_id)
  where status in ('pending', 'reviewing');

alter table public.reports enable row level security;

-- A reporter can see only their own submitted reports (so the UI can
-- show "รายงานแล้ว" instead of the report form for a target they've
-- already reported). Nobody -- including the person being reported --
-- can see who reported what or how many reports exist against them;
-- moderator/admin visibility into the full queue is added by WYN-029,
-- not here.
create policy "Users can view their own submitted reports"
  on public.reports
  for select
  to authenticated
  using (auth.uid() = reporter_id);

-- Deliberately no insert policy: every report is created through
-- submit_report() below, which validates the target actually exists
-- and isn't the reporter's own content/profile before inserting -- a
-- client can never write a reports row via a raw insert() call no
-- matter what target_id it sends. Same reasoning as club_members
-- having no update policy (see above).
create or replace function public.submit_report(
  p_target_type text,
  p_target_id uuid,
  p_category text,
  p_detail text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reporter uuid := auth.uid();
  v_report_id uuid;
begin
  if v_reporter is null then
    raise exception 'Not authenticated';
  end if;

  if p_target_type = 'user' then
    if p_target_id = v_reporter then
      raise exception 'Cannot report yourself';
    end if;
    if not exists (select 1 from public.profiles where id = p_target_id) then
      raise exception 'Target user not found';
    end if;
  elsif p_target_type = 'drop' then
    if not exists (
      select 1 from public.drops
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Drop not found, or is your own';
    end if;
  elsif p_target_type = 'drop_comment' then
    if not exists (
      select 1 from public.drop_comments
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Comment not found, or is your own';
    end if;
  elsif p_target_type = 'club' then
    if not exists (
      select 1 from public.clubs
      where id = p_target_id and owner_id <> v_reporter
    ) then
      raise exception 'Club not found, or is your own';
    end if;
  elsif p_target_type = 'club_post' then
    if not exists (
      select 1 from public.club_posts
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Club post not found, or is your own';
    end if;
  elsif p_target_type = 'club_post_comment' then
    if not exists (
      select 1 from public.club_post_comments
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Club post comment not found, or is your own';
    end if;
  elsif p_target_type = 'message' then
    -- WYN-031: security definer bypasses messages' participant-only
    -- SELECT policy on purpose here (same reasoning as every other
    -- branch above) -- the caller must still actually be a
    -- participant of the message's conversation, checked explicitly
    -- via the join below, not implied by RLS.
    if not exists (
      select 1 from public.messages m
      join public.conversations c on c.id = m.conversation_id
      where m.id = p_target_id
        and m.sender_id <> v_reporter
        and v_reporter in (c.user_a_id, c.user_b_id)
    ) then
      raise exception 'Message not found, is your own, or you are not a participant';
    end if;
  else
    raise exception 'Unsupported report target type: %', p_target_type;
  end if;

  insert into public.reports (reporter_id, target_type, target_id, category, detail)
  values (
    v_reporter,
    p_target_type,
    p_target_id,
    p_category,
    nullif(trim(coalesce(p_detail, '')), '')
  )
  returning id into v_report_id;

  return v_report_id;
exception
  when unique_violation then
    raise exception 'You have already reported this';
end;
$$;

grant execute on function public.submit_report(text, uuid, text, text) to authenticated;

-- ============================================================
-- WYN-027: Block System
-- ============================================================
-- See .wyn/docs/design/wyn-027-block-system.md ("ภาพรวมแนวทาง") --
-- enforcement lives here, at the data layer, not as bespoke UI-side
-- filtering scattered across every screen.
create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_no_self_block check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

-- A user can list only the blocks *they* created (their own Blocked
-- List, WYN-027 Design Screen 5) -- nobody can see who has blocked
-- them via a raw select, only through block_relationship() below,
-- which reveals just the relationship *kind*, not a browsable list.
create policy "Users can view blocks they created"
  on public.blocks
  for select
  to authenticated
  using (auth.uid() = blocker_id);

-- Deliberately no insert/delete policy: every block/unblock goes
-- through block_user()/unblock_user() below, which also tears down
-- any existing Follow relationship atomically on block -- same
-- reasoning as club_members having no update policy (see above).

-- `internal` holds helper functions that must be callable from *within*
-- RLS policies (which run as role `authenticated`) but must NEVER be
-- directly callable as a client-facing RPC. Putting a function in
-- `public` is not enough for that on its own: PostgREST auto-exposes
-- every function in its configured schema list (`public` by default)
-- as `POST /rest/v1/rpc/<name>` purely based on the function's EXECUTE
-- ACL, and Postgres grants EXECUTE to PUBLIC by default on function
-- creation, so omitting a `grant`/`revoke` statement does NOT make a
-- `public`-schema function internal-only (see WYN-027 bug report,
-- `.wyn/tasks/bugs/WYN-027-is-blocked-either-way-rpc-exposure.md`, for
-- the exact leak this caused, and why a plain `revoke execute ... from
-- authenticated` does not work either -- it breaks the RLS policies
-- themselves, since a policy's `using`/`with check` clause is evaluated
-- under the querying role's own privileges). `internal` is never added
-- to PostgREST's exposed-schema list, so nothing in it is reachable
-- over the REST API regardless of its SQL-level GRANTs -- the schema
-- boundary is the actual protection, not the ACL.
create schema if not exists internal;
grant usage on schema internal to authenticated;

-- Single reusable authorization primitive used by every RLS policy
-- below (drops/pops/club_posts/*_comments/*_likes/follows/mentions)
-- to test "is there a block between these two people, in either
-- direction". security definer so it can run from inside those
-- policies without needing a broader select policy on blocks itself
-- that would otherwise leak who-blocked-whom to the blocked party.
-- Lives in `internal`, not `public` -- see the schema comment above:
-- both parties are caller-supplied free parameters (unlike
-- block_relationship() below, which always resolves the caller's own
-- relationship via auth.uid()), so if this were reachable as a client
-- RPC it would let anyone probe any two arbitrary users' block status.
create or replace function internal.is_blocked_either_way(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

grant execute on function internal.is_blocked_either_way(uuid, uuid) to authenticated;

-- security definer author-lookups for the *_likes/*_comments INSERT
-- policies below (Interaction defense-in-depth) -- deliberately NOT
-- inlined as a raw `exists (select 1 from public.drops d where
-- d.id = drop_id and is_blocked_either_way(...))` subquery, because
-- that subquery would itself run under the *inserting* role and be
-- subject to drops' own (now block-aware) SELECT policy: if the
-- author is blocked, the row is invisible to that subquery too, so
-- "does a blocked-author row exist" would always find nothing and
-- the NOT EXISTS guard would incorrectly pass. Same self-referential
-- trap club_role() above already solves for club_members -- these
-- functions bypass RLS via security definer so the author id comes
-- back regardless of the caller's own visibility into that row.
create or replace function internal.drop_author_id(p_drop_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select author_id from public.drops where id = p_drop_id;
$$;

grant execute on function internal.drop_author_id(uuid) to authenticated;

create or replace function internal.pop_author_id(p_pop_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select author_id from public.pops where id = p_pop_id;
$$;

grant execute on function internal.pop_author_id(uuid) to authenticated;

create or replace function internal.drop_comment_author_id(p_comment_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select author_id from public.drop_comments where id = p_comment_id;
$$;

grant execute on function internal.drop_comment_author_id(uuid) to authenticated;

create or replace function internal.pop_comment_author_id(p_comment_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select author_id from public.pop_comments where id = p_comment_id;
$$;

grant execute on function internal.pop_comment_author_id(uuid) to authenticated;

-- Exposed to the client (unlike is_blocked_either_way) so
-- ViewProfileScreen's Blocked persona (WYN-027 Design, Screen 3) can
-- tell "I blocked them" apart from "they blocked me" for its banner
-- copy, and its More menu (Screen 1) can decide whether to offer
-- "บล็อก" at all.
create or replace function public.block_relationship(p_other_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when exists (select 1 from public.blocks where blocker_id = auth.uid() and blocked_id = p_other_user_id)
     and exists (select 1 from public.blocks where blocker_id = p_other_user_id and blocked_id = auth.uid())
      then 'mutual'
    when exists (select 1 from public.blocks where blocker_id = auth.uid() and blocked_id = p_other_user_id)
      then 'blocked_by_me'
    when exists (select 1 from public.blocks where blocker_id = p_other_user_id and blocked_id = auth.uid())
      then 'blocked_me'
    else 'none'
  end;
$$;

grant execute on function public.block_relationship(uuid) to authenticated;

-- Blocking someone also severs any existing Follow relationship
-- between them, both directions, atomically -- Product spec's
-- Requirements: "ยกเลิก Follow ทั้งสองทิศทางทันทีที่ Block สำเร็จ".
create or replace function public.block_user(p_target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_blocker uuid := auth.uid();
begin
  if v_blocker is null then
    raise exception 'Not authenticated';
  end if;
  if p_target_user_id = v_blocker then
    raise exception 'Cannot block yourself';
  end if;
  if not exists (select 1 from public.profiles where id = p_target_user_id) then
    raise exception 'Target user not found';
  end if;

  insert into public.blocks (blocker_id, blocked_id)
  values (v_blocker, p_target_user_id)
  on conflict (blocker_id, blocked_id) do nothing;

  delete from public.follows
  where (follower_id = v_blocker and following_id = p_target_user_id)
     or (follower_id = p_target_user_id and following_id = v_blocker);
end;
$$;

grant execute on function public.block_user(uuid) to authenticated;

-- Unblock is one-directional and self-scoped by definition (a client
-- can only ever delete a blocks row it owns as blocker_id = auth.uid()
-- -- there is nothing to authorize beyond that, so this stays a plain
-- delete rather than needing its own RLS policy). Per Product spec,
-- the Follow relationship that existed before the block is *not*
-- restored automatically.
create or replace function public.unblock_user(p_target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.blocks
  where blocker_id = auth.uid() and blocked_id = p_target_user_id;
end;
$$;

grant execute on function public.unblock_user(uuid) to authenticated;

-- ------------------------------------------------------------
-- Content visibility: hide a blocked-either-way author's Drop/Pop and
-- their comments on *anyone's* content, both directions.
-- ------------------------------------------------------------
drop policy "Drops are viewable by authenticated users" on public.drops;
create policy "Drops are viewable by authenticated users, excluding blocked authors"
  on public.drops
  for select
  to authenticated
  using (not internal.is_blocked_either_way(auth.uid(), author_id));

drop policy "Drop comments are viewable by authenticated users" on public.drop_comments;
create policy "Drop comments are viewable by authenticated users, excluding blocked authors"
  on public.drop_comments
  for select
  to authenticated
  using (not internal.is_blocked_either_way(auth.uid(), author_id));

drop policy "Pops are viewable by authenticated users" on public.pops;
create policy "Pops are viewable by authenticated users, excluding blocked authors"
  on public.pops
  for select
  to authenticated
  using (not internal.is_blocked_either_way(auth.uid(), author_id));

drop policy "Pop comments are viewable by authenticated users" on public.pop_comments;
create policy "Pop comments are viewable by authenticated users, excluding blocked authors"
  on public.pop_comments
  for select
  to authenticated
  using (not internal.is_blocked_either_way(auth.uid(), author_id));

drop policy "Approved club members can view club posts" on public.club_posts;
create policy "Approved club members can view club posts, excluding blocked authors"
  on public.club_posts
  for select
  to authenticated
  using (
    public.club_role(club_id, auth.uid()) is not null
    and not internal.is_blocked_either_way(auth.uid(), author_id)
  );

drop policy "Approved club members can view club post comments" on public.club_post_comments;
create policy "Approved club members can view club post comments, excluding blocked authors"
  on public.club_post_comments
  for select
  to authenticated
  using (
    exists (
      select 1 from public.club_posts cp
      where cp.id = club_post_id
        and public.club_role(cp.club_id, auth.uid()) is not null
    )
    and not internal.is_blocked_either_way(auth.uid(), author_id)
  );

-- ------------------------------------------------------------
-- Interaction: defense-in-depth against liking/commenting on a
-- blocked-either-way author's content via a direct API call, even
-- though the content is already invisible to fetch normally (see
-- above). Product spec's Requirements, "Interaction ถูกจำกัด".
-- ------------------------------------------------------------
drop policy "Users can like drops as themselves" on public.drop_likes;
create policy "Users can like drops as themselves, excluding blocked authors"
  on public.drop_likes
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and not internal.is_blocked_either_way(auth.uid(), internal.drop_author_id(drop_id))
  );

drop policy "Users can comment on drops as themselves" on public.drop_comments;
create policy "Users can comment on drops as themselves, excluding blocked authors"
  on public.drop_comments
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and not internal.is_blocked_either_way(auth.uid(), internal.drop_author_id(drop_id))
  );

drop policy "Users can like drop comments as themselves" on public.drop_comment_likes;
create policy "Users can like drop comments as themselves, excluding blocked authors"
  on public.drop_comment_likes
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and not internal.is_blocked_either_way(auth.uid(), internal.drop_comment_author_id(comment_id))
  );

drop policy "Users can like pops as themselves" on public.pop_likes;
create policy "Users can like pops as themselves, excluding blocked authors"
  on public.pop_likes
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and not internal.is_blocked_either_way(auth.uid(), internal.pop_author_id(pop_id))
  );

drop policy "Users can comment on pops as themselves" on public.pop_comments;
create policy "Users can comment on pops as themselves, excluding blocked authors"
  on public.pop_comments
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and not internal.is_blocked_either_way(auth.uid(), internal.pop_author_id(pop_id))
  );

drop policy "Users can like pop comments as themselves" on public.pop_comment_likes;
create policy "Users can like pop comments as themselves, excluding blocked authors"
  on public.pop_comment_likes
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and not internal.is_blocked_either_way(auth.uid(), internal.pop_comment_author_id(comment_id))
  );

drop policy "Approved club members can like club posts as themselves" on public.club_post_likes;
create policy "Approved club members can like club posts as themselves, excluding blocked authors"
  on public.club_post_likes
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.club_posts cp
      where cp.id = club_post_id
        and public.club_role(cp.club_id, auth.uid()) is not null
        and not internal.is_blocked_either_way(auth.uid(), cp.author_id)
    )
  );

drop policy "Approved club members can comment on club posts as themselves" on public.club_post_comments;
create policy "Approved club members can comment on club posts as themselves, excluding blocked authors"
  on public.club_post_comments
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and exists (
      select 1 from public.club_posts cp
      where cp.id = club_post_id
        and public.club_role(cp.club_id, auth.uid()) is not null
        and not internal.is_blocked_either_way(auth.uid(), cp.author_id)
    )
  );

-- ------------------------------------------------------------
-- Follow: can't follow (either direction) while a block relationship
-- exists. The reverse -- blocking while already following -- is torn
-- down by block_user() itself, not by this policy (this only guards
-- *new* follow attempts).
-- ------------------------------------------------------------
drop policy "Users can follow others as themselves" on public.follows;
create policy "Users can follow others as themselves, excluding blocked relationships"
  on public.follows
  for insert
  to authenticated
  with check (
    auth.uid() = follower_id
    and not internal.is_blocked_either_way(auth.uid(), following_id)
  );

-- ------------------------------------------------------------
-- Mentions: a block relationship stops a mention from ever being
-- recorded at all (not just from notifying) -- see WYN-027 Design,
-- Screen 9. The caption text itself may still literally contain
-- "@username" (MentionInput doesn't retroactively edit what was
-- typed), but no drop_mentions/club_post_mentions row is created for
-- it, so notify_drop_mention()/notify_club_post_mention() never fire.
-- ------------------------------------------------------------
drop policy "Drop authors can mention users in their own drops" on public.drop_mentions;
create policy "Drop authors can mention users in their own drops, excluding blocked relationships"
  on public.drop_mentions
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.drops
      where drops.id = drop_id and drops.author_id = auth.uid()
    )
    and not internal.is_blocked_either_way(auth.uid(), mentioned_user_id)
  );

drop policy "Club post authors can mention users in their own posts" on public.club_post_mentions;
create policy "Club post authors can mention users in their own posts, excluding blocked relationships"
  on public.club_post_mentions
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.club_posts
      where club_posts.id = club_post_id and club_posts.author_id = auth.uid()
    )
    and not internal.is_blocked_either_way(auth.uid(), mentioned_user_id)
  );

-- ============================================================
-- WYN-028: Mute System
-- ============================================================
-- See .wyn/docs/design/wyn-028-mute-system.md ("ภาพรวมแนวทาง") --
-- unlike blocks, mute has no side effect to coordinate atomically (no
-- Follow teardown, no interaction restriction), so this needs no RPC:
-- plain client-side insert/delete through RLS, same shape as `follows`.
create table if not exists public.mutes (
  muter_id uuid not null references public.profiles (id) on delete cascade,
  muted_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (muter_id, muted_id),
  constraint mutes_no_self_mute check (muter_id <> muted_id)
);

alter table public.mutes enable row level security;

-- A user can only ever see/create/remove their own mute rows -- unlike
-- blocks there's no relationship-kind RPC to reveal here, because mute
-- is one-directional only and the muted party must never be able to
-- tell they've been muted through any channel (Product spec).
create policy "Users can view mutes they created"
  on public.mutes
  for select
  to authenticated
  using (auth.uid() = muter_id);

create policy "Users can mute others as themselves"
  on public.mutes
  for insert
  to authenticated
  with check (auth.uid() = muter_id);

create policy "Users can unmute as themselves"
  on public.mutes
  for delete
  to authenticated
  using (auth.uid() = muter_id);

-- Mute's one and only enforcement point: the home_feed view itself,
-- not a SELECT policy on drops/pops directly. drops/pops are queried
-- directly from several other places (Search, ProfileDropGridTab/
-- ProfilePopGridTab via fetchByAuthor) that must stay completely
-- unaffected by mute per the Product spec ("ไม่กระทบ Search, ไม่กระทบ
-- Club Post ร่วม, ไม่กระทบ Profile") -- filtering only inside this view
-- keeps the effect scoped to exactly HomeRepository's fetchFeed/
-- fetchTrending/fetchFollowingFeed, all of which query this view and
-- nothing else, which is exactly "Home Feed" in the sense the
-- Requirement means (see wyn-028-mute-system.md, Screen 2, for why the
-- Trending row is an intentional, disclosed side effect of that scope).
--
-- The `not exists (select 1 from public.mutes where muter_id =
-- auth.uid() ...)` subquery below does NOT hit the RLS self-referential
-- trap found in WYN-027 (see drop_author_id() above): that trap needed
-- a subquery to check a table (drops) whose own RLS filtered on an
-- *unrelated* condition (block) to what the subquery needed (author
-- id), so RLS silently hid rows the subquery needed to see. Here the
-- subquery's own condition (`muter_id = auth.uid()`) is identical to
-- mutes' SELECT policy condition -- RLS permits exactly the rows this
-- subquery is already looking for, so no self-defeat is possible and a
-- security-definer helper function is unnecessary.
create or replace view public.home_feed
  with (security_invoker = true) as
select
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  d.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  null::bigint as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count
from public.drops d
join public.profiles prof on prof.id = d.author_id
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
  p.created_at,
  p.caption,
  null::text as image_url,
  p.video_url,
  p.thumbnail_url,
  p.duration_seconds,
  p.view_count,
  (select count(*) from public.pop_likes where pop_id = p.id) as like_count,
  (select count(*) from public.pop_comments where pop_id = p.id) as comment_count
from public.pops p
join public.profiles prof on prof.id = p.author_id
where not exists (
  select 1 from public.mutes where muter_id = auth.uid() and muted_id = p.author_id
);

grant select on public.home_feed to authenticated;

-- ============================================================
-- WYN-029: Moderation Queue + Action
-- ============================================================
-- See .wyn/docs/design/wyn-029-moderation-queue.md ("Handoff") --
-- platform_role first (with both the insert- and update-time client
-- tampering paths closed, not just one), then moderation_actions +
-- apply_moderation_action() (the RPC-over-raw-write pattern this schema
-- already uses for submit_report()/block_user()/club role transitions,
-- since taking a moderation action has several side effects that must
-- happen atomically), then get_my_moderation_status() (the single
-- source of truth both the login gate and the Restrict banner read),
-- then the RLS enforcement itself.

alter table public.profiles
  add column if not exists platform_role text not null default 'user';

alter table public.profiles
  add constraint profiles_platform_role_check
  check (platform_role in ('user', 'moderator', 'admin'));

-- Insert-time guard against self-escalation: a client can create their
-- own profiles row (AuthRepository.setUsername's upsert), so the INSERT
-- policy itself must pin platform_role to 'user' rather than trusting
-- whatever value a raw insert()/upsert() call sends -- same shape as
-- club_members' insert policy pinning role = 'member' (WYN-014).
drop policy "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id and platform_role = 'user');

-- Update-time guard: RLS has no column-level granularity (a WITH CHECK
-- clause can't express "any column except this one"), so the existing
-- "Users can update their own profile" policy alone would still let a
-- client PATCH platform_role on their own row via a raw update() call
-- even with the insert-time guard above in place. Blocked with a
-- trigger instead, mirroring clubs_prevent_owner_id_change (WYN-014)
-- exactly. Unlike that trigger, this one *is* meant to be lifted
-- occasionally (an admin promoting someone to moderator/admin, per
-- .wyn/tasks/backlog/WYN-029-moderation-queue.md Recommendation #3) --
-- that is never done by calling this trigger at all: run `alter table
-- public.profiles disable trigger profiles_prevent_platform_role_change;`,
-- the UPDATE, then `... enable trigger ...`, directly in the Supabase
-- SQL editor. Only a superuser/table owner can ALTER TABLE at all --
-- the `authenticated` role PostgREST clients run as has no such
-- privilege, so a client can never disable this guard itself.
create or replace function public.profiles_prevent_platform_role_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.platform_role <> old.platform_role then
    raise exception 'Changing platform_role directly is not supported -- see supabase/schema.sql (WYN-029)';
  end if;
  return new;
end;
$$;

create trigger profiles_prevent_platform_role_change
  before update on public.profiles
  for each row execute function public.profiles_prevent_platform_role_change();

-- Reusable "is the caller a moderator or admin" check for RLS policies
-- below. `security definer` here is NOT about bypassing RLS on
-- `profiles` (its own SELECT policy is `using (true)`, so there is no
-- recursive self-defeat risk like club_role()/is_blocked_either_way()
-- guard against) -- it's needed because a plain `stable` SQL function
-- that references `auth.uid()` is a planner-inlining candidate, and
-- Postgres re-checks schema privileges *as the calling role* at inline
-- time (confirmed empirically against real Postgres: `authenticated`
-- has never been explicitly granted `usage on schema auth` anywhere in
-- this project, and every *other* `auth.uid()` call in this file only
-- ever works because it's embedded directly in a policy's own
-- pre-resolved expression tree, created by the table owner, not
-- re-resolved under the querying role at call time). `security
-- definer` functions are never inlined, so this sidesteps that
-- entirely, the same way it incidentally does for every other
-- `internal.*`/`public.*` helper in this file that calls `auth.uid()`.
-- Lives in `internal`, not `public`, purely to stay consistent with
-- "helpers meant to run inside RLS policies, not to be called as a
-- client RPC" rather than out of a real leak risk here (a caller can
-- already learn their own platform_role by reading their own profiles
-- row).
create or replace function internal.current_platform_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select platform_role from public.profiles where id = auth.uid();
$$;

grant execute on function internal.current_platform_role() to authenticated;

-- Moderator/admin visibility into the full report queue -- deliberately
-- NOT a new RLS policy on public.reports itself (unlike every other
-- "extra visibility" case in this schema, e.g. the WYN-027 block-aware
-- SELECT policies). Reasoning: RLS is row-level, not column-level -- a
-- policy granting moderators row access to `reports` would still let a
-- moderator `select reporter_id` directly off the base table via a raw
-- REST call, and WYN-026's Requirement is unambiguous that nobody,
-- including the review team, ever sees who filed a report (design
-- doc's Handoff, item 2). Instead, this view is created WITHOUT
-- `security_invoker` (the default, unlike home_feed/saved_feed above,
-- which deliberately *do* use it) -- a plain view runs RLS-wise as its
-- *owner* (the migration role, which owns/bypasses RLS on every table
-- in this schema), so it sees every reports row regardless of caller,
-- and re-implements the caller-based visibility rule itself via the
-- `where` clause below instead of delegating to reports' own policies.
-- Combined with reports' existing reporter-only SELECT policy being
-- left completely untouched (a moderator hitting `/rest/v1/reports`
-- directly still only ever sees their own submitted reports, same as
-- any other user), reporter_id is unreachable through any query path a
-- client can construct -- not just absent from this view's column list,
-- but structurally unreachable even by a moderator role.
create or replace view public.moderation_queue as
select
  id,
  target_type,
  target_id,
  category,
  detail,
  status,
  created_at
from public.reports
where internal.current_platform_role() <> 'user';

grant select on public.moderation_queue to authenticated;

-- target_user_id is nullable: a report's target can be deleted (by its
-- own author, or by an earlier Remove Content action against a
-- different report on the same content) before a moderator gets to it,
-- in which case apply_moderation_action() below can still record a
-- No Action closing the case, just with nothing to resolve to.
create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  target_user_id uuid references public.profiles (id) on delete cascade,
  action_type text not null
    check (action_type in ('no_action', 'warning', 'remove_content', 'restrict', 'suspend', 'ban')),
  reason text not null,
  duration_days integer check (duration_days in (1, 3, 7)),
  expires_at timestamptz,
  reviewer_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint moderation_actions_reason_not_blank check (length(trim(reason)) > 0),
  -- Restrict/Suspend always carry a duration + computed expiry; every
  -- other action type (including Ban, which is permanent by design --
  -- see the Product spec) always carries neither.
  constraint moderation_actions_duration_matches_action_type check (
    (action_type in ('restrict', 'suspend') and duration_days is not null and expires_at is not null)
    or (action_type not in ('restrict', 'suspend') and duration_days is null and expires_at is null)
  )
);

-- Supports both is_posting_blocked()/get_my_moderation_status()'s
-- "is there a still-active restrict/suspend/ban row for this user"
-- lookups below.
create index if not exists moderation_actions_target_user_idx
  on public.moderation_actions (target_user_id, action_type, expires_at);
create index if not exists moderation_actions_report_idx
  on public.moderation_actions (report_id);

-- WYN-030: set only by decide_appeal() when an appeal is approved --
-- never by a client directly (moderation_actions has no client
-- update policy at all, see below). Shared by all 5 action types
-- rather than a bespoke undo field per type; see
-- .wyn/docs/design/wyn-030-appeal-system.md, Screen 8.
alter table public.moderation_actions
  add column if not exists overturned_at timestamptz;

alter table public.moderation_actions enable row level security;

-- Moderator/admin audit visibility only. Deliberately NO policy grants
-- the *target* of an action select access to this table directly --
-- reviewer_id would leak who reviewed them the moment they queried
-- their own rows, defeating the exact same reviewer-identity protection
-- Screen 5/8 of the design doc call out (mirrors WYN-026's
-- reporter-identity protection, opposite direction). A target's own
-- current status is read exclusively through get_my_moderation_status()
-- below, which returns only reason/expiry, never reviewer_id.
-- Deliberately no insert/update/delete policy for any role either --
-- every row here is written by apply_moderation_action() below.
create policy "Moderators can view moderation action history"
  on public.moderation_actions
  for select
  to authenticated
  using (internal.current_platform_role() <> 'user');

-- Single reusable "does this user currently have an active
-- restrict/suspend, or any ban at all, that should block them from
-- posting" check -- used by the INSERT policies below. security definer
-- (with the same self-referential-trap reasoning as
-- internal.drop_author_id, WYN-027): moderation_actions grants ordinary
-- users no SELECT policy at all (see above), so an inserting user
-- checking *their own* restriction status here would otherwise have
-- that row hidden from them by RLS, making the guard silently always
-- pass. Ban has no expires_at (permanent, see the table's own check
-- constraint above) so its branch checks existence only -- the only way
-- to lift a Ban is deleting/superseding that row directly via SQL (no
-- in-app Unban this round, per the Product spec).
-- WYN-030: `and overturned_at is null` added to both branches below --
-- an approved appeal (decide_appeal() sets overturned_at, never
-- expires_at) must lift a still-unexpired Restrict/Suspend or a
-- permanent Ban immediately, without touching the expires_at logic
-- that already handles natural expiry. See
-- .wyn/docs/design/wyn-030-appeal-system.md, Screen 8 (scope decision
-- #1) for why this is one column shared by all 5 action types rather
-- than a bespoke undo field per type.
create or replace function internal.is_posting_blocked(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.moderation_actions
    where target_user_id = p_user_id
      and overturned_at is null
      and (
        (action_type in ('restrict', 'suspend') and expires_at > now())
        or action_type = 'ban'
      )
  );
$$;

grant execute on function internal.is_posting_blocked(uuid) to authenticated;

-- Atomically applies one of the 6 moderation actions to a report:
-- resolves the target account (user -> themselves, content -> its
-- author, club -> its owner_id, mirroring submit_report()'s own
-- per-target-type resolution and the design doc's Handoff item 2),
-- closes the report (dismissed for No Action, actioned for the other
-- 5), records the action for audit, and performs the action's real
-- effect (Warning/Remove Content notify via the existing notification
-- system per the design doc's Screen 5, Remove Content additionally
-- hard-deletes the content -- see the comment below for why that's
-- equivalent to the "RLS SELECT filter" mechanism the design doc
-- describes, not a deviation from it -- Restrict/Suspend compute an
-- expiry, Ban is permanent). Mirrors block_user()'s
-- validate-then-multi-write shape. `for update` on the report row
-- guards against two moderators actioning the same report at once (the
-- design doc's overview decision #3 -- no claim/"reviewing" mechanic --
-- explicitly leans on this as the actual double-action guard).
create or replace function public.apply_moderation_action(
  p_report_id uuid,
  p_action_type text,
  p_reason text,
  p_duration_days integer default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reviewer uuid := auth.uid();
  v_reviewer_role text;
  v_report record;
  v_target_user uuid;
  v_expires_at timestamptz;
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_action_id uuid;
begin
  if v_reviewer is null then
    raise exception 'Not authenticated';
  end if;

  select platform_role into v_reviewer_role from public.profiles where id = v_reviewer;
  if v_reviewer_role is null or v_reviewer_role = 'user' then
    raise exception 'Not authorized';
  end if;

  if p_action_type not in ('no_action', 'warning', 'remove_content', 'restrict', 'suspend', 'ban') then
    raise exception 'Invalid action_type: %', p_action_type;
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  select * into v_report from public.reports where id = p_report_id for update;
  if v_report is null then
    raise exception 'Report not found';
  end if;
  if v_report.status not in ('pending', 'reviewing') then
    raise exception 'Report has already been actioned';
  end if;

  if v_report.target_type = 'user' then
    v_target_user := v_report.target_id;
  elsif v_report.target_type = 'drop' then
    select author_id into v_target_user from public.drops where id = v_report.target_id;
  elsif v_report.target_type = 'drop_comment' then
    select author_id into v_target_user from public.drop_comments where id = v_report.target_id;
  elsif v_report.target_type = 'club' then
    select owner_id into v_target_user from public.clubs where id = v_report.target_id;
  elsif v_report.target_type = 'club_post' then
    select author_id into v_target_user from public.club_posts where id = v_report.target_id;
  elsif v_report.target_type = 'club_post_comment' then
    select author_id into v_target_user from public.club_post_comments where id = v_report.target_id;
  else
    raise exception 'Unsupported report target type: %', v_report.target_type;
  end if;

  -- Remove Content only applies to content targets, per the Product
  -- spec ("เฉพาะ target ที่เป็นเนื้อหา ไม่ใช้กับ target ที่เป็น User/Club").
  if p_action_type = 'remove_content' and v_report.target_type in ('user', 'club') then
    raise exception 'Remove Content is not supported for target type %', v_report.target_type;
  end if;

  -- Every action except No Action needs a real account to act on -- if
  -- the target vanished before review (deleted by its own author, or by
  -- an earlier Remove Content against a different report on the same
  -- content), only No Action can still close the case.
  if v_target_user is null and p_action_type <> 'no_action' then
    raise exception 'Target no longer exists -- use No Action to close this report';
  end if;

  if p_action_type in ('restrict', 'suspend') then
    if p_duration_days is null or p_duration_days not in (1, 3, 7) then
      raise exception 'duration_days must be 1, 3, or 7 for % ', p_action_type;
    end if;
    v_expires_at := now() + (p_duration_days || ' days')::interval;
  else
    v_expires_at := null;
  end if;

  insert into public.moderation_actions (
    report_id, target_user_id, action_type, reason, duration_days, expires_at, reviewer_id
  ) values (
    p_report_id,
    v_target_user,
    p_action_type,
    v_trimmed_reason,
    case when p_action_type in ('restrict', 'suspend') then p_duration_days else null end,
    v_expires_at,
    v_reviewer
  )
  returning id into v_action_id;

  update public.reports
  set status = case when p_action_type = 'no_action' then 'dismissed' else 'actioned' end
  where id = p_report_id;

  -- actor_id is deliberately NULL for both effects below (WYN-029 fix,
  -- see .wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md) --
  -- v_reviewer must never be written here, since notifications.actor_id
  -- is a plain, target-readable column (RLS is row-level, not column-
  -- level), unlike moderation_actions.reviewer_id which has no client
  -- SELECT access at all and remains the only correctly-protected place
  -- this identity is recorded.
  if p_action_type = 'warning' then
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_target_user, null, 'moderation_warning', v_trimmed_reason, v_action_id, p_action_type);
  elsif p_action_type = 'remove_content' then
    -- Notification inserted *before* the delete below on purpose: both
    -- drop_id/club_post_id etc. are left null on this notification (see
    -- the notifications_type_check migration further down), so nothing
    -- here references the row about to be deleted and there is no
    -- on-delete-cascade ordering hazard either way -- but inserting
    -- first keeps the "notify, then remove" sequence readable as the
    -- two-step user-facing effect the design doc describes.
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_target_user, null, 'moderation_content_removed', v_trimmed_reason, v_action_id, p_action_type);

    -- Hard-delete, not a soft-delete-and-filter flag: the design doc's
    -- Screen 5 explicitly specifies the *effect* as "hidden from
    -- everyone including the author -- exactly like deleting it
    -- themselves" -- self-delete everywhere else in this schema
    -- (deleteDrop/deleteComment/deletePost) is already a hard DELETE,
    -- so this reuses that exact same mechanism instead of inventing a
    -- new is_deleted column + SELECT-filter policy that would produce
    -- an identical externally-visible result with more surface area.
    if v_report.target_type = 'drop' then
      delete from public.drops where id = v_report.target_id;
    elsif v_report.target_type = 'drop_comment' then
      delete from public.drop_comments where id = v_report.target_id;
    elsif v_report.target_type = 'club_post' then
      delete from public.club_posts where id = v_report.target_id;
    elsif v_report.target_type = 'club_post_comment' then
      delete from public.club_post_comments where id = v_report.target_id;
    end if;
  end if;

  -- WYN-048: audit trail for this privileged action, recorded after
  -- everything above has already succeeded. actor_id is the real
  -- reviewer identity (v_reviewer) -- unlike the notifications inserted
  -- above (which deliberately null out actor_id so the target never
  -- learns who reviewed them), audit_log has zero client-facing SELECT
  -- policy at all, so recording the true reviewer here creates no such
  -- leak. No exception handling around this call: if it raises, the
  -- whole action rolls back (fail-closed) rather than letting a
  -- privileged moderation action succeed unlogged -- see
  -- internal.log_audit_event()'s own comment (WYN-048 section) for why
  -- that failure mode is realistically never hit anyway.
  perform internal.log_audit_event(
    v_reviewer,
    'moderation_action_applied',
    v_target_user,
    jsonb_build_object('action_type', p_action_type, 'reason', v_trimmed_reason)
  );
end;
$$;

grant execute on function public.apply_moderation_action(uuid, text, text, integer) to authenticated;

-- Single source of truth for "is auth.uid() currently
-- restricted/suspended/banned" -- both AuthGate's login-time check and
-- RestrictionBanner's posting-time check call this same RPC (design
-- doc's Handoff item 4), so the two can never disagree about what
-- "currently restricted" means. security definer for the same reason as
-- is_posting_blocked() above (ordinary users have no SELECT policy on
-- moderation_actions). Only ever resolves the caller's own auth.uid()
-- -- there is no user-id parameter, so this can never be used to probe
-- anyone else's moderation status.
-- WYN-030: `and overturned_at is null` added to every restrict/suspend/
-- ban lookup below (same reasoning as internal.is_posting_blocked()
-- above) -- an approved appeal must make is_restricted/is_suspended/
-- is_banned flip to false immediately. This function is redefined
-- again further down (after the `appeals` table exists) to add 6 more
-- columns the appeal UI needs -- this in-place edit only carries the
-- overturned_at fix forward so it's not lost in between.
create or replace function public.get_my_moderation_status()
returns table (
  is_restricted boolean,
  restrict_reason text,
  restrict_expires_at timestamptz,
  is_suspended boolean,
  suspend_reason text,
  suspend_expires_at timestamptz,
  is_banned boolean,
  ban_reason text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1 from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'restrict'
        and expires_at > now() and overturned_at is null
    ),
    (
      select reason from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'restrict'
        and expires_at > now() and overturned_at is null
      order by created_at desc limit 1
    ),
    (
      select expires_at from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'restrict'
        and expires_at > now() and overturned_at is null
      order by created_at desc limit 1
    ),
    exists (
      select 1 from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'suspend'
        and expires_at > now() and overturned_at is null
    ),
    (
      select reason from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'suspend'
        and expires_at > now() and overturned_at is null
      order by created_at desc limit 1
    ),
    (
      select expires_at from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'suspend'
        and expires_at > now() and overturned_at is null
      order by created_at desc limit 1
    ),
    exists (
      select 1 from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'ban' and overturned_at is null
    ),
    (
      select reason from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'ban' and overturned_at is null
      order by created_at desc limit 1
    );
$$;

grant execute on function public.get_my_moderation_status() to authenticated;

-- ------------------------------------------------------------
-- Notification types 2, 3 (Screen 5): Warning / Remove Content ride the
-- existing notification system instead of new UI. `reason` is
-- denormalized directly onto the row (same reasoning as clubName/
-- orderStoreName being denormalized/joined elsewhere) rather than
-- joined from moderation_actions at read time, since ordinary users
-- have no SELECT policy on moderation_actions at all (see above) -- the
-- notification row is the *only* place the target ever sees this text.
-- ------------------------------------------------------------
alter table public.notifications
  add column if not exists reason text;

do $$
declare
  v_constraint_name text;
begin
  select tc.constraint_name into v_constraint_name
  from information_schema.table_constraints tc
  join information_schema.constraint_column_usage ccu
    on ccu.constraint_name = tc.constraint_name
   and ccu.constraint_schema = tc.constraint_schema
  where tc.table_schema = 'public'
    and tc.table_name = 'notifications'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'type';

  if v_constraint_name is not null then
    execute format('alter table public.notifications drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'like_drop', 'like_pop', 'comment_drop', 'comment_pop', 'follow',
    'club_join_request', 'club_join_approved', 'club_post_like', 'club_post_comment',
    'mention_drop', 'mention_club_post',
    'moderation_warning', 'moderation_content_removed',
    'appeal_approved', 'appeal_rejected'
  ));

-- ------------------------------------------------------------
-- WYN-030: lets MyModerationActionScreen (and NotificationListScreen's
-- tap handler) resolve straight from a notification row to "which
-- moderation_actions row is this about" without a second query.
-- moderation_action_type is denormalized alongside the id (not just
-- joined at read time) so _messageFor() can pick the right per-type
-- wording (Screen 7) even though ordinary users have no SELECT policy
-- on moderation_actions to join through themselves.
-- ------------------------------------------------------------
alter table public.notifications
  add column if not exists moderation_action_id uuid references public.moderation_actions (id);
alter table public.notifications
  add column if not exists moderation_action_type text;

-- ------------------------------------------------------------
-- Restrict/Suspend/Ban enforcement (Screen 8): posting is blocked at
-- the RLS INSERT layer, not just by disabling a button in Dart -- a
-- restricted/suspended/banned account calling these endpoints directly
-- still gets rejected. Auto-expiry is inherent to
-- internal.is_posting_blocked()'s own `expires_at > now()` check (no
-- cron/batch job anywhere in this project's infrastructure) -- the
-- instant a Restrict/Suspend's expires_at is in the past, the very next
-- insert attempt succeeds again with no other action needed. Login-time
-- blocking (Suspend/Ban) is enforced client-side by AuthGate calling
-- get_my_moderation_status() above, not here -- RLS has no hook into
-- Supabase Auth's session-issuing step itself. Pop is deliberately left
-- untouched (no pops/pop_comments policy below) -- Pop feature
-- development is suspended, see .wyn/company/DECISIONS.md (2026-08-14).
-- ------------------------------------------------------------
drop policy "Users can create their own drops" on public.drops;
create policy "Users can create their own drops, excluding moderation-blocked accounts"
  on public.drops
  for insert
  to authenticated
  with check (auth.uid() = author_id and not internal.is_posting_blocked(auth.uid()));

drop policy "Users can comment on drops as themselves, excluding blocked authors" on public.drop_comments;
create policy "Users can comment on drops as themselves, excluding blocked authors and moderation-blocked accounts"
  on public.drop_comments
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and not internal.is_blocked_either_way(auth.uid(), internal.drop_author_id(drop_id))
    and not internal.is_posting_blocked(auth.uid())
  );

drop policy "Users can create clubs as themselves" on public.clubs;
create policy "Users can create clubs as themselves, excluding moderation-blocked accounts"
  on public.clubs
  for insert
  to authenticated
  with check (auth.uid() = owner_id and not internal.is_posting_blocked(auth.uid()));

drop policy "Approved club members can create club posts as themselves" on public.club_posts;
create policy "Approved club members can create club posts as themselves, excluding moderation-blocked accounts"
  on public.club_posts
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and public.club_role(club_id, auth.uid()) is not null
    and not internal.is_posting_blocked(auth.uid())
  );

drop policy "Approved club members can comment on club posts as themselves, excluding blocked authors" on public.club_post_comments;
create policy "Approved club members can comment on club posts as themselves, excluding blocked authors and moderation-blocked accounts"
  on public.club_post_comments
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and exists (
      select 1 from public.club_posts cp
      where cp.id = club_post_id
        and public.club_role(cp.club_id, auth.uid()) is not null
        and not internal.is_blocked_either_way(auth.uid(), cp.author_id)
    )
    and not internal.is_posting_blocked(auth.uid())
  );

-- ============================================================
-- WYN-030: Appeal System
-- ============================================================
-- See .wyn/docs/design/wyn-030-appeal-system.md ("Handoff") -- builds
-- entirely on top of WYN-029's moderation_actions/apply_moderation_action
-- shipped above (overturned_at was already added earlier in this file
-- so internal.is_posting_blocked()/get_my_moderation_status() could be
-- fixed in place without forward-reference issues; this section is
-- everything that needs the `appeals` table to exist first).

-- No INSERT/UPDATE/DELETE policy for any role -- every row is written
-- by submit_appeal()/decide_appeal() below (RPC-over-raw-write, same
-- shape as moderation_actions/reports/blocks). moderation_action_id is
-- unique as the DB-level backstop of "1 appeal per action" -- the
-- client hiding the button after submit is UX, not the actual boundary.
create table if not exists public.appeals (
  id uuid primary key default gen_random_uuid(),
  moderation_action_id uuid not null unique references public.moderation_actions (id) on delete cascade,
  appellant_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null,
  evidence_paths text[],
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reviewer_id uuid references public.profiles (id) on delete cascade,
  decision_reason text,
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  constraint appeals_reason_not_blank check (length(trim(reason)) > 0),
  constraint appeals_evidence_paths_max_3 check (evidence_paths is null or array_length(evidence_paths, 1) <= 3),
  constraint appeals_decision_reason_required_on_reject check (
    status <> 'rejected' or (decision_reason is not null and length(trim(decision_reason)) > 0)
  )
);

create index if not exists appeals_appellant_idx on public.appeals (appellant_id);

alter table public.appeals enable row level security;

create policy "Appellants can view their own appeals"
  on public.appeals
  for select
  to authenticated
  using (auth.uid() = appellant_id);

create policy "Moderators can view all appeals"
  on public.appeals
  for select
  to authenticated
  using (internal.current_platform_role() <> 'user');

-- Evidence images: private bucket scoped by *file owner* (appellant_id),
-- not club membership -- mirrors club-media's private-bucket/signed-URL
-- pattern but the avatar/drop-images path-ownership convention, since
-- evidence is personal to the appellant, not shared with a group. Path
-- convention: `{appellant_id}/{timestamp}-{n}.ext`. No UPDATE/DELETE
-- policy -- evidence is immutable once submitted, consistent with the
-- rest of this moderation system being an audit trail.
insert into storage.buckets (id, name, public)
values ('appeal-evidence', 'appeal-evidence', false)
on conflict (id) do nothing;

create policy "Appellants and moderators can view appeal evidence"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'appeal-evidence'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or internal.current_platform_role() <> 'user'
    )
  );

create policy "Users can upload their own appeal evidence"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'appeal-evidence'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Validates target_user_id = auth.uid() (nobody can appeal on someone
-- else's behalf), action_type <> 'no_action' (nothing to appeal),
-- reason non-blank, evidence array <= 3 paths each owned by the
-- caller (defense-in-depth beyond the storage RLS above -- these are
-- plain text parameters, not verified uploads, so a client could send
-- someone else's already-uploaded path here without this check), and
-- relies on appeals.moderation_action_id's unique constraint (not
-- application logic) to reject a second appeal on the same action.
create or replace function public.submit_appeal(
  p_action_id uuid,
  p_reason text,
  p_evidence_paths text[] default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_appellant uuid := auth.uid();
  v_action record;
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_appeal_id uuid;
  v_path text;
begin
  if v_appellant is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_action from public.moderation_actions where id = p_action_id;
  if v_action is null then
    raise exception 'Moderation action not found';
  end if;

  if v_action.target_user_id <> v_appellant then
    raise exception 'You can only appeal actions taken against your own account';
  end if;

  if v_action.action_type = 'no_action' then
    raise exception 'No Action cannot be appealed';
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  if p_evidence_paths is not null then
    if array_length(p_evidence_paths, 1) > 3 then
      raise exception 'At most 3 evidence images allowed';
    end if;
    foreach v_path in array p_evidence_paths loop
      if v_path is null or v_path not like (v_appellant::text || '/%') then
        raise exception 'Invalid evidence path';
      end if;
    end loop;
  end if;

  insert into public.appeals (moderation_action_id, appellant_id, reason, evidence_paths)
  values (p_action_id, v_appellant, v_trimmed_reason, p_evidence_paths)
  returning id into v_appeal_id;

  return v_appeal_id;
exception
  when unique_violation then
    raise exception 'This moderation action has already been appealed';
end;
$$;

grant execute on function public.submit_appeal(uuid, text, text[]) to authenticated;

-- `for update` on the appeal row guards two moderators deciding the
-- same appeal at once, mirroring apply_moderation_action()'s own
-- report-row lock. Self-review guard is the real boundary here (not
-- the UI hiding the buttons) -- this project has hit the "UI omission
-- is not a data-access boundary" lesson twice already (WYN-027's
-- is_blocked_either_way RPC exposure, WYN-029's actor_id leak); this
-- is the third place it applies. Blocks BOTH approve and reject for a
-- self-review, wider than the Product spec's stated minimum ("at
-- least block approve") -- see the design doc's scope decision #4 for
-- why allowing self-reject makes no sense once self-approve is
-- already blocked.
create or replace function public.decide_appeal(
  p_appeal_id uuid,
  p_approve boolean,
  p_decision_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reviewer uuid := auth.uid();
  v_reviewer_role text;
  v_appeal record;
  v_action record;
  v_trimmed_reason text := trim(coalesce(p_decision_reason, ''));
begin
  if v_reviewer is null then
    raise exception 'Not authenticated';
  end if;

  select platform_role into v_reviewer_role from public.profiles where id = v_reviewer;
  if v_reviewer_role is null or v_reviewer_role = 'user' then
    raise exception 'Not authorized';
  end if;

  select * into v_appeal from public.appeals where id = p_appeal_id for update;
  if v_appeal is null then
    raise exception 'Appeal not found';
  end if;
  if v_appeal.status <> 'pending' then
    raise exception 'This appeal has already been decided';
  end if;

  select * into v_action from public.moderation_actions where id = v_appeal.moderation_action_id;
  if v_action is null then
    raise exception 'Moderation action not found';
  end if;

  if v_reviewer = v_action.target_user_id then
    raise exception 'You cannot decide an appeal for a moderation action taken against your own account';
  end if;

  if not p_approve and length(v_trimmed_reason) = 0 then
    raise exception 'A reason is required to reject an appeal';
  end if;

  update public.appeals
  set status = case when p_approve then 'approved' else 'rejected' end,
      reviewer_id = v_reviewer,
      decision_reason = case when p_approve then null else v_trimmed_reason end,
      decided_at = now()
  where id = p_appeal_id;

  if p_approve then
    update public.moderation_actions
    set overturned_at = now()
    where id = v_action.id;

    -- actor_id deliberately NULL, exactly like apply_moderation_action()
    -- above -- the real reviewer identity lives only in
    -- appeals.reviewer_id, a column the target has no SELECT access to.
    -- This is the third time this project has had to protect a
    -- moderation-adjacent identity this way (WYN-027, WYN-029); it is
    -- done correctly from the very first insert here, not patched in
    -- afterward.
    insert into public.notifications (recipient_id, actor_id, type, moderation_action_id, moderation_action_type)
    values (v_action.target_user_id, null, 'appeal_approved', v_action.id, v_action.action_type);
  else
    -- Reuses notifications.reason (WYN-029's column) for the rejection
    -- message -- see the design doc's scope decision #6.
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_action.target_user_id, null, 'appeal_rejected', v_trimmed_reason, v_action.id, v_action.action_type);
  end if;

  -- WYN-048: audit trail, recorded after the decision has already
  -- committed above. actor_id is the real reviewer identity (same
  -- reasoning as apply_moderation_action()'s own WYN-048 comment --
  -- audit_log has no client-facing SELECT policy, so this creates no
  -- reviewer-identity leak the way notifications.actor_id would).
  -- target = the appellant (v_appeal.appellant_id), not the reviewer.
  perform internal.log_audit_event(
    v_reviewer,
    'appeal_decided',
    v_appeal.appellant_id,
    jsonb_build_object('decision', case when p_approve then 'approved' else 'rejected' end)
  );
end;
$$;

grant execute on function public.decide_appeal(uuid, boolean, text) to authenticated;

-- Full redefinition of get_my_moderation_status() now that `appeals`
-- exists -- the in-place edit earlier in this file already added the
-- overturned_at fix to the original 8 columns; this adds the 6 new
-- columns RestrictionBanner/AccountRestrictedScreen need to render the
-- appeal entry point/status without a second RPC round-trip. Once an
-- appeal is approved, overturned_at is set and is_restricted/
-- is_suspended/is_banned + the corresponding *_action_id both flip to
-- false/null together in the very next call -- there is no reachable
-- state where *_appeal_status reads 'approved' here, since the row
-- backing it stops being "the active one" at that exact moment (see
-- the design doc, Screen 2, on why 'approved' never surfaces on the
-- banner).
--
-- An explicit DROP is required first -- CREATE OR REPLACE cannot
-- change a RETURNS TABLE function's column list, only its body, and
-- this redefinition adds 6 columns to the 8-column version defined
-- earlier in this file.
drop function if exists public.get_my_moderation_status();

create function public.get_my_moderation_status()
returns table (
  is_restricted boolean,
  restrict_reason text,
  restrict_expires_at timestamptz,
  restrict_action_id uuid,
  restrict_appeal_status text,
  is_suspended boolean,
  suspend_reason text,
  suspend_expires_at timestamptz,
  suspend_action_id uuid,
  suspend_appeal_status text,
  is_banned boolean,
  ban_reason text,
  ban_action_id uuid,
  ban_appeal_status text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1 from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'restrict'
        and expires_at > now() and overturned_at is null
    ),
    (
      select reason from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'restrict'
        and expires_at > now() and overturned_at is null
      order by created_at desc limit 1
    ),
    (
      select expires_at from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'restrict'
        and expires_at > now() and overturned_at is null
      order by created_at desc limit 1
    ),
    (
      select id from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'restrict'
        and expires_at > now() and overturned_at is null
      order by created_at desc limit 1
    ),
    coalesce((
      select a.status from public.moderation_actions ma
      join public.appeals a on a.moderation_action_id = ma.id
      where ma.target_user_id = auth.uid() and ma.action_type = 'restrict'
        and ma.expires_at > now() and ma.overturned_at is null
      order by ma.created_at desc limit 1
    ), 'none'),
    exists (
      select 1 from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'suspend'
        and expires_at > now() and overturned_at is null
    ),
    (
      select reason from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'suspend'
        and expires_at > now() and overturned_at is null
      order by created_at desc limit 1
    ),
    (
      select expires_at from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'suspend'
        and expires_at > now() and overturned_at is null
      order by created_at desc limit 1
    ),
    (
      select id from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'suspend'
        and expires_at > now() and overturned_at is null
      order by created_at desc limit 1
    ),
    coalesce((
      select a.status from public.moderation_actions ma
      join public.appeals a on a.moderation_action_id = ma.id
      where ma.target_user_id = auth.uid() and ma.action_type = 'suspend'
        and ma.expires_at > now() and ma.overturned_at is null
      order by ma.created_at desc limit 1
    ), 'none'),
    exists (
      select 1 from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'ban' and overturned_at is null
    ),
    (
      select reason from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'ban' and overturned_at is null
      order by created_at desc limit 1
    ),
    (
      select id from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'ban' and overturned_at is null
      order by created_at desc limit 1
    ),
    coalesce((
      select a.status from public.moderation_actions ma
      join public.appeals a on a.moderation_action_id = ma.id
      where ma.target_user_id = auth.uid() and ma.action_type = 'ban' and ma.overturned_at is null
      order by ma.created_at desc limit 1
    ), 'none');
$$;

grant execute on function public.get_my_moderation_status() to authenticated;

-- The only way an ordinary user can read anything from
-- moderation_actions about themselves -- returns only the columns safe
-- for the target to see (no reviewer_id, no report_id). Never add a
-- raw SELECT policy on moderation_actions for the target instead: RLS
-- is row-level, not column-level, so that would expose reviewer_id
-- immediately -- the exact same class of bug WYN-029 just fixed.
create or replace function public.get_my_moderation_action(p_action_id uuid)
returns table (
  action_type text,
  reason text,
  duration_days integer,
  expires_at timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select action_type, reason, duration_days, expires_at, created_at
  from public.moderation_actions
  where id = p_action_id and target_user_id = auth.uid();
$$;

grant execute on function public.get_my_moderation_action(uuid) to authenticated;

-- ============================================================
-- WYN-031: 1:1 Chat (Basic DM)
-- ============================================================
-- See .wyn/docs/design/wyn-031-chat-1to1.md for the full reasoning
-- behind every decision below. Short version: no group chat this
-- round (2-column canonical-ordered pair table, not a junction
-- table), `status` reserved for WYN-032's future Message Request gate
-- (always 'active' this round), read status is 2 timestamp columns on
-- the conversation row (not per-message read receipts), sending a
-- message needs no RPC (plain RLS INSERT mirrors drops/club_posts),
-- deleting one does (delete_message() nulls the content, not just a
-- flag -- RLS is row-level, not column-level, the same lesson this
-- project keeps relearning).

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_a_id uuid not null references public.profiles (id) on delete cascade,
  user_b_id uuid not null references public.profiles (id) on delete cascade,
  -- WYN-032: 'active' when the recipient already followed the sender
  -- at conversation-creation time, 'pending' (a Message Request)
  -- otherwise -- see get_or_create_conversation() below.
  status text not null default 'active' check (status in ('active', 'pending')),
  -- WYN-032: who started this conversation. Null for every
  -- conversation that started 'active' (nothing to decide on) -- set
  -- once, at creation, never updated afterward.
  requested_by uuid references public.profiles (id) on delete cascade,
  user_a_last_read_at timestamptz,
  user_b_last_read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint conversations_no_self_chat check (user_a_id <> user_b_id),
  -- Canonical ordering enforced at the constraint level, not just by
  -- convention -- get_or_create_conversation() below is the only
  -- write path and always normalizes with least()/greatest(), so this
  -- also catches any future write path that forgets to.
  constraint conversations_canonical_order check (user_a_id < user_b_id),
  constraint conversations_requested_by_is_participant
    check (requested_by is null or requested_by in (user_a_id, user_b_id)),
  unique (user_a_id, user_b_id)
);

create index if not exists conversations_user_a_idx on public.conversations (user_a_id);
create index if not exists conversations_user_b_idx on public.conversations (user_b_id);

alter table public.conversations enable row level security;

create policy "Participants can view their own conversations"
  on public.conversations
  for select
  to authenticated
  using (auth.uid() in (user_a_id, user_b_id));

-- No insert/update policy for either column here -- both writes only
-- ever happen through the 2 RPCs below (canonical-ordering + block
-- checks need to happen server-side, and mark_conversation_read()
-- must only ever touch the caller's own read-timestamp column, which
-- plain row-level RLS can't express column-conditionally).

create or replace function public.get_or_create_conversation(p_other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_a uuid;
  v_b uuid;
  v_id uuid;
  v_status text;
  v_requested_by uuid;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;
  if p_other_user_id = v_me then
    raise exception 'Cannot start a conversation with yourself';
  end if;
  if not exists (select 1 from public.profiles where id = p_other_user_id) then
    raise exception 'User not found';
  end if;
  if internal.is_blocked_either_way(v_me, p_other_user_id) then
    raise exception 'Cannot start a conversation with a blocked user';
  end if;

  v_a := least(v_me, p_other_user_id);
  v_b := greatest(v_me, p_other_user_id);

  -- An existing conversation (of either status) is returned as-is --
  -- status is decided once, at creation, never re-evaluated.
  select id into v_id from public.conversations where user_a_id = v_a and user_b_id = v_b;
  if v_id is not null then
    return v_id;
  end if;

  -- WYN-045: dm_permission gates whether a *new* conversation can be
  -- created at all -- only reachable here, in the "no existing
  -- conversation yet" branch (an existing conversation already
  -- returned above, unaffected by whatever the recipient's setting is
  -- today). 'no_one' always rejects, no exceptions, even from someone
  -- the recipient already follows.
  if (select dm_permission from public.profiles where id = p_other_user_id) = 'no_one' then
    raise exception 'This user is not accepting new conversations';
  end if;

  -- WYN-032: a message from someone the recipient does not already
  -- follow starts as a pending Message Request instead of going
  -- straight to their inbox -- one-directional (does the recipient
  -- follow the sender), evaluated only here, at creation time.
  --
  -- WYN-045: 'people_i_follow' only allows creation when this exact
  -- condition is true (the recipient already follows the sender) --
  -- the same condition that already produces 'active' below. If it's
  -- false, this now raises instead of falling through to a 'pending'
  -- Message Request, since "people I follow" is meant to be a hard
  -- boundary against strangers, not just a routing choice between
  -- inbox and request folder.
  if exists (
    select 1 from public.follows
    where follower_id = p_other_user_id and following_id = v_me
  ) then
    v_status := 'active';
    v_requested_by := null;
  elsif (select dm_permission from public.profiles where id = p_other_user_id) = 'people_i_follow' then
    raise exception 'This user is not accepting new conversations';
  else
    v_status := 'pending';
    v_requested_by := v_me;
  end if;

  insert into public.conversations (user_a_id, user_b_id, status, requested_by)
  values (v_a, v_b, v_status, v_requested_by)
  on conflict (user_a_id, user_b_id) do nothing
  returning id into v_id;

  if v_id is null then
    -- Lost a race with a concurrent call for the same pair -- fetch
    -- the row that won instead of erroring.
    select id into v_id from public.conversations where user_a_id = v_a and user_b_id = v_b;
  elsif v_status = 'pending' and internal.notification_enabled(p_other_user_id, 'messages') then
    insert into public.notifications (recipient_id, actor_id, type, conversation_id)
    values (p_other_user_id, v_me, 'message_request', v_id);
  end if;

  return v_id;
end;
$$;

grant execute on function public.get_or_create_conversation(uuid) to authenticated;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
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

  update public.conversations
  set user_a_last_read_at = case when user_a_id = v_me then now() else user_a_last_read_at end,
      user_b_last_read_at = case when user_b_id = v_me then now() else user_b_last_read_at end
  where id = p_conversation_id and v_me in (user_a_id, user_b_id);

  if not found then
    raise exception 'Conversation not found, or you are not a participant';
  end if;
end;
$$;

grant execute on function public.mark_conversation_read(uuid) to authenticated;

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  text text,
  image_url text,
  reply_to_message_id uuid references public.messages (id) on delete set null,
  -- WYN-033: Share to Chat -- polymorphic, no FK (mirrors
  -- reports.target_type/target_id, which references 3+ different
  -- tables the same way). Deliberately NOT joined/denormalized into
  -- any view here -- the client resolves it via the same
  -- DropRepository/ClubRepository/ProfileRepository fetch calls used
  -- everywhere else, so the existing RLS on those tables (e.g.
  -- drops' own block-aware SELECT policy) protects a shared
  -- reference for free, with no new privacy mechanism needed.
  shared_content_type text
    check (shared_content_type is null or shared_content_type in ('drop', 'profile', 'club')),
  shared_content_id uuid,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  -- Empty messages are rejected -- except once deleted, when
  -- text/image_url/shared_content_* are all nulled out on purpose
  -- (see delete_message()). A shared-content card with no caption is
  -- not blank, same as an image message with no caption isn't.
  constraint messages_not_blank_unless_deleted
    check (
      deleted_at is not null
      or text is not null
      or image_url is not null
      or shared_content_id is not null
    )
);

create index if not exists messages_conversation_idx on public.messages (conversation_id, created_at);

alter table public.messages enable row level security;

create policy "Participants can view messages in their conversations"
  on public.messages
  for select
  to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id and auth.uid() in (c.user_a_id, c.user_b_id)
    )
  );

-- No RPC needed to send a message -- every condition is expressible
-- as a plain RLS check, mirroring drops/club_posts (which also have
-- no "create post" RPC): sender is the caller, the caller is an
-- actual participant of the conversation (not just any authenticated
-- user), neither side has blocked the other, and the caller isn't
-- Restricted/Suspended/Banned. conversations has no block-aware
-- SELECT filter of its own, so this subquery doesn't hit the same
-- self-referential RLS trap drop_author_id()/pop_author_id() exist to
-- solve (see the WYN-027 comment on those) -- it can be inlined directly.
--
-- WYN-032: a 'pending' conversation still accepts sends from whoever
-- started it (requested_by) -- they can keep messaging while waiting
-- on a decision, mirroring Instagram's own Message Request behavior --
-- but from nobody else. The recipient has no INSERT path at all until
-- accept_message_request() flips status to 'active'.
create policy "Participants can send messages in active or own-pending conversations"
  on public.messages
  for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and not internal.is_posting_blocked(auth.uid())
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and auth.uid() in (c.user_a_id, c.user_b_id)
        and not internal.is_blocked_either_way(
          c.user_a_id,
          c.user_b_id
        )
        and (
          c.status = 'active'
          or (c.status = 'pending' and c.requested_by = auth.uid())
        )
    )
  );

-- No update/delete policy for the client -- delete_message() below is
-- the only write path for an existing row.

create or replace function public.prevent_cross_conversation_reply()
returns trigger
language plpgsql
as $$
begin
  if new.reply_to_message_id is not null then
    if not exists (
      select 1 from public.messages m
      where m.id = new.reply_to_message_id and m.conversation_id = new.conversation_id
    ) then
      raise exception 'Cannot reply to a message from a different conversation';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists messages_prevent_cross_conversation_reply on public.messages;
create trigger messages_prevent_cross_conversation_reply
  before insert on public.messages
  for each row execute function public.prevent_cross_conversation_reply();

create or replace function public.delete_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- WYN-033: shared_content_type/shared_content_id null-out alongside
  -- text/image_url -- same discipline as the original text/image_url
  -- nulling (RLS is row-level, not column-level; a deleted share
  -- must not leave its reference reachable through this row).
  update public.messages
  set text = null, image_url = null, shared_content_type = null, shared_content_id = null, deleted_at = now()
  where id = p_message_id and sender_id = auth.uid() and deleted_at is null;

  if not found then
    raise exception 'Message not found, already deleted, or not yours';
  end if;
end;
$$;

grant execute on function public.delete_message(uuid) to authenticated;

-- Moderator-facing read of a single message's content for the
-- Moderation Queue's Appeal/Report detail screens -- security definer
-- bypasses messages' participant-only SELECT policy on purpose
-- (mirrors moderation_queue view's own reasoning: a moderator is
-- never a conversation participant) but re-implements the *right*
-- check itself rather than skipping it.
-- WYN-033: return-table column list changed (added shared_content_*)
-- -- `create or replace function` cannot change a function's return
-- table shape, so the old signature must be dropped first (same
-- lesson as get_my_moderation_status(), WYN-030).
drop function if exists public.get_message_for_moderation(uuid);

create or replace function public.get_message_for_moderation(p_message_id uuid)
returns table (
  text text,
  image_url text,
  shared_content_type text,
  shared_content_id uuid,
  deleted_at timestamptz,
  sender_username text
)
language sql
stable
security definer
set search_path = public
as $$
  select m.text, m.image_url, m.shared_content_type, m.shared_content_id, m.deleted_at, p.username
  from public.messages m
  join public.profiles p on p.id = m.sender_id
  where m.id = p_message_id
    and internal.current_platform_role() <> 'user';
$$;

grant execute on function public.get_message_for_moderation(uuid) to authenticated;

-- Per-conversation notification mute -- deliberately a separate table
-- from WYN-028's `mutes` (user-level Home Feed content mute). Same
-- shape as `follows`/`mutes`: plain RLS insert/delete, no RPC needed
-- (no side effects to sequence atomically).
create table if not exists public.conversation_mutes (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

alter table public.conversation_mutes enable row level security;

create policy "Users can view conversations they muted"
  on public.conversation_mutes
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can mute a conversation as themselves"
  on public.conversation_mutes
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can unmute a conversation as themselves"
  on public.conversation_mutes
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- Chat media: private bucket (mirrors club-media's reasoning exactly
-- -- a 1:1 conversation is a stronger privacy boundary than even a
-- private Club, so a public bucket is out of the question). Path
-- shape: {conversation_id}/{sender_id}-{timestamp}.ext -- messages.
-- image_url stores the storage *path*, not a display URL; the Dart
-- repository mints a fresh signed URL per read (same reasoning as
-- club-media). Participant-only, both ways -- no separate "1 segment
-- vs >1 segment" split like club-media needed, since chat has no
-- public-preview equivalent of a Club's cover/icon.
insert into storage.buckets (id, name, public)
values ('chat-media', 'chat-media', false)
on conflict (id) do nothing;

create policy "Participants can view media in their conversations"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'chat-media'
    and exists (
      select 1 from public.conversations c
      where c.id = ((storage.foldername(name))[1])::uuid
        and auth.uid() in (c.user_a_id, c.user_b_id)
    )
  );

-- WYN-032: mirrors the messages INSERT policy's own active-or-own-
-- pending condition exactly -- without this, a requester's image (not
-- text) message would silently fail to upload during the pending
-- phase even though the messages row itself is allowed, since the
-- upload happens before the row insert (see ChatRepository.sendMessage()).
create policy "Participants can upload media to their conversations"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'chat-media'
    and exists (
      select 1 from public.conversations c
      where c.id = ((storage.foldername(name))[1])::uuid
        and auth.uid() in (c.user_a_id, c.user_b_id)
        and not internal.is_blocked_either_way(c.user_a_id, c.user_b_id)
        and (
          c.status = 'active'
          or (c.status = 'pending' and c.requested_by = auth.uid())
        )
    )
    and not internal.is_posting_blocked(auth.uid())
  );

-- Chat Inbox row: the other participant's profile + the conversation's
-- last message (however that got there -- text, image, or already
-- soft-deleted) + this caller's own read-timestamp + whether *this*
-- caller has muted it. security_invoker = true (mirrors
-- saved_feed/home_feed's own reasoning) -- conversations'/messages'
-- own participant-only SELECT policies still apply on top of this
-- view's own `where`, not bypassed by view-owner privileges.
-- WYN-032: a 'pending' conversation only shows up here for whoever
-- started it (requested_by) -- the recipient sees it in
-- `message_requests` instead, until they accept it. requested_by is
-- exposed so the client can tell "I'm still waiting on a decision"
-- apart from an ordinary active conversation.
create or replace view public.chat_inbox
  with (security_invoker = true) as
select
  c.id as conversation_id,
  c.status,
  c.requested_by,
  c.created_at as conversation_created_at,
  case when c.user_a_id = auth.uid() then c.user_b_id else c.user_a_id end as other_user_id,
  op.username as other_username,
  op.display_name as other_display_name,
  op.avatar_url as other_avatar_url,
  lm.text as last_message_text,
  lm.image_url as last_message_image_url,
  lm.deleted_at as last_message_deleted_at,
  lm.created_at as last_message_at,
  lm.sender_id as last_message_sender_id,
  case when c.user_a_id = auth.uid() then c.user_a_last_read_at else c.user_b_last_read_at end
    as my_last_read_at
from public.conversations c
join public.profiles op
  on op.id = (case when c.user_a_id = auth.uid() then c.user_b_id else c.user_a_id end)
left join lateral (
  select m.text, m.image_url, m.deleted_at, m.created_at, m.sender_id
  from public.messages m
  where m.conversation_id = c.id
  order by m.created_at desc
  limit 1
) lm on true
where auth.uid() in (c.user_a_id, c.user_b_id)
  and (c.status = 'active' or c.requested_by = auth.uid());

grant select on public.chat_inbox to authenticated;

-- Badge count for the Chat icon entry point (Screen 1) -- mirrors
-- NotificationRepository.countUnread()'s role, but "unread" here means
-- "at least one message from the other side after my own last-read
-- timestamp", a cross-column comparison PostgREST's simple filters
-- can't express directly, hence the RPC rather than a plain count()
-- query like notifications uses.
create or replace function public.count_unread_conversations()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.conversations c
  where auth.uid() in (c.user_a_id, c.user_b_id)
    and exists (
      select 1 from public.messages m
      where m.conversation_id = c.id
        and m.sender_id <> auth.uid()
        and m.created_at > coalesce(
          case when c.user_a_id = auth.uid() then c.user_a_last_read_at else c.user_b_last_read_at end,
          '-infinity'::timestamptz
        )
    );
$$;

grant execute on function public.count_unread_conversations() to authenticated;

-- Enables realtime for `messages` (new/edited/deleted messages) and
-- `conversations` (so a "read" receipt -- the other participant's
-- user_a_last_read_at/user_b_last_read_at moving forward -- reaches an
-- already-open ConversationScreen live, not just on next reload) --
-- guarded so schema.sql still applies cleanly against a bare local
-- Postgres test harness (supabase/tests/*.sh's stub never creates the
-- `supabase_realtime` publication, only a real Supabase project does by
-- default), and guarded per-table against already being a member so
-- re-running this against an already-migrated project doesn't error.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
    ) then
      execute 'alter publication supabase_realtime add table public.messages';
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'conversations'
    ) then
      execute 'alter publication supabase_realtime add table public.conversations';
    end if;
  end if;
end
$$;

-- ============================================================
-- WYN-032: Message Request flow (Accept/Delete/Block/Report)
-- ============================================================
-- See .wyn/docs/design/wyn-032-message-request.md for the full
-- reasoning. Short version: `conversations.requested_by` (added to
-- the CREATE TABLE above) plus the gating logic now built into
-- get_or_create_conversation() (also edited above) are the only
-- structural changes to what WYN-031 already built -- everything
-- below is new RPCs/views layered on top. Block/Report from a
-- Message Request reuse WYN-027/026's existing block_user()/
-- submit_report() directly -- no new mechanism for either.

create or replace function public.accept_message_request(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set status = 'active'
  where id = p_conversation_id
    and status = 'pending'
    and auth.uid() in (user_a_id, user_b_id)
    -- The requester cannot "accept" their own request -- only the
    -- other participant (the one being asked) can.
    and requested_by is distinct from auth.uid();

  if not found then
    raise exception 'Message request not found, already accepted, or not yours to accept';
  end if;
end;
$$;

grant execute on function public.accept_message_request(uuid) to authenticated;

-- Declining a request discards it outright (no "dismissed" flag, no
-- new state) -- messages.conversation_id already cascades on delete
-- (WYN-031), so this also removes every message in it. The requester
-- gets no notification that they were declined (mirrors the
-- Message-Request UX users already know from other apps) and can
-- start a fresh request later if they try again.
create or replace function public.delete_message_request(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted_id uuid;
begin
  delete from public.conversations
  where id = p_conversation_id
    and status = 'pending'
    and auth.uid() in (user_a_id, user_b_id)
    -- The requester cannot delete their own outgoing request this way
    -- (only the recipient can decline it) -- deleting your own sent
    -- message request isn't a feature this round.
    and requested_by is distinct from auth.uid()
  returning id into v_deleted_id;

  if v_deleted_id is null then
    raise exception 'Message request not found, already accepted, or not yours to delete';
  end if;
end;
$$;

grant execute on function public.delete_message_request(uuid) to authenticated;

-- Message Requests list (Design Screen 2): only the recipient sees a
-- pending conversation here (requested_by <> auth.uid()) -- the
-- requester sees their own outgoing request in chat_inbox instead
-- (see that view's WHERE clause above). Blocked-either-way pairs are
-- excluded outright -- once blocked, there is nothing left to decide.
create or replace view public.message_requests
  with (security_invoker = true) as
select
  c.id as conversation_id,
  c.created_at as conversation_created_at,
  case when c.user_a_id = auth.uid() then c.user_b_id else c.user_a_id end as other_user_id,
  op.username as other_username,
  op.display_name as other_display_name,
  op.avatar_url as other_avatar_url,
  lm.text as last_message_text,
  lm.image_url as last_message_image_url,
  lm.created_at as last_message_at
from public.conversations c
join public.profiles op
  on op.id = (case when c.user_a_id = auth.uid() then c.user_b_id else c.user_a_id end)
left join lateral (
  select m.text, m.image_url, m.created_at
  from public.messages m
  where m.conversation_id = c.id
  order by m.created_at desc
  limit 1
) lm on true
where c.status = 'pending'
  and c.requested_by <> auth.uid()
  and auth.uid() in (c.user_a_id, c.user_b_id)
  and not internal.is_blocked_either_way(c.user_a_id, c.user_b_id);

grant select on public.message_requests to authenticated;

-- ------------------------------------------------------------
-- Notification type `message_request` -- fired once by
-- get_or_create_conversation() above, the moment a new pending
-- conversation is created (never re-fired for an existing one).
-- conversation_id lets NotificationListScreen's tap handler open
-- ConversationScreen directly, same role dropId/popId/clubPostId play
-- for their own types.
-- ------------------------------------------------------------
alter table public.notifications
  add column if not exists conversation_id uuid references public.conversations (id) on delete cascade;

do $$
declare
  v_constraint_name text;
begin
  select tc.constraint_name into v_constraint_name
  from information_schema.table_constraints tc
  join information_schema.constraint_column_usage ccu
    on ccu.constraint_name = tc.constraint_name
   and ccu.constraint_schema = tc.constraint_schema
  where tc.table_schema = 'public'
    and tc.table_name = 'notifications'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'type';

  if v_constraint_name is not null then
    execute format('alter table public.notifications drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'like_drop', 'like_pop', 'comment_drop', 'comment_pop', 'follow',
    'club_join_request', 'club_join_approved', 'club_post_like', 'club_post_comment',
    'mention_drop', 'mention_club_post',
    'moderation_warning', 'moderation_content_removed',
    'appeal_approved', 'appeal_rejected',
    'message_request', 'redrop'
  ));

-- ============================================================
-- WYN-034: ReDrop (Standard + Quote)
-- ============================================================

-- Standard ReDrop (quote_text is null) and Quote ReDrop (quote_text
-- not null) share one table -- both are "someone shares a Drop into
-- their own feed," differing only in whether they add their own
-- words. drop_id cascades: if the original Drop is removed (by its
-- owner or via Moderation Remove Content), every ReDrop of it -- both
-- kinds -- disappears too. This mirrors every other engagement table's
-- FK to drops (drop_likes/drop_comments/saved_drops all cascade the
-- same way) rather than the WYN-033 shared-content pattern (no FK,
-- placeholder-on-missing) -- that pattern exists because a shared
-- message can reference 3 different tables with no single FK possible;
-- a ReDrop always references exactly one Drop, so a real FK is the
-- more defensible default here, and it also means a moderator's Remove
-- Content action correctly takes every ReDrop of the removed content
-- down with it instead of leaving it re-postable via someone else's
-- Quote ReDrop.
create table if not exists public.redrops (
  id uuid primary key default gen_random_uuid(),
  drop_id uuid not null references public.drops (id) on delete cascade,
  redropper_id uuid not null references public.profiles (id) on delete cascade,
  quote_text text,
  created_at timestamptz not null default now(),
  constraint redrops_quote_text_length
    check (quote_text is null or char_length(quote_text) between 1 and 500)
);

-- A user can Standard ReDrop (quote_text is null) a given Drop at most
-- once -- toggled via insert/delete, mirroring drop_likes' own
-- (drop_id, user_id) uniqueness. Quote ReDrop has no such limit: the
-- same Drop can be quoted multiple times with different commentary,
-- same as most platforms' actual Quote behavior.
create unique index if not exists redrops_standard_unique
  on public.redrops (drop_id, redropper_id) where quote_text is null;
create index if not exists redrops_drop_idx on public.redrops (drop_id);
create index if not exists redrops_redropper_created_idx
  on public.redrops (redropper_id, created_at desc);

alter table public.redrops enable row level security;

-- `exists (select 1 from public.drops d where d.id = drop_id)` does
-- double duty without a second block-check written by hand: it
-- piggybacks on drops' own SELECT policy (block-aware since WYN-027),
-- so a redrop of a Drop authored by someone the viewer is
-- blocked-either-way with becomes invisible through this subquery
-- alone -- not the WYN-027 self-referential trap (that trap needed to
-- extract author_id from a row RLS might hide before the check could
-- run; here we only need to know whether the row is visible at all,
-- which is exactly what a plain exists() against an RLS-protected
-- table answers). It also covers the Drop having been deleted, though
-- that case is already handled by the FK's cascade above -- this is a
-- harmless defensive backstop, not the primary mechanism.
create policy "Redrops are viewable by authenticated users, excluding blocked redroppers"
  on public.redrops
  for select
  to authenticated
  using (
    not internal.is_blocked_either_way(auth.uid(), redropper_id)
    and exists (select 1 from public.drops d where d.id = drop_id)
  );

create policy "Users can redrop as themselves, excluding blocked authors and moderation-blocked accounts"
  on public.redrops
  for insert
  to authenticated
  with check (
    auth.uid() = redropper_id
    and not internal.is_posting_blocked(auth.uid())
    and exists (
      select 1 from public.drops d
      where d.id = drop_id and not internal.is_blocked_either_way(auth.uid(), d.author_id)
    )
  );

create policy "Users can delete their own redrops"
  on public.redrops
  for delete
  to authenticated
  using (auth.uid() = redropper_id);

-- reports.target_type gains 'redrop' -- Quote ReDrop's own commentary
-- can be reported separately from the Drop it quotes (the commentary
-- may be the problem even when the original Drop is fine). Standard
-- ReDrop carries no commentary of its own, so it has no report path
-- here -- reporting the original Drop already covers it.
do $$
declare
  v_constraint_name text;
begin
  select tc.constraint_name into v_constraint_name
  from information_schema.table_constraints tc
  join information_schema.constraint_column_usage ccu
    on ccu.constraint_name = tc.constraint_name
   and ccu.constraint_schema = tc.constraint_schema
  where tc.table_schema = 'public'
    and tc.table_name = 'reports'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'target_type';

  if v_constraint_name is not null then
    execute format('alter table public.reports drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.reports
  add constraint reports_target_type_check
  check (target_type in (
    'user', 'drop', 'drop_comment', 'club', 'club_post',
    'club_post_comment', 'message', 'redrop'
  ));

create or replace function public.submit_report(
  p_target_type text,
  p_target_id uuid,
  p_category text,
  p_detail text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reporter uuid := auth.uid();
  v_report_id uuid;
begin
  if v_reporter is null then
    raise exception 'Not authenticated';
  end if;

  if p_target_type = 'user' then
    if p_target_id = v_reporter then
      raise exception 'Cannot report yourself';
    end if;
    if not exists (select 1 from public.profiles where id = p_target_id) then
      raise exception 'Target user not found';
    end if;
  elsif p_target_type = 'drop' then
    if not exists (
      select 1 from public.drops
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Drop not found, or is your own';
    end if;
  elsif p_target_type = 'drop_comment' then
    if not exists (
      select 1 from public.drop_comments
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Comment not found, or is your own';
    end if;
  elsif p_target_type = 'club' then
    if not exists (
      select 1 from public.clubs
      where id = p_target_id and owner_id <> v_reporter
    ) then
      raise exception 'Club not found, or is your own';
    end if;
  elsif p_target_type = 'club_post' then
    if not exists (
      select 1 from public.club_posts
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Club post not found, or is your own';
    end if;
  elsif p_target_type = 'club_post_comment' then
    if not exists (
      select 1 from public.club_post_comments
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Club post comment not found, or is your own';
    end if;
  elsif p_target_type = 'message' then
    if not exists (
      select 1 from public.messages m
      join public.conversations c on c.id = m.conversation_id
      where m.id = p_target_id
        and m.sender_id <> v_reporter
        and v_reporter in (c.user_a_id, c.user_b_id)
    ) then
      raise exception 'Message not found, is your own, or you are not a participant';
    end if;
  elsif p_target_type = 'redrop' then
    if not exists (
      select 1 from public.redrops
      where id = p_target_id and redropper_id <> v_reporter
    ) then
      raise exception 'Redrop not found, or is your own';
    end if;
  else
    raise exception 'Unsupported report target type: %', p_target_type;
  end if;

  insert into public.reports (reporter_id, target_type, target_id, category, detail)
  values (
    v_reporter,
    p_target_type,
    p_target_id,
    p_category,
    nullif(trim(coalesce(p_detail, '')), '')
  )
  returning id into v_report_id;

  return v_report_id;
end;
$$;

grant execute on function public.submit_report(text, uuid, text, text) to authenticated;

-- Notifies the original Drop's author on every ReDrop (Standard or
-- Quote alike -- the Product spec doesn't distinguish) -- mirrors
-- notify_drop_like()'s exact shape (WYN-012), reusing
-- notifications.drop_id the same way like_drop/comment_drop already do.
create or replace function public.notify_redrop()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  select author_id into v_author_id from public.drops where id = new.drop_id;
  -- ReDropping your own Drop is normal and allowed -- it just shouldn't
  -- notify you about your own action.
  if v_author_id is not null and v_author_id <> new.redropper_id
     and internal.notification_enabled(v_author_id, 'likes') then
    insert into public.notifications (recipient_id, actor_id, type, drop_id)
    values (v_author_id, new.redropper_id, 'redrop', new.drop_id);
  end if;
  return new;
end;
$$;

create trigger redrops_notify
  after insert on public.redrops
  for each row execute function public.notify_redrop();

-- home_feed gains a 3rd branch for ReDrops. content_type stays 'drop'
-- (not a new value) and id/author_id/image_url/caption/like_count/
-- comment_count all keep describing the *original* Drop -- so every
-- existing Like/Comment/Save action, and rankingScore() (WYN-018),
-- keeps working unmodified against a redrop-sourced row: liking a
-- card seen via ReDrop likes the original Drop, exactly matching the
-- Master Spec's "เครดิตเจ้าของเดิมต้องยังอยู่" requirement. Only
-- `created_at` changes meaning for this branch -- it is the *redrop's*
-- timestamp, not the original Drop's, so a freshly-shared old Drop
-- resurfaces near the top of a chronological/recency-weighted feed,
-- which is the entire point of the feature. New trailing columns
-- (redrop_count/redrop_id/redropper_*/quote_text) are appended after
-- comment_count, never inserted earlier in the list, so this stays a
-- valid `create or replace view` over the WYN-024 version below (adding
-- columns at the end is allowed; reordering or retyping existing ones
-- is not).
create or replace view public.home_feed
  with (security_invoker = true) as
select
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  d.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  null::bigint as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
  null::uuid as redrop_id,
  null::uuid as redropper_id,
  null::text as redropper_username,
  null::text as redropper_display_name,
  null::text as redropper_avatar_url,
  null::text as quote_text
from public.drops d
join public.profiles prof on prof.id = d.author_id
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
  p.created_at,
  p.caption,
  null::text as image_url,
  p.video_url,
  p.thumbnail_url,
  p.duration_seconds,
  p.view_count,
  (select count(*) from public.pop_likes where pop_id = p.id) as like_count,
  (select count(*) from public.pop_comments where pop_id = p.id) as comment_count,
  null::bigint as redrop_count,
  null::uuid as redrop_id,
  null::uuid as redropper_id,
  null::text as redropper_username,
  null::text as redropper_display_name,
  null::text as redropper_avatar_url,
  null::text as quote_text
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
  r.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  null::bigint as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
  r.id as redrop_id,
  r.redropper_id,
  redropper.username as redropper_username,
  redropper.display_name as redropper_display_name,
  redropper.avatar_url as redropper_avatar_url,
  r.quote_text
from public.redrops r
join public.drops d on d.id = r.drop_id
join public.profiles prof on prof.id = d.author_id
join public.profiles redropper on redropper.id = r.redropper_id
where not exists (
  select 1 from public.mutes
  where muter_id = auth.uid() and muted_id in (d.author_id, r.redropper_id)
);

grant select on public.home_feed to authenticated;

-- ============================================================
-- WYN-035: Poll ใน Drop
-- ============================================================

-- A Drop can now carry either an image or a Poll, never both this
-- round (see the Product spec's Risks -- Poll+image together, and
-- multi-image, are both out of scope). image_url therefore becomes
-- nullable. There is deliberately no cross-table CHECK enforcing
-- "image_url is not null or a drop_polls row exists" -- Postgres CHECK
-- constraints cannot reference other tables at all, and a deferred
-- constraint trigger would be new machinery this project has never
-- needed before. Instead, create_poll_drop() below is the *only*
-- sanctioned way to create a Drop with a null image_url: it inserts
-- both the drops row and its drop_polls row in one atomic function
-- call (mirroring create_orders()'s multi-table-insert-in-one-
-- transaction shape), so the "has content" invariant is guaranteed by
-- there being no other code path that can produce a null-image Drop,
-- not by a constraint checked after the fact.
alter table public.drops alter column image_url drop not null;

-- Structural validation (2-4 options, each 1-80 chars, no exact
-- duplicates) lives in this IMMUTABLE function rather than inline in
-- the CHECK below, only because a CHECK expression can't itself
-- contain a subquery -- unnest()'ing the array to inspect each
-- element needs one. The function still only ever looks at its own
-- argument, never another table, so this is a plain single-row CHECK
-- in spirit, just written as a named predicate for readability.
-- create_poll_drop() below re-validates the same rules before calling
-- this (defense in depth, same posture as every other RPC in this
-- schema re-deriving/re-checking rather than trusting the caller).
create or replace function public.valid_poll_options(p_options text[])
returns boolean
language sql
immutable
as $$
  select
    p_options is not null
    and array_length(p_options, 1) between 2 and 4
    and not exists (
      select 1 from unnest(p_options) as o(text)
      where o.text is null or char_length(trim(o.text)) not between 1 and 80
    )
    and (select count(distinct lower(trim(o))) from unnest(p_options) as o)
      = array_length(p_options, 1);
$$;

-- One Poll per Drop (drop_id unique) -- a 1:1 companion table rather
-- than columns on drops itself, same reasoning WYN-014's approach to
-- optional per-row extras used: most Drops never have a poll, and
-- PostgREST embeds a to-one relation cleanly via the unique FK.
create table if not exists public.drop_polls (
  id uuid primary key default gen_random_uuid(),
  drop_id uuid not null unique references public.drops (id) on delete cascade,
  options text[] not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint drop_polls_options_valid check (public.valid_poll_options(options))
);

create index if not exists drop_polls_drop_idx on public.drop_polls (drop_id);

alter table public.drop_polls enable row level security;

-- Same piggyback-on-drops'-own-SELECT-policy shape WYN-034's redrops
-- policy uses -- if the underlying Drop is invisible (blocked author),
-- the exists() makes the poll invisible too, with no separate
-- block-check written by hand.
create policy "Drop polls are viewable by authenticated users"
  on public.drop_polls
  for select
  to authenticated
  using (exists (select 1 from public.drops d where d.id = drop_id));

-- No insert/update/delete policy at all -- the only writer is
-- create_poll_drop() below (SECURITY DEFINER, bypasses RLS as its
-- owning role) and cascade-delete via the drops FK. An ordinary
-- authenticated client has no path to insert or mutate a drop_polls
-- row directly, same "no raw policy" posture as WYN-014's
-- club_members.

-- Individual votes are never readable by anyone but the voter --
-- "no one, not even the poll's author, can see who voted for what"
-- is a deliberate privacy decision (Product spec's "ผลโหวต
-- (privacy-first)"). Aggregate results are computed by
-- get_poll_results() below (SECURITY DEFINER, reads across this RLS)
-- rather than ever being derived from a client-side SELECT here.
create table if not exists public.drop_poll_votes (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.drop_polls (id) on delete cascade,
  voter_id uuid not null references public.profiles (id) on delete cascade,
  option_index smallint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (poll_id, voter_id)
);

create index if not exists drop_poll_votes_poll_idx on public.drop_poll_votes (poll_id);

alter table public.drop_poll_votes enable row level security;

create policy "Users can view only their own poll votes"
  on public.drop_poll_votes
  for select
  to authenticated
  using (auth.uid() = voter_id);

create policy "Users can vote as themselves"
  on public.drop_poll_votes
  for insert
  to authenticated
  with check (auth.uid() = voter_id);

-- Changing your mind (re-voting) is an UPDATE of the same row, not a
-- new INSERT -- the unique (poll_id, voter_id) index is what makes an
-- upsert from the client land here instead of failing as a duplicate.
create policy "Users can change their own poll vote"
  on public.drop_poll_votes
  for update
  to authenticated
  using (auth.uid() = voter_id)
  with check (auth.uid() = voter_id);

-- All the business rules RLS's `using`/`with check` can't express on
-- their own (poll not expired, option_index in range, not the poll's
-- own author, not posting-blocked, not blocked with the author) live
-- here instead -- fires for both the insert path and the
-- change-your-vote update path.
create or replace function public.validate_poll_vote()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_options text[];
  v_expires_at timestamptz;
  v_author_id uuid;
begin
  select dp.options, dp.expires_at, d.author_id
    into v_options, v_expires_at, v_author_id
  from public.drop_polls dp
  join public.drops d on d.id = dp.drop_id
  where dp.id = new.poll_id;

  if v_options is null then
    raise exception 'Poll not found';
  end if;

  if now() >= v_expires_at then
    raise exception 'Poll has closed';
  end if;

  if new.option_index < 0 or new.option_index >= array_length(v_options, 1) then
    raise exception 'Invalid poll option';
  end if;

  if new.voter_id = v_author_id then
    raise exception 'Cannot vote on your own poll';
  end if;

  if internal.is_posting_blocked(new.voter_id) then
    raise exception 'Account is posting-restricted';
  end if;

  if internal.is_blocked_either_way(new.voter_id, v_author_id) then
    raise exception 'Cannot vote on this poll';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger drop_poll_votes_validate
  before insert or update on public.drop_poll_votes
  for each row execute function public.validate_poll_vote();

-- Atomic "create a Poll Drop" -- inserts drops (image_url left null)
-- + drop_polls + (optionally) drop_mentions in one transaction, the
-- only sanctioned way to produce a null-image drops row (see the
-- image_url comment above). Mirrors create_orders()'s
-- multi-table-insert-in-one-function shape. Re-validates options with
-- the same public.valid_poll_options() the table CHECK uses, and
-- duration against the fixed 1/3/7-day menu the Product spec locked
-- in (no custom durations) -- both belt-and-suspenders against a
-- malformed direct RPC call bypassing whatever the client UI enforces.
create or replace function public.create_poll_drop(
  p_caption text,
  p_options text[],
  p_duration_days int,
  p_mentioned_user_ids uuid[] default '{}'
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

  -- Trimmed server-side (not just validated-as-trimmed) so a direct
  -- RPC call bypassing the Flutter client's own .trim() can't leave
  -- stray leading/trailing whitespace sitting in stored option text.
  select array_agg(trim(o)) into v_options from unnest(p_options) as o;

  if not public.valid_poll_options(v_options) then
    raise exception 'Poll must have 2-4 non-empty, non-duplicate options (max 80 characters each)';
  end if;

  if p_duration_days not in (1, 3, 7) then
    raise exception 'Poll duration must be 1, 3, or 7 days';
  end if;

  insert into public.drops (author_id, image_url, caption)
  values (v_author, null, trim(p_caption))
  returning id into v_drop_id;

  insert into public.drop_polls (drop_id, options, expires_at)
  values (v_drop_id, v_options, now() + make_interval(days => p_duration_days));

  -- WYN-045: this RPC is SECURITY DEFINER and bypasses drop_mentions'
  -- own RLS INSERT policy entirely -- without this same
  -- internal.mention_allowed() check the policy below also gained,
  -- Mention Permission would be fully bypassable via Poll Drop
  -- creation. Same non-error posture as the block-exclusion right
  -- next to it: the caption may still literally read "@username", it
  -- just doesn't produce a drop_mentions row (and therefore no
  -- notification) for a user who disallows it.
  insert into public.drop_mentions (drop_id, mentioned_user_id)
  select v_drop_id, m
  from unnest(p_mentioned_user_ids) as m
  where not internal.is_blocked_either_way(v_author, m)
    and internal.mention_allowed(m, v_author);

  return v_drop_id;
end;
$$;

-- Aggregate poll results, batched over a page's worth of poll ids at
-- once (mirroring DropRepository's existing _fetchLikedDropIds/
-- _fetchRedroppedDropIds "one query per page, not one per card"
-- shape). visible=false means "keep this poll's options-only, no
-- percentages" client-side -- the caller hasn't voted, isn't the
-- author, and the poll hasn't closed yet. total_votes/option_counts
-- are only ever populated when visible=true; SECURITY DEFINER is what
-- lets this count across every voter's row despite drop_poll_votes'
-- own SELECT policy restricting each voter to their own row.
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
    and not internal.is_blocked_either_way(v_me, d.author_id);
end;
$$;

-- home_feed/saved_feed gain 3 trailing poll columns (poll_id,
-- poll_options, poll_expires_at) on every branch -- null for Pop and
-- for any Drop/ReDrop without a poll. Deliberately *not* including
-- vote counts/results here: those must only ever come from
-- get_poll_results() so its visibility rule is enforced once, at the
-- DB layer, not reimplemented (or forgotten) at every call site that
-- reads these views. Appended after quote_text, same "add at the end,
-- never reorder" discipline WYN-034 established for this view.
create or replace view public.home_feed
  with (security_invoker = true) as
select
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  d.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  null::bigint as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
  null::uuid as redrop_id,
  null::uuid as redropper_id,
  null::text as redropper_username,
  null::text as redropper_display_name,
  null::text as redropper_avatar_url,
  null::text as quote_text,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at
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
  p.created_at,
  p.caption,
  null::text as image_url,
  p.video_url,
  p.thumbnail_url,
  p.duration_seconds,
  p.view_count,
  (select count(*) from public.pop_likes where pop_id = p.id) as like_count,
  (select count(*) from public.pop_comments where pop_id = p.id) as comment_count,
  null::bigint as redrop_count,
  null::uuid as redrop_id,
  null::uuid as redropper_id,
  null::text as redropper_username,
  null::text as redropper_display_name,
  null::text as redropper_avatar_url,
  null::text as quote_text,
  null::uuid as poll_id,
  null::text[] as poll_options,
  null::timestamptz as poll_expires_at
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
  r.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  null::bigint as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
  r.id as redrop_id,
  r.redropper_id,
  redropper.username as redropper_username,
  redropper.display_name as redropper_display_name,
  redropper.avatar_url as redropper_avatar_url,
  r.quote_text,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at
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

-- Same 3 trailing columns added to saved_feed's Drop branch (Pop
-- branch: null) so a saved Poll Drop renders correctly in the Saved
-- tab too -- see WYN-013's original view this redefines.
create or replace view public.saved_feed
  with (security_invoker = true) as
select
  s.user_id,
  s.created_at as saved_at,
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  d.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  null::bigint as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at
from public.saves s
join public.drops d on d.id = s.content_id and s.content_type = 'drop'
join public.profiles prof on prof.id = d.author_id
left join public.drop_polls dp on dp.drop_id = d.id
union all
select
  s.user_id,
  s.created_at as saved_at,
  p.id,
  'pop'::text as content_type,
  p.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  p.created_at,
  p.caption,
  null::text as image_url,
  p.video_url,
  p.thumbnail_url,
  p.duration_seconds,
  p.view_count,
  (select count(*) from public.pop_likes where pop_id = p.id) as like_count,
  (select count(*) from public.pop_comments where pop_id = p.id) as comment_count,
  null::uuid as poll_id,
  null::text[] as poll_options,
  null::timestamptz as poll_expires_at
from public.saves s
join public.pops p on p.id = s.content_id and s.content_type = 'pop'
join public.profiles prof on prof.id = p.author_id;

grant select on public.saved_feed to authenticated;

-- ============================================================
-- WYN-036: Draft System
-- ============================================================

-- Structural-only validation for a draft's poll options -- looser
-- than public.valid_poll_options() (WYN-035) on purpose: a Draft is
-- explicitly allowed to be incomplete (e.g. duplicate or still-empty
-- option text while the user is mid-edit) since the whole point of
-- saving one is "not finished yet." Only the array size (2-4, the
-- Poll composer's own UI bounds) and a per-option length cap are
-- enforced here -- full validation (non-empty, no duplicates) only
-- ever runs at actual publish time via create_poll_drop(), unchanged.
create or replace function public.valid_draft_poll_options(p_options text[])
returns boolean
language sql
immutable
as $$
  select
    p_options is null
    or (
      array_length(p_options, 1) between 2 and 4
      and not exists (
        select 1 from unnest(p_options) as o(text)
        where o.text is not null and char_length(o.text) > 80
      )
    );
$$;

-- A Draft is a fully separate table from `drops` -- never inserted
-- into, joined with, or read by home_feed/search/notifications/
-- reports/anything else in the app. It is not a real Drop yet, so
-- none of those systems have any business seeing it; keeping it
-- structurally isolated (rather than e.g. a `status = 'draft'` flag
-- on `drops` itself) means zero risk of a Draft accidentally leaking
-- into any existing query that assumes every `drops` row is
-- published content. image_url/caption/poll_* are all nullable --
-- unlike a published Drop, a Draft can legitimately have none, one,
-- or a partial combination of them while the user is mid-edit.
create table if not exists public.drop_drafts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  image_url text,
  caption text,
  poll_options text[],
  poll_duration_days int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint drop_drafts_caption_length
    check (caption is null or char_length(caption) between 1 and 500),
  constraint drop_drafts_poll_options_valid
    check (public.valid_draft_poll_options(poll_options)),
  constraint drop_drafts_poll_duration_valid
    check (poll_duration_days is null or poll_duration_days in (1, 3, 7))
);

create index if not exists drop_drafts_author_updated_idx
  on public.drop_drafts (author_id, updated_at desc);

alter table public.drop_drafts enable row level security;

-- Every policy is scoped to auth.uid() = author_id, with no
-- exceptions or piggybacked visibility for anyone else -- unlike
-- redrops/drop_polls (WYN-034/WYN-035), which piggyback SELECT on
-- another table's own policy, a Draft has no "other party" to ever
-- share visibility with. This is Product's "Draft ต้องเป็น Private"
-- requirement enforced directly as the only policy shape, not layered
-- on top of a more permissive default.
create policy "Users can view only their own drafts"
  on public.drop_drafts
  for select
  to authenticated
  using (auth.uid() = author_id);

create policy "Users can create their own drafts"
  on public.drop_drafts
  for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Users can update their own drafts"
  on public.drop_drafts
  for update
  to authenticated
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);

create policy "Users can delete their own drafts"
  on public.drop_drafts
  for delete
  to authenticated
  using (auth.uid() = author_id);

-- ============================================================
-- WYN-037: Edit / Delete Drop (time window + soft delete/restore)
-- ============================================================

-- edited_at: null until the first successful edit_drop() call, then
-- set every time -- drives the "แก้ไขแล้ว" UI badge. deleted_at: null
-- means visible/live; once set (via soft_delete_drop()) the row still
-- physically exists but is hidden from everyone except its own author
-- (see the SELECT policy changes below) until either restore_drop()
-- clears it again or the 30-day restore window lapses.
alter table public.drops add column if not exists edited_at timestamptz;
alter table public.drops add column if not exists deleted_at timestamptz;

-- There is deliberately no client-facing UPDATE policy on `drops` at
-- all (there never was one before this task either) -- every mutation
-- to an existing Drop goes through exactly one of the 3 RPCs below,
-- each SECURITY DEFINER so it can enforce its own business rule (owner
-- + time window) directly rather than trying to express "created_at >
-- now() - 30 minutes" cleanly across a using/with check pair. This
-- mirrors create_poll_drop()/apply_moderation_action()'s own reasoning
-- for using an RPC instead of raw RLS wherever the rule is more than
-- row ownership.
--
-- Self-delete no longer goes through a raw client DELETE either --
-- see the dropped "Users can delete their own drops" policy further
-- down. Moderation's apply_moderation_action() (WYN-029) is
-- unaffected: it hard-deletes directly inside its own SECURITY
-- DEFINER function, which already bypasses RLS entirely and never
-- depended on that policy to begin with.

create or replace function public.edit_drop(p_drop_id uuid, p_caption text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_drop record;
begin
  select * into v_drop from public.drops where id = p_drop_id for update;
  if v_drop is null then
    raise exception 'Drop not found';
  end if;
  if v_drop.author_id <> v_me then
    raise exception 'Only the author can edit this Drop';
  end if;
  if v_drop.deleted_at is not null then
    raise exception 'Cannot edit a deleted Drop';
  end if;
  if v_drop.created_at <= now() - interval '30 minutes' then
    raise exception 'The 30-minute edit window has passed';
  end if;

  -- WYNOS V1.0.0 Beta requirement 2: a Drop with no image (a text-only
  -- Drop, or a Poll -- its "caption" is really the question) can no
  -- longer be edited down to an empty caption -- that would leave
  -- nothing at all, and trip the drops_has_content CHECK constraint
  -- below with a much less clear error than this one. The client's own
  -- EditDropCaptionScreen._canSave already prevents reaching this RPC
  -- with an empty caption in that case; this is the same defense-in-
  -- depth re-check every other RPC in this schema already does rather
  -- than trusting the caller.
  if v_drop.image_url is null
     and length(trim(both from p_caption)) = 0 then
    raise exception 'This Drop has no image -- its caption cannot be left empty';
  end if;

  update public.drops
  set caption = nullif(trim(both from p_caption), ''),
      edited_at = now()
  where id = p_drop_id;
end;
$$;

grant execute on function public.edit_drop(uuid, text) to authenticated;

create or replace function public.soft_delete_drop(p_drop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_drop record;
begin
  select * into v_drop from public.drops where id = p_drop_id for update;
  if v_drop is null then
    raise exception 'Drop not found';
  end if;
  if v_drop.author_id <> v_me then
    raise exception 'Only the author can delete this Drop';
  end if;
  if v_drop.deleted_at is not null then
    raise exception 'Drop is already deleted';
  end if;

  update public.drops set deleted_at = now() where id = p_drop_id;
end;
$$;

grant execute on function public.soft_delete_drop(uuid) to authenticated;

create or replace function public.restore_drop(p_drop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_drop record;
begin
  select * into v_drop from public.drops where id = p_drop_id for update;
  if v_drop is null then
    raise exception 'Drop not found';
  end if;
  if v_drop.author_id <> v_me then
    raise exception 'Only the author can restore this Drop';
  end if;
  if v_drop.deleted_at is null then
    raise exception 'Drop is not deleted';
  end if;
  if v_drop.deleted_at <= now() - interval '30 days' then
    raise exception 'The 30-day restore window has passed';
  end if;

  update public.drops set deleted_at = null where id = p_drop_id;
end;
$$;

grant execute on function public.restore_drop(uuid) to authenticated;

-- Self-delete now exclusively goes through soft_delete_drop() above --
-- drop the raw client DELETE policy entirely so there is no remaining
-- path for a user to bypass the restore window by hard-deleting their
-- own Drop directly.
drop policy "Users can delete their own drops" on public.drops;

-- Extends WYN-028's block-exclusion predicate (unchanged) with the new
-- visibility rule: a deleted Drop is invisible to everyone except its
-- own author. This single change is sufficient to hide a soft-deleted
-- Drop from Home Feed/Search/Profile grid *and* from every ReDrop of
-- it -- home_feed/saved_feed are both `security_invoker = true` views
-- that join straight onto `public.drops`, so RLS on this one table is
-- enforced inside those joins too. No view redefinition needed.
drop policy "Drops are viewable by authenticated users, excluding blocked authors" on public.drops;
create policy "Drops are viewable by authenticated users, excluding blocked authors and deleted"
  on public.drops
  for select
  to authenticated
  using (
    not internal.is_blocked_either_way(auth.uid(), author_id)
    and (deleted_at is null or auth.uid() = author_id)
  );

-- A soft-deleted Drop's comments must become just as invisible as the
-- Drop itself -- without this, drop_comments' own SELECT policy (row-
-- level on drop_comments only) would let anyone who already knows a
-- comment's id/drop_id keep reading it directly, an indirect leak that
-- didn't exist before this task (the old hard DELETE cascade-deleted
-- every comment along with the Drop; a soft delete leaves them in
-- place).
drop policy "Drop comments are viewable by authenticated users, excluding blocked authors" on public.drop_comments;
create policy "Drop comments are viewable by authenticated users, excluding blocked authors and on deleted drops only by their author"
  on public.drop_comments
  for select
  to authenticated
  using (
    not internal.is_blocked_either_way(auth.uid(), author_id)
    and exists (
      select 1 from public.drops d
      where d.id = drop_comments.drop_id
        and (d.deleted_at is null or d.author_id = auth.uid())
    )
  );

-- QA finding (WYN-037): the INSERT policy never checked deleted_at at
-- all -- before this task a soft-deleted Drop's row didn't exist, so
-- a comment insert against it was already impossible via the
-- drop_comments_drop_id_fkey constraint. Now that delete is soft, the
-- row (and the FK target) still exists, so without this a stranger
-- could still comment on a Drop they can no longer even see -- and
-- notify_drop_comment()'s trigger would still notify its author,
-- surfacing "someone commented" on content they believe is gone.
--
-- SECURITY DEFINER, mirroring internal.drop_author_id() immediately
-- above -- a plain `exists (select 1 from public.drops where id = ...
-- and deleted_at is not null)` inside the policy below would be
-- self-defeating: that subquery is itself subject to `drops`' own
-- SELECT RLS, which already hides a deleted Drop from anyone but its
-- author, so exists() would evaluate false (not-exists true, i.e.
-- "not deleted") for exactly the stranger this check exists to catch
-- -- caught by this task's own QA before it shipped by proving the
-- naive version stayed exploitable.
create or replace function internal.is_drop_deleted(p_drop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select deleted_at is not null from public.drops where id = p_drop_id;
$$;

grant execute on function internal.is_drop_deleted(uuid) to authenticated;

drop policy "Users can comment on drops as themselves, excluding blocked authors and moderation-blocked accounts" on public.drop_comments;
create policy "Users can comment on drops as themselves, excluding blocked authors, moderation-blocked accounts, and deleted drops"
  on public.drop_comments
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and not internal.is_blocked_either_way(auth.uid(), internal.drop_author_id(drop_id))
    and not internal.is_posting_blocked(auth.uid())
    and coalesce(internal.is_drop_deleted(drop_id), false) = false
  );

-- ============================================================
-- WYN-038: View Counting System (Drop) -- rate limit, velocity cap
--
-- WYN-083 (Wynos V1.0.0 Beta2, item 21, 2026-09-02): Founder overrode
-- this task's original "unique-viewer, lifetime dedup, exclude the
-- author" design -- "การนับวิว จะนับตั้งแต่วินาทีแรก ที่มีคนเห็น
-- รวมถึงเจ้าของโพสต์ด้วย นับไม่จำกัด" (count from the first moment
-- someone sees it, including the post's own author, uncapped). This
-- table went from a "has this viewer ever seen this Drop" ledger (one
-- row per (drop_id, viewer_id) pair, enforced by that pair being the
-- primary key) to a plain view-event log -- one row per View, repeats
-- from the same viewer (including the author) all count. Matches
-- Pop's own increment_pop_view_count() (WYN-006), which never had a
-- dedup/self-view exclusion in the first place -- this brings Drop's
-- view counting in line with Pop's rather than the other way around.
-- ============================================================

create table if not exists public.drop_views (
  id uuid not null default gen_random_uuid() primary key,
  drop_id uuid not null references public.drops (id) on delete cascade,
  viewer_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Read hot-path for record_drop_view()'s rate-limit/velocity-cap
-- window queries below (one filters created_at scoped to viewer_id,
-- the other created_at scoped to drop_id) and for drop_view_count()'s
-- per-drop total -- three separate access patterns now that drop_id
-- is no longer part of a composite primary key/its implicit index, so
-- each gets its own plain index instead of the one composite index
-- used to cover both. There is no purge/archival job yet (this task's
-- original Product spec, "Risks") -- more true than ever now that
-- repeat views are no longer deduped away, so this table grows faster
-- than before.
create index if not exists drop_views_created_at_idx
  on public.drop_views (created_at);

create index if not exists drop_views_drop_id_idx
  on public.drop_views (drop_id);

alter table public.drop_views enable row level security;

-- Deliberately NOT the "viewable by every authenticated user" shape
-- drop_likes/drop_comments/pop_likes use -- "who viewed what" is
-- private to the viewer themselves, unlike a Like. Opening this up the
-- same way Likes are would let any authenticated user query
-- drop_views directly over the REST API and learn exactly which Drops
-- a specific other person has opened -- a real privacy leak nothing in
-- the app's UI ever intends to expose, mirroring the lesson from
-- .wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md (an
-- overly-broad SELECT policy leaking identity that should have stayed
-- private). A user can only ever see the rows of Drops *they*
-- personally viewed, never anyone else's.
--
-- This intentionally makes a plain correlated `count(*) from
-- drop_views` subquery inside home_feed/saved_feed (both
-- security_invoker = true, so RLS applies to whoever is reading the
-- view) return the wrong number for anyone but the viewer themselves
-- -- public.drop_view_count() below exists specifically to give every
-- viewer of a Drop the *same*, correct total without ever exposing a
-- raw drop_views row (or any viewer identity) to them.
create policy "Users can view only their own Drop view history"
  on public.drop_views
  for select
  to authenticated
  using (auth.uid() = viewer_id);

-- No INSERT/UPDATE/DELETE policy at all, on purpose -- every write
-- goes through record_drop_view() below (SECURITY DEFINER), which is
-- the only place the rate-limit/velocity-cap rules (WYN-083: the only
-- ones left -- see this table's own doc comment) are enforced. A raw
-- client insert would bypass those checks, so there is deliberately
-- no way to perform one --
-- mirrors drop_views' sibling policy comment above and
-- increment_pop_view_count()'s identical "no update policy" reasoning
-- (WYN-006).

-- Rate-limit (20 inserts / 60 seconds, per account) and velocity-cap
-- (50 inserts / 10 seconds, per Drop) below are Product's own
-- temporary starting numbers -- there is no production traffic yet to
-- calibrate against (this task's Product spec, "Risks"). Revisit once
-- real traffic data exists; both are kept as isolated, easy-to-find
-- literal values right where they're used, rather than scattered
-- across the codebase -- mirrors how WYN-037 documented its own
-- 30-minute/30-day windows next to each of edit_drop()/
-- soft_delete_drop()/restore_drop()'s own checks, for the same reason
-- (a plpgsql function body has no clean way to reference one shared
-- named constant across multiple functions).
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

  -- (a) Drop doesn't exist, or is soft-deleted (WYN-037) -- silent
  -- no-op, never an exception. View counting must never surface an
  -- error back to the client (Product spec) -- this also covers the
  -- harmless race where the author deletes the Drop a moment after
  -- the viewer opened DropDetailScreen. Checks v_drop.deleted_at
  -- directly (equivalent to internal.is_drop_deleted(), which this
  -- function already has the row in hand to avoid re-querying).
  if v_drop is null or v_drop.deleted_at is not null then
    return;
  end if;

  -- (b) Rate limit, per account: at most 20 new View rows from this
  -- account in the trailing 60 seconds.
  select count(*) into v_account_recent_count
  from public.drop_views
  where viewer_id = v_me and created_at > now() - interval '60 seconds';
  if v_account_recent_count >= 20 then
    return;
  end if;

  -- (c) Velocity cap, per Drop: at most 50 new View rows landing on
  -- this one Drop in the trailing 10 seconds, regardless of which
  -- account each came from -- catches a bot ring (many different
  -- accounts) piling onto a single Drop to fake virality, which the
  -- per-account rate limit above can't catch alone.
  select count(*) into v_drop_recent_count
  from public.drop_views
  where drop_id = p_drop_id and created_at > now() - interval '10 seconds';
  if v_drop_recent_count >= 50 then
    return;
  end if;

  -- Every check above passed -- record the View. WYN-083: no more
  -- ON CONFLICT DO NOTHING/unique-viewer dedup -- every call that
  -- clears (a)-(c) above is its own new View row now, including
  -- repeats from the same viewer and the Drop's own author (the
  -- client-side skip for the author case is gone too -- see
  -- DropDetailScreen._recordViewOnce()).
  insert into public.drop_views (drop_id, viewer_id)
  values (p_drop_id, v_me);
end;
$$;

grant execute on function public.record_drop_view(uuid) to authenticated;

-- Bypasses drop_views' own restrictive SELECT policy on purpose -- see
-- that policy's comment above for why a raw subquery can't be used
-- instead. Returns only a count, never a row, so no viewer identity is
-- ever exposed through this path either. SECURITY DEFINER functions
-- run with their owner's privileges regardless of the caller (or of
-- whether the calling view is security_invoker), the same "runs as
-- owner, bypassing owner-exempt RLS" mechanism internal.is_drop_deleted()
-- and internal.drop_author_id() already rely on.
create or replace function public.drop_view_count(p_drop_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*) from public.drop_views where drop_id = p_drop_id;
$$;

grant execute on function public.drop_view_count(uuid) to authenticated;

-- home_feed/saved_feed's Drop branches (WYN-007/WYN-013) reserved a
-- view_count column from the start but hardcoded it to null::bigint --
-- this is the first task to actually populate it, via
-- drop_view_count() (never a raw correlated subquery on drop_views
-- directly) so every viewer of the feed sees the same, correct total
-- regardless of their own drop_views SELECT visibility -- see that
-- function's own comment above. Pop's own view_count branches
-- (p.view_count, both views, both already non-null) are untouched --
-- out of scope this round (Product spec, "ขอบเขต: Drop เท่านั้น").
-- Same "append a fresh full redefinition rather than editing history
-- in place" discipline as every prior task that changed one of these
-- two views (WYN-034 quote_text/redrop columns, WYN-035 poll columns).
create or replace view public.home_feed
  with (security_invoker = true) as
select
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  d.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  public.drop_view_count(d.id) as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
  null::uuid as redrop_id,
  null::uuid as redropper_id,
  null::text as redropper_username,
  null::text as redropper_display_name,
  null::text as redropper_avatar_url,
  null::text as quote_text,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at
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
  p.created_at,
  p.caption,
  null::text as image_url,
  p.video_url,
  p.thumbnail_url,
  p.duration_seconds,
  p.view_count,
  (select count(*) from public.pop_likes where pop_id = p.id) as like_count,
  (select count(*) from public.pop_comments where pop_id = p.id) as comment_count,
  null::bigint as redrop_count,
  null::uuid as redrop_id,
  null::uuid as redropper_id,
  null::text as redropper_username,
  null::text as redropper_display_name,
  null::text as redropper_avatar_url,
  null::text as quote_text,
  null::uuid as poll_id,
  null::text[] as poll_options,
  null::timestamptz as poll_expires_at
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
  r.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  public.drop_view_count(d.id) as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
  r.id as redrop_id,
  r.redropper_id,
  redropper.username as redropper_username,
  redropper.display_name as redropper_display_name,
  redropper.avatar_url as redropper_avatar_url,
  r.quote_text,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at
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

-- WYNOSHomeSpec.md 4.8 (Liked-by row) + 4.10 (Top reply preview) --
-- both are independent tasks that happen to touch the same view, so
-- this single redefinition carries both forward together (whichever of
-- the two PRs merges first, the other's own copy of this exact block
-- is a no-op CREATE OR REPLACE against the same final shape):
--   * `liked_by`: the first 3 likers of each row (most-recent-first),
--     jsonb array of {id, username, display_name, avatar_url} --
--     drop_likes/pop_likes already existed and are already readable by
--     any authenticated user, so this is just a new view column.
--   * `top_reply`: the highest-engagement top-level comment on each
--     row (by its own like count on drop_comment_likes/
--     pop_comment_likes), or null if no comment has ever been liked
--     (Founder decision: an unliked comment doesn't count as "worth
--     surfacing" -- see WYNOSHomeSpec.md 4.10's own "at least one reply
--     worth surfacing" trigger). jsonb object of
--     {author_username, author_display_name, text}.
-- Same "append a fresh full redefinition" discipline as every prior
-- task that changed this view.
-- SCHEMA-002 (Beta2 audit, 2026-09-03): dropped first, not just
-- replaced. This redefinition inserts `liked_by` *before*
-- `comment_count` rather than appending it, and CREATE OR REPLACE VIEW
-- refuses to rename or reorder an existing column -- so a fresh load of
-- this file aborted here with `cannot change name of view column
-- "comment_count" to "liked_by"`, leaving the database half-migrated.
-- Production was built up statement by statement and so never hit it,
-- but no new environment (staging, disaster recovery, a developer's
-- machine) could be created from this file, and 29 of the 33
-- supabase/tests/*.sh could not run at all because each one starts by
-- loading it. Nothing references the view at this point in the file, so
-- dropping it here is safe and the end state is byte-for-byte the same.
drop view if exists public.home_feed;
create or replace view public.home_feed
  with (security_invoker = true) as
select
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
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
  null::text as quote_text,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at
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
  null::text as quote_text,
  null::uuid as poll_id,
  null::text[] as poll_options,
  null::timestamptz as poll_expires_at
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
  r.quote_text,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at
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

create or replace view public.saved_feed
  with (security_invoker = true) as
select
  s.user_id,
  s.created_at as saved_at,
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  d.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  public.drop_view_count(d.id) as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at
from public.saves s
join public.drops d on d.id = s.content_id and s.content_type = 'drop'
join public.profiles prof on prof.id = d.author_id
left join public.drop_polls dp on dp.drop_id = d.id
union all
select
  s.user_id,
  s.created_at as saved_at,
  p.id,
  'pop'::text as content_type,
  p.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  p.created_at,
  p.caption,
  null::text as image_url,
  p.video_url,
  p.thumbnail_url,
  p.duration_seconds,
  p.view_count,
  (select count(*) from public.pop_likes where pop_id = p.id) as like_count,
  (select count(*) from public.pop_comments where pop_id = p.id) as comment_count,
  null::uuid as poll_id,
  null::text[] as poll_options,
  null::timestamptz as poll_expires_at
from public.saves s
join public.pops p on p.id = s.content_id and s.content_type = 'pop'
join public.profiles prof on prof.id = p.author_id;

grant select on public.saved_feed to authenticated;

-- ============================================================
-- WYN-039: Private Account + Follow Request
-- ============================================================

-- Account type. Default false everywhere -- every existing profile and
-- every new signup stays Public exactly as today unless the user opts
-- in via Settings (WYN-039 Design, Screen 1).
alter table public.profiles
  add column if not exists is_private boolean not null default false;

-- Single reusable predicate, mirrors internal.is_blocked_either_way's
-- placement/shape exactly -- security definer so it can be called from
-- inside other tables' RLS policies (drops, follows itself) without
-- those policies' own subqueries against `follows` re-triggering
-- `follows`' own (now-restrictive, see below) SELECT policy. Without
-- security definer here, `follows`' policy calling this function would
-- recurse into `follows`' own RLS via the `exists (... from follows
-- ...)` check below, since a plain (non-definer) function runs with the
-- caller's RLS applied to every table it touches.
create or replace function internal.can_view_author_content(p_viewer uuid, p_author uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_author = p_viewer
    or not exists (select 1 from public.profiles where id = p_author and is_private)
    or exists (
      select 1 from public.follows
      where follower_id = p_viewer and following_id = p_author
    );
$$;

-- Pending Follow Request state. A separate table from `follows` (not a
-- `status` column added to it) -- unlike conversations.status (WYN-031
-- -> WYN-032), `follows` already has years of call sites assuming every
-- row means "accepted follow" (FollowRepository, home_feed/saved_feed
-- ranking, get_or_create_conversation()'s follow check, badge counts).
-- Retrofitting all of them to filter a new status column is far riskier
-- than a new table that leaves every one of those untouched.
create table if not exists public.follow_requests (
  requester_id uuid not null references public.profiles (id) on delete cascade,
  target_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (requester_id, target_id),
  constraint follow_requests_no_self check (requester_id <> target_id)
);

alter table public.follow_requests enable row level security;

-- Only the two parties involved may see a pending request at all -- a
-- request is exactly as sensitive as a Message Request (WYN-032's
-- message_requests view has the same "only the two parties" shape),
-- not open like `follows`' own SELECT policy.
create policy "Follow requests are viewable by the two parties only"
  on public.follow_requests
  for select
  to authenticated
  using (auth.uid() in (requester_id, target_id));

create policy "Users can send follow requests as themselves"
  on public.follow_requests
  for insert
  to authenticated
  with check (
    auth.uid() = requester_id
    and not internal.is_blocked_either_way(auth.uid(), target_id)
    and exists (select 1 from public.profiles where id = target_id and is_private)
    and not exists (
      select 1 from public.follows
      where follower_id = auth.uid() and following_id = target_id
    )
  );

-- Requester cancels their own pending request, or target rejects a
-- request sent to them -- both are a plain DELETE, no RPC needed (no
-- edge case as subtle as WYN-032's requested_by-on-an-active-
-- conversation situation exists here).
create policy "Requester or target can remove a follow request"
  on public.follow_requests
  for delete
  to authenticated
  using (auth.uid() in (requester_id, target_id));

-- Fires the `follow_request` notification the moment a request is
-- created -- mirrors the trigger-per-table-event shape every other
-- ordinary-user-action notification in this schema uses (notify_follow,
-- notify_drop_like, etc.), since (unlike message_request, which is
-- inserted manually inside get_or_create_conversation()) nothing else
-- server-side runs when a client inserts a follow_requests row directly.
create or replace function internal.notify_follow_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if internal.notification_enabled(new.target_id, 'follows') then
    insert into public.notifications (recipient_id, actor_id, type)
    values (new.target_id, new.requester_id, 'follow_request');
  end if;
  return new;
end;
$$;

create trigger follow_requests_notify
  after insert on public.follow_requests
  for each row execute function internal.notify_follow_request();

-- Accept: must be an RPC (not a raw client insert into `follows`) --
-- deleting the request and creating the follow relationship has to
-- happen atomically, and only the target may perform it.
create or replace function public.accept_follow_request(p_requester_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.follow_requests
  where requester_id = p_requester_id and target_id = auth.uid();

  if not found then
    raise exception 'Follow request not found, or not yours to accept';
  end if;

  insert into public.follows (follower_id, following_id)
  values (p_requester_id, auth.uid())
  on conflict do nothing;

  if internal.notification_enabled(p_requester_id, 'follows') then
    insert into public.notifications (recipient_id, actor_id, type)
    values (p_requester_id, auth.uid(), 'follow_request_accepted');
  end if;
end;
$$;

grant execute on function public.accept_follow_request(uuid) to authenticated;

-- Rejecting is just `delete from follow_requests` from the client,
-- allowed by the DELETE policy above -- no notification is sent to the
-- requester (mirrors Message Request's Delete, WYN-032), and no RPC is
-- needed since there's no side effect beyond the row disappearing.

-- Switching Private -> Public auto-approves every request that was
-- still waiting -- the user just chose to let everyone see their
-- content, so there is no reason left to keep anyone waiting on a
-- decision (mirrors ordinary Instagram-style behavior).
create or replace function internal.auto_approve_pending_follow_requests()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_private = false and old.is_private = true then
    insert into public.follows (follower_id, following_id)
    select requester_id, target_id
    from public.follow_requests
    where target_id = new.id
    on conflict do nothing;

    delete from public.follow_requests where target_id = new.id;
  end if;
  return new;
end;
$$;

create trigger profiles_auto_approve_follow_requests
  after update of is_private on public.profiles
  for each row execute function internal.auto_approve_pending_follow_requests();

-- The single point of enforcement: gate Drop visibility on the same RLS
-- layer WYN-027 already uses for Block, so every existing reader of
-- `drops` -- home_feed/saved_feed (both security_invoker views),
-- redrops (already piggybacks via `exists (select 1 from drops ...)`),
-- drop_comments (same piggyback shape, WYN-037), drop_polls (same
-- shape, WYN-035), and every direct `.from('drops')` client query
-- (Search/Profile grid/fetchById) -- inherits the private-account gate
-- automatically, with no separate change needed at any of those call
-- sites. This is why Mute (WYN-028) *couldn't* reuse this shape (mute
-- only ever hid content from the Home/Saved feed, never from a direct
-- profile visit) but Block and now Private both can: both are meant to
-- be a full, everywhere block on visibility.
-- NOTE: WYN-037 already renamed this policy to "...excluding blocked
-- authors and deleted" (its own USING clause also excludes a
-- soft-deleted Drop unless you're its author) -- that name and this
-- task's OLD pre-WYN-037 name below both truncate to the identical
-- 63-byte Postgres identifier prefix, so `drop policy` by either string
-- targets the same underlying policy. Named here by its current
-- (WYN-037) full name to avoid the same confusion, and the soft-delete
-- condition is carried forward unchanged into the new USING clause.
drop policy "Drops are viewable by authenticated users, excluding blocked authors and deleted" on public.drops;
create policy "Drops are viewable by authenticated users, excluding blocked, deleted, and locked-private authors"
  on public.drops
  for select
  to authenticated
  using (
    not internal.is_blocked_either_way(auth.uid(), author_id)
    and (deleted_at is null or auth.uid() = author_id)
    and internal.can_view_author_content(auth.uid(), author_id)
  );

-- get_poll_results() (WYN-035) is SECURITY DEFINER and already
-- duplicates its own is_blocked_either_way check in its WHERE clause
-- precisely because it can't rely on drops' RLS -- it bypasses RLS
-- entirely, poll_id in hand is enough to call it directly. Needs the
-- same duplicated check added for private accounts, or a stranger could
-- still read a private Drop's poll results by poll_id even though the
-- Drop row itself is now correctly hidden from them.
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
    and internal.can_view_author_content(v_me, d.author_id);
end;
$$;

-- follows' own SELECT policy: a party to an edge can always see it
-- (needed for FollowRepository.isFollowing/badge counts/self-status
-- regardless of the other side's privacy -- otherwise a user couldn't
-- even tell whether *they themselves* still follow a private account);
-- a third party can see it only when *both* people's content are
-- visible to them. Slightly more conservative than Instagram (which
-- shows a private account's own follower/following list to its
-- accepted followers even when some entries in that list are people the
-- viewer can't otherwise see) but far simpler to reason about and audit
-- -- one predicate, symmetric, reused as-is from can_view_author_content.
drop policy "Follows are viewable by authenticated users" on public.follows;
create policy "Follows are viewable by parties or when both sides are visible"
  on public.follows
  for select
  to authenticated
  using (
    auth.uid() in (follower_id, following_id)
    or (
      internal.can_view_author_content(auth.uid(), follower_id)
      and internal.can_view_author_content(auth.uid(), following_id)
    )
  );

-- follows' own INSERT policy (WYN-008, tightened for Block by WYN-027)
-- never checked the target's privacy at all -- without this fix, a
-- client could `insert into follows` directly and skip the Follow
-- Request flow entirely for a Private account, making Requirement 2
-- (Design doc) purely decorative. A direct insert is now only allowed
-- against a Public target; the one legitimate way to create a `follows`
-- row for a Private target is accept_follow_request() above, which is
-- SECURITY DEFINER and therefore bypasses this policy (as intended --
-- only the target themself can ever call it, and only for a request
-- that genuinely exists). WYN-027's blocked-relationship check is kept
-- as-is.
drop policy "Users can follow others as themselves, excluding blocked relationships" on public.follows;
create policy "Users can follow public accounts directly, excluding blocked relationships"
  on public.follows
  for insert
  to authenticated
  with check (
    auth.uid() = follower_id
    and not internal.is_blocked_either_way(auth.uid(), following_id)
    and not exists (
      select 1 from public.profiles where id = following_id and is_private
    )
  );

-- Follower/Following *counts* must stay visible to everyone regardless
-- of privacy (Product AC: a locked profile still shows its stats, only
-- the drill-down list is gated) -- mirrors drop_view_count() (WYN-038)
-- exactly: a SECURITY DEFINER function bypassing the row-level
-- restriction above to return only an aggregate, never individual rows.
create or replace function public.follower_count(p_user_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*) from public.follows where following_id = p_user_id;
$$;

create or replace function public.following_count(p_user_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*) from public.follows where follower_id = p_user_id;
$$;

grant execute on function public.follower_count(uuid) to authenticated;
grant execute on function public.following_count(uuid) to authenticated;

-- 05-profile.tsx's StatsRow adds a 3rd stat ("โพสต์") alongside
-- follower/following count -- same SECURITY DEFINER shape as
-- follower_count()/following_count() directly above (an aggregate-only
-- bypass of drops' own RLS, never individual rows), excluding
-- soft-deleted rows (WYN-037) the same way every other DropRepository
-- read path already does.
create or replace function public.drop_count(p_user_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*) from public.drops
  where author_id = p_user_id and deleted_at is null;
$$;

grant execute on function public.drop_count(uuid) to authenticated;

-- Notification types: 2 new, both ordinary user-action actors (not the
-- null-actor moderation case) -- mirrors message_request's addition
-- (WYN-032) exactly, including going ahead of WYN-043/Phase 5's nominal
-- "new notification types" slot for the same reason WYN-032 already did.
do $$
declare
  v_constraint_name text;
begin
  select tc.constraint_name into v_constraint_name
  from information_schema.table_constraints tc
  join information_schema.constraint_column_usage ccu
    on ccu.constraint_name = tc.constraint_name
   and ccu.constraint_schema = tc.constraint_schema
  where tc.table_schema = 'public'
    and tc.table_name = 'notifications'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'type';

  if v_constraint_name is not null then
    execute format('alter table public.notifications drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'like_drop', 'like_pop', 'comment_drop', 'comment_pop', 'follow',
    'club_join_request', 'club_join_approved', 'club_post_like', 'club_post_comment',
    'mention_drop', 'mention_club_post',
    'moderation_warning', 'moderation_content_removed',
    'appeal_approved', 'appeal_rejected',
    'message_request', 'redrop',
    'follow_request', 'follow_request_accepted'
  ));

-- WYN-039 QA finding (Requirement 3, "Remove Follower") -- Product's
-- explicit acceptance criterion "เจ้าของบัญชีกด Remove Follower ... ต้อง
-- หลุดจากการ follow จริง" was missing entirely from both the Design doc
-- and Coding's first pass: `follows`' only DELETE policy (WYN-008) lets
-- the *follower* remove their own outgoing follow (unfollow), but never
-- let the person *being followed* remove one of their own followers.
-- Postgres RLS OR's multiple permissive policies for the same command
-- together, so this is purely additive -- the existing WYN-008 policy is
-- untouched.
create policy "Users can remove a follower from their own followers list"
  on public.follows
  for delete
  to authenticated
  using (auth.uid() = following_id);

-- ============================================================
-- WYN-040: Discovery Page (Rising / Suggested Users)
-- ============================================================
-- See .wyn/docs/design/wyn-040-discovery-page.md, "Data Layer". Both
-- RPCs below are bulk single-query ranking functions (not an N+1 call
-- per candidate profile) and both are SECURITY DEFINER for the exact
-- same reason follower_count()/internal.can_view_author_content() are
-- (WYN-039, directly above): follows' own SELECT policy only reveals an
-- edge to the two parties involved, or to a third party when *both*
-- sides' content are visible to them -- a plain (non-definer) query
-- ranking *other people's* follow edges from an arbitrary caller would
-- silently see far fewer rows than actually exist (wrong/empty ranking,
-- not an error), exactly the trap the Product spec's own Risks section
-- calls out by name. Both return only `profile_id`, deliberately never
-- the ranking signal itself (new-follower count / total follower
-- count) -- the Design doc's explicit anti-gaming instruction: showing
-- either number to the client would turn it into a public target to
-- game. The caller re-fetches full Profile rows for the id list through
-- the ordinary ProfileRepository/RLS path (DiscoveryRepository, Flutter
-- side) -- same "RPC hands back an ordered id list, client re-fetches
-- the real rows itself" shape get_poll_results() and every other
-- ranking RPC in this schema already uses.

-- "กำลังเติบโต" (Rising) -- ranks candidates by how many new followers
-- they gained in the last p_days days, most first. Growth is measured
-- purely from `follows.created_at` (no new table/column needed).
-- Excludes: the caller themself, accounts the caller already follows,
-- accounts blocked either-way, and accounts below p_min_followers total
-- followers (Product spec: guards against a brand-new account's first
-- follower ever, e.g. 0 -> 1, showing up as "Rising" purely from a
-- 100% growth rate). Note p_min_followers is checked against the
-- *total* follower count (a plain count(*) subquery, same shape
-- follower_count() itself uses), not the in-window growth count.
create or replace function public.rising_profiles(
  p_limit int default 10,
  p_days int default 7,
  p_min_followers int default 5
)
returns table(profile_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select f.following_id as profile_id
  from public.follows f
  where f.created_at >= now() - (p_days || ' days')::interval
    and f.following_id <> auth.uid()
    and not internal.is_blocked_either_way(auth.uid(), f.following_id)
    and not exists (
      select 1 from public.follows mine
      where mine.follower_id = auth.uid()
        and mine.following_id = f.following_id
    )
  group by f.following_id
  having (
    select count(*) from public.follows total
    where total.following_id = f.following_id
  ) >= p_min_followers
  order by count(*) desc
  limit p_limit;
$$;

grant execute on function public.rising_profiles(int, int, int) to authenticated;

-- "แนะนำให้ติดตาม" (Suggested Users) -- ranks every eligible candidate
-- by *total* follower count, most first (v1: no personalization/ML,
-- per the Product spec's explicit scope). Excludes: the caller
-- themself, accounts already followed, accounts blocked either-way,
-- and accounts the caller has muted (WYN-028) -- mirrors home_feed's
-- own mute-exclusion subquery shape exactly (`not exists (select 1
-- from mutes where muter_id = auth.uid() ...)`); no RLS self-defeat risk
-- here either, same reasoning home_feed's own comment gives, since the
-- subquery's condition (`muter_id = auth.uid()`) is identical to
-- mutes' own SELECT policy condition.
create or replace function public.suggested_users(p_limit int default 10)
returns table(profile_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select p.id as profile_id
  from public.profiles p
  where p.id <> auth.uid()
    and not internal.is_blocked_either_way(auth.uid(), p.id)
    and not exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.following_id = p.id
    )
    and not exists (
      select 1 from public.mutes m
      where m.muter_id = auth.uid() and m.muted_id = p.id
    )
  order by (
    select count(*) from public.follows fc where fc.following_id = p.id
  ) desc
  limit p_limit;
$$;

grant execute on function public.suggested_users(int) to authenticated;

-- ============================================================
-- WYN-041: Trending Engine v2 (Anti-Manipulation)
-- ============================================================
-- See .wyn/docs/design/wyn-041-trending-engine-v2.md, "Decision 2".
-- Batched wrapper around internal.is_posting_blocked() (WYN-029/030)
-- for Trending/ranked-feed candidate filtering on the Flutter side
-- (HomeRepository.fetchTrending/fetchRankedFeed). moderation_actions has
-- no SELECT policy for ordinary users, and internal.is_posting_blocked()
-- deliberately lives in `internal` so it's unreachable as a direct
-- client RPC (same reasoning as internal.is_blocked_either_way,
-- WYN-027) -- this public wrapper is the one sanctioned way a client
-- can ask "which of these candidate authors currently can't post"
-- without ever learning *why*: action_type/reason/reviewer_id/
-- expires_at all stay server-side. Returns only the subset of the input
-- that's true (an author currently blocked from posting), never a
-- true/false per input id -- identical anti-gaming return shape to
-- rising_profiles()/suggested_users() directly above (an ordered/
-- filtered id list only, never the underlying signal). `stable`, not
-- `volatile`: no side effects, purely reads.
create or replace function public.authors_posting_blocked(p_author_ids uuid[])
returns table(author_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select id as author_id
  from unnest(p_author_ids) as id
  where internal.is_posting_blocked(id);
$$;

grant execute on function public.authors_posting_blocked(uuid[]) to authenticated;

-- ============================================================
-- WYN-043: Notification Types (system) + redrop client-side fix note
-- ============================================================
-- See .wyn/tasks/backlog/WYN-043-notification-types.md and
-- .wyn/docs/design/wyn-043-notification-types.md. Of the roadmap's
-- nominal "ReDrop/Quote/FollowRequest/MessageRequest/Trending/Top100/
-- System" list, only `system` is actually new here -- redrop/
-- follow_request/follow_request_accepted/message_request already exist
-- in notifications_type_check (added ahead of schedule during
-- WYN-032/034/039, see the comment directly above this section).
-- redrop's bug was purely client-side (the Flutter NotificationType
-- enum never got the case) -- nothing to fix in this file for it.
-- Trending/Top100 notifications are explicitly out of scope: there is
-- no snapshot/diff mechanism for "newly trending" and no cron/
-- scheduled-job infrastructure anywhere in this project (see the
-- comment on Restrict/Suspend auto-expiry, WYN-030, for that same
-- "no cron/batch job" fact stated directly).
do $$
declare
  v_constraint_name text;
begin
  select tc.constraint_name into v_constraint_name
  from information_schema.table_constraints tc
  join information_schema.constraint_column_usage ccu
    on ccu.constraint_name = tc.constraint_name
   and ccu.constraint_schema = tc.constraint_schema
  where tc.table_schema = 'public'
    and tc.table_name = 'notifications'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'type';

  if v_constraint_name is not null then
    execute format('alter table public.notifications drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'like_drop', 'like_pop', 'comment_drop', 'comment_pop', 'follow',
    'club_join_request', 'club_join_approved', 'club_post_like', 'club_post_comment',
    'mention_drop', 'mention_club_post',
    'moderation_warning', 'moderation_content_removed',
    'appeal_approved', 'appeal_rejected',
    'message_request', 'redrop',
    'follow_request', 'follow_request_accepted',
    'system',
    -- WYN-116: club_post_new/club_post_pinned added here (added ahead
    -- of schedule during a later migration, same as this comment's
    -- neighbor above describes for an earlier type) -- see
    -- notify_club_post_new()/notify_club_post_pinned() further down.
    'club_post_new', 'club_post_pinned',
    -- WYN-124: club_invite, added here for the same "ahead of schedule"
    -- reason -- see invite_to_club() further down.
    'club_invite'
  ));

-- Lets an admin send a free-text notification to one recipient
-- (Master Spec section 20, "System: Security, Policy, Announcement") --
-- security definer + an explicit platform_role check (mirrors
-- decide_appeal()'s own moderator/admin gate, WYN-030) rather than an
-- RLS insert policy, since ordinary users must never be able to insert
-- into notifications directly for any type (see this table's own
-- comment history -- every notification row is created by a trigger or
-- a definer function, never a raw client insert). actor_id is always
-- null (this is the system speaking, not another user), and the
-- message goes into the existing `reason` column rather than a new one
-- -- moderation_warning/moderation_content_removed already use it the
-- same way. Single-recipient only in this round: broadcasting to every
-- profile at once is a meaningfully different (and riskier -- an
-- unbounded bulk insert with no batching designed for it yet)
-- operation that deserves its own task, not a same-round addition
-- squeezed in here.
create or replace function public.send_system_notification(
  p_recipient_id uuid,
  p_message text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- coalesce() is load-bearing, not decoration -- current_platform_role()
  -- returns NULL for a caller with no `profiles` row at all, and
  -- `NULL <> 'admin'` evaluates to NULL, which PL/pgSQL's `if` treats
  -- as false (branch skipped, exception never raised) -- the same
  -- NULL-role-bypass class WYN-050 found and fixed in
  -- admin_dashboard_metrics(), found here too during WYN-051's QA. See
  -- .wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md
  -- and .wyn/tasks/bugs/WYN-043-send-system-notification-null-role-bypass.md.
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can send system notifications';
  end if;

  if p_message is null or length(trim(p_message)) = 0 then
    raise exception 'System notification message must not be blank';
  end if;

  if internal.notification_enabled(p_recipient_id, 'system') then
    insert into public.notifications (recipient_id, actor_id, type, reason)
    values (p_recipient_id, null, 'system', p_message);

    -- WYN-048: audit trail. actor_id is the real admin caller --
    -- audit_log has no client-facing SELECT policy at all (unlike
    -- notifications.actor_id, which this function already correctly
    -- nulls out above so the recipient never learns who sent it), so
    -- recording the true sender identity here creates no leak. Placed
    -- inside this `if` branch (not unconditionally at the end of the
    -- function) on purpose -- the event_type is 'system_notification_
    -- sent', and if the recipient has this category turned off nothing
    -- was actually sent, so nothing should be logged as sent. detail
    -- stores the message plainly, same as the notifications row above
    -- -- not a new exposure, since the recipient already sees this
    -- exact text via the notification itself.
    perform internal.log_audit_event(
      auth.uid(),
      'system_notification_sent',
      p_recipient_id,
      jsonb_build_object('message', p_message)
    );
  end if;
end;
$$;

grant execute on function public.send_system_notification(uuid, text) to authenticated;

-- ============================================================
-- WYN-044: Notification Settings
-- ============================================================
-- See .wyn/tasks/backlog/WYN-044-notification-settings.md and
-- .wyn/docs/design/wyn-044-notification-settings.md. Opt-out model
-- (Master Spec section 21): a user who has never opened
-- NotificationSettingsScreen and toggled anything has no row here at
-- all -- every category defaults to enabled in that case, matching
-- this table's own `not null default true` columns. Rows are created
-- lazily by the client's first upsert (RLS insert policy below), not
-- by handle_new_user() or any trigger, to keep this task's blast
-- radius limited to gating public.notifications inserts -- it doesn't
-- touch signup at all.
--
-- `trending` has no producer anywhere in the schema yet (WYN-041/042
-- compute rankings transiently, no cron/snapshot infra -- same "no
-- cron/batch job" fact WYN-030/WYN-043 already document elsewhere in
-- this file) -- the column exists purely so a future Trending
-- Notification Engine task doesn't need its own migration, and is a
-- deliberate forward-compat no-op today, not an oversight.
create table if not exists public.notification_settings (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  likes boolean not null default true,
  comments boolean not null default true,
  follows boolean not null default true,
  messages boolean not null default true,
  club boolean not null default true,
  trending boolean not null default true,
  system boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.notification_settings enable row level security;

-- Mirrors public.saves' RLS shape (WYN-011/013) exactly: select/
-- insert/update all restricted to the owning row's own user_id, no
-- delete policy needed (on delete cascade handles account deletion,
-- and there is no product reason for a user to delete their own
-- preference row instead of just toggling everything back on).
create policy "Users can view their own notification settings"
  on public.notification_settings
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can create their own notification settings"
  on public.notification_settings
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own notification settings"
  on public.notification_settings
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Single source of truth every gated notify_*/RPC call site above (16
-- of them -- see the Product/Design spec's mapping table) calls before
-- inserting into public.notifications, so "no row = every category
-- enabled" is encoded exactly once instead of separately at each call
-- site. `security definer` + `set search_path = public`, same shape
-- as internal.current_platform_role() elsewhere in this file, since
-- every caller is itself a `security definer` trigger/RPC already
-- running as the table owner, not as the querying `authenticated`
-- role.
--
-- No `grant execute ... to authenticated` (unlike internal.drop_author_id/
-- internal.current_platform_role/internal.is_drop_deleted, which are all
-- called directly by RLS policies evaluated as the querying `authenticated`
-- role and so genuinely need the grant) -- every real caller of this
-- helper is itself already `security definer` (the 16 gated call sites
-- above), so granting EXECUTE to `authenticated` would only let an
-- ordinary user call this directly with someone *else's* p_user_id and
-- read that user's real per-category preference, bypassing
-- notification_settings' own RLS (WYN-044 debug fix -- QA-confirmed leak).
--
-- Omitting the grant is NOT enough on its own, though (independently
-- re-confirmed against real Postgres while fixing this -- deleting only
-- the `grant ... to authenticated` line left the direct-call probe below
-- still succeeding): PostgreSQL grants EXECUTE on a newly created
-- function to PUBLIC by default (the exact class of leak
-- WYN-027/`.wyn/tasks/bugs/WYN-027-is-blocked-either-way-rpc-exposure.md`
-- already documented for this schema), and `authenticated` already holds
-- `usage` on the whole `internal` schema (granted once, above, for the
-- RLS-embedded helpers that genuinely need it) -- so PUBLIC-execute plus
-- schema USAGE is already sufficient for an ordinary `authenticated`
-- caller to invoke this function directly by SQL, grant statement or
-- not. The explicit `revoke` below is the actual fix; PostgREST's own
-- non-exposure of `internal` (see the schema-boundary comment above)
-- protects the REST API surface but not a direct SQL/psql caller, which
-- is the threat this helper's own p_user_id parameter creates (unlike
-- the RLS-embedded helpers, which never take a caller-supplied "whose
-- data" parameter).
--
-- `language plpgsql` (not `sql`) specifically so an unrecognized
-- p_category can RAISE instead of silently falling through the CASE to
-- NULL -> coalesce(..., true) -> fail-open with no signal (WYN-044
-- debug fix). All 16 existing gated call sites pass one of the 7
-- literals below, so this is a no-op for them.
--
-- Defined here, after every notify_* trigger function that calls it,
-- because PL/pgSQL function bodies are late-bound in Postgres --
-- identifiers inside a plpgsql body are only resolved the first time
-- the function actually executes, not at CREATE FUNCTION time, so it
-- is safe for this helper to be declared later in the file than its
-- callers as long as (as is the case here) it exists by the time any
-- of those triggers can actually fire, which is only ever after this
-- entire file has finished loading.
create or replace function internal.notification_enabled(p_user_id uuid, p_category text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  -- `p_category is null or ...`, not just `p_category not in (...)` --
  -- NOT IN's 3-valued logic makes `NULL not in (...)` evaluate to NULL
  -- (neither true nor false), so `if NULL then` silently skips the
  -- raise and falls through to the old fail-open coalesce(...,true)
  -- behavior for a NULL category specifically, even though every
  -- other bad value (unrecognized string, '') is correctly caught by
  -- `not in (...)` alone (QA round 2 finding, WYN-044 debug fix).
  if p_category is null or p_category not in
      ('likes', 'comments', 'follows', 'messages', 'club', 'trending', 'system') then
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
      end
      from public.notification_settings
      where user_id = p_user_id
    ),
    true
  );
end;
$$;

-- Explicit revoke, not just an omitted grant -- see the comment above
-- this function for why the omission alone left it directly callable by
-- any `authenticated` role via SQL (PostgreSQL's default PUBLIC-execute
-- ACL). `authenticated`/`anon` are both implicitly members of PUBLIC, so
-- revoking from PUBLIC alone is sufficient; no separate `from
-- authenticated, anon` needed since neither ever held a more specific
-- grant of their own.
revoke execute on function internal.notification_enabled(uuid, text) from public;

-- ============================================================
-- WYN-045: Settings — Interaction Privacy Controls (DM / Mention / Comment)
-- ============================================================
-- See .wyn/tasks/backlog/WYN-045-settings-privacy-controls.md and
-- .wyn/docs/design/wyn-045-settings-privacy-controls.md. Closes the
-- explicit deferred scope WYN-039's own spec file logged: "Privacy
-- settings ย่อยอื่นๆ ... (DM Permissions, Mention, Comment) ไม่อยู่ใน
-- สโคปนี้ ทำใน WYN-045."
--
-- Three independent per-owner settings, one shared 3-value vocabulary
-- reused across all of them ('everyone' default / 'people_i_follow' /
-- 'no_one'), same shape as is_private's own `alter table ... add
-- column if not exists` (WYN-039). "People I follow" always means the
-- *owner* of the setting follows the actor -- the same one trust
-- direction this project has used for every trust-based feature to
-- date (WYN-039's is_private/follow-request gating, and this exact
-- condition already being what decides `active` vs `pending` in
-- get_or_create_conversation() below). None of this retroactively
-- affects content/conversations that already exist -- same posture as
-- Private Account and Block (WYN-039/027), documented in the Product
-- spec's Risks.
alter table public.profiles
  add column if not exists dm_permission text not null default 'everyone'
    check (dm_permission in ('everyone', 'people_i_follow', 'no_one')),
  add column if not exists mention_permission text not null default 'everyone'
    check (mention_permission in ('everyone', 'people_i_follow', 'no_one')),
  add column if not exists comment_permission text not null default 'everyone'
    check (comment_permission in ('everyone', 'people_i_follow', 'no_one'));

-- internal.mention_allowed()/internal.comment_allowed() below are
-- deliberately two separate functions rather than one taking a
-- category parameter -- mirrors internal.drop_author_id()/
-- internal.pop_author_id() staying separate despite near-identical
-- bodies, for the same reason: clearer error/call-site reading, and
-- each one only ever needs to check exactly one column. Both are
-- SECURITY DEFINER so they can be called from inside another table's
-- RLS policy (drop_mentions/club_post_mentions/drop_comments/
-- pop_comments below) without those policies' own lookups against
-- `profiles` being subject to `profiles`' own SELECT RLS -- same
-- reasoning as internal.can_view_author_content() (WYN-039) and
-- internal.is_blocked_either_way() (WYN-027) above.
create or replace function internal.mention_allowed(p_owner uuid, p_actor uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_owner = p_actor then true
    else coalesce(
      (
        select case (select mention_permission from public.profiles where id = p_owner)
          when 'no_one' then false
          when 'people_i_follow' then exists (
            select 1 from public.follows
            where follower_id = p_owner and following_id = p_actor
          )
          else true
        end
      ),
      true
    )
  end;
$$;

grant execute on function internal.mention_allowed(uuid, uuid) to authenticated;

create or replace function internal.comment_allowed(p_owner uuid, p_actor uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_owner = p_actor then true
    else coalesce(
      (
        select case (select comment_permission from public.profiles where id = p_owner)
          when 'no_one' then false
          when 'people_i_follow' then exists (
            select 1 from public.follows
            where follower_id = p_owner and following_id = p_actor
          )
          else true
        end
      ),
      true
    )
  end;
$$;

grant execute on function internal.comment_allowed(uuid, uuid) to authenticated;

-- Mention Permission: extends the block-exclusion INSERT policies
-- (WYN-027) with the same non-error posture the comment right above
-- them already documents -- a block relationship stops a mention from
-- ever being recorded at all, and now so does mention_permission =
-- 'no_one'/'people_i_follow' being unmet. The caption text itself may
-- still literally contain "@username" (MentionInput doesn't
-- retroactively edit what was typed), but no drop_mentions/
-- club_post_mentions row is created for it, so
-- notify_drop_mention()/notify_club_post_mention() never fire.
drop policy "Drop authors can mention users in their own drops, excluding blocked relationships" on public.drop_mentions;
create policy "Drop authors can mention users in their own drops, excluding blocked relationships and disallowed mentions"
  on public.drop_mentions
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.drops
      where drops.id = drop_id and drops.author_id = auth.uid()
    )
    and not internal.is_blocked_either_way(auth.uid(), mentioned_user_id)
    and internal.mention_allowed(mentioned_user_id, auth.uid())
  );

drop policy "Club post authors can mention users in their own posts, excluding blocked relationships" on public.club_post_mentions;
create policy "Club post authors can mention users in their own posts, excluding blocked relationships and disallowed mentions"
  on public.club_post_mentions
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.club_posts
      where club_posts.id = club_post_id and club_posts.author_id = auth.uid()
    )
    and not internal.is_blocked_either_way(auth.uid(), mentioned_user_id)
    and internal.mention_allowed(mentioned_user_id, auth.uid())
  );

-- Comment Permission: extends the latest (WYN-037) generation of each
-- INSERT policy -- Drop and Pop only. Club Post comment (WYN-005/006's
-- club_post_comments) is deliberately left untouched: approved Club
-- membership is already its own trust model (WYN-014/015), and
-- layering a personal comment_permission on top would fight the
-- membership grant a Club owner already extended -- see Product
-- spec's Requirement 4.
drop policy "Users can comment on drops as themselves, excluding blocked authors, moderation-blocked accounts, and deleted drops" on public.drop_comments;
create policy "Users can comment on drops as themselves, excluding blocked authors, moderation-blocked accounts, deleted drops, and disallowed comments"
  on public.drop_comments
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and not internal.is_blocked_either_way(auth.uid(), internal.drop_author_id(drop_id))
    and not internal.is_posting_blocked(auth.uid())
    and coalesce(internal.is_drop_deleted(drop_id), false) = false
    and internal.comment_allowed(internal.drop_author_id(drop_id), auth.uid())
  );

drop policy "Users can comment on pops as themselves, excluding blocked authors" on public.pop_comments;
create policy "Users can comment on pops as themselves, excluding blocked authors and disallowed comments"
  on public.pop_comments
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and not internal.is_blocked_either_way(auth.uid(), internal.pop_author_id(pop_id))
    and internal.comment_allowed(internal.pop_author_id(pop_id), auth.uid())
  );

-- ============================================================
-- WYN-046: Platform Documents + Acceptance Flow
-- ============================================================
-- See .wyn/tasks/backlog/WYN-046-platform-documents-acceptance.md and
-- .wyn/docs/design/wyn-046-platform-documents-acceptance.md. First task
-- of Phase 6 (Legal & Compliance Layer, Master Spec sections 27/28).
-- Technical layer only -- the `content` seeded below is a
-- placeholder that explicitly states it is not the final,
-- legally-binding text (see APPROVAL_REQUIRED entry in
-- .wyn/company/APPROVALS.md, 2026-08-23: real legal content and the
-- DPS-category analysis are both out of AI team scope and require a
-- lawyer before this can go to production users).
--
-- No "Future Commerce Terms" row -- Master Spec section 27 lists one
-- for WYN Shop, but ZOKY/Marketplace was removed from the product
-- entirely, not merely parked, so there is nothing for it to cover.
create table if not exists public.platform_documents (
  id uuid primary key default gen_random_uuid(),
  type text not null check (
    type in (
      'terms_of_service', 'privacy_policy', 'community_guidelines',
      'copyright_policy', 'report_policy', 'appeal_policy'
    )
  ),
  version integer not null,
  title text not null,
  content text not null,
  effective_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (type, version)
);

alter table public.platform_documents enable row level security;

-- Select-all-authenticated: document text is not private data, every
-- logged-in user must be able to read it (both from the Acceptance
-- Gate and from Settings' "กฎหมาย" section). Deliberately no insert/
-- update/delete policy for any client role at all -- content only
-- ever changes via a schema migration in this round; there is no
-- Admin UI yet (WYN Admin is Phase 7).
create policy "Platform documents are viewable by authenticated users"
  on public.platform_documents
  for select
  to authenticated
  using (true);

-- Mirrors public.notification_settings' RLS shape (WYN-044) exactly:
-- select/insert/update all restricted to the owning row's own
-- user_id. No delete policy (on delete cascade handles account
-- deletion, same reasoning as notification_settings). Primary key is
-- (user_id, document_type) rather than a surrogate id -- Product's
-- Requirement 2 only needs the latest accepted version per type per
-- user, not a full acceptance history, so upserting this pair is the
-- whole mechanism a future document version bump re-prompts on.
create table if not exists public.user_document_acceptances (
  user_id uuid not null references public.profiles (id) on delete cascade,
  document_type text not null,
  version integer not null,
  accepted_at timestamptz not null default now(),
  primary key (user_id, document_type)
);

alter table public.user_document_acceptances enable row level security;

create policy "Users can view their own document acceptances"
  on public.user_document_acceptances
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can create their own document acceptances"
  on public.user_document_acceptances
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own document acceptances"
  on public.user_document_acceptances
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Seed: version 1 of all 6 document types. Every `content` value
-- starts with the exact placeholder paragraph Product specified,
-- followed only by a short outline of section headings appropriate
-- to that document type -- no actual legal content under any
-- heading. Do not replace this with real legal text without a
-- lawyer's review (see APPROVAL_REQUIRED entry above).
insert into public.platform_documents (type, version, title, content, effective_at) values
(
  'terms_of_service', 1, 'ข้อกำหนดการใช้งาน',
  $doc$เอกสารฉบับนี้อยู่ระหว่างการตรวจสอบโดยผู้เชี่ยวชาญกฎหมาย ยังไม่ใช่ฉบับสมบูรณ์ที่มีผลผูกพันทางกฎหมาย — เนื้อหาฉบับเต็มจะปรับปรุงหลังผ่านการตรวจสอบ

หัวข้อที่จะครอบคลุม (โครงร่างเบื้องต้น ยังไม่มีเนื้อหา):
- การใช้งาน
- บัญชีผู้ใช้
- เนื้อหาที่ต้องห้าม
- การยกเลิกบัญชี$doc$,
  now()
),
(
  'privacy_policy', 1, 'นโยบายความเป็นส่วนตัว',
  $doc$เอกสารฉบับนี้อยู่ระหว่างการตรวจสอบโดยผู้เชี่ยวชาญกฎหมาย ยังไม่ใช่ฉบับสมบูรณ์ที่มีผลผูกพันทางกฎหมาย — เนื้อหาฉบับเต็มจะปรับปรุงหลังผ่านการตรวจสอบ

หัวข้อที่จะครอบคลุม (โครงร่างเบื้องต้น ยังไม่มีเนื้อหา):
- ข้อมูลที่จัดเก็บ
- วัตถุประสงค์การใช้ข้อมูล
- การแบ่งปันข้อมูล
- สิทธิ์ของผู้ใช้$doc$,
  now()
),
(
  'community_guidelines', 1, 'แนวทางชุมชน',
  $doc$เอกสารฉบับนี้อยู่ระหว่างการตรวจสอบโดยผู้เชี่ยวชาญกฎหมาย ยังไม่ใช่ฉบับสมบูรณ์ที่มีผลผูกพันทางกฎหมาย — เนื้อหาฉบับเต็มจะปรับปรุงหลังผ่านการตรวจสอบ

หัวข้อที่จะครอบคลุม (โครงร่างเบื้องต้น ยังไม่มีเนื้อหา):
- พฤติกรรมที่ยอมรับได้
- เนื้อหาที่ไม่อนุญาต
- การรายงานการละเมิด
- ผลจากการละเมิด$doc$,
  now()
),
(
  'copyright_policy', 1, 'นโยบายลิขสิทธิ์',
  $doc$เอกสารฉบับนี้อยู่ระหว่างการตรวจสอบโดยผู้เชี่ยวชาญกฎหมาย ยังไม่ใช่ฉบับสมบูรณ์ที่มีผลผูกพันทางกฎหมาย — เนื้อหาฉบับเต็มจะปรับปรุงหลังผ่านการตรวจสอบ

หัวข้อที่จะครอบคลุม (โครงร่างเบื้องต้น ยังไม่มีเนื้อหา):
- การแจ้งการละเมิดลิขสิทธิ์
- กระบวนการพิจารณา
- การยื่นคำโต้แย้ง$doc$,
  now()
),
(
  'report_policy', 1, 'นโยบายการรายงาน',
  $doc$เอกสารฉบับนี้อยู่ระหว่างการตรวจสอบโดยผู้เชี่ยวชาญกฎหมาย ยังไม่ใช่ฉบับสมบูรณ์ที่มีผลผูกพันทางกฎหมาย — เนื้อหาฉบับเต็มจะปรับปรุงหลังผ่านการตรวจสอบ

หัวข้อที่จะครอบคลุม (โครงร่างเบื้องต้น ยังไม่มีเนื้อหา):
- ประเภทการรายงาน
- กระบวนการตรวจสอบ
- การแจ้งผล$doc$,
  now()
),
(
  'appeal_policy', 1, 'นโยบายการอุทธรณ์',
  $doc$เอกสารฉบับนี้อยู่ระหว่างการตรวจสอบโดยผู้เชี่ยวชาญกฎหมาย ยังไม่ใช่ฉบับสมบูรณ์ที่มีผลผูกพันทางกฎหมาย — เนื้อหาฉบับเต็มจะปรับปรุงหลังผ่านการตรวจสอบ

หัวข้อที่จะครอบคลุม (โครงร่างเบื้องต้น ยังไม่มีเนื้อหา):
- สิทธิ์ในการอุทธรณ์
- ขั้นตอนการยื่นอุทธรณ์
- ผลของการอุทธรณ์$doc$,
  now()
);

-- ============================================================
-- WYN-047: Data Rights (PDPA) -- Data Export + Account Deletion
-- ============================================================
-- See .wyn/tasks/backlog/WYN-047-data-rights.md and
-- .wyn/docs/design/wyn-047-data-rights.md. Second task of Phase 6
-- (Legal & Compliance Layer, Master Spec section 28). Data Access and
-- Data Correction are already satisfied by existing screens (Edit
-- Profile, Following/Followers, Saved, Notification/Privacy settings)
-- and content-level Data Deletion is already satisfied by existing
-- per-item delete/unfollow/unsave affordances (WYN-005/006/008/037) --
-- nothing new to build for either of those. This section only adds
-- the two rights that had zero mechanism at all: exporting a copy of
-- one's own data, and deleting the account itself.

-- export_my_data(): SECURITY DEFINER + no parameters, always operates
-- on auth.uid() -- there is no way to pass another user's id in, so
-- this can never be used to read anyone else's data. Every branch
-- below filters by the caller's own id even though SECURITY DEFINER
-- already bypasses each table's RLS -- the filter, not RLS, is what
-- keeps this scoped to "my data" (the same discipline
-- internal.notification_enabled()'s own comment block above explains
-- for a different reason).
--
-- WYN-048: no longer `language sql` / `stable` -- it now also writes
-- one audit_log row via internal.log_audit_event(), so it is no longer
-- purely read-only, and internal.log_audit_event() itself is only
-- defined later in this file (WYN-048 section, appended at the end per
-- this project's convention). A plain `language sql` function body is
-- parsed and its references resolved at CREATE FUNCTION time (verified
-- empirically -- referencing a not-yet-defined function errors
-- immediately with "function ... does not exist"), which would break
-- top-to-bottom loading; `language plpgsql` defers resolution of
-- embedded SQL statements to first call, the same reason every other
-- forward-referencing helper in this file already uses plpgsql, so
-- this is now plpgsql too. The jsonb_build_object expression itself
-- and every branch's filtering logic are otherwise untouched -- moved
-- as-is into a `select ... into v_export`. No exception handling
-- around the log call -- if it fails, the whole export fails too
-- (fail-closed, same reasoning as every other WYN-048 call site -- see
-- internal.log_audit_event()'s own comment below).
--
-- Drops: mirrors internal.is_drop_deleted()/restore_drop()'s own
-- 30-day cutoff (see restore_drop() above, "deleted_at <= now() -
-- interval '30 days'" raises) -- a soft-deleted Drop still inside its
-- restore window is still the user's own recoverable data and belongs
-- in an Access/Export request; one that has aged out of the window is
-- gone for good (same content a fresh restore_drop() call would now
-- reject), so it is excluded here too.
--
-- Deliberately NOT included (Product's explicit scope decision, see
-- Requirement 1's "ไม่รวมโดยเจตนา"): moderation_actions, reports
-- (filed by or against the caller), and appeals. WYN-026/029 built a
-- specific privacy protection where a reporter's identity is never
-- revealed to the person they reported -- folding report rows into
-- this export (which the reported user could request for themselves)
-- would be a backdoor around that protection.
create or replace function public.export_my_data()
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_export jsonb;
begin
  select jsonb_build_object(
    'exported_at', now(),
    'profile', (
      select to_jsonb(p) from public.profiles p where p.id = auth.uid()
    ),
    'drops', (
      select coalesce(jsonb_agg(to_jsonb(d) order by d.created_at), '[]'::jsonb)
      from public.drops d
      where d.author_id = auth.uid()
        and (d.deleted_at is null or d.deleted_at > now() - interval '30 days')
    ),
    'pops', (
      select coalesce(jsonb_agg(to_jsonb(pp) order by pp.created_at), '[]'::jsonb)
      from public.pops pp
      where pp.author_id = auth.uid()
    ),
    'drop_comments', (
      select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at), '[]'::jsonb)
      from public.drop_comments c
      where c.author_id = auth.uid()
    ),
    'pop_comments', (
      select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at), '[]'::jsonb)
      from public.pop_comments c
      where c.author_id = auth.uid()
    ),
    'club_post_comments', (
      select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at), '[]'::jsonb)
      from public.club_post_comments c
      where c.author_id = auth.uid()
    ),
    'following', (
      select coalesce(jsonb_agg(to_jsonb(f) order by f.created_at), '[]'::jsonb)
      from public.follows f
      where f.follower_id = auth.uid()
    ),
    'followers', (
      select coalesce(jsonb_agg(to_jsonb(f) order by f.created_at), '[]'::jsonb)
      from public.follows f
      where f.following_id = auth.uid()
    ),
    'saves', (
      select coalesce(jsonb_agg(to_jsonb(s) order by s.created_at), '[]'::jsonb)
      from public.saves s
      where s.user_id = auth.uid()
    ),
    'club_memberships', (
      select coalesce(jsonb_agg(to_jsonb(cm) order by cm.created_at), '[]'::jsonb)
      from public.club_members cm
      where cm.user_id = auth.uid()
    ),
    'notification_settings', (
      select to_jsonb(ns) from public.notification_settings ns where ns.user_id = auth.uid()
    ),
    'sent_messages', (
      select coalesce(jsonb_agg(to_jsonb(m) order by m.created_at), '[]'::jsonb)
      from public.messages m
      where m.sender_id = auth.uid()
    )
  ) into v_export;

  perform internal.log_audit_event(auth.uid(), 'data_exported', auth.uid(), null);

  return v_export;
end;
$$;

-- Unlike most other SECURITY DEFINER helpers in this file (which are
-- only ever called from other SECURITY DEFINER functions/triggers and
-- so deliberately omit this grant, see notification_enabled()'s
-- comment above), this one is legitimately called directly by the
-- Flutter client from the Settings screen -- it has no caller-
-- supplied "whose data" parameter for that grant to leak, only
-- auth.uid(), so granting it to `authenticated` is safe.
grant execute on function public.export_my_data() to authenticated;

-- delete_my_account(): SECURITY DEFINER + no parameters, always
-- operates on auth.uid() -- there is no way to pass another user's id
-- in, so this can never be used to delete anyone else's account.
-- Deletes the auth.users row directly; the 88 `on delete cascade` FKs
-- already in this file (all ultimately rooted at
-- public.profiles.id references auth.users(id) on delete cascade)
-- remove every public.* row belonging to that user transitively --
-- Drop/Pop/Comment/Like/Follow/Save/Club membership/Chat message/
-- Notification/Settings/everything.
--
-- Inspected whether anything beyond `auth.users` itself needs an
-- explicit delete: every stub `auth.users` table this project's own
-- supabase/tests/*.sh scripts define (all ~17 of them) only ever
-- creates `auth.users (id, email)` -- none of them, and no other file
-- in this repo, references auth.identities/auth.sessions/
-- auth.refresh_tokens/auth.mfa_factors/auth.one_time_tokens anywhere.
-- Real Supabase's own managed auth schema already defines those with
-- `on delete cascade` back to auth.users(id) (Supabase's Auth service
-- is the thing that creates/owns that schema, not this project's
-- schema.sql), so deleting the auth.users row alone is sufficient --
-- there is nothing for this function to delete from those tables
-- itself, and nothing in this codebase to stub/test against for them
-- either. No grace period, no soft-delete: irreversible and
-- immediate, per Product's decision (no cron/scheduled-job
-- infrastructure exists anywhere in this project to ever purge a
-- "pending deletion" state -- see WYN-030/043's identical reasoning).
-- QA finding (2026-08-24, WYN-047 round 1): before this guard, a
-- Restricted/Suspended/Banned account could call this RPC to erase
-- its own moderation_actions/appeals rows outright (both reference
-- public.profiles(id) on delete cascade -- WYN-029/030) and sign up
-- again with a clean slate, evading the sanction entirely. Reuses
-- internal.is_posting_blocked() -- the same "currently under an
-- active restrict/suspend/ban" check already gating content creation
-- elsewhere (drop_comments/pop_comments' INSERT policies, etc.) --
-- rather than inventing a second definition of "blocked" for this one
-- call site.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if internal.is_posting_blocked(auth.uid()) then
    raise exception 'Cannot delete account while a moderation action is active';
  end if;

  -- WYN-048: audit trail, logged *before* the delete below, not after --
  -- this is the one call site in this whole task where getting the
  -- order backwards would silently defeat the entire point of audit_log.
  -- internal.log_audit_event() looks up actor_username_snapshot from
  -- public.profiles while auth.uid()'s row still exists (the delete
  -- below removes it, via the profiles(id) references auth.users(id)
  -- on delete cascade chain, in the very next statement) -- captured
  -- here it survives permanently, since audit_log.actor_id has
  -- deliberately no FK/cascade back to profiles/auth.users at all (see
  -- the WYN-048 section below) -- verified by
  -- supabase/tests/wyn_048_audit_log_test.sh, which asserts the row
  -- for this exact event is still readable, with a non-null
  -- actor_username_snapshot, after the delete below has fully
  -- committed and profiles/auth.users no longer have a matching row.
  perform internal.log_audit_event(
    auth.uid(),
    'account_deleted',
    auth.uid(),
    null
  );

  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function public.delete_my_account() to authenticated;

-- ============================================================
-- WYN-048: Audit Log Foundation + Security Incident Runbook
-- ============================================================
-- See .wyn/tasks/backlog/WYN-048-consent-audit-security-incident.md.
-- Last task of Phase 6 (Legal & Compliance Layer, Master Spec section
-- 28). Consent Management has no new requirement this round (already
-- satisfied by WYN-044/045/046, per the Product spec's Requirement 1)
-- and the Security Incident Response Runbook is a document, not code
-- (see .wyn/docs/security/incident-response-runbook.md) -- this
-- section only adds the third piece: an append-only audit trail for
-- the 5 existing privileged actions that had no centralized record at
-- all (moderation actions, appeal decisions, admin system
-- notifications, account deletion, data export).
--
-- Deliberately append-only, with `actor_id`/`target_id` carrying NO
-- foreign key at all -- the single most important architectural
-- decision in this task (Product spec's Requirement 2). Every other
-- table in this schema roots its FKs at
-- public.profiles.id references auth.users(id) on delete cascade, so
-- that deleting an account correctly erases that account's own data
-- everywhere. audit_log must do the *opposite* on purpose: its entire
-- reason to exist is to remember a privileged action even after the
-- account behind it is gone -- most critically, the 'account_deleted'
-- event itself, whose whole point is to still be readable after the
-- very deletion it records. An `on delete cascade` FK here would erase
-- that row in the same transaction that creates it, defeating the
-- table's purpose at its single most important use case. Verified,
-- not just reasoned about -- see CHECK 12-13 in
-- supabase/tests/wyn_048_audit_log_test.sh, which deletes a test
-- user via delete_my_account() and then confirms their
-- 'account_deleted' audit_log row (with a non-null
-- actor_username_snapshot) still exists afterward, even though
-- profiles/auth.users no longer have a matching row for that id.
create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  -- No FK/cascade -- see the section comment above.
  actor_id uuid,
  -- Denormalized at write time (internal.log_audit_event() below looks
  -- this up from profiles once, at insert time) so the log stays
  -- readable by username even after the actor's account is later
  -- deleted -- profiles.username would otherwise be unreachable for a
  -- deleted actor, same problem actor_id's lack of FK solves for the
  -- row's existence itself.
  actor_username_snapshot text,
  event_type text not null
    check (event_type in (
      'moderation_action_applied', 'appeal_decided',
      'system_notification_sent', 'account_deleted', 'data_exported'
    )),
  -- Polymorphic per event_type, no FK either -- mirrors
  -- public.reports.target_id's own no-FK polymorphic pattern (WYN-026,
  -- "target_id is polymorphic (no FK -- the referenced table depends
  -- on target_type), so integrity is enforced entirely by
  -- submit_report() below rather than at the column level"). Nullable
  -- here (unlike reports.target_id, which is `not null`) since not
  -- every event type has a meaningful separate target -- account_deleted
  -- and data_exported both set target_id to the same value as actor_id
  -- (the caller acting on themselves), which is why this stays
  -- nullable rather than `not null` -- a future event type with no
  -- natural single target at all remains representable without a
  -- schema change.
  target_id uuid,
  detail jsonb,
  created_at timestamptz not null default now()
);

alter table public.audit_log enable row level security;

-- Deliberately ZERO policies of any kind -- not select, not insert, not
-- update, not delete, and not even for platform_role = 'moderator' or
-- 'admin'. There is no Admin UI with proper per-role access control
-- built yet (WYN-054, Phase 7, is what adds the screen that reads this
-- table) -- exposing raw SELECT to every admin/moderator now, before
-- that screen exists to gate who specifically should see what, would
-- be premature. The only way any row ever gets written is through
-- internal.log_audit_event() below, a SECURITY DEFINER function that
-- bypasses RLS the same way every notify_* trigger function elsewhere
-- in this file already does to write into public.notifications despite
-- that table also having no client-facing insert policy. Until WYN-054
-- ships, this table is readable only via direct SQL access (Founder,
-- through the Supabase SQL editor) -- see the Product spec's own Risks
-- section, which accepts this explicitly as this round's scope.
--
-- internal.log_audit_event(): the only sanctioned way any row is ever
-- written to audit_log. SECURITY DEFINER so it can insert despite
-- audit_log having no insert policy for any role. Not granted to
-- `authenticated` -- unlike export_my_data() (which is safe to expose
-- directly since its only "whose data" input is auth.uid(), with no
-- caller-supplied override), this function's p_actor_id/p_target_id
-- are caller-supplied, so a direct grant would let any client forge
-- audit_log rows attributing arbitrary actions to arbitrary users. It
-- must only ever be called from other SECURITY DEFINER functions that
-- already independently derived p_actor_id from something trustworthy
-- (auth.uid(), or a value already established server-side, such as
-- decide_appeal()'s v_appeal.appellant_id), never by passing
-- unvalidated client input straight through.
--
-- p_actor_id handled gracefully when null (looked up conditionally
-- below), though none of the 5 call sites wired in this round actually
-- pass null -- each of moderation/appeal/notification/delete/export
-- has exactly one natural single actor (the moderator/admin/self), per
-- Product's Requirement 2.
--
-- Deliberately no exception handling around the insert here, and none
-- around any of the 5 `perform internal.log_audit_event(...)` call
-- sites either -- if this insert fails for any reason, the exception
-- propagates and rolls back the calling function's entire transaction
-- (fail-closed), rather than letting a privileged action succeed
-- silently unlogged. This is a deliberate choice, not a default: the
-- insert here has no realistic failure mode (event_type is always a
-- literal that matches the check constraint above, id/created_at have
-- defaults, actor_id/target_id/detail are all nullable), so fail-closed
-- costs nothing in practice while keeping audit trail integrity
-- strictly coupled to the action it records.
create or replace function internal.log_audit_event(
  p_actor_id uuid,
  p_event_type text,
  p_target_id uuid,
  p_detail jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_username text;
begin
  if p_actor_id is not null then
    select username into v_actor_username from public.profiles where id = p_actor_id;
  end if;

  insert into public.audit_log (actor_id, actor_username_snapshot, event_type, target_id, detail)
  values (p_actor_id, v_actor_username, p_event_type, p_target_id, p_detail);
end;
$$;

-- QA finding (2026-08-24, WYN-048): explicit revoke, not just an
-- omitted grant -- mirrors internal.notification_enabled()'s own fix
-- (WYN-044 round 1 finding) for the identical reason: PostgreSQL
-- grants EXECUTE on a newly created function to PUBLIC by default,
-- and `authenticated` already holds `usage` on schema `internal`
-- (needed by the RLS-embedded helpers elsewhere in this file), so
-- PUBLIC-execute plus schema USAGE was already sufficient for any
-- ordinary authenticated user to call this function directly by SQL
-- and forge arbitrary audit_log rows -- p_actor_id/p_target_id are
-- fully caller-supplied here, unlike export_my_data()/
-- delete_my_account() (both legitimately granted to authenticated),
-- whose only "whose data" input is auth.uid() with no caller override.
revoke execute on function internal.log_audit_event(uuid, text, uuid, jsonb) from public;

-- ============================================================
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

-- ============================================================
-- Admin Dashboard: trends (vs-yesterday deltas + 14-day DAU chart)
-- ============================================================
-- Added directly per the Founder's request to make the Dashboard "more
-- detailed, easier to understand" -- a separate RPC, not more columns
-- bolted onto admin_dashboard_metrics(), on purpose: that function was
-- *just* fixed after today's production migration-gap incident (it had
-- silently been running WYN-050's original 14-column shape in
-- production long after WYN-077 added 8 more), so this keeps the new,
-- purely-additive work isolated rather than risking another
-- drop-and-recreate on the one already confirmed working.
create or replace function public.admin_dashboard_trends()
returns table (
  new_users_yesterday bigint,
  drops_yesterday bigint,
  views_yesterday bigint,
  likes_yesterday bigint,
  comments_yesterday bigint,
  redrops_yesterday bigint,
  messages_yesterday bigint,
  -- One point per calendar day, oldest first -- see admin-metrics.ts's
  -- DauDay type. Deliberately DAU specifically (not new signups or
  -- drops): every other section of this dashboard already treats DAU as
  -- the platform's primary rolling-activity pulse (see
  -- admin_dashboard_metrics()'s own DAU/WAU/MAU comment above), so it's
  -- the one metric worth a full trend line rather than a single
  -- vs-yesterday badge.
  dau_last_14d jsonb
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not permitted to view admin dashboard trends';
  end if;

  return query
  -- Same "every did-something table" union admin_dashboard_metrics()
  -- uses for its own DAU/WAU/MAU -- duplicated here rather than shared,
  -- since Postgres has no cross-function CTE reuse and this keeps each
  -- RPC's SQL self-contained and independently readable.
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
  days as (
    select generate_series(
      date_trunc('day', now()) - interval '13 days',
      date_trunc('day', now()),
      interval '1 day'
    )::date as day
  ),
  daily_dau as (
    select d.day, count(distinct a.actor_id) as cnt
    from days d
    left join actions a
      on a.created_at >= d.day and a.created_at < d.day + interval '1 day'
    group by d.day
  )
  select
    (select count(*) from public.profiles
      where created_at >= now() - interval '2 days' and created_at < now() - interval '1 day'),
    (select count(*) from public.drops
      where created_at >= now() - interval '2 days' and created_at < now() - interval '1 day'),
    (select count(*) from public.drop_views
      where created_at >= now() - interval '2 days' and created_at < now() - interval '1 day'),
    (select count(*) from public.drop_likes where created_at >= now() - interval '2 days' and created_at < now() - interval '1 day')
      + (select count(*) from public.pop_likes where created_at >= now() - interval '2 days' and created_at < now() - interval '1 day')
      + (select count(*) from public.club_post_likes where created_at >= now() - interval '2 days' and created_at < now() - interval '1 day'),
    (select count(*) from public.drop_comments where created_at >= now() - interval '2 days' and created_at < now() - interval '1 day')
      + (select count(*) from public.pop_comments where created_at >= now() - interval '2 days' and created_at < now() - interval '1 day')
      + (select count(*) from public.club_post_comments where created_at >= now() - interval '2 days' and created_at < now() - interval '1 day'),
    (select count(*) from public.redrops
      where created_at >= now() - interval '2 days' and created_at < now() - interval '1 day'),
    (select count(*) from public.messages where deleted_at is null
      and created_at >= now() - interval '2 days' and created_at < now() - interval '1 day'),
    (select coalesce(jsonb_agg(jsonb_build_object('date', day, 'count', cnt) order by day), '[]'::jsonb)
      from daily_dau);
end;
$$;

grant execute on function public.admin_dashboard_trends() to authenticated;

-- ============================================================
-- Admin Dashboard: signup counts by calendar period
-- ============================================================
-- Added directly per the Founder's request ("กี่คน ต่อวัน ต่ออาทิตย์
-- ต่อเดือน ต่อปี") -- admin_dashboard_metrics()'s new_users_today only
-- ever answers the "today" slice of this question. Deliberately its
-- own tiny RPC rather than more columns on either existing dashboard
-- function: no joins, no CTEs, every value plain `count(*) from
-- profiles`, cheap enough that a 4th/5th RPC round trip isn't worth
-- optimizing away by bolting it onto a function that already does much
-- more work.
create or replace function public.admin_signup_counts()
returns table (
  today bigint,
  this_week bigint,
  this_month bigint,
  this_year bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not permitted to view signup counts';
  end if;

  return query
  select
    (select count(*) from public.profiles where created_at >= date_trunc('day', now())),
    -- date_trunc('week', ...) starts on Monday (ISO 8601), matching the
    -- Thai business-week convention already assumed elsewhere in this
    -- schema (nothing here currently disagrees with it).
    (select count(*) from public.profiles where created_at >= date_trunc('week', now())),
    (select count(*) from public.profiles where created_at >= date_trunc('month', now())),
    (select count(*) from public.profiles where created_at >= date_trunc('year', now()));
end;
$$;

grant execute on function public.admin_signup_counts() to authenticated;

-- ============================================================
-- WYN-051: WYN Admin User Management (direct Warn/Restrict/Suspend/
-- Ban/Unban, not tied to a Report)
-- ============================================================
-- See .wyn/tasks/backlog/WYN-051-admin-user-management.md and
-- .wyn/docs/design/wyn-051-admin-user-management.md. Every action
-- taken here inserts into the same `moderation_actions` table WYN-029
-- already built -- internal.is_posting_blocked()/
-- get_my_moderation_status()/RestrictionBanner and every other
-- existing consumer needs zero changes, since none of them ever
-- referenced report_id.

-- Nullable, not a new parallel table: a direct admin action has no
-- Report to point at. Evaluated against every `report_id` reference
-- in this file before making this change -- none of them assume NOT
-- NULL (is_posting_blocked() and friends only ever filter by
-- target_user_id/action_type/expires_at/overturned_at). This is
-- deliberately smaller-blast-radius than a second table would have
-- been: a parallel table would have required editing
-- is_posting_blocked() itself, which RLS policies across 15+ tables
-- call.
alter table public.moderation_actions
  alter column report_id drop not null;

-- Extend audit_log's event_type check constraint with this task's 2
-- new event types -- same drop+recreate pattern this schema already
-- uses for notifications_type_check (WYN-032/034/039/043/044).
do $$
declare
  v_constraint_name text;
begin
  select tc.constraint_name into v_constraint_name
  from information_schema.table_constraints tc
  join information_schema.constraint_column_usage ccu
    on ccu.constraint_name = tc.constraint_name
   and ccu.constraint_schema = tc.constraint_schema
  where tc.table_schema = 'public'
    and tc.table_name = 'audit_log'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'event_type';

  if v_constraint_name is not null then
    execute format('alter table public.audit_log drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.audit_log
  add constraint audit_log_event_type_check
  check (event_type in (
    'moderation_action_applied', 'appeal_decided',
    'system_notification_sent', 'account_deleted', 'data_exported',
    'admin_user_action_applied', 'admin_user_unbanned'
  ));

-- Same validation/notification/audit shape as apply_moderation_action()
-- above, minus the report lookup/status update (there is no report)
-- and minus remove_content/no_action (neither makes sense without a
-- report -- remove_content targets content, not a user directly; see
-- the Product spec's Requirement 3).
create or replace function public.admin_apply_user_action(
  p_target_user_id uuid,
  p_action_type text,
  p_reason text,
  p_duration_days integer default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reviewer uuid := auth.uid();
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_expires_at timestamptz;
  v_action_id uuid;
begin
  -- coalesce() is load-bearing here -- see
  -- .wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md
  -- for exactly why a bare `not in (...)` against a possibly-NULL role
  -- silently lets an unverified caller through.
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  if p_action_type not in ('warning', 'restrict', 'suspend', 'ban') then
    raise exception 'Invalid action_type: %', p_action_type;
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  if not exists (select 1 from public.profiles where id = p_target_user_id) then
    raise exception 'Target user not found';
  end if;

  if p_action_type in ('restrict', 'suspend') then
    if p_duration_days is null or p_duration_days not in (1, 3, 7) then
      raise exception 'duration_days must be 1, 3, or 7 for %', p_action_type;
    end if;
    v_expires_at := now() + (p_duration_days || ' days')::interval;
  else
    v_expires_at := null;
  end if;

  insert into public.moderation_actions (
    report_id, target_user_id, action_type, reason, duration_days, expires_at, reviewer_id
  ) values (
    null,
    p_target_user_id,
    p_action_type,
    v_trimmed_reason,
    case when p_action_type in ('restrict', 'suspend') then p_duration_days else null end,
    v_expires_at,
    v_reviewer
  )
  returning id into v_action_id;

  -- Only Warn gets an explicit push notification here, mirroring
  -- apply_moderation_action() exactly -- Restrict/Suspend/Ban are
  -- surfaced to the target through get_my_moderation_status() the next
  -- time AuthGate/RestrictionBanner checks, same as the report-driven
  -- path already relies on.
  if p_action_type = 'warning' then
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (p_target_user_id, null, 'moderation_warning', v_trimmed_reason, v_action_id, p_action_type);
  end if;

  perform internal.log_audit_event(
    v_reviewer,
    'admin_user_action_applied',
    p_target_user_id,
    jsonb_build_object('action_type', p_action_type, 'reason', v_trimmed_reason)
  );
end;
$$;

grant execute on function public.admin_apply_user_action(uuid, text, text, integer) to authenticated;

-- Clears every currently-active restrict/suspend/ban row for a user
-- (there is normally at most one, but this is written to be correct
-- even if more than one is somehow active at once) by setting
-- overturned_at -- the exact same column decide_appeal() already sets
-- on approval (WYN-030), so is_posting_blocked()'s
-- `overturned_at is null` check picks this up with no changes there.
create or replace function public.admin_unban_user(
  p_target_user_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reviewer uuid := auth.uid();
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  update public.moderation_actions
  set overturned_at = now()
  where target_user_id = p_target_user_id
    and overturned_at is null
    and (
      action_type = 'ban'
      or (action_type in ('restrict', 'suspend') and expires_at > now())
    );

  perform internal.log_audit_event(
    v_reviewer,
    'admin_user_unbanned',
    p_target_user_id,
    jsonb_build_object('reason', v_trimmed_reason)
  );
end;
$$;

grant execute on function public.admin_unban_user(uuid, text) to authenticated;

-- Admin/moderator visibility into moderation history, mirroring
-- moderation_queue's exact structural pattern (WYN-029): a plain view
-- (no security_invoker) that re-implements its own caller-based
-- visibility in the `where` clause, so a client hitting
-- `/rest/v1/moderation_actions` directly still sees nothing (that
-- table still has zero SELECT policy of its own). Unlike
-- moderation_queue, this DOES expose the reviewer's identity
-- (username) -- WYN-026/029's "never let the target learn who acted"
-- rule protects the target from seeing this, not other Admin/Moderator
-- staff from seeing each other's actions, which is ordinary
-- accountability, not the same privacy concern (see the Design spec's
-- reasoning).
create or replace view public.admin_user_moderation_history as
select
  ma.id,
  ma.target_user_id,
  ma.action_type,
  ma.reason,
  ma.duration_days,
  ma.expires_at,
  ma.overturned_at,
  ma.created_at,
  p.username as reviewer_username
from public.moderation_actions ma
join public.profiles p on p.id = ma.reviewer_id
where internal.current_platform_role() <> 'user';

grant select on public.admin_user_moderation_history to authenticated;

-- ============================================================
-- Admin User Management: directory (sort/filter, wide-angle view)
-- ============================================================
-- Added directly per the Founder's request -- User Management could
-- only ever show one user at a time (typed a username, got a row).
-- This is the "see the whole picture" complement: rank/filter every
-- user by activity or status, no query typed. Same "did-something"
-- union every other admin RPC in this file already builds
-- (admin_dashboard_metrics()/admin_dashboard_trends()'s DAU calc) --
-- duplicated rather than shared for the same reason those two are: no
-- cross-function CTE reuse in Postgres, and each RPC stays
-- self-contained and independently readable.
create or replace function public.admin_user_directory(
  p_sort text default 'newest',
  p_role text default null,
  p_status text default null,
  p_limit int default 50
)
returns table (
  id uuid,
  username text,
  display_name text,
  platform_role text,
  created_at timestamptz,
  last_active_at timestamptz,
  activity_count bigint,
  current_status text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not permitted to view the user directory';
  end if;

  -- Every column/table alias in this query body is deliberately named
  -- to NOT match any name in this function's own RETURNS TABLE list
  -- (created_at/last_active_at/activity_count/current_status) --
  -- PL/pgSQL's RETURNS TABLE OUT parameters are visible as variables
  -- for the whole function body, so a bare `created_at` inside the
  -- query below is genuinely ambiguous between "the OUT parameter" and
  -- "the table column" (Postgres error 42702) the moment more than one
  -- table in scope has a same-named column -- confirmed the hard way
  -- against production. Table-qualifying alone doesn't fully dodge it
  -- (a bare alias like `acted_at` still could, in principle, coincide
  -- with a future OUT param), so every intermediate name here is
  -- chosen to be distinct from the OUT list on top of being qualified.
  return query
  with actions as (
    select dl.user_id as actor_id, dl.created_at as acted_at from public.drop_likes dl
    union all
    select pl.user_id, pl.created_at from public.pop_likes pl
    union all
    select cpl.user_id, cpl.created_at from public.club_post_likes cpl
    union all
    select dc.author_id, dc.created_at from public.drop_comments dc
    union all
    select pc.author_id, pc.created_at from public.pop_comments pc
    union all
    select cpc.author_id, cpc.created_at from public.club_post_comments cpc
    union all
    select r.redropper_id, r.created_at from public.redrops r
    union all
    select m.sender_id, m.created_at from public.messages m where m.deleted_at is null
    union all
    select d.author_id, d.created_at from public.drops d
  ),
  activity as (
    select act.actor_id, max(act.acted_at) as last_active, count(*) as total_actions
    from actions act
    group by act.actor_id
  ),
  -- Same "still-active restrict/suspend, or any ban, not overturned"
  -- rule as currentActiveAction() in admin/lib/admin-users.ts applies
  -- client-side to one user's own history -- computed here instead so
  -- every row in a many-user directory gets it without an N+1 query per
  -- user. `distinct on` picks the most recent qualifying row per user,
  -- matching that helper's "the" (singular) active action assumption.
  active_action as (
    select distinct on (ma.target_user_id)
      ma.target_user_id,
      ma.action_type as resolved_action_type
    from public.moderation_actions ma
    where ma.overturned_at is null
      and (
        ma.action_type = 'ban'
        or (ma.action_type in ('restrict', 'suspend') and ma.expires_at > now())
      )
    order by ma.target_user_id, ma.created_at desc
  )
  select
    p.id,
    p.username,
    p.display_name,
    p.platform_role,
    p.created_at,
    act.last_active,
    coalesce(act.total_actions, 0),
    coalesce(aa.resolved_action_type, 'normal')
  from public.profiles p
  left join activity act on act.actor_id = p.id
  left join active_action aa on aa.target_user_id = p.id
  where (p_role is null or p.platform_role = p_role)
    and (p_status is null or coalesce(aa.resolved_action_type, 'normal') = p_status)
  order by
    case when p_sort = 'newest' then p.created_at end desc,
    case when p_sort = 'oldest' then p.created_at end asc,
    case when p_sort = 'most_active' then coalesce(act.total_actions, 0) end desc,
    -- Never-active users (last_active is null) count as the most
    -- dormant of all, not sorted to the bottom -- nulls first is the
    -- point, not an artifact.
    case when p_sort = 'dormant' then act.last_active end asc nulls first
  limit p_limit;
end;
$$;

grant execute on function public.admin_user_directory(text, text, text, int) to authenticated;

-- ============================================================
-- WYN-052: WYN Admin Content Moderation (Search Drop, Remove,
-- Restore -- Drop only in V1)
-- ============================================================
-- See .wyn/tasks/backlog/WYN-052-admin-content-moderation.md and
-- .wyn/docs/design/wyn-052-admin-content-moderation.md. Closes a real
-- architecture gap found while drafting the spec: apply_moderation_action()'s
-- remove_content branch (WYN-029) was a permanent hard DELETE with no
-- restore path at all, and simply reusing drops.deleted_at (WYN-037's
-- self-service soft-delete) for it as-is would let a Drop's own author
-- self-restore content an Admin removed for breaking the rules, via
-- restore_drop() -- which never distinguished *who* deleted it. Comment/
-- Club Post have no soft-delete infrastructure to restore into and keep
-- hard-deleting exactly as before, completely untouched by this task.

-- Polymorphic pair mirroring reports.target_type/target_id (WYN-026) --
-- nullable because most rows here still target a *user* directly
-- (target_user_id, unchanged), not a piece of content. V1 only ever
-- writes 'drop' here.
alter table public.moderation_actions
  add column if not exists target_content_type text;
alter table public.moderation_actions
  add column if not exists target_content_id uuid;

alter table public.moderation_actions
  add constraint moderation_actions_target_content_type_check
  check (target_content_type is null or target_content_type = 'drop');

alter table public.moderation_actions
  add constraint moderation_actions_target_content_pairing_check
  check ((target_content_type is null) = (target_content_id is null));

create index if not exists moderation_actions_target_content_idx
  on public.moderation_actions (target_content_type, target_content_id)
  where target_content_type is not null;

-- The core security fix: restore_drop() (WYN-037, self-service) now
-- refuses to restore a Drop that carries a still-active
-- ('overturned_at is null') moderation remove_content action against
-- it -- the exact self-restore-defeats-moderation bypass the Product
-- spec's Requirement 2 describes. A self-deleted Drop (no such row at
-- all) is completely unaffected -- the Product spec's Acceptance
-- Criteria calls this regression case out explicitly.
create or replace function public.restore_drop(p_drop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_drop record;
begin
  select * into v_drop from public.drops where id = p_drop_id for update;
  if v_drop is null then
    raise exception 'Drop not found';
  end if;
  if v_drop.author_id <> v_me then
    raise exception 'Only the author can restore this Drop';
  end if;
  if v_drop.deleted_at is null then
    raise exception 'Drop is not deleted';
  end if;

  if exists (
    select 1 from public.moderation_actions
    where target_content_type = 'drop'
      and target_content_id = p_drop_id
      and action_type = 'remove_content'
      and overturned_at is null
  ) then
    raise exception 'เนื้อหานี้ถูกลบโดยผู้ดูแลระบบ ติดต่อผ่านการอุทธรณ์เท่านั้น';
  end if;

  if v_drop.deleted_at <= now() - interval '30 days' then
    raise exception 'The 30-day restore window has passed';
  end if;

  update public.drops set deleted_at = null where id = p_drop_id;
end;
$$;

grant execute on function public.restore_drop(uuid) to authenticated;

-- apply_moderation_action() (WYN-029) redefined: remove_content against
-- a Drop now soft-deletes (reuses soft_delete_drop()'s own deleted_at
-- column) and records target_content_type/target_content_id on the
-- moderation_actions row it inserts, instead of a permanent hard
-- DELETE -- so a Report-driven Remove Content is restorable via
-- admin_restore_drop() below exactly like a direct admin_remove_drop()
-- one, and is caught by restore_drop()'s new guard above the same way.
-- drop_comment/club_post/club_post_comment are completely untouched --
-- still an immediate hard DELETE, per the Product spec's Requirement 1.
create or replace function public.apply_moderation_action(
  p_report_id uuid,
  p_action_type text,
  p_reason text,
  p_duration_days integer default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reviewer uuid := auth.uid();
  v_reviewer_role text;
  v_report record;
  v_target_user uuid;
  v_target_content_type text;
  v_target_content_id uuid;
  v_expires_at timestamptz;
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_action_id uuid;
begin
  if v_reviewer is null then
    raise exception 'Not authenticated';
  end if;

  select platform_role into v_reviewer_role from public.profiles where id = v_reviewer;
  if v_reviewer_role is null or v_reviewer_role = 'user' then
    raise exception 'Not authorized';
  end if;

  if p_action_type not in ('no_action', 'warning', 'remove_content', 'restrict', 'suspend', 'ban') then
    raise exception 'Invalid action_type: %', p_action_type;
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  select * into v_report from public.reports where id = p_report_id for update;
  if v_report is null then
    raise exception 'Report not found';
  end if;
  if v_report.status not in ('pending', 'reviewing') then
    raise exception 'Report has already been actioned';
  end if;

  if v_report.target_type = 'user' then
    v_target_user := v_report.target_id;
  elsif v_report.target_type = 'drop' then
    select author_id into v_target_user from public.drops where id = v_report.target_id;
  elsif v_report.target_type = 'drop_comment' then
    select author_id into v_target_user from public.drop_comments where id = v_report.target_id;
  elsif v_report.target_type = 'club' then
    select owner_id into v_target_user from public.clubs where id = v_report.target_id;
  elsif v_report.target_type = 'club_post' then
    select author_id into v_target_user from public.club_posts where id = v_report.target_id;
  elsif v_report.target_type = 'club_post_comment' then
    select author_id into v_target_user from public.club_post_comments where id = v_report.target_id;
  else
    raise exception 'Unsupported report target type: %', v_report.target_type;
  end if;

  -- Remove Content only applies to content targets, per the Product
  -- spec ("เฉพาะ target ที่เป็นเนื้อหา ไม่ใช้กับ target ที่เป็น User/Club").
  if p_action_type = 'remove_content' and v_report.target_type in ('user', 'club') then
    raise exception 'Remove Content is not supported for target type %', v_report.target_type;
  end if;

  -- Every action except No Action needs a real account to act on -- if
  -- the target vanished before review (deleted by its own author, or by
  -- an earlier Remove Content against a different report on the same
  -- content), only No Action can still close the case.
  if v_target_user is null and p_action_type <> 'no_action' then
    raise exception 'Target no longer exists -- use No Action to close this report';
  end if;

  if p_action_type in ('restrict', 'suspend') then
    if p_duration_days is null or p_duration_days not in (1, 3, 7) then
      raise exception 'duration_days must be 1, 3, or 7 for % ', p_action_type;
    end if;
    v_expires_at := now() + (p_duration_days || ' days')::interval;
  else
    v_expires_at := null;
  end if;

  -- WYN-052: only a Drop gets restorable tracking -- other content
  -- types have no soft-delete infra to point this at (see the section
  -- comment above).
  if p_action_type = 'remove_content' and v_report.target_type = 'drop' then
    v_target_content_type := 'drop';
    v_target_content_id := v_report.target_id;
  end if;

  insert into public.moderation_actions (
    report_id, target_user_id, action_type, reason, duration_days, expires_at,
    reviewer_id, target_content_type, target_content_id
  ) values (
    p_report_id,
    v_target_user,
    p_action_type,
    v_trimmed_reason,
    case when p_action_type in ('restrict', 'suspend') then p_duration_days else null end,
    v_expires_at,
    v_reviewer,
    v_target_content_type,
    v_target_content_id
  )
  returning id into v_action_id;

  update public.reports
  set status = case when p_action_type = 'no_action' then 'dismissed' else 'actioned' end
  where id = p_report_id;

  -- actor_id is deliberately NULL for both effects below (WYN-029 fix,
  -- see .wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md) --
  -- v_reviewer must never be written here, since notifications.actor_id
  -- is a plain, target-readable column (RLS is row-level, not column-
  -- level), unlike moderation_actions.reviewer_id which has no client
  -- SELECT access at all and remains the only correctly-protected place
  -- this identity is recorded.
  if p_action_type = 'warning' then
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_target_user, null, 'moderation_warning', v_trimmed_reason, v_action_id, p_action_type);
  elsif p_action_type = 'remove_content' then
    -- Notification inserted *before* the removal below on purpose: both
    -- drop_id/club_post_id etc. are left null on this notification (see
    -- the notifications_type_check migration further down), so nothing
    -- here references the row about to be removed and there is no
    -- on-delete-cascade ordering hazard either way -- but inserting
    -- first keeps the "notify, then remove" sequence readable as the
    -- two-step user-facing effect the design doc describes.
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_target_user, null, 'moderation_content_removed', v_trimmed_reason, v_action_id, p_action_type);

    -- WYN-052: Drop now soft-deletes (restorable, see admin_restore_drop()
    -- below and restore_drop()'s new guard above) instead of a hard
    -- DELETE -- drop_comment/club_post/club_post_comment are unchanged,
    -- still an immediate hard DELETE (design doc's Screen 5 effect,
    -- unmodified for those 3 types: "hidden from everyone including the
    -- author").
    if v_report.target_type = 'drop' then
      update public.drops set deleted_at = now() where id = v_report.target_id and deleted_at is null;
    elsif v_report.target_type = 'drop_comment' then
      delete from public.drop_comments where id = v_report.target_id;
    elsif v_report.target_type = 'club_post' then
      delete from public.club_posts where id = v_report.target_id;
    elsif v_report.target_type = 'club_post_comment' then
      delete from public.club_post_comments where id = v_report.target_id;
    end if;
  end if;

  -- WYN-048: audit trail for this privileged action, recorded after
  -- everything above has already succeeded. actor_id is the real
  -- reviewer identity (v_reviewer) -- unlike the notifications inserted
  -- above (which deliberately null out actor_id so the target never
  -- learns who reviewed them), audit_log has zero client-facing SELECT
  -- policy at all, so recording the true reviewer here creates no such
  -- leak. No exception handling around this call: if it raises, the
  -- whole action rolls back (fail-closed) rather than letting a
  -- privileged moderation action succeed unlogged -- see
  -- internal.log_audit_event()'s own comment (WYN-048 section) for why
  -- that failure mode is realistically never hit anyway.
  perform internal.log_audit_event(
    v_reviewer,
    'moderation_action_applied',
    v_target_user,
    jsonb_build_object('action_type', p_action_type, 'reason', v_trimmed_reason)
  );
end;
$$;

grant execute on function public.apply_moderation_action(uuid, text, text, integer) to authenticated;

-- Extend audit_log's event_type check constraint with this task's 2 new
-- event types, same drop+recreate pattern WYN-051 already used.
do $$
declare
  v_constraint_name text;
begin
  select tc.constraint_name into v_constraint_name
  from information_schema.table_constraints tc
  join information_schema.constraint_column_usage ccu
    on ccu.constraint_name = tc.constraint_name
   and ccu.constraint_schema = tc.constraint_schema
  where tc.table_schema = 'public'
    and tc.table_name = 'audit_log'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'event_type';

  if v_constraint_name is not null then
    execute format('alter table public.audit_log drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.audit_log
  add constraint audit_log_event_type_check
  check (event_type in (
    'moderation_action_applied', 'appeal_decided',
    'system_notification_sent', 'account_deleted', 'data_exported',
    'admin_user_action_applied', 'admin_user_unbanned',
    'admin_content_removed', 'admin_content_restored'
  ));

-- Direct Remove, not tied to a Report -- mirrors admin_apply_user_action()
-- (WYN-051) exactly: coalesce() role guard (WYN-050's lesson), no Report
-- lookup, notification via the existing moderation_content_removed type
-- apply_moderation_action() already sends. Soft-deletes through the same
-- deleted_at column self-delete uses (soft_delete_drop(), WYN-037)
-- rather than a parallel flag, so every other consumer of deleted_at
-- (RLS SELECT policy, is_drop_deleted(), the 30-day purge boundary)
-- needs zero changes.
create or replace function public.admin_remove_drop(
  p_drop_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reviewer uuid := auth.uid();
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_drop record;
  v_action_id uuid;
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  select * into v_drop from public.drops where id = p_drop_id for update;
  if v_drop is null then
    raise exception 'Drop not found';
  end if;
  if v_drop.deleted_at is not null then
    raise exception 'Drop is already deleted';
  end if;

  update public.drops set deleted_at = now() where id = p_drop_id;

  insert into public.moderation_actions (
    report_id, target_user_id, action_type, reason,
    target_content_type, target_content_id, reviewer_id
  ) values (
    null, v_drop.author_id, 'remove_content', v_trimmed_reason,
    'drop', p_drop_id, v_reviewer
  )
  returning id into v_action_id;

  insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
  values (v_drop.author_id, null, 'moderation_content_removed', v_trimmed_reason, v_action_id, 'remove_content');

  perform internal.log_audit_event(
    v_reviewer,
    'admin_content_removed',
    v_drop.author_id,
    jsonb_build_object('target_content_type', 'drop', 'target_content_id', p_drop_id, 'reason', v_trimmed_reason)
  );
end;
$$;

grant execute on function public.admin_remove_drop(uuid, text) to authenticated;

-- Admin/moderator restore -- distinct from self-service restore_drop()
-- above because the authorization/eligibility rules are entirely
-- different (any Admin/Moderator, any Drop, regardless of who deleted
-- it or how long ago -- no 30-day window, no author check). Works for a
-- self-deleted Drop too (Design spec's Screen 2: an Admin may restore on
-- a user's behalf after they reach out) -- the moderation_actions update
-- below is then simply a no-op (0 rows), which is correct: there is no
-- moderation action to mark overturned in that case.
create or replace function public.admin_restore_drop(
  p_drop_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reviewer uuid := auth.uid();
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_drop record;
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  select * into v_drop from public.drops where id = p_drop_id for update;
  if v_drop is null then
    raise exception 'Drop not found';
  end if;
  if v_drop.deleted_at is null then
    raise exception 'Drop is not deleted';
  end if;

  update public.drops set deleted_at = null where id = p_drop_id;

  update public.moderation_actions
  set overturned_at = now()
  where target_content_type = 'drop'
    and target_content_id = p_drop_id
    and action_type = 'remove_content'
    and overturned_at is null;

  perform internal.log_audit_event(
    v_reviewer,
    'admin_content_restored',
    v_drop.author_id,
    jsonb_build_object('target_content_type', 'drop', 'target_content_id', p_drop_id, 'reason', v_trimmed_reason)
  );
end;
$$;

grant execute on function public.admin_restore_drop(uuid, text) to authenticated;

-- Admin/moderator Drop search -- SECURITY DEFINER so it bypasses drops'
-- own SELECT policy entirely (block/private-account/deleted gating,
-- WYN-027/037/039), the same mechanism is_posting_blocked() etc.
-- already rely on, per the Product spec's Requirement 3 ("เห็น Drop
-- ทุกโพสต์แม้ของบัญชี Private/ที่ Block กันอยู่"). A plain view can't take a
-- query parameter cleanly, so this is a function rather than mirroring
-- moderation_queue's view shape directly.
create or replace function public.admin_search_drops(p_query text)
returns table (
  id uuid,
  image_url text,
  caption text,
  author_id uuid,
  author_username text,
  deleted_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  return query
  select d.id, d.image_url, d.caption, d.author_id, p.username, d.deleted_at, d.created_at
  from public.drops d
  join public.profiles p on p.id = d.author_id
  where d.caption ilike '%' || p_query || '%' or p.username ilike '%' || p_query || '%'
  order by d.created_at desc
  limit 30;
end;
$$;

grant execute on function public.admin_search_drops(text) to authenticated;

-- Single-Drop fetch for Screen 2, same bypass/authorization shape as
-- admin_search_drops() above -- needed because navigating straight to
-- /moderation/[id] doesn't go through the search results at all.
create or replace function public.admin_get_drop(p_drop_id uuid)
returns table (
  id uuid,
  image_url text,
  caption text,
  author_id uuid,
  author_username text,
  deleted_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  return query
  select d.id, d.image_url, d.caption, d.author_id, p.username, d.deleted_at, d.created_at
  from public.drops d
  join public.profiles p on p.id = d.author_id
  where d.id = p_drop_id;
end;
$$;

grant execute on function public.admin_get_drop(uuid) to authenticated;

-- Extend admin_user_moderation_history (WYN-051) with the 2 new
-- columns rather than a parallel view, per the Product spec's
-- Requirement 3 -- existing consumers (WYN-051's /users/[id] page,
-- filtering by target_user_id) are unaffected by 2 additional nullable
-- columns; this task's /moderation/[id] page filters the same view by
-- target_content_id instead.
create or replace view public.admin_user_moderation_history as
select
  ma.id,
  ma.target_user_id,
  ma.action_type,
  ma.reason,
  ma.duration_days,
  ma.expires_at,
  ma.overturned_at,
  ma.created_at,
  p.username as reviewer_username,
  ma.target_content_type,
  ma.target_content_id
from public.moderation_actions ma
join public.profiles p on p.id = ma.reviewer_id
where internal.current_platform_role() <> 'user';

grant select on public.admin_user_moderation_history to authenticated;

-- ============================================================
-- WYN-054: Audit Log (Admin/Moderator read screen)
-- ============================================================
-- See .wyn/tasks/backlog/WYN-054-audit-log.md. audit_log (WYN-048) was
-- deliberately built with zero client-facing policy of any kind -- its
-- own section comment says explicitly "WYN-054, Phase 7, is what adds
-- the screen that reads this table." This is that screen's read path:
-- a plain VIEW mirroring moderation_queue/admin_user_moderation_history's
-- exact established shape (no security_invoker, re-implements its own
-- visibility in the WHERE clause, so a client hitting
-- `/rest/v1/audit_log` directly still sees nothing -- that table keeps
-- zero policies of its own, completely unchanged by this task). Same
-- admin-OR-moderator threshold as every other admin view so far --
-- there is no third tier to split on, and every event type logged so
-- far is already the direct result of a privileged action or a
-- compliance-relevant self-service one (account_deleted/data_exported)
-- Admin staff legitimately need visibility into. actor_username_snapshot
-- shown plainly -- same reasoning as admin_user_moderation_history's
-- reviewer_username: the "never let the target learn who acted" rule
-- protects the target, not other staff from each other. No delete/
-- update path added anywhere -- a SELECT-only view changes nothing
-- about audit_log's existing immutability.
create or replace view public.admin_audit_log as
select
  id,
  actor_id,
  actor_username_snapshot,
  event_type,
  target_id,
  detail,
  created_at
from public.audit_log
where internal.current_platform_role() <> 'user';

grant select on public.admin_audit_log to authenticated;

-- ============================================================
-- WYN-055: WYN Official Announcement (Admin broadcast to a group)
-- ============================================================
-- See .wyn/tasks/backlog/WYN-055-official-announcements.md.
-- send_system_notification() (WYN-043) is single-recipient only --
-- this is the group-send primitive: one insert-select statement, not a
-- client-side loop over the existing RPC (which would be hundreds/
-- thousands of round trips and not atomic). Reuses the exact same
-- 'system' notification type/category send_system_notification()
-- already uses -- NotificationListScreen needs zero changes, no new
-- notification type. Audience is profiles.platform_role -- the one
-- real, already-meaningful split available (no cohort/segment/region
-- model exists anywhere in this schema to target by instead).

-- Extend audit_log's event_type check constraint with this task's 1
-- new event type, same drop+recreate pattern used repeatedly already.
do $$
declare
  v_constraint_name text;
begin
  select tc.constraint_name into v_constraint_name
  from information_schema.table_constraints tc
  join information_schema.constraint_column_usage ccu
    on ccu.constraint_name = tc.constraint_name
   and ccu.constraint_schema = tc.constraint_schema
  where tc.table_schema = 'public'
    and tc.table_name = 'audit_log'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'event_type';

  if v_constraint_name is not null then
    execute format('alter table public.audit_log drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.audit_log
  add constraint audit_log_event_type_check
  check (event_type in (
    'moderation_action_applied', 'appeal_decided',
    'system_notification_sent', 'account_deleted', 'data_exported',
    'admin_user_action_applied', 'admin_user_unbanned',
    'admin_content_removed', 'admin_content_restored',
    'admin_announcement_sent'
  ));

-- Admin-only (not moderator) -- matches send_system_notification()'s
-- own existing restriction and the Product spec's literal "Admin
-- สร้างประกาศ" wording. Every other Phase 7 RPC so far
-- (admin_apply_user_action/admin_remove_drop/etc.) uses
-- `not in ('admin', 'moderator')` -- this one deliberately does not,
-- see the Product spec's Risks section for why that distinction
-- matters here specifically.
create or replace function public.admin_send_announcement(
  p_category text,
  p_message text,
  p_audience text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_trimmed_message text := trim(coalesce(p_message, ''));
  v_recipient_count integer;
begin
  -- coalesce() is load-bearing -- see
  -- .wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md.
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can send announcements';
  end if;

  if p_category not in ('system_update', 'policy_update', 'maintenance', 'important') then
    raise exception 'Invalid category: %', p_category;
  end if;

  if length(v_trimmed_message) = 0 then
    raise exception 'Announcement message must not be blank';
  end if;

  if p_audience not in ('all', 'users', 'staff') then
    raise exception 'Invalid audience: %', p_audience;
  end if;

  with recipients as (
    select id from public.profiles
    where
      case p_audience
        when 'users' then platform_role = 'user'
        when 'staff' then platform_role in ('moderator', 'admin')
        else true
      end
      and internal.notification_enabled(id, 'system')
  ),
  inserted as (
    insert into public.notifications (recipient_id, actor_id, type, reason)
    select id, null, 'system', v_trimmed_message from recipients
    returning 1
  )
  select count(*) into v_recipient_count from inserted;

  perform internal.log_audit_event(
    v_admin,
    'admin_announcement_sent',
    null,
    jsonb_build_object(
      'category', p_category,
      'message', v_trimmed_message,
      'audience', p_audience,
      'recipient_count', v_recipient_count
    )
  );

  return v_recipient_count;
end;
$$;

grant execute on function public.admin_send_announcement(text, text, text) to authenticated;

-- ============================================================
-- WYNOS V1.0.0 Beta: UX/UI Fix & Feature Update, requirement 2
-- ============================================================

-- A Drop may now be image-only, caption-only, or both -- the client's
-- own _canShare guard (CreateDropScreen) is the primary gate, same
-- posture as everywhere else in this schema; this CHECK is a defense-
-- in-depth safety net so a totally-empty Drop (no image_url, no
-- caption) can never land in the table no matter which code path
-- writes it, including a future one nobody has reasoned about yet.
-- Single-row, no cross-table reference needed: every valid Drop shape
-- already satisfies this without qualification -- an image Drop always
-- has image_url, a Poll Drop always has caption (create_poll_drop()
-- raises 'Poll question is required' otherwise), and a new text-only
-- Drop always has caption (createTextDrop's own client-side guard,
-- mirrored below).
alter table public.drops
  add constraint drops_has_content
  check (image_url is not null or caption is not null);

-- ============================================================
-- WYNOS Unified Home Feed Algorithm V1.0
-- ============================================================

-- Founder's own weight proportions (Personalized Interest 35% /
-- Following 25% / Engagement 15% / Trending 10% / Recency 10% /
-- Discovery 5%) are explicitly *not* meant to be permanent
-- ("ห้ามใช้สัดส่วนนี้แบบตายตัวในระยะยาว ให้โครงสร้างรองรับการปรับ
-- น้ำหนักตามข้อมูลจริงในอนาคต") -- stored as data, not hardcoded into
-- get_wynos_ranked_feed() below, so adjusting them later is a plain
-- UPDATE, never a schema migration or a Coding task.
create table if not exists public.feed_ranking_config (
  key text primary key,
  weight double precision not null,
  updated_at timestamptz not null default now()
);

alter table public.feed_ranking_config enable row level security;

-- Every authenticated user's own ranked feed reads these weights (via
-- get_wynos_ranked_feed(), running as invoker) -- there is nothing
-- sensitive in a scoring weight, so a plain "viewable by everyone"
-- policy is enough. No insert/update/delete policy for ordinary users
-- -- weights are operator-adjusted directly (or by a future admin
-- tool), never by a client-facing mutation.
create policy "Feed ranking weights are viewable by authenticated users"
  on public.feed_ranking_config
  for select
  to authenticated
  using (true);

insert into public.feed_ranking_config (key, weight) values
  ('personalized_interest', 0.35),
  ('following', 0.25),
  ('engagement', 0.15),
  ('trending', 0.10),
  ('recency', 0.10),
  ('discovery', 0.05)
on conflict (key) do nothing;

-- User Signals not already captured by a dedicated table elsewhere in
-- this schema (Like/Comment/Save/Follow/View/Report all already have
-- their own tables -- drop_likes, drop_comments, saves, follows,
-- drop_views, reports). This one covers the 2 that don't yet: visiting
-- someone's profile (a soft "interested in this author" signal), and
-- explicitly hiding a piece of content (a hard negative signal).
-- Phase 4 extends this stream below with explicit negative and bounded
-- consumption signals while preserving these original values and policies.
create table if not exists public.feed_signals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  signal_type text not null check (signal_type in ('profile_visit', 'hide', 'not_interested')),
  target_type text not null check (target_type in ('drop', 'pop', 'profile')),
  target_id uuid not null,
  created_at timestamptz not null default now()
);

-- Covers both get_wynos_ranked_feed()'s "which content has this user
-- hidden" lookup (user_id, signal_type='hide', target_id) and the
-- author-affinity CTE's "which profiles has this user visited" lookup
-- (user_id, signal_type='profile_visit') -- a single composite index
-- serves both since user_id is always the leading filter.
create index if not exists feed_signals_user_type_idx
  on public.feed_signals (user_id, signal_type, target_id);

alter table public.feed_signals enable row level security;

-- Same "private to the user themselves" posture as drop_views
-- (WYN-038) -- what you've hidden or whose profile you've visited is
-- not something any other user should be able to query about you.
create policy "Users can view only their own feed signals"
  on public.feed_signals
  for select
  to authenticated
  using (auth.uid() = user_id);

-- Unlike drop_views, a plain client INSERT is fine here (no rate-
-- limit/anti-gaming concern -- hiding your own feed content or
-- visiting a profile isn't something that benefits from being spoofed
-- at scale the way inflating a public View count would), so this
-- skips the "RPC-only, no INSERT policy" pattern drop_views/Pop's
-- view_count use.
create policy "Users can record their own feed signals"
  on public.feed_signals
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- WYN-079 (Wynos V1.0.0 Beta2, item 8): Founder wants "ไม่สนใจโพสต์นี้"
-- (Hide) reversible via a Snackbar "เลิกทำ" (Undo) action, overriding
-- this table's original "hide is one-way, no delete policy" posture --
-- own-row-only, same auth.uid() = user_id shape as the select/insert
-- policies above, so a user can only ever unhide content they
-- themselves hid.
create policy "Users can delete their own feed signals"
  on public.feed_signals
  for delete
  to authenticated
  using (auth.uid() = user_id);

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

-- Total Save count for one piece of content, regardless of who's
-- asking -- mirrors drop_view_count()'s exact reasoning (WYN-038):
-- `saves`' own SELECT policy only lets a user see *their own* saves
-- (auth.uid() = user_id), so a plain correlated subquery on it would
-- give every caller of get_wynos_ranked_feed() a different (mostly 0
-- or 1) number instead of the true total. SECURITY DEFINER bypasses
-- that restrictive policy for this one read-only, no-side-effect,
-- count-only purpose -- never reveals *which* users saved it, only
-- how many.
create or replace function public.content_save_count(p_content_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*) from public.saves where content_id = p_content_id;
$$;

grant execute on function public.content_save_count(uuid) to authenticated;

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

-- ============================================================
-- WYNOS Top100 Organic Ranking Engine V1 (Phase 3)
-- ============================================================

-- Top100 is a broader seven-day chart, precomputed independently from the
-- short-window Trending cache. The published Trending score is consumed only
-- as a capped momentum bonus; impressions, placements, fetches, and rank are
-- absent from both the refresh inputs and this table.
create table if not exists public.top100_scores (
  drop_id uuid primary key references public.drops (id) on delete cascade,
  content_type text not null default 'drop' check (content_type = 'drop'),
  creator_id uuid not null references public.profiles (id) on delete cascade,
  top100_score double precision not null check (top100_score >= 0),
  organic_score double precision not null check (organic_score >= 0),
  trend_bonus double precision not null check (trend_bonus >= 0),
  unique_engagers_7d integer not null default 0,
  likes_7d integer not null default 0,
  comments_7d integer not null default 0,
  shares_7d integer not null default 0,
  saves_7d integer not null default 0,
  qualified_views_7d integer not null default 0,
  current_rank integer,
  previous_rank integer,
  first_entered_at timestamptz not null,
  observed_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create index if not exists top100_scores_rank_idx
  on public.top100_scores (top100_score desc, organic_score desc,
    observed_at desc, drop_id);
create index if not exists top100_scores_public_rank_idx
  on public.top100_scores (current_rank, observed_at desc, drop_id);

alter table public.top100_scores enable row level security;
drop policy if exists "Top100 safe metadata is viewable by authenticated users"
  on public.top100_scores;
create policy "Top100 safe metadata is viewable by authenticated users"
  on public.top100_scores for select to authenticated using (true);
revoke all on public.top100_scores from authenticated, anon;
grant select (
  drop_id, creator_id, top100_score, current_rank, previous_rank,
  first_entered_at, observed_at
) on public.top100_scores to authenticated;

-- One authoritative score decomposition. Organic quality is broad-window and
-- log-normalized. Trending contributes only a multiplier in [1, 1.25], so its
-- bonus can be at most 25% of organic score (20% of the effective total). It
-- cannot create Top100 score from zero organic quality and does not re-add the
-- recent raw actions already represented in the broad aggregates.
create or replace function public.calculate_top100_score(
  p_likes integer,
  p_comments integer,
  p_shares integer,
  p_saves integer,
  p_qualified_views integer,
  p_unique_engagers integer,
  p_action_count integer,
  p_content_age_hours double precision,
  p_trend_score double precision,
  p_report_count integer,
  p_suspicious boolean
)
returns table (
  organic_score double precision,
  trend_bonus double precision,
  top100_score double precision
)
language sql
immutable
parallel safe
as $$
  with factors as (
    select
      case when p_unique_engagers <= 0 then 0.0 else
        ln(1.0
          + greatest(p_likes, 0) * 2.0
          + greatest(p_comments, 0) * 4.0
          + greatest(p_shares, 0) * 6.0
          + greatest(p_saves, 0) * 5.0
          + greatest(p_qualified_views, 0) * 0.1)
        * (0.70 + 0.30 * least(1.0,
            ln(1.0 + p_unique_engagers) / ln(101.0)))
        * greatest(0.30, least(1.0,
            p_unique_engagers * 4.0 / greatest(p_action_count, 1)))
        * (0.70 + 0.30 * power(0.5,
            greatest(p_content_age_hours, 0) / 168.0))
      end as raw_organic,
      least(0.25, ln(1.0 + greatest(p_trend_score, 0)) / 40.0)
        as trend_multiplier,
      power(0.20::double precision,
        greatest(p_report_count, 0)::double precision)
        * case when p_suspicious then 0.15 else 1.0 end as penalty
  ), scored as (
    select raw_organic * penalty as organic,
      raw_organic * trend_multiplier * penalty as bonus
    from factors
  )
  select organic, bonus, least(1000000.0, organic + bonus) from scored;
$$;

grant execute on function public.calculate_top100_score(
  integer, integer, integer, integer, integer, integer, integer,
  double precision, double precision, integer, boolean
) to authenticated;

create or replace function public.refresh_top100_scores(
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
  -- Preserve real rank history before replacing this snapshot. Re-running with
  -- identical inputs changes neither candidate cardinality nor score rows.
  update public.top100_scores
  set previous_rank = current_rank
  where observed_at < p_observed_at;

  with raw_actions as (
    select dl.drop_id, dl.user_id as actor_id, 'like'::text as action_type,
      dl.created_at, 2.0::double precision as action_weight
    from public.drop_likes dl
    where dl.created_at >= p_observed_at - interval '7 days'
    union all
    select dc.drop_id, dc.author_id, 'comment', dc.created_at, 4.0
    from public.drop_comments dc
    where dc.created_at >= p_observed_at - interval '7 days'
    union all
    select r.drop_id, r.redropper_id, 'share', r.created_at, 6.0
    from public.redrops r
    where r.created_at >= p_observed_at - interval '7 days'
    union all
    select dv.drop_id, dv.viewer_id, 'view', dv.created_at, 0.1
    from public.drop_views dv
    where dv.created_at >= p_observed_at - interval '7 days'
    union all
    select s.content_id, s.user_id, 'save', s.created_at, 5.0
    from public.saves s
    where s.content_type = 'drop'
      and s.created_at >= p_observed_at - interval '7 days'
  ), organic as (
    select ra.*
    from raw_actions ra
    join public.drops d on d.id = ra.drop_id
    where ra.actor_id <> d.author_id and d.deleted_at is null
  ), identity_hours as (
    select drop_id, actor_id, action_type,
      date_bin(interval '1 hour', created_at,
        timestamptz '2000-01-01 00:00:00+00') as bucket_start,
      case when action_type = 'comment' then least(count(*), 2)::integer
           else 1 end as capped_actions
    from organic
    group by drop_id, actor_id, action_type,
      date_bin(interval '1 hour', created_at,
        timestamptz '2000-01-01 00:00:00+00')
  ), aggregates as (
    select ih.drop_id,
      count(distinct ih.actor_id)::integer as unique_engagers,
      sum(ih.capped_actions)::integer as action_count,
      coalesce(sum(ih.capped_actions) filter (
        where ih.action_type = 'like'), 0)::integer as likes,
      coalesce(sum(ih.capped_actions) filter (
        where ih.action_type = 'comment'), 0)::integer as comments,
      coalesce(sum(ih.capped_actions) filter (
        where ih.action_type = 'share'), 0)::integer as shares,
      coalesce(sum(ih.capped_actions) filter (
        where ih.action_type = 'save'), 0)::integer as saves,
      coalesce(sum(ih.capped_actions) filter (
        where ih.action_type = 'view'), 0)::integer as views,
      count(distinct ih.actor_id) filter (
        where engager.created_at >= p_observed_at - interval '24 hours')::integer
        as new_engagers
    from identity_hours ih
    join public.profiles engager on engager.id = ih.actor_id
    group by ih.drop_id
  ), reports as (
    select target_id as drop_id, count(*)::integer as report_count
    from public.reports
    where target_type = 'drop' and status in ('pending', 'reviewing', 'actioned')
    group by target_id
  ), candidate_ids as (
    -- Broad organic performers plus the published Phase 2 Trending candidates.
    -- UNION deduplicates the stable underlying Drop identity.
    select drop_id from aggregates
    union
    select drop_id from public.trending_scores
    where trend_score > 0
      and observed_at >= p_observed_at - interval '2 hours'
  ), candidate_data as (
    select d.id as drop_id, d.author_id,
      greatest(extract(epoch from (p_observed_at - d.created_at)) / 3600.0, 0)
        as age_hours,
      coalesce(a.likes, 0) as likes,
      coalesce(a.comments, 0) as comments,
      coalesce(a.shares, 0) as shares,
      coalesce(a.saves, 0) as saves,
      coalesce(a.views, 0) as views,
      coalesce(a.unique_engagers, 0) as unique_engagers,
      coalesce(a.action_count, 0) as action_count,
      coalesce(ts.trend_score, 0) as trend_score,
      coalesce(r.report_count, 0) as report_count,
      ((coalesce(a.action_count, 0) >= 50 and coalesce(a.unique_engagers, 0) <= 3)
        or (coalesce(a.unique_engagers, 0) >= 5
          and coalesce(a.new_engagers, 0)::double precision
            / greatest(a.unique_engagers, 1) >= 0.80)) as suspicious
    from candidate_ids candidate
    join public.drops d on d.id = candidate.drop_id
    left join aggregates a on a.drop_id = d.id
    left join public.trending_scores ts on ts.drop_id = d.id
    left join reports r on r.drop_id = d.id
    where d.deleted_at is null
      and not internal.is_posting_blocked(d.author_id)
  ), scored as (
    select data.*, components.*
    from candidate_data data
    cross join lateral public.calculate_top100_score(
      data.likes, data.comments, data.shares, data.saves, data.views,
      data.unique_engagers, data.action_count, data.age_hours,
      data.trend_score, data.report_count, data.suspicious
    ) components
  )
  insert into public.top100_scores (
    drop_id, creator_id, top100_score, organic_score, trend_bonus,
    unique_engagers_7d, likes_7d, comments_7d, shares_7d, saves_7d,
    qualified_views_7d, first_entered_at, observed_at, updated_at
  )
  select drop_id, author_id, top100_score, organic_score, trend_bonus,
    unique_engagers, likes, comments, shares, saves, views,
    p_observed_at, p_observed_at, clock_timestamp()
  from scored
  where top100_score > 0
  on conflict (drop_id) do update set
    creator_id = excluded.creator_id,
    top100_score = excluded.top100_score,
    organic_score = excluded.organic_score,
    trend_bonus = excluded.trend_bonus,
    unique_engagers_7d = excluded.unique_engagers_7d,
    likes_7d = excluded.likes_7d,
    comments_7d = excluded.comments_7d,
    shares_7d = excluded.shares_7d,
    saves_7d = excluded.saves_7d,
    qualified_views_7d = excluded.qualified_views_7d,
    observed_at = excluded.observed_at,
    updated_at = excluded.updated_at;
  get diagnostics v_rows = row_count;

  with ranked as (
    select drop_id, row_number() over (
      order by top100_score desc, organic_score desc, observed_at desc, drop_id desc
    )::integer as rank
    from public.top100_scores
    where observed_at = p_observed_at
  )
  update public.top100_scores score
  set current_rank = ranked.rank
  from ranked
  where score.drop_id = ranked.drop_id;

  return v_rows;
end;
$$;

revoke all on function public.refresh_top100_scores(timestamptz) from public;
revoke all on function public.refresh_top100_scores(timestamptz)
  from authenticated, anon;

create or replace function public.get_top100_candidates(p_limit integer default 100)
returns table (
  row_data jsonb,
  rank integer,
  previous_rank integer,
  first_entered_at timestamptz,
  observed_at timestamptz
)
language sql
stable
as $$
  select to_jsonb(hf.*), score.current_rank, score.previous_rank,
    score.first_entered_at, score.observed_at
  from public.top100_scores score
  join public.drops d on d.id = score.drop_id and d.deleted_at is null
  join public.home_feed hf
    on hf.id = score.drop_id and hf.content_type = 'drop' and hf.redrop_id is null
  where score.top100_score > 0
    and score.observed_at >= now() - interval '2 hours'
    and not exists (
      select 1 from public.feed_signals fs
      where fs.user_id = auth.uid() and fs.signal_type in ('hide', 'not_interested')
        and fs.target_id = score.drop_id
    )
    and not internal.is_posting_blocked(score.creator_id)
  -- current_rank was computed with the full private tie-break tuple during
  -- refresh; the read path needs only safe rank metadata.
  order by score.current_rank asc, score.observed_at desc, score.drop_id desc
  limit least(greatest(coalesce(p_limit, 100), 1), 100);
$$;

revoke all on function public.get_top100_candidates(integer) from public;
grant execute on function public.get_top100_candidates(integer) to authenticated;

-- The Wynos Score ranking function (WYNOS Unified Home Feed Algorithm
-- V1.0) -- backend-computed per the Product spec's explicit "Client ->
-- Request Feed / Backend -> Retrieve Candidates / Backend -> Calculate
-- Ranking Score / Backend -> Return Ranked Feed" flow, replacing
-- WYN-018's client-side rankingScore()/fetchRankedFeed() sort for
-- Home's "สำหรับคุณ" tab specifically. WYN-018's rankingScore() itself
-- (still used by DropFeedScreen's own "For You" tab), and
-- Trending and content-ranked Top100 now consume their separate precomputed
-- contracts above; neither changes Home's seven-source allocation.
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
-- ============================================================
-- WYNOS Home Feed Quality & Risk V1 (Phase 6)
-- ============================================================

-- Precomputed and intentionally private. Missing rows mean "unknown", not bad:
-- the Home RPC uses a neutral factor so fresh/New Creator content stays viable.
create table if not exists public.feed_content_quality (
  drop_id uuid primary key references public.drops(id) on delete cascade,
  quality_score double precision not null check (quality_score between 0 and 1),
  spam_risk double precision not null check (spam_risk between 0 and 1),
  sample_size integer not null default 0 check (sample_size >= 0),
  computed_at timestamptz not null,
  quality_version integer not null default 1
);
create index if not exists feed_content_quality_rank_idx
  on public.feed_content_quality (quality_score desc, computed_at desc, drop_id);
create index if not exists feed_signals_quality_window_idx
  on public.feed_signals (created_at, target_id, user_id)
  where target_type='drop'
    and signal_type in ('hide','not_interested','fast_skip');
create index if not exists reports_quality_window_idx
  on public.reports (created_at, target_id, reporter_id)
  where target_type='drop' and status in ('pending','reviewing','actioned');
alter table public.feed_content_quality enable row level security;
revoke all on public.feed_content_quality from authenticated, anon;

-- One batched, non-API-exposed bridge lets the invoker-mode Home RPC join safe
-- factors without granting clients table access. The `internal` schema is not
-- exposed by PostgREST; risk/sample/report internals never leave this layer.
create or replace function internal.content_quality_factors(p_ids uuid[])
returns table(drop_id uuid, quality_score double precision)
language sql stable security definer set search_path=public as $$
  select q.drop_id, q.quality_score
  from public.feed_content_quality q
  where q.drop_id=any(p_ids) and q.computed_at >= now()-interval '24 hours';
$$;
revoke all on function internal.content_quality_factors(uuid[]) from public;
grant execute on function internal.content_quality_factors(uuid[]) to authenticated;

-- Rates use a 20-observation prior: one hide/skip cannot create an extreme
-- result, while repeated independent negative outcomes converge quickly. Raw
-- popularity is absent; positive quality is unique reach plus action mix.
create or replace function public.calculate_feed_quality_score(
  p_unique_engagers integer,
  p_actions integer,
  p_shares integer,
  p_saves integer,
  p_hides integer,
  p_fast_skips integer,
  p_reports integer,
  p_spam_risk double precision
)
returns double precision language sql immutable parallel safe as $$
  select greatest(0.0, least(1.0,
    0.65
    + least(0.20, ln(1 + greatest(p_unique_engagers, 0)) / ln(101.0) * 0.20)
    + least(0.15, (greatest(p_shares, 0) * 2.0 + greatest(p_saves, 0))
        / greatest(p_actions + 20, 20) * 0.40)
    - greatest(p_hides, 0)::double precision
        / greatest(p_actions + p_hides + p_fast_skips + 20, 20) * 1.8
    - greatest(p_fast_skips, 0)::double precision
        / greatest(p_actions + p_hides + p_fast_skips + 20, 20) * 1.0
    - least(0.80, greatest(p_reports, 0) * 0.25)
    - least(0.70, greatest(p_spam_risk, 0.0) * 0.70)
  ));
$$;

revoke all on function public.calculate_feed_quality_score(
  integer, integer, integer, integer, integer, integer, integer,
  double precision) from public, anon;
grant execute on function public.calculate_feed_quality_score(
  integer, integer, integer, integer, integer, integer, integer,
  double precision) to authenticated;

-- Idempotent, background-compatible refresh over seven bounded days. It reuses
-- Phase 2/3's identity-capped organic aggregates/manipulation signal and only
-- batches existing negative events; Home requests never scan event history.
create or replace function public.refresh_feed_content_quality(
  p_computed_at timestamptz default clock_timestamp()
)
returns integer language plpgsql security definer set search_path = public as $$
declare v_rows integer;
begin
  with recent_drops as (
    select d.id, d.author_id, d.caption, d.created_at,
      count(*) over (partition by d.author_id) as creator_posts_7d,
      count(*) over (
        partition by d.author_id,
        regexp_replace(lower(trim(coalesce(d.caption,''))), '[^[:alnum:]#]+', '', 'g')
      ) as duplicate_posts_7d
    from public.drops d
    where d.deleted_at is null
      and d.created_at >= p_computed_at - interval '7 days'
      and not internal.is_posting_blocked(d.author_id)
  ), negatives as (
    select fs.target_id as drop_id,
      count(distinct fs.user_id) filter (where fs.signal_type in ('hide','not_interested'))::int as hides,
      count(distinct fs.user_id) filter (where fs.signal_type='fast_skip')::int as fast_skips
    from public.feed_signals fs
    where fs.target_type='drop'
      and fs.created_at >= p_computed_at - interval '7 days'
    group by fs.target_id
  ), report_counts as (
    select target_id as drop_id, count(distinct reporter_id)::int as reports
    from public.reports
    where target_type='drop' and status in ('pending','reviewing','actioned')
      and created_at >= p_computed_at - interval '7 days'
    group by target_id
  ), metrics as (
    select d.*,
      coalesce(q.unique_engagers_7d,t.unique_engagers_1h,0)::int
        as unique_engagers,
      coalesce(q.likes_7d+q.comments_7d+q.shares_7d+q.saves_7d
        +q.qualified_views_7d, t.likes_1h+t.comments_1h+t.shares_1h
        +t.saves_1h+t.qualified_views_1h, 0)::int as actions,
      coalesce(q.shares_7d,t.shares_1h,0)::int as shares,
      coalesce(q.saves_7d,t.saves_1h,0)::int as saves,
      coalesce(n.hides,0)::int as hides,
      coalesce(n.fast_skips,0)::int as fast_skips,
      coalesce(r.reports,0)::int as reports,
      least(1.0,
        case when d.creator_posts_7d > 30 then 0.35 else 0 end
        + case when trim(coalesce(d.caption,'')) <> ''
            and d.duplicate_posts_7d > 3 then 0.35 else 0 end
        + case when coalesce(t.manipulation_penalty,1) < 0.5 then 0.50 else 0 end
        + case when coalesce(d.caption,'') ~* '(like if|comment (yes|done)|share this with)'
            then 0.15 else 0 end) as spam_risk
    from recent_drops d
    left join public.trending_scores t on t.drop_id=d.id
    left join public.top100_scores q on q.drop_id=d.id
    left join negatives n on n.drop_id=d.id
    left join report_counts r on r.drop_id=d.id
  )
  insert into public.feed_content_quality(
    drop_id,quality_score,spam_risk,sample_size,computed_at,quality_version)
  select id, public.calculate_feed_quality_score(unique_engagers,actions,shares,
      saves,hides,fast_skips,reports,spam_risk), spam_risk,
    actions+hides+fast_skips+reports, p_computed_at, 1
  from metrics
  on conflict(drop_id) do update set
    quality_score=excluded.quality_score, spam_risk=excluded.spam_risk,
    sample_size=excluded.sample_size, computed_at=excluded.computed_at,
    quality_version=excluded.quality_version;
  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;
revoke all on function public.refresh_feed_content_quality(timestamptz)
  from public, authenticated, anon;

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
        and fs.signal_type in ('hide', 'not_interested')
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
      - 'top100_quality_bonus' - 'maturity_state' - 'home_quality_score')
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
            + base_ranked.content_type_affinity * 2)
          - (1 - base_ranked.home_quality_score) * 8,
        'recommended', base_ranked.nonpersonal_score
          + base_ranked.top100_quality_bonus
          + (case when base_ranked.age_hours <= 24 then 5 else 0 end)
          + base_ranked.personalization_confidence * (
            base_ranked.base_score - base_ranked.nonpersonal_score
            + base_ranked.affinity_raw * 20)
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

-- ============================================================
-- WYN-071: WYNOS Visual Refresh -- Profile Recommendation Section
-- ============================================================
-- See .wyn/docs/design/wyn-064-wynos-visual-refresh.md, Screen 5.
-- Dismissing a suggested account (the "X" on a recommendation card)
-- must stick permanently and everywhere the account might be
-- suggested again -- not just hide the card client-side for the
-- current session -- so this is a real table, not local state.
create table if not exists public.profile_recommendation_dismissals (
  user_id uuid not null references public.profiles (id) on delete cascade,
  dismissed_profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, dismissed_profile_id),
  constraint profile_recommendation_dismissals_no_self check (user_id <> dismissed_profile_id)
);

alter table public.profile_recommendation_dismissals enable row level security;

-- Same shape as `mutes`' RLS (WYN-028) -- a user only ever sees/creates
-- their own dismissal rows, no RPC needed for the write path since a
-- plain insert already satisfies the client's needs.
create policy "Users can view dismissals they created"
  on public.profile_recommendation_dismissals
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can dismiss recommendations as themselves"
  on public.profile_recommendation_dismissals
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- suggested_users() (WYN-040) reused as-is for the Recommendation
-- Section's source list (see Design doc Screen 5 -- true
-- "similar to the profile being viewed" personalization is deferred,
-- not scoped into this round) -- extended here with one more
-- exclusion so a dismissed account never resurfaces. Signature
-- unchanged, so Discovery's existing call site (DiscoveryRepository.
-- fetchSuggestedUsers) picks this up automatically with no code change
-- there -- dismissing from Profile also cleans up Discovery's list and
-- vice versa, which is the correct behavior (it's the same "suggested
-- to you" concept in both places).
create or replace function public.suggested_users(p_limit int default 10)
returns table(profile_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select p.id as profile_id
  from public.profiles p
  where p.id <> auth.uid()
    and not internal.is_blocked_either_way(auth.uid(), p.id)
    and not exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.following_id = p.id
    )
    and not exists (
      select 1 from public.mutes m
      where m.muter_id = auth.uid() and m.muted_id = p.id
    )
    and not exists (
      select 1 from public.profile_recommendation_dismissals d
      where d.user_id = auth.uid() and d.dismissed_profile_id = p.id
    )
  order by (
    select count(*) from public.follows fc where fc.following_id = p.id
  ) desc
  limit p_limit;
$$;

grant execute on function public.suggested_users(int) to authenticated;

-- ============================================================
-- WYN-071: WYNOS Visual Refresh -- Multi-image Drop (1-9 photos)
-- ============================================================
-- See .wyn/docs/design/wyn-064-wynos-visual-refresh.md, Screens 2-4.
-- `drops.image_url` is kept exactly as-is (still the first/primary
-- image, still what home_feed/get_wynos_ranked_feed/saved_feed/the
-- admin web app/every existing consumer reads) -- this table is a
-- purely additive companion holding the *full* ordered image list,
-- read only by the app's new multi-image UI (full-screen viewer,
-- image-count badge). Every image of every Drop gets a row here,
-- including position 0 (the same URL as drops.image_url) -- keeping
-- drop_images the single source of truth for "how many images/what
-- order" rather than having position 0 live in one place and 1-8
-- elsewhere.
create table if not exists public.drop_images (
  id uuid primary key default gen_random_uuid(),
  drop_id uuid not null references public.drops (id) on delete cascade,
  image_url text not null,
  position int not null,
  unique (drop_id, position),
  -- WYN-103 (Wynos V1.0.0 Beta2, item 15, 2026-09-02) defense-in-depth:
  -- CreateDropScreen's `_maxImages = 9` already blocks this at the UI,
  -- but nothing enforced it at the DB before this -- a direct REST
  -- insert could otherwise add a 10th image row (position 9) to a Drop.
  -- Positions are 0-based (see the loop that assigns them in
  -- DropRepository.createDrop), so 9 positions is 0..8.
  constraint drop_images_position_max_9 check (position >= 0 and position < 9)
);

alter table public.drop_images enable row level security;

-- Deliberately re-checks visibility through `drops` itself (a plain
-- `exists` subquery, evaluated under drops' own current SELECT policy)
-- rather than duplicating its blocked-author/deleted/locked-private
-- conditions here -- this is the "want the exact same restriction"
-- case, not the self-defeat trap noted elsewhere in this file for an
-- *unrelated* condition: whatever drops' policy allows a viewer to see
-- right now is exactly what its images should be visible.
create policy "Drop images inherit their Drop's visibility"
  on public.drop_images
  for select
  to authenticated
  using (exists (select 1 from public.drops d where d.id = drop_images.drop_id));

create policy "Users can add images to their own drops"
  on public.drop_images
  for insert
  to authenticated
  with check (exists (
    select 1 from public.drops d
    where d.id = drop_images.drop_id and d.author_id = auth.uid()
  ));

-- Backfill: every existing Drop with an image gets exactly one
-- drop_images row (position 0, same URL) so drop_images(count) is
-- accurate for old data too, not just Drops created after this
-- migration. Idempotent (safe to re-run/already-applied).
insert into public.drop_images (drop_id, image_url, position)
select d.id, d.image_url, 0
from public.drops d
where d.image_url is not null
  and not exists (
    select 1 from public.drop_images di where di.drop_id = d.id
  );

-- ============================================================
-- WYN-093 (Wynos V1.0.0 Beta2, item 19): Dynamic-height feed images
-- ============================================================
-- See .wyn/docs/design/wyn-093-dynamic-height-images.md. Nullable on
-- both tables -- CreateDropScreen/DropRepository.createDrop() writes
-- the real pixel dimensions (already known in memory before upload, no
-- extra decode round-trip) for every newly-created Drop, but every
-- Drop created before this migration has no way to backfill this
-- cheaply (would need re-downloading and decoding every image in
-- storage) -- HomeDropCard's client-side aspect-ratio clamp falls back
-- to the old fixed 1:1 square whenever these are null, same
-- "known gap, acceptable for old data" posture WYN-071's own
-- drop_images backfill note took for a different column. `drops`
-- carries the *primary* image's dimensions (what home_feed/
-- get_wynos_ranked_feed/HomeFeedItem actually read); `drop_images`
-- carries per-image dimensions for every position, kept in sync at
-- insert time for forward-compat with the still-unbuilt multi-image
-- viewer (WYN-092) -- not read by any consumer yet.
alter table public.drops add column if not exists image_width integer;
alter table public.drops add column if not exists image_height integer;
alter table public.drop_images add column if not exists image_width integer;
alter table public.drop_images add column if not exists image_height integer;

-- WYN-109: the aspect ratio the poster chose for this Drop's photos,
-- applied to all of them. NULL = posted before WYN-109, which the client
-- renders at 4:5 -- the shape those photos were already cropped to.
-- Founder-approved 2026-09-04, see .wyn/company/APPROVALS.md.
alter table public.drops add column if not exists image_aspect_ratio text;

alter table public.drops
  drop constraint if exists drops_image_aspect_ratio_valid;

alter table public.drops
  add constraint drops_image_aspect_ratio_valid
  check (
    image_aspect_ratio is null
    or image_aspect_ratio in ('original', '1:1', '4:5', '16:9')
  );

-- Deliberately NOT added to the public.home_feed / public.saved_feed
-- views below, and it must stay that way. `create or replace view` only
-- permits appending columns, production's home_feed has drifted from
-- this file (SCHEMA-004), and the attempt to append there failed with
-- 42P16 on 2026-09-04. Rather than rewrite a production view nobody can
-- see the current text of, HomeRepository reads this column off the
-- `drops` table in the feed page's existing batched Future.wait
-- (_fetchAspectRatios). Adding it to the views here would put this file
-- back out of step with the database it is supposed to describe, for a
-- column no reader needs there.

-- ============================================================
-- WYNOSHomeSpec.md 4.9's header row / 4.6's suggested-account row --
-- Verified badge
-- ============================================================
-- Scoped to exactly one account (spec: "Verified badge for the
-- official WYNOS account", not a general creator-verification
-- system) -- no client-writable path at all, admin-only via a direct
-- UPDATE against this column (no RLS insert/update policy grants it,
-- and profiles' own existing update policy -- see WYN-002/003 -- never
-- lets a user set this on themselves). Defaults false for every
-- existing and future row; nobody is flagged yet as of this
-- migration -- that's a separate, deliberate one-off UPDATE once
-- Product names the actual account.
alter table public.profiles
  add column if not exists is_verified boolean not null default false;

-- Same "append a fresh full redefinition" discipline as every prior
-- task that changed this view -- adds `author_is_verified` and
-- `redropper_is_verified` (null on the 2 branches with no redropper)
-- on top of the liked_by/top_reply columns already added above.
-- SCHEMA-002: same reason as the drop above -- this redefinition
-- inserts `author_is_verified` before `created_at` instead of
-- appending it. The only thing referencing home_feed by now is
-- get_wynos_ranked_feed(), a dollar-quoted `language sql` function,
-- for which PostgreSQL records no hard dependency -- so this drop
-- needs no CASCADE and takes nothing else with it.
drop view if exists public.home_feed;
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
  -- WYN-093: appended at the end (not interleaved with image_url
  -- above) -- CREATE OR REPLACE VIEW only allows appending new
  -- columns, never inserting them mid-list, without dropping the
  -- view first.
  d.image_width,
  d.image_height
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
  null::integer as image_height
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
  d.image_height
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

-- ============================================================
-- WYN-097: Audience Selector (Post-level privacy: ทุกคน/เพื่อน/ซ่อนเพื่อน
-- บางคน/เพื่อนที่สนิท/เฉพาะฉัน) + "เพื่อน" (mutual follow) primitive +
-- "เพื่อนที่สนิท" (Close Friends) list. Wynos V1.0.0 Beta2.pdf item 2/28.
-- See .wyn/docs/product/wyn-097-audience-friends.md for the full spec
-- this migration implements.
-- ============================================================

-- 5 values, matching the Product spec's 5 options exactly. Default
-- 'everyone' -- every existing Drop (before this migration), and every
-- Poll/text Drop that doesn't pass an explicit choice, still shows to
-- everyone exactly as today (backward compatible, no data backfill
-- needed for existing rows).
alter table public.drops
  add column if not exists audience text not null default 'everyone'
  check (audience in ('everyone', 'friends', 'friends_except', 'close_friends', 'only_me'));

-- "เพื่อน" = mutual follow (Founder decision 2026-09-02, see
-- DECISIONS.md) -- reuses the existing `follows` table, no separate
-- friend-request system. security definer, same reasoning as
-- internal.can_view_author_content (WYN-039): called from inside other
-- tables' RLS policies (drops, close_friends below) without those
-- policies' own subqueries re-triggering `follows`' own RLS.
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

-- Persistent "close friends" list -- set once, reused across every
-- Drop the owner posts with audience = 'close_friends' (mirrors
-- Instagram Close Friends -- not a per-post choice, unlike
-- drop_audience_exclusions below). A friend never sees their own
-- presence on this list -- SELECT is owner-only, deliberately (same
-- "the list itself is the owner's private business" posture Instagram
-- uses).
create table if not exists public.close_friends (
  owner_id uuid not null references public.profiles (id) on delete cascade,
  friend_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, friend_id),
  constraint close_friends_no_self check (owner_id <> friend_id)
);

alter table public.close_friends enable row level security;

create policy "Owner views their own close friends list"
  on public.close_friends
  for select
  to authenticated
  using (auth.uid() = owner_id);

-- Can only add someone who is currently a mutual follow -- re-checked
-- here (not just relied on client-side), the same "server re-validates
-- what the UI already filtered to" posture as every other insert
-- policy in this schema.
create policy "Owner adds a mutual follow as a close friend"
  on public.close_friends
  for insert
  to authenticated
  with check (auth.uid() = owner_id and internal.is_mutual_follow(owner_id, friend_id));

create policy "Owner removes a close friend"
  on public.close_friends
  for delete
  to authenticated
  using (auth.uid() = owner_id);

-- Per-post "hide from these friends" list -- only meaningful when a
-- Drop's audience = 'friends_except'. Not persisted across posts
-- (unlike close_friends above) -- a fresh choice on every Drop, per
-- Product spec's Screen 2/3 flow.
create table if not exists public.drop_audience_exclusions (
  drop_id uuid not null references public.drops (id) on delete cascade,
  excluded_user_id uuid not null references public.profiles (id) on delete cascade,
  primary key (drop_id, excluded_user_id)
);

alter table public.drop_audience_exclusions enable row level security;

create policy "Drop author manages their own audience exclusions"
  on public.drop_audience_exclusions
  for all
  to authenticated
  using (auth.uid() = (select author_id from public.drops where id = drop_id))
  with check (auth.uid() = (select author_id from public.drops where id = drop_id));

-- Single reusable predicate for all 5 audience values -- security
-- definer, same reasoning as internal.can_view_author_content, called
-- from drops' own SELECT policy below.
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
    -- 'only_me': no branch above matches for anyone but the author
    -- (already checked first), so this falls through to false.
$$;

-- The single point of enforcement -- layers on top of (not instead of)
-- the existing private-account gate (internal.can_view_author_content,
-- WYN-039). Every existing reader of `drops` (home_feed/saved_feed --
-- both security_invoker views, redrops, drop_comments, drop_polls, and
-- every direct `.from('drops')` client query) inherits this
-- automatically, with no separate change needed at any of those call
-- sites -- same "one RLS change, every entry point covered" reasoning
-- WYN-039's own comment on this policy already explains.
drop policy "Drops are viewable by authenticated users, excluding blocked, deleted, and locked-private authors" on public.drops;
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

-- get_poll_results() (WYN-035) is SECURITY DEFINER and bypasses drops'
-- RLS entirely (same reasoning as its own existing
-- is_blocked_either_way/can_view_author_content duplication, WYN-039)
-- -- needs the same audience check duplicated too, or a stranger could
-- still read a "เพื่อน"/"เฉพาะฉัน" Drop's poll results by poll_id even
-- though the Drop row itself is now correctly hidden from them.
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

-- Extends create_poll_drop (WYN-035) with the same audience choice
-- image/text Drops get (below) -- a Poll Drop is still a Drop, no
-- reason its own audience selector wouldn't apply. Defaults preserve
-- every existing call's behavior unchanged (p_audience = 'everyone',
-- p_excluded_friend_ids = '{}').
create or replace function public.create_poll_drop(
  p_caption text,
  p_options text[],
  p_duration_days int,
  p_mentioned_user_ids uuid[] default '{}',
  p_audience text default 'everyone',
  p_excluded_friend_ids uuid[] default '{}'
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

  -- Trimmed server-side (not just validated-as-trimmed) so a direct
  -- RPC call bypassing the Flutter client's own .trim() can't leave
  -- stray leading/trailing whitespace sitting in stored option text.
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

  insert into public.drops (author_id, image_url, caption, audience)
  values (v_author, null, trim(p_caption), p_audience)
  returning id into v_drop_id;

  insert into public.drop_polls (drop_id, options, expires_at)
  values (v_drop_id, v_options, now() + make_interval(days => p_duration_days));

  if p_audience = 'friends_except' then
    insert into public.drop_audience_exclusions (drop_id, excluded_user_id)
    select v_drop_id, u
    from unnest(p_excluded_friend_ids) as u;
  end if;

  -- WYN-045: this RPC is SECURITY DEFINER and bypasses drop_mentions'
  -- own RLS INSERT policy entirely -- without this same
  -- internal.mention_allowed() check the policy below also gained,
  -- Mention Permission would be fully bypassable via Poll Drop
  -- creation. Same non-error posture as the block-exclusion right
  -- next to it: the caption may still literally read "@username", it
  -- just doesn't produce a drop_mentions row (and therefore no
  -- notification) for a user who disallows it.
  insert into public.drop_mentions (drop_id, mentioned_user_id)
  select v_drop_id, m
  from unnest(p_mentioned_user_ids) as m
  where not internal.is_blocked_either_way(v_author, m)
    and internal.mention_allowed(m, v_author);

  return v_drop_id;
end;
$$;

-- "เพื่อนของฉัน" (mutual-follow list) -- the shared candidate list
-- Screen 3 (เลือกเพื่อนที่จะซ่อน) and Screen 4 (เพื่อนที่สนิท) both
-- list from. security invoker is fine here -- `profiles` itself is
-- publicly readable to authenticated users, and is_mutual_follow()
-- does its own security-definer lookup against `follows` internally
-- regardless of the caller's own RLS.
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

-- ============================================================
-- WYN-099: Likes Tab Privacy (ทุกคน/เพื่อน/เฉพาะฉัน). Wynos V1.0.0
-- Beta2.pdf item 4/28. See .wyn/docs/product/wyn-099-likes-privacy.md.
-- ============================================================

-- 3 values only (not the 5-value audience above) -- "เพื่อน" here
-- reuses the exact same mutual-follow definition via
-- internal.is_mutual_follow, but this is a narrower, account-level
-- setting (governs every Like a user has ever made, not a per-post
-- choice) -- its own column rather than reusing drops.audience or
-- InteractionPermission (WYN-045's people_i_follow != mutual friend --
-- see Product spec's Architecture Decision).
alter table public.profiles
  add column if not exists likes_visibility text not null default 'everyone'
  check (likes_visibility in ('everyone', 'friends', 'only_me'));

-- Deliberately does NOT touch drop_likes/pop_likes' own RLS (still
-- `using (true)`) -- those rows are also the sole source for
-- like_count/liked_by (top-3 avatars) shown on *every* Drop/Pop across
-- the whole app, which must stay accurate regardless of any individual
-- liker's own likes_visibility setting. See Product spec's
-- "Architecture Decision" for the full reasoning and the accepted
-- residual risk (a caller that queries drop_likes/pop_likes directly,
-- bypassing fetch_liked_drop_ids/fetch_liked_pop_ids below, still sees
-- the raw like rows -- only the two RPCs below enforce this setting).
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

-- Public wrapper so the Flutter client can ask this question directly
-- (`internal.*` functions are never exposed to PostgREST -- only
-- `public.*` ones are). ProfileLikesTab needs this to tell apart its 2
-- empty states ("no Likes yet" vs. "not allowed to see this tab" --
-- fetch_liked_drop_ids alone returns an empty list either way, which
-- isn't enough to pick the right copy).
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

-- Ordered drop_id list for ProfileLikesTab's Drop side --
-- DropRepository.fetchLikedByAuthor calls this first, then does a
-- normal `.from('drops').select($_dropSelect).inFilter('id', ids)` for
-- the rich card shape, which also re-applies drops' own RLS a second
-- time for free (defense in depth). This RPC's own join against
-- `drops` below (security definer, bypasses that RLS) is what actually
-- has to duplicate the is_blocked_either_way/can_view_author_content/
-- can_view_drop_audience checks, same reasoning as get_poll_results()
-- above -- and is exactly Product spec's Edge Case 3: a friend liking
-- someone else's "เฉพาะฉัน" Drop must never leak that Drop into a
-- friend's-eye view of the Likes tab.
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

-- Same shape for Pop -- Pop itself is hidden app-wide per WYN-102, but
-- the underlying table/RLS/RPC still exist, so this stays a direct
-- parallel to fetch_liked_drop_ids rather than a half-finished feature.
-- Pop has no audience concept (WYN-097 explicitly out of scope for
-- Pop), so no can_view_drop_audience-equivalent check is needed here.
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

-- home_feed: append `audience` (WYN-097 Screen 6 -- hides the ReDrop
-- button client-side when a Drop's audience != 'everyone'). Same
-- "append a fresh full redefinition" discipline as every prior task
-- that changed this view (see the comment on the previous
-- redefinition above). Pop has no audience concept, so its branch
-- carries a literal 'everyone' (it never had a ReDrop-equivalent
-- button to hide anyway). The redrop branch carries the *original*
-- Drop's own audience (d.audience) -- a ReDrop of a non-'everyone'
-- Drop is only reachable at all by someone who could already see the
-- original per the RLS above, and Screen 6 hides that ReDrop's own
-- further-ReDrop button the same way its source Drop's button is
-- hidden.
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
  d.audience
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
  'everyone'::text as audience
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
  d.audience
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

-- ============================================================
-- WYN-098: Location Check-in (LocationIQ). Wynos V1.0.0 Beta2.pdf
-- item 3/28. See .wyn/docs/product/wyn-098-location-checkin.md for
-- the full spec this migration implements.
-- ============================================================

-- `drops.location` (free text, display name) already exists since
-- WYN-019 -- reused as-is per Product spec ("อนาคต" that column was
-- prepared for has arrived). These 3 are new: metadata for referring
-- back to the LocationIQ result and the real coordinates, kept purely
-- server-side/non-displayed per Product spec's Privacy section (the
-- app only ever shows `location`, the human-readable name -- never
-- these lat/lon/place_id values directly to a user).
alter table public.drops add column if not exists location_lat double precision;
alter table public.drops add column if not exists location_lon double precision;
alter table public.drops add column if not exists location_place_id text;

-- lat/lon must be null together or set together (never just one) --
-- and a place_id always implies a name is present too (no ID-only
-- rows with nothing to display). Deliberately does NOT require the
-- reverse (a `location` name with no lat/lon/place_id) -- Product spec
-- leaves room for a future free-text-only entry path that never goes
-- through LocationIQ at all.
-- drop-then-add (not `add constraint if not exists`, which plain
-- PostgreSQL doesn't support -- only `drop constraint if exists` is a
-- thing) so this migration is safe to re-run.
alter table public.drops drop constraint if exists drops_location_lat_lon_together;
alter table public.drops
  add constraint drops_location_lat_lon_together
  check ((location_lat is null) = (location_lon is null));

alter table public.drops drop constraint if exists drops_location_place_id_needs_name;
alter table public.drops
  add constraint drops_location_place_id_needs_name
  check (location_place_id is null or location is not null);

-- No RLS changes needed on `drops` itself -- location/location_lat/
-- location_lon/location_place_id are just 3 more columns on a row
-- already governed by drops' own SELECT policy (WYN-039/WYN-097's
-- can_view_author_content/can_view_drop_audience) -- a Drop's
-- check-in inherits that same audience automatically, with no
-- separate policy to keep in sync (see Product spec's Privacy
-- section, and its explicit "this is why reuse a column on `drops`
-- instead of a new table" reasoning).

-- Server-side-only rate-limit log for the `location-search` Edge
-- Function (WYN-098's own LOCATIONIQ_API_KEY quota is shared across
-- every WYN user, so a single user hammering search-as-you-type could
-- exhaust the whole app's daily quota without this) -- one row per
-- *actual* LocationIQ call (not every Edge Function invocation; a
-- request rejected for being over-limit is never logged, so a sustained
-- flood doesn't inflate the very count that would eventually let it
-- back in). Mirrors drop_views' "count rows in a recent window before
-- allowing another" shape (WYN-038/WYN-083), but this table serves the
-- exact opposite direction (reject once over a cap, not just skip a
-- duplicate). RLS enabled with **zero policies** -- deliberately
-- inaccessible to every client role; only the Edge Function's
-- service-role key (which bypasses RLS entirely) ever touches it. Same
-- "audit/internal-only, no policy grants at all" posture as this
-- schema's moderation audit tables.
create table if not exists public.location_search_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  requested_at timestamptz not null default now()
);

alter table public.location_search_requests enable row level security;

create index if not exists location_search_requests_user_id_requested_at_idx
  on public.location_search_requests (user_id, requested_at desc);

-- Extends create_poll_drop (WYN-035) with the same location check-in
-- fields image/text Drops get (via _insertDrop, DropRepository) --
-- the location toolbar button in CreateDropScreen is already reachable
-- in both image and poll compose modes (never gated by _mode, unlike
-- the photo/camera buttons), so a Poll Drop needs the same 4 fields.
-- Defaults preserve every existing call's behavior unchanged.
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

  -- Trimmed server-side (not just validated-as-trimmed) so a direct
  -- RPC call bypassing the Flutter client's own .trim() can't leave
  -- stray leading/trailing whitespace sitting in stored option text.
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

  -- WYN-045: this RPC is SECURITY DEFINER and bypasses drop_mentions'
  -- own RLS INSERT policy entirely -- without this same
  -- internal.mention_allowed() check the policy below also gained,
  -- Mention Permission would be fully bypassable via Poll Drop
  -- creation. Same non-error posture as the block-exclusion right
  -- next to it: the caption may still literally read "@username", it
  -- just doesn't produce a drop_mentions row (and therefore no
  -- notification) for a user who disallows it.
  insert into public.drop_mentions (drop_id, mentioned_user_id)
  select v_drop_id, m
  from unnest(p_mentioned_user_ids) as m
  where not internal.is_blocked_either_way(v_author, m)
    and internal.mention_allowed(m, v_author);

  return v_drop_id;
end;
$$;

-- home_feed: append `location` (Design spec Screen 4 -- shown on
-- HomeDropCard/DropDetailScreen, " · 📍 {location}" after the
-- relative-time text, only when set). Same "append a fresh full
-- redefinition" discipline as every prior task that changed this
-- view. Pop has no location/check-in concept (out of scope), so its
-- branch carries a literal null. The redrop branch carries the
-- *original* Drop's own location (d.location).
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
  d.location
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
  null::text as location
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
  d.location
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

-- Merge-reconciliation note (2026-09-02): WYN-092 (Home feed multi-image
-- peek carousel) and WYN-097/098/099 (audience selector + location
-- check-in) were developed in parallel worktrees and each independently
-- appended their own full redefinition of this view on the same prior
-- base -- WYN-092's redefinition (image_count only) and WYN-098's
-- redefinition (audience+location, immediately above) would have
-- silently dropped each other's column if merged naively (last
-- `create or replace view` wins). This redefinition is the
-- reconciliation: identical to the redefinition immediately above, plus
-- `image_count` (WYN-092, Wynos V1.0.0 Beta2 Phase 2, item 14) as the
-- very last column of every branch -- a scalar subquery counting
-- `drop_images` rows the same way like_count/comment_count/redrop_count
-- above already count their own tables. Deliberately just a count, not
-- the image URLs themselves (those stay fetched on demand via
-- DropRepository.fetchDropImages, same as DropImageGallery already does
-- for DropDetailScreen). The `pop` branch has no multi-image concept, so
-- it gets a typed null, same pattern as every other drop-only column on
-- that branch (redrop_count, poll_id, ...).
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

-- ===========================================================================
-- WYNOS First Login / Account Onboarding -- multi-step onboarding state
-- (Birthday, Username, Display Name, WYNOS Password, Optional Profile).
-- Extends WYN-002 (Authentication & Onboarding)/WYN-003 (User Profile),
-- which already own `profiles.username`/`display_name`/`bio`/`avatar_url`
-- -- this section only adds what's missing: a birthday (privacy-sensitive,
-- so it lives in its own table with owner-only RLS, never the
-- "viewable by any authenticated user" policy `profiles` itself has), and
-- an explicit onboarding-completion flag AuthGate can check in one read
-- instead of inferring "done" from `username is not null` the way WYN-002
-- originally did.
-- ===========================================================================

-- A separate table, not new columns on `profiles`, specifically so
-- `date_of_birth` is never covered by "Profiles are viewable by
-- authenticated users" (see that policy above) -- PostgREST/Supabase RLS
-- is row-level, not column-level, so the only reliable way to keep one
-- column private while the rest of a row stays public is to not store it
-- in that row at all. Any authenticated user can still discover *that* a
-- profile_private row exists (not useful on its own -- every fully
-- onboarded account has one), but never its `date_of_birth` value, which
-- is the actual privacy requirement.
create table if not exists public.profile_private (
  id uuid primary key references public.profiles (id) on delete cascade,
  date_of_birth date,
  -- Whether this account already has a password credential set on its
  -- Supabase Auth user (via the onboarding Password step, or -- checked
  -- client-side instead of stored here -- by having signed up with
  -- email+password directly, see AuthRepository.fetchOnboardingState).
  -- Lets a returning user resume onboarding without being asked to set a
  -- password twice.
  password_set boolean not null default false,
  onboarding_completed boolean not null default false,
  onboarding_completed_at timestamptz
);

alter table public.profile_private enable row level security;

-- `drop policy if exists` first on every policy/constraint below (not
-- just `create table if not exists` on the table itself) -- this whole
-- block must be safely re-runnable from scratch. A production run hit
-- `profiles_username_not_reserved` failing on a pre-existing row (see
-- that constraint's own comment) partway through the original version of
-- this script; Supabase's SQL Editor does not guarantee the earlier
-- statements in a multi-statement paste rolled back together with that
-- failure, so simply re-pasting a non-idempotent script could then hit
-- "policy/constraint already exists" on whatever *did* commit before the
-- failure. Every statement here is now safe to run any number of times.
drop policy if exists "Users can view their own private profile fields" on public.profile_private;
create policy "Users can view their own private profile fields"
  on public.profile_private
  for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "Users can insert their own private profile fields" on public.profile_private;
create policy "Users can insert their own private profile fields"
  on public.profile_private
  for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "Users can update their own private profile fields" on public.profile_private;
create policy "Users can update their own private profile fields"
  on public.profile_private
  for update
  to authenticated
  using (auth.uid() = id);

alter table public.profile_private
  drop constraint if exists profile_private_date_of_birth_not_future;
alter table public.profile_private
  add constraint profile_private_date_of_birth_not_future
  check (date_of_birth is null or date_of_birth <= current_date);

-- Minimum age 13 (Founder, industry-standard minimum for a social
-- platform -- see .wyn/company/DECISIONS.md). Revisit here (and in
-- BirthdayStep's client-side copy of this same rule) if that policy ever
-- changes.
alter table public.profile_private
  drop constraint if exists profile_private_date_of_birth_min_age;
alter table public.profile_private
  add constraint profile_private_date_of_birth_min_age
  check (date_of_birth is null or date_of_birth <= (current_date - interval '13 years'));

-- Defense in depth alongside AuthRepository's own reservedUsernames set
-- (lib/features/auth/data/auth_repository.dart) -- keep both lists in
-- sync. A client-side check alone would not stop a direct REST call.
--
-- `not valid`: a plain `add constraint` validates every *existing* row
-- immediately, which fails outright if even one pre-existing account
-- already has a reserved-looking username (a seed/test account predating
-- this rule, for example) -- exactly what happened against production.
-- `not valid` grandfathers whatever is already there and enforces the
-- rule only on every INSERT/UPDATE from this point forward, which is the
-- actual goal here (stop *new* reserved-username signups) without either
-- silently renaming/deleting an existing account or blocking this
-- migration on manually finding and fixing it first.
alter table public.profiles
  drop constraint if exists profiles_username_not_reserved;
alter table public.profiles
  add constraint profiles_username_not_reserved
  check (
    username is null or lower(username) not in (
      'admin', 'administrator', 'support', 'help', 'wynos', 'wyn',
      'official', 'root', 'api', 'moderator', 'staff', 'security', 'system',
      'null', 'undefined', 'everyone', 'here', 'channel', 'settings',
      'about', 'terms', 'privacy', 'www', 'app'
    )
  ) not valid;

-- Backfill: every account that already finished the old (WYN-002)
-- onboarding -- i.e. has a username -- must not be asked to onboard again
-- just because this new `onboarding_completed` flag didn't exist yet when
-- they signed up. Existing users are never sent through Birthday/Display
-- Name/Password/Profile Optional retroactively.
insert into public.profile_private (id, onboarding_completed, onboarding_completed_at)
select id, true, created_at
from public.profiles
where username is not null
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Beta2 audit (2026-09-03) — indexes for the feed, social-graph and
-- Club queries the app actually runs.
--
-- Purely additive: no table, column, policy, or constraint is touched,
-- and no query changes behaviour -- only how Postgres finds the rows.
-- Safe to run at any time, and safe to re-run. Identical copy kept at
-- supabase/migrations_beta2_indexes.sql for applying on its own.
--
-- Every index below was checked against a real call site before being
-- included, and each one is listed with the query it serves. Composite
-- primary keys are the recurring reason these are needed: a PK on
-- (a, b) cannot serve a lookup by `b` alone, and several of these
-- queries read in exactly that direction.
--
-- Two indexes proposed in the first draft of the audit were REMOVED
-- after that re-check, because they would have helped nothing:
--   * blocks (blocked_id) -- internal.is_blocked_either_way() checks
--     `(blocker_id = a and blocked_id = b) or (blocker_id = b and
--     blocked_id = a)`; both branches pin the leading PK column, so the
--     PK already serves them. Every other blocks query does too.
--   * mutes (muted_id) -- every mute check in the schema and in Dart is
--     `muter_id = auth.uid() and muted_id = ?`, again leading-column.
-- (Both columns are un-indexed foreign keys, so an account deletion
-- cascade scans them -- but that is true of many FK columns here, is
-- rare, and is not what these indexes were claimed to fix.)
--
-- The counterpart work -- denormalised like/comment counters so
-- `public.home_feed` stops running eight correlated subqueries per row
-- -- is deliberately NOT here: that changes the schema's shape and needs
-- Founder approval plus a backfill. See
-- .wyn/docs/qa/wynos-v1.0.0-beta2-full-audit.md §5.5.
--
-- NOTE for whoever applies this: on a table with substantial existing
-- data, `create index concurrently` avoids holding a write lock -- it
-- cannot run inside a transaction block, so it has to be run statement
-- by statement rather than as part of this file. At Beta2's data volume
-- the plain form below is fine.

-- 1. The Home feed's own ordering: `order by created_at desc` on
--    home_feed, every tab, every page.
create index if not exists drops_created_at_idx
  on public.drops (created_at desc);

-- 2. Profile's post grid and count (fetchByAuthor / countByAuthor:
--    `author_id = ? order by created_at desc`), and the Following
--    feed's `author_id in (...)`.
create index if not exists drops_author_created_idx
  on public.drops (author_id, created_at desc);

-- 3. Profile's "ถูกใจ" tab -- fetch_liked_drop_ids() runs
--    `user_id = ? order by created_at desc offset ? limit 21`. The PK
--    is (drop_id, user_id), so a user-first read could use neither the
--    filter nor the sort; this serves both.
create index if not exists drop_likes_user_idx
  on public.drop_likes (user_id, created_at desc);

-- 4. Every comment list (`drop_id = ? order by created_at`), plus the
--    comment_count and top_reply subqueries inside home_feed itself,
--    which run per feed row.
create index if not exists drop_comments_drop_created_idx
  on public.drop_comments (drop_id, created_at);

-- 5. Follower lists and follower_count() (`following_id = ? order by
--    created_at desc`), plus the suggested-users ranking's
--    `count(*) where following_id = p.id`. The PK is
--    (follower_id, following_id) -- only the "who do I follow"
--    direction.
create index if not exists follows_following_idx
  on public.follows (following_id, created_at desc);

-- 6. The incoming follow-request list and its badge count
--    (`target_id = ? order by created_at desc`), and the trigger that
--    clears requests when an account goes public. Same PK-direction
--    problem: the PK is (requester_id, target_id).
create index if not exists follow_requests_target_idx
  on public.follow_requests (target_id, created_at desc);

-- 7. content_save_count() is `count(*) from saves where content_id = ?`
--    with no user_id at all -- a full scan of saves on every call,
--    since the PK leads with user_id. Indexed on content_id alone:
--    an earlier draft used (content_type, content_id), whose leading
--    column has about three distinct values and so would not have
--    served this lookup well.
create index if not exists saves_content_idx
  on public.saves (content_id);

-- 8. A Club's post list -- `club_id = ? order by pinned desc,
--    created_at desc`. club_posts had no index of any kind beyond its
--    own id. Column order matches the query's sort exactly.
create index if not exists club_posts_club_pinned_created_idx
  on public.club_posts (club_id, pinned desc, created_at desc);

-- 9. A Club post's comment list (`club_post_id = ? order by
--    created_at`) -- the Club-side counterpart of index 4.
create index if not exists club_post_comments_post_created_idx
  on public.club_post_comments (club_post_id, created_at);

-- ---------------------------------------------------------------------
-- SCHEMA-003 (Beta2 audit, 2026-09-03) — drop the two obsolete
-- `create_poll_drop` overloads.
--
-- `create or replace function` only replaces a function with the *same
-- signature*. WYN-097 added `p_audience`/`p_excluded_friend_ids` and
-- WYN-098 added the four location parameters, so each of those grew the
-- parameter list -- and quietly created a new function each time instead
-- of replacing the old one. All three ended up coexisting, all three
-- SECURITY DEFINER, all three executable by `authenticated`.
--
-- Two consequences:
--   1. A 4-argument call is ambiguous -- `function ... is not unique` --
--      which is what fails 5 of the supabase/tests/*.sh.
--   2. The two stale overloads are reachable SECURITY DEFINER entry
--      points that skip the audience (WYN-097) and location (WYN-098)
--      handling the current one performs.
--
-- The app is unaffected either way: DropRepository.createPollDrop is the
-- only call site in the repository and passes all ten named parameters,
-- which matches the surviving overload exactly (verified before this
-- change). Dropping the other two therefore removes dead code, not a
-- code path anything uses.
--
-- Placed at the end of the file rather than edited in place so this
-- file's history stays intact and a fresh load ends with exactly one
-- create_poll_drop. Signatures are spelled out in full because that is
-- what identifies a function to `drop function` -- and `if exists` keeps
-- the statement safe to re-run.
drop function if exists public.create_poll_drop(text, text[], int, uuid[]);
drop function if exists public.create_poll_drop(text, text[], int, uuid[], text, uuid[]);

-- ---------------------------------------------------------------------
-- Discovery UX audit, 2026-09-05 -- suggested_users() was surfacing
-- incomplete-onboarding "ghost" accounts.
--
-- `setDateOfBirth` (AuthRepository, the *first* onboarding step) upserts
-- a bare `profiles` row -- id only, no username/display_name -- before
-- the Username step ever runs. A signup abandoned right there (app
-- closed, never finished) leaves that row behind forever: 0 followers,
-- same as every brand-new real account. suggested_users() had no filter
-- for it, so once real candidates ran out it filled the remaining
-- `p_limit` slots with these -- Founder's own screenshot of "แนะนำให้
-- ติดตาม": 1 real suggestion, 7 rows rendering "?" avatar / bare "@".
--
-- rising_profiles() never had this problem -- its own `p_min_followers`
-- floor (default 5) already excludes a 0-follower account, ghost or
-- not.
--
-- Fix: exclude any profile whose profile_private.onboarding_completed
-- is not true. Placed here (end of file), not edited into the original
-- `create or replace function` above -- that definition sits before
-- `profile_private` is created further down this same file, so editing
-- it in place would break a fresh load of this file top-to-bottom, the
-- same reasoning SCHEMA-003 above already established for
-- create_poll_drop. Same signature, so this replaces it; additive-only
-- (one more `and exists(...)`), nothing dropped or retyped, safe to
-- re-run.
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.
create or replace function public.suggested_users(p_limit int default 10)
returns table(profile_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select p.id as profile_id
  from public.profiles p
  where p.id <> auth.uid()
    and not internal.is_blocked_either_way(auth.uid(), p.id)
    and not exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.following_id = p.id
    )
    and not exists (
      select 1 from public.mutes m
      where m.muter_id = auth.uid() and m.muted_id = p.id
    )
    and not exists (
      select 1 from public.profile_recommendation_dismissals d
      where d.user_id = auth.uid() and d.dismissed_profile_id = p.id
    )
    and exists (
      select 1 from public.profile_private pp
      where pp.id = p.id and pp.onboarding_completed = true
    )
  order by (
    select count(*) from public.follows fc where fc.following_id = p.id
  ) desc
  limit p_limit;
$$;

grant execute on function public.suggested_users(int) to authenticated;

-- ---------------------------------------------------------------------
-- Discovery UX, 2026-09-05 -- Trending Hashtags/Top 100 made global.
--
-- Founder: "อยากได้เหมือน X" (Twitter) -- on X, trending topics are one
-- global ranking every viewer sees, not filtered by who *you* personally
-- follow or block. WYNOS's own trending_hashtags computation never had
-- that property: DiscoveryRepository.fetchTrendingHashtags read its
-- candidate Drops from HomeRepository.fetchTrending, which queries
-- public.home_feed -- a `security_invoker = true` view, so the exact
-- same RLS policy that scopes a viewer's own Home feed (blocked-either-
-- way / private-account-follow-gate / audience targeting, see "Drops
-- are viewable by authenticated users, excluding blocked, deleted,
-- locked-private authors, and out-of-audience" above) scoped the
-- trending *candidate pool* too. Two accounts with different block
-- lists or different follow graphs could legitimately see different
-- top hashtags -- correct for a personalized Home feed, wrong for
-- something the UI calls a leaderboard.
--
-- This function is the fix: SECURITY DEFINER, deliberately bypassing
-- that per-viewer RLS, computing over one explicit, viewer-independent
-- definition of "public" instead --
--   * d.audience = 'everyone' (not friends/close friends/excluded/only
--     me -- WYNOS's own 5 audience values, see the `audience` column's
--     check constraint above)
--   * author's account is not private (a private account's Drops are
--     never "public" regardless of audience, matching
--     internal.can_view_author_content's own is_private branch)
--   * author is not under an active moderation sanction
--     (internal.is_posting_blocked -- a platform-wide restriction,
--     same as fetchTrending/fetchTopContent's own
--     _fetchPostingBlockedAuthorIds exclusion, so this isn't a new
--     moderation bypass, just the one exclusion that was already
--     viewer-independent to begin with)
--   * not soft-deleted
--
-- Deliberately excludes the caller's personal block list (the one part
-- of the old scoping this does NOT replicate) -- that is the entire
-- point: whether *you* have blocked someone must never change what
-- hashtag ranks #1 for everyone else, the same way it doesn't on X.
--
-- Returns raw per-Drop signals (id/created_at/caption/like_count/
-- comment_count/redrop_count/view_count), not pre-ranked hashtags --
-- DiscoveryRepository.fetchTrendingHashtags still does the actual
-- ranking via the existing, already-tested rankTrendingHashtags()
-- (app/lib/features/search/data/discovery_ranking.dart), unchanged.
-- Keeping that scoring logic in Dart (rather than reimplementing
-- WYN-101's engagement-weighted/time-decay formula a second time in
-- SQL) is what keeps this a candidate-*source* change, not a ranking-
-- logic rewrite with its own chance to drift from the tested formula.
--
-- 48h window / 100-candidate cap match HomeRepository's own
-- _trendingWindow/trendingCandidateLimit exactly (the Dart-side
-- defaults below reuse those same numbers) -- this is a source swap,
-- not a product-behavior change to the window itself.
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.
create or replace function public.trending_hashtag_candidates(
  p_hours int default 48,
  p_limit int default 100
)
returns table(
  id uuid,
  created_at timestamptz,
  caption text,
  like_count bigint,
  comment_count bigint,
  redrop_count bigint,
  view_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    d.id,
    d.created_at,
    d.caption,
    (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
    (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
    (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
    public.drop_view_count(d.id) as view_count
  from public.drops d
  where d.deleted_at is null
    and d.audience = 'everyone'
    -- Cheap pre-filter, not a behavior change: rankTrendingHashtags
    -- (Dart) already skips any caption with zero hashtags in it, so
    -- excluding a caption that provably has no '#' at all here changes
    -- nothing about the final ranking -- it only keeps this query from
    -- scanning/returning rows that would contribute nothing anyway.
    and d.caption is not null
    and d.caption like '%#%'
    and d.created_at >= now() - (p_hours || ' hours')::interval
    and not internal.is_posting_blocked(d.author_id)
    and not exists (
      select 1 from public.profiles p
      where p.id = d.author_id and p.is_private
    )
  order by d.created_at desc
  limit p_limit;
$$;

grant execute on function public.trending_hashtag_candidates(int, int) to authenticated;

-- Founder feedback ("ส่งรูปแล้วอีกฝ่ายกดดูแล้วหาย เหมือน IG จะได้เซฟพื้นที่"):
-- while scoping that request, found that `delete_message()` (WYN-031,
-- defined earlier in this file) has never actually deleted anything
-- from `chat-media` storage -- it only ever nulled `messages.image_url`
-- (the DB reference), leaving the real file orphaned in the bucket
-- forever regardless of how many image messages got "deleted". A
-- storage bucket only ever had SELECT ("Participants can view media in
-- their conversations") and INSERT ("Participants can upload media to
-- their conversations") policies -- no DELETE policy existed at all, so
-- even a client that tried to call `.remove()` on its own uploaded path
-- would have been rejected by RLS regardless.
--
-- This is the fix: lets ChatRepository.deleteMessage() (app/lib/
-- features/chat/data/chat_repository.dart) actually call
-- `storage.from('chat-media').remove([path])` for the sender's own
-- upload. Scoped to the path's own {sender_id}-{timestamp}.ext filename
-- segment matching the caller's uid -- deliberately *not* the same
-- "look up the conversation, check auth.uid() is a participant" shape
-- the SELECT/INSERT policies above use, because the path already
-- encodes exactly one identity claim that matters here (whoever
-- uploaded a given object is the only one ever allowed to delete it,
-- full stop) -- a participant-of-the-conversation check would
-- additionally let the *other* participant delete a sender's image out
-- from under them, which is not what "the sender deleted their own
-- message" means.
--
-- Only fixes the problem going forward -- a message already deleted
-- before this policy existed has `image_url` already null in the DB,
-- so there is no path left to reconstruct which storage objects are
-- now orphaned from that history. A one-time sweep (list every
-- chat-media object, delete whichever isn't referenced by any current
-- non-deleted message) is a separate, explicit cleanup task, not
-- something this policy attempts.
create policy "Senders can delete their own chat media"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'chat-media'
    and split_part(name, '/', 2) like (auth.uid()::text || '-%')
  );

-- Founder feedback ("ส่งรูปแล้วอีกฝ่ายกดดูแล้วหาย เหมือน IG จะได้เซฟพื้นที่"):
-- View Once chat photos. A sender opts an image message into this at
-- Compose time; the recipient sees a blurred/hidden placeholder until
-- they explicitly tap to open it, at which point the client shows it
-- for a short, fixed window (5-10s) and then both nulls the DB
-- reference and deletes the underlying chat-media object -- same "the
-- content is genuinely gone, not just hidden" posture as
-- delete_message() already established for a manually-deleted message.
--
-- Two columns, both on `messages` (WYN-031's own table):
--   view_once -- set once, at send time, never changed after.
--   viewed_at -- null until the recipient's one open; the client's own
--     countdown timer decides *when* to actually clear the content
--     (mark_view_once_viewed below only records that opening happened,
--     it doesn't itself expire anything), so this is also the signal
--     the sender's own screen needs to flip its bubble from "sent,
--     waiting to be opened" to "opened" live via realtime.
alter table public.messages add column if not exists view_once boolean not null default false;
alter table public.messages add column if not exists viewed_at timestamptz;

-- A View Once photo is almost always sent with no caption -- once
-- clear_view_once_message() nulls image_url below, the original
-- messages_not_blank_unless_deleted constraint (which only exempted a
-- *deleted* message) would reject that row outright. An expired View
-- Once message is legitimately content-free on purpose, the same
-- rationale that constraint already carves out for deleted_at -- so
-- widen it rather than force this to fake a deletion (which would
-- misreport the message as deleted in the UI, not merely expired).
alter table public.messages drop constraint if exists messages_not_blank_unless_deleted;
alter table public.messages add constraint messages_not_blank_unless_deleted
  check (
    deleted_at is not null
    or text is not null
    or image_url is not null
    or shared_content_id is not null
    or (view_once and viewed_at is not null)
  );

-- The recipient's one explicit "I'm opening this now" action -- called
-- the instant they tap the placeholder, before the image itself is
-- ever fetched (a signed URL is only ever minted after this succeeds),
-- so there is no way to inspect the image's storage path without this
-- row actually flipping to "viewed" first. security definer + explicit
-- ownership checks (not a raw UPDATE RLS policy) for the same reason
-- delete_message() already uses one: this has to enforce "the caller
-- is the *other* participant, not the sender" and "exactly once,
-- ever" together, neither of which a column-level RLS policy expresses
-- on its own.
create or replace function public.mark_view_once_viewed(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.messages m
  set viewed_at = now()
  from public.conversations c
  where m.id = p_message_id
    and m.conversation_id = c.id
    and m.view_once
    and m.viewed_at is null
    and m.deleted_at is null
    and m.sender_id != auth.uid()
    and auth.uid() in (c.user_a_id, c.user_b_id);

  if not found then
    raise exception 'Message not found, not View Once, already viewed, or not yours to view';
  end if;
end;
$$;

grant execute on function public.mark_view_once_viewed(uuid) to authenticated;

-- The client's own countdown timer (not this function) decides when a
-- viewed View Once photo's content is actually cleared -- this just
-- performs that clearing once told to, mirroring delete_message()'s
-- "null the reference, not just flag a column" shape. Callable by
-- *either* participant (not sender-only like delete_message()) since
-- it's the recipient's own countdown that normally triggers this, but
-- deliberately guarded on `viewed_at is not null` regardless of caller
-- -- nobody, sender included, can use this to clear a photo that
-- hasn't actually been opened yet.
create or replace function public.clear_view_once_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.messages m
  set image_url = null
  from public.conversations c
  where m.id = p_message_id
    and m.conversation_id = c.id
    and m.view_once
    and m.viewed_at is not null
    and auth.uid() in (c.user_a_id, c.user_b_id);

  if not found then
    raise exception 'Message not found, not View Once, not yet viewed, or not yours to clear';
  end if;
end;
$$;

grant execute on function public.clear_view_once_message(uuid) to authenticated;

-- Lets ChatRepository.expireViewOnceMessage() actually free the storage
-- object once clear_view_once_message() above has run (same "an
-- explicit DELETE policy, not just relying on the sender's own upload
-- policy" gap the earlier "Senders can delete their own chat media"
-- policy fixed for a manually-deleted message) -- a View Once photo
-- must be removable by *either* participant, since it's normally the
-- recipient's countdown that triggers cleanup, not the sender's.
create policy "Participants can delete a viewed View Once photo"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'chat-media'
    and exists (
      select 1 from public.messages m
      join public.conversations c on c.id = m.conversation_id
      where m.image_url = storage.objects.name
        and m.view_once
        and m.viewed_at is not null
        and auth.uid() in (c.user_a_id, c.user_b_id)
    )
  );

-- ============================================================
-- WYN-122: Temporary chat lockdown (testing only, before public
-- launch) -- see .wyn/tasks/active/WYN-122-chat-lockdown-testers-only.md
-- and .wyn/docs/design/wyn-122-chat-lockdown-testers-only.md. Founder:
-- "ปิดระบบ แชทไม่ให้คนใช้ทั่วไป ยกเว้น @warren กับ @wynos_online".
--
-- A single-row toggle (`chat_lockdown.enabled`) plus a small allowlist
-- table (`chat_lockdown_allowlist`) -- flipping `enabled` back to
-- false restores normal chat for everyone with one UPDATE, no client
-- rebuild needed (Product spec's R2 -- this is explicitly temporary,
-- "ก่อนเปิดใช้งานจริง"). Enforced at the RLS/RPC layer, never
-- client-side alone (Founder's explicit requirement) -- and reversible
-- with zero data loss: nothing here ever deletes or edits an existing
-- conversation/message row, only what a non-allowlisted pair can
-- additionally see/do at the RLS layer while `enabled` is true.
--
-- Rule (confirmed with Founder via 2 rounds of clarifying questions,
-- not assumed): a conversation/send/create is allowed only when BOTH
-- participants are in the allowlist -- not "either one". A regular
-- user cannot even chat with @warren directly during lockdown; only
-- the @warren<->@wynos_online pair itself works. This also means a
-- 3rd tester added later can freely talk to the existing 2 without
-- any code change -- just another row in the allowlist table.
-- ============================================================

create table if not exists public.chat_lockdown (
  id boolean primary key default true,
  enabled boolean not null default false,
  constraint chat_lockdown_singleton check (id)
);

insert into public.chat_lockdown (id, enabled) values (true, false)
on conflict (id) do nothing;

create table if not exists public.chat_lockdown_allowlist (
  user_id uuid primary key references public.profiles (id) on delete cascade
);

-- Neither table has a client-facing SELECT policy -- both are read
-- only through the SECURITY DEFINER helpers below, mirroring how
-- moderation_actions/reports back internal.is_posting_blocked()
-- without exposing themselves directly to every authenticated caller.
alter table public.chat_lockdown enable row level security;
alter table public.chat_lockdown_allowlist enable row level security;

-- True when chat is fully open (lockdown off) OR both p_a and p_b are
-- allowlisted testers. SECURITY DEFINER for the same inlining/
-- privilege reason internal.current_platform_role()'s own comment
-- explains above (a plain `stable` SQL function referencing auth.uid()
-- is a planner-inlining candidate, re-checked under the caller's own
-- schema privileges at inline time) -- also independently necessary
-- here since chat_lockdown/chat_lockdown_allowlist have no SELECT
-- policy for the caller's own role at all.
create or replace function internal.chat_pair_allowed(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    not coalesce((select enabled from public.chat_lockdown where id), false)
    or (
      exists (select 1 from public.chat_lockdown_allowlist where user_id = p_a)
      and exists (select 1 from public.chat_lockdown_allowlist where user_id = p_b)
    )
$$;

-- QA finding (2026-09-06, WYN-122): this is called directly inside the
-- `using`/`with check` clause of 4 RLS policies (conversations SELECT,
-- messages SELECT/INSERT, chat-media storage INSERT), which evaluate as
-- the querying role (`authenticated`) itself, not as this function's
-- owner -- unlike get_or_create_conversation()/count_unread_conversations()/
-- chat_lockdown_status() below, which are all SECURITY DEFINER and
-- therefore run as the owner regardless. Without this explicit grant,
-- `authenticated`'s ability to call this function inside those 4
-- policies depends entirely on Postgres's default EXECUTE-to-PUBLIC
-- grant never having been revoked anywhere -- exactly the assumption
-- this file's own internal-schema comment above (WYN-027 section)
-- warns against relying on. Every other internal.* RLS helper in this
-- file already has this same grant; this one didn't, and QA confirmed
-- by revoking EXECUTE from PUBLIC on this function directly that doing
-- so breaks every chat RLS policy for every user, including the two
-- allowlisted testers -- not a graceful lockdown, a hard "permission
-- denied for function chat_pair_allowed".
grant execute on function internal.chat_pair_allowed(uuid, uuid) to authenticated;

-- Client-facing check (WYN-122 Design doc's "Contract for AI Coding"):
-- p_other_user_id null -> "can I use chat at all right now" (Chat
-- Inbox/New Message screens' Locked-state check); non-null -> "can
-- this specific pair talk" (Conversation Screen, whether opening an
-- existing conversation or one freshly created via
-- get_or_create_conversation()).
create or replace function public.chat_lockdown_status(p_other_user_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_other_user_id is null then
      not coalesce((select enabled from public.chat_lockdown where id), false)
      or exists (select 1 from public.chat_lockdown_allowlist where user_id = auth.uid())
    else
      internal.chat_pair_allowed(auth.uid(), p_other_user_id)
  end
$$;

grant execute on function public.chat_lockdown_status(uuid) to authenticated;

-- get_or_create_conversation(): reject before even checking for an
-- existing conversation, so a non-allowlisted pair with a
-- pre-lockdown conversation can't have its id handed back out either
-- (the id would be useless downstream anyway once conversations/
-- messages SELECT below hides it, but rejecting here keeps the
-- contract simple: this RPC never returns an id this pair can't
-- actually use).
create or replace function public.get_or_create_conversation(p_other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_a uuid;
  v_b uuid;
  v_id uuid;
  v_status text;
  v_requested_by uuid;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;
  if p_other_user_id = v_me then
    raise exception 'Cannot start a conversation with yourself';
  end if;
  if not exists (select 1 from public.profiles where id = p_other_user_id) then
    raise exception 'User not found';
  end if;
  if internal.is_blocked_either_way(v_me, p_other_user_id) then
    raise exception 'Cannot start a conversation with a blocked user';
  end if;
  if not internal.chat_pair_allowed(v_me, p_other_user_id) then
    raise exception 'Chat is temporarily closed for testing';
  end if;

  v_a := least(v_me, p_other_user_id);
  v_b := greatest(v_me, p_other_user_id);

  -- An existing conversation (of either status) is returned as-is --
  -- status is decided once, at creation, never re-evaluated.
  select id into v_id from public.conversations where user_a_id = v_a and user_b_id = v_b;
  if v_id is not null then
    return v_id;
  end if;

  -- WYN-045: dm_permission gates whether a *new* conversation can be
  -- created at all -- only reachable here, in the "no existing
  -- conversation yet" branch (an existing conversation already
  -- returned above, unaffected by whatever the recipient's setting is
  -- today). 'no_one' always rejects, no exceptions, even from someone
  -- the recipient already follows.
  if (select dm_permission from public.profiles where id = p_other_user_id) = 'no_one' then
    raise exception 'This user is not accepting new conversations';
  end if;

  -- WYN-032: a message from someone the recipient does not already
  -- follow starts as a pending Message Request instead of going
  -- straight to their inbox -- one-directional (does the recipient
  -- follow the sender), evaluated only here, at creation time.
  --
  -- WYN-045: 'people_i_follow' only allows creation when this exact
  -- condition is true (the recipient already follows the sender) --
  -- the same condition that already produces 'active' below. If it's
  -- false, this now raises instead of falling through to a 'pending'
  -- Message Request, since "people I follow" is meant to be a hard
  -- boundary against strangers, not just a routing choice between
  -- inbox and request folder.
  if exists (
    select 1 from public.follows
    where follower_id = p_other_user_id and following_id = v_me
  ) then
    v_status := 'active';
    v_requested_by := null;
  elsif (select dm_permission from public.profiles where id = p_other_user_id) = 'people_i_follow' then
    raise exception 'This user is not accepting new conversations';
  else
    v_status := 'pending';
    v_requested_by := v_me;
  end if;

  insert into public.conversations (user_a_id, user_b_id, status, requested_by)
  values (v_a, v_b, v_status, v_requested_by)
  on conflict (user_a_id, user_b_id) do nothing
  returning id into v_id;

  if v_id is null then
    -- Lost a race with a concurrent call for the same pair -- fetch
    -- the row that won instead of erroring.
    select id into v_id from public.conversations where user_a_id = v_a and user_b_id = v_b;
  elsif v_status = 'pending' and internal.notification_enabled(p_other_user_id, 'messages') then
    insert into public.notifications (recipient_id, actor_id, type, conversation_id)
    values (p_other_user_id, v_me, 'message_request', v_id);
  end if;

  return v_id;
end;
$$;

drop policy "Participants can view their own conversations" on public.conversations;
create policy "Participants can view their own conversations (lockdown-aware)"
  on public.conversations
  for select
  to authenticated
  using (
    auth.uid() in (user_a_id, user_b_id)
    and internal.chat_pair_allowed(user_a_id, user_b_id)
  );

drop policy "Participants can view messages in their conversations" on public.messages;
create policy "Participants can view messages in their conversations (lockdown-aware)"
  on public.messages
  for select
  to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and auth.uid() in (c.user_a_id, c.user_b_id)
        and internal.chat_pair_allowed(c.user_a_id, c.user_b_id)
    )
  );

drop policy "Participants can send messages in active or own-pending conversations" on public.messages;
create policy "Participants can send messages in active/pending convos (lockdown-aware)"
  on public.messages
  for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and not internal.is_posting_blocked(auth.uid())
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and auth.uid() in (c.user_a_id, c.user_b_id)
        and not internal.is_blocked_either_way(
          c.user_a_id,
          c.user_b_id
        )
        and internal.chat_pair_allowed(c.user_a_id, c.user_b_id)
        and (
          c.status = 'active'
          or (c.status = 'pending' and c.requested_by = auth.uid())
        )
    )
  );

-- WYN-032's own comment on this policy ("mirrors the messages INSERT
-- policy's own active-or-own-pending condition exactly") still holds
-- -- mirroring the same lockdown addition here too, for the identical
-- reason: without it, a locked-out pair's image upload would still
-- succeed even though the messages row referencing it can never be
-- inserted, leaving an orphaned object in storage for no benefit.
drop policy "Participants can upload media to their conversations" on storage.objects;
create policy "Participants can upload media to their conversations (lockdown-aware)"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'chat-media'
    and exists (
      select 1 from public.conversations c
      where c.id = ((storage.foldername(name))[1])::uuid
        and auth.uid() in (c.user_a_id, c.user_b_id)
        and not internal.is_blocked_either_way(c.user_a_id, c.user_b_id)
        and internal.chat_pair_allowed(c.user_a_id, c.user_b_id)
        and (
          c.status = 'active'
          or (c.status = 'pending' and c.requested_by = auth.uid())
        )
    )
    and not internal.is_posting_blocked(auth.uid())
  );

-- count_unread_conversations() (Screen 1's badge) is SECURITY DEFINER
-- and queries conversations/messages directly -- it does NOT go
-- through the RLS policies above (a security definer function runs as
-- its owner, which bypasses RLS unless FORCE ROW LEVEL SECURITY is
-- set, which this project does not use anywhere). Without this same
-- chat_pair_allowed() check duplicated here, a locked-out user's Chat
-- icon badge would keep counting real unread messages from
-- conversations that ChatInboxScreen itself will refuse to show them
-- at all -- a confusing "badge says 3, inbox says closed" mismatch.
create or replace function public.count_unread_conversations()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.conversations c
  where auth.uid() in (c.user_a_id, c.user_b_id)
    and internal.chat_pair_allowed(c.user_a_id, c.user_b_id)
    and exists (
      select 1 from public.messages m
      where m.conversation_id = c.id
        and m.sender_id <> auth.uid()
        and m.created_at > coalesce(
          case when c.user_a_id = auth.uid() then c.user_a_last_read_at else c.user_b_last_read_at end,
          '-infinity'::timestamptz
        )
    );
$$;

-- WYN-115 (Club Poll) -- mirrors drop_polls/drop_poll_votes (WYN-035)
-- as closely as possible, per this task's own Design doc
-- (.wyn/docs/design/wyn-115-club-poll.md). One real difference: a Poll
-- Club Post's visibility is club-membership-gated (piggybacks on
-- club_posts' own trust model via club_role()) rather than "any
-- authenticated user" the way drop_polls is, since club_posts
-- themselves are already members-only-visible.
create table if not exists public.club_post_polls (
  id uuid primary key default gen_random_uuid(),
  club_post_id uuid not null unique references public.club_posts (id) on delete cascade,
  options text[] not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint club_post_polls_options_valid check (public.valid_poll_options(options))
);

create index if not exists club_post_polls_post_idx on public.club_post_polls (club_post_id);

alter table public.club_post_polls enable row level security;

create policy "Approved club members can view club post polls"
  on public.club_post_polls
  for select
  to authenticated
  using (
    exists (
      select 1 from public.club_posts cp
      where cp.id = club_post_id
        and public.club_role(cp.club_id, auth.uid()) is not null
    )
  );

-- No insert/update/delete policy at all -- the only writer is
-- create_poll_club_post() below (SECURITY DEFINER, bypasses RLS as its
-- owning role) and cascade-delete via the club_posts FK. Same "no raw
-- policy" posture as drop_polls.

-- Individual votes are never readable by anyone but the voter -- same
-- privacy posture as drop_poll_votes. Aggregate results come from
-- get_club_poll_results() below (SECURITY DEFINER), never from a
-- client-side SELECT here.
create table if not exists public.club_post_poll_votes (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.club_post_polls (id) on delete cascade,
  voter_id uuid not null references public.profiles (id) on delete cascade,
  option_index smallint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (poll_id, voter_id)
);

create index if not exists club_post_poll_votes_poll_idx on public.club_post_poll_votes (poll_id);

alter table public.club_post_poll_votes enable row level security;

create policy "Users can view only their own club poll votes"
  on public.club_post_poll_votes
  for select
  to authenticated
  using (auth.uid() = voter_id);

create policy "Users can vote as themselves on club polls"
  on public.club_post_poll_votes
  for insert
  to authenticated
  with check (auth.uid() = voter_id);

-- Changing your mind (re-voting) is an UPDATE of the same row, not a
-- new INSERT -- same shape as drop_poll_votes' identical policy.
create policy "Users can change their own club poll vote"
  on public.club_post_poll_votes
  for update
  to authenticated
  using (auth.uid() = voter_id)
  with check (auth.uid() = voter_id);

-- Same business-rule trigger shape as validate_poll_vote() (WYN-035),
-- plus one extra check drop_poll_votes never needed: the voter must
-- currently be an *approved* member of the club that owns this post --
-- club_posts' own trust model requires it for everything else visible
-- on a Club post, and a vote is no exception.
create or replace function public.validate_club_poll_vote()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_options text[];
  v_expires_at timestamptz;
  v_author_id uuid;
  v_club_id uuid;
begin
  select cpp.options, cpp.expires_at, cp.author_id, cp.club_id
    into v_options, v_expires_at, v_author_id, v_club_id
  from public.club_post_polls cpp
  join public.club_posts cp on cp.id = cpp.club_post_id
  where cpp.id = new.poll_id;

  if v_options is null then
    raise exception 'Poll not found';
  end if;

  if now() >= v_expires_at then
    raise exception 'Poll has closed';
  end if;

  if new.option_index < 0 or new.option_index >= array_length(v_options, 1) then
    raise exception 'Invalid poll option';
  end if;

  if new.voter_id = v_author_id then
    raise exception 'Cannot vote on your own poll';
  end if;

  if public.club_role(v_club_id, new.voter_id) is null then
    raise exception 'Must be an approved club member to vote';
  end if;

  if internal.is_posting_blocked(new.voter_id) then
    raise exception 'Account is posting-restricted';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger club_post_poll_votes_validate
  before insert or update on public.club_post_poll_votes
  for each row execute function public.validate_club_poll_vote();

-- Atomic "create a Poll Club Post" -- mirrors create_poll_drop()
-- (WYN-035): inserts club_posts (content = the poll question,
-- image_urls/link_url left null) + club_post_polls + (optionally)
-- club_post_mentions in one transaction. A poll question alone already
-- satisfies club_posts_have_content (content is not null), so this
-- doesn't need drops' "nullable image_url" workaround -- kept as an
-- RPC anyway for the same atomicity reason WYN-035 has one: a
-- club_posts row with a question but no matching club_post_polls row
-- (if that second insert failed) would read as a broken, option-less
-- post with no way to recover it client-side.
create or replace function public.create_poll_club_post(
  p_club_id uuid,
  p_content text,
  p_options text[],
  p_duration_days int,
  p_mentioned_user_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid := auth.uid();
  v_post_id uuid;
  v_options text[];
begin
  if v_author is null then
    raise exception 'Not authenticated';
  end if;

  if public.club_role(p_club_id, v_author) is null then
    raise exception 'Must be an approved club member to post';
  end if;

  if internal.is_posting_blocked(v_author) then
    raise exception 'Account is posting-restricted';
  end if;

  if p_content is null or length(trim(p_content)) = 0 then
    raise exception 'Poll question is required';
  end if;

  -- Trimmed server-side (not just validated-as-trimmed) so a direct
  -- RPC call bypassing the Flutter client's own .trim() can't leave
  -- stray leading/trailing whitespace sitting in stored option text.
  select array_agg(trim(o)) into v_options from unnest(p_options) as o;

  if not public.valid_poll_options(v_options) then
    raise exception 'Poll must have 2-4 non-empty, non-duplicate options (max 80 characters each)';
  end if;

  if p_duration_days not in (1, 3, 7) then
    raise exception 'Poll duration must be 1, 3, or 7 days';
  end if;

  insert into public.club_posts (club_id, author_id, content, image_urls, link_url)
  values (p_club_id, v_author, trim(p_content), null, null)
  returning id into v_post_id;

  insert into public.club_post_polls (club_post_id, options, expires_at)
  values (v_post_id, v_options, now() + make_interval(days => p_duration_days));

  -- This RPC is SECURITY DEFINER and bypasses club_post_mentions' own
  -- RLS INSERT policy entirely -- mirrored manually here (the raw
  -- policy only checks "author owns the post", nothing more; club post
  -- mentions have no mention_allowed()/block-exclusion filtering
  -- anywhere else in this codebase today -- see this task's Design doc
  -- for why that's a pre-existing gap left out of this round's scope).
  insert into public.club_post_mentions (club_post_id, mentioned_user_id)
  select v_post_id, m
  from unnest(p_mentioned_user_ids) as m;

  return v_post_id;
end;
$$;

-- Aggregate poll results, batched over a page's worth of poll ids at
-- once (mirroring ClubPostRepository's existing per-page batch fetches
-- for likes/saves). Mirrors get_poll_results() (WYN-035) with one
-- extra visibility gate neither drop_polls nor its results function
-- needed: the caller must currently be an approved member of the club
-- that owns the post, applied as a WHERE filter (excludes the row
-- entirely, same defense-in-depth shape get_poll_results() uses for
-- Drop's own block/audience checks) -- on top of the existing
-- voted/author/expired check that controls whether percentages show.
create or replace function public.get_club_poll_results(p_poll_ids uuid[])
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
    cpp.id as poll_id,
    v.is_visible,
    case when v.is_visible
      then (select count(*) from public.club_post_poll_votes cppv where cppv.poll_id = cpp.id)
      else null end as total_votes,
    case when v.is_visible
      then (
        select array_agg(cnt order by idx)
        from (
          select gs as idx, count(pv.id) as cnt
          from generate_series(0, array_length(cpp.options, 1) - 1) as gs
          left join public.club_post_poll_votes pv
            on pv.poll_id = cpp.id and pv.option_index = gs
          group by gs
        ) counted
      )
      else null end as option_counts
  from public.club_post_polls cpp
  join public.club_posts cp on cp.id = cpp.club_post_id
  cross join lateral (
    select
      cpp.expires_at <= now()
      or cp.author_id = v_me
      or exists (
        select 1 from public.club_post_poll_votes cppv2
        where cppv2.poll_id = cpp.id and cppv2.voter_id = v_me
      ) as is_visible
  ) v
  where cpp.id = any(p_poll_ids)
    and public.club_role(cp.club_id, v_me) is not null;
end;
$$;

-- ============================================================
-- WYN-116: Club Re-engagement Notifications
-- ============================================================
-- See .wyn/tasks/active/WYN-116-club-reengagement-notifications.md and
-- .wyn/docs/design/wyn-116-club-reengagement-notifications.md. Two new
-- notification types, both fanned out to *every approved member* of a
-- club (not just owner/admin like notify_club_join_request(), and not
-- a single recipient like notify_club_post_like()/_comment()):
-- 'club_post_new' (a new post from someone else) and 'club_post_pinned'
-- (a post just got pinned). Both reuse the existing 'club'
-- notification_settings category -- see internal.notification_enabled()
-- above, unchanged by this task.

-- Per-club mute -- mirrors public.conversation_mutes exactly (plain RLS
-- insert/delete, no RPC needed, no side effects to sequence atomically).
-- Deliberately scoped to ONLY the 2 new types below, not the existing
-- club_post_like/club_post_comment/mention_club_post/club_join_* types
-- -- those are about the muter's own content (someone liked/commented/
-- mentioned *their* post, or a join request needs *their* approval),
-- which stays useful even after muting a club's general activity. See
-- the Design doc's own reasoning for this scope decision.
create table if not exists public.club_notification_mutes (
  club_id uuid not null references public.clubs (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

alter table public.club_notification_mutes enable row level security;

create policy "Users can view clubs they muted"
  on public.club_notification_mutes
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can mute a club as themselves"
  on public.club_notification_mutes
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can unmute a club as themselves"
  on public.club_notification_mutes
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- Fan-out to every approved member except the post's own author, gated
-- by (a) the recipient's 'club' preference (b) not muted this specific
-- club (c) a per-(recipient, club) throttle: skip if this recipient
-- already got a club_post_new notification for this exact club within
-- the last 3 hours (Design doc's chosen window -- no cron/digest infra
-- exists anywhere in this project to build a real batched digest, see
-- the 'trending' category's own comment above, so this in-trigger
-- time-window check is the whole throttle mechanism, not a placeholder
-- for one). A Poll Club Post (WYN-115) is an ordinary club_posts row --
-- no special-casing needed here, it notifies exactly like any other post.
create or replace function public.notify_club_post_new()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (recipient_id, actor_id, type, club_post_id, club_id)
  select cm.user_id, new.author_id, 'club_post_new', new.id, new.club_id
  from public.club_members cm
  where cm.club_id = new.club_id
    and cm.status = 'approved'
    and cm.user_id <> new.author_id
    and internal.notification_enabled(cm.user_id, 'club')
    and not exists (
      select 1 from public.club_notification_mutes cnm
      where cnm.club_id = new.club_id and cnm.user_id = cm.user_id
    )
    and not exists (
      select 1 from public.notifications n
      where n.recipient_id = cm.user_id
        and n.club_id = new.club_id
        and n.type = 'club_post_new'
        and n.created_at > now() - interval '3 hours'
    );
  return new;
end;
$$;

create trigger club_posts_notify_new
  after insert on public.club_posts
  for each row execute function public.notify_club_post_new();

-- Fan-out to every approved member except whoever pinned it
-- (auth.uid()) -- deliberately NOT excluding the post's own author
-- (unlike notify_club_post_new() above): an author whose own post gets
-- pinned by staff should still be told, same as they'd want to know
-- about a like/comment on their own content. Never throttled --
-- Product's own Acceptance Criteria requires every real pin to notify.
create or replace function public.notify_club_post_pinned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (recipient_id, actor_id, type, club_post_id, club_id)
  select cm.user_id, auth.uid(), 'club_post_pinned', new.id, new.club_id
  from public.club_members cm
  where cm.club_id = new.club_id
    and cm.status = 'approved'
    and cm.user_id <> auth.uid()
    and internal.notification_enabled(cm.user_id, 'club')
    and not exists (
      select 1 from public.club_notification_mutes cnm
      where cnm.club_id = new.club_id and cnm.user_id = cm.user_id
    );
  return new;
end;
$$;

create trigger club_posts_notify_pinned
  after update on public.club_posts
  for each row
  when (old.pinned = false and new.pinned = true)
  execute function public.notify_club_post_pinned();

-- ============================================================
-- WYN-117: Club Owner Insights
-- ============================================================
-- See .wyn/tasks/active/WYN-117-club-owner-insights.md and
-- .wyn/docs/design/wyn-117-club-owner-insights.md. One aggregate RPC
-- for the whole Insights tab -- computed at the DB layer in a single
-- round trip, mirroring admin_dashboard_metrics() (WYN-050/077) rather
-- than pulling raw rows to the client and summing them there (the
-- Product spec's own Risks note names that RPC as the pattern to
-- follow).
create or replace function public.club_insights(p_club_id uuid, p_days int)
returns table (
  new_members bigint,
  new_posts bigint,
  likes_and_comments bigint,
  active_members bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cutoff timestamptz;
begin
  -- Owner/Admin only -- the same 2-tier canManageClub gate
  -- approve_club_member()/reject_club_member() already use, NOT the
  -- wider 3-tier owner/admin/moderator gate club_posts' own moderation
  -- policies use (Insights is explicitly owner/admin-only per the
  -- Product spec's Target User). coalesce(...) is load-bearing here,
  -- not decoration: club_role() returns NULL for a non-member, and
  -- `NULL not in (...)` evaluates to NULL, which plpgsql's `if` treats
  -- as false -- silently skipping the exception. This is the exact
  -- null-role-bypass class WYN-050 found in admin_dashboard_metrics()
  -- (.wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md)
  -- and it is guarded against here from day one.
  if coalesce(public.club_role(p_club_id, auth.uid()), '') not in ('owner', 'admin') then
    raise exception 'Not permitted to view Club insights';
  end if;

  -- Only 7 or 30 days -- a fixed toggle, not an arbitrary date range,
  -- per the Design doc's explicit anti-over-engineering decision.
  if p_days not in (7, 30) then
    raise exception 'Invalid insights window: %', p_days;
  end if;

  v_cutoff := now() - (p_days || ' days')::interval;

  return query
  with post_ids as (
    select id from public.club_posts where club_id = p_club_id
  ),
  -- Same "actor_id + created_at, union every did-something table"
  -- shape admin_dashboard_metrics()'s own `actions` CTE uses, scoped to
  -- this one club instead of the whole platform.
  actions as (
    select author_id as actor_id, created_at
    from public.club_posts
    where club_id = p_club_id
    union all
    select cpl.user_id as actor_id, cpl.created_at
    from public.club_post_likes cpl
    where cpl.club_post_id in (select id from post_ids)
    union all
    select cpc.author_id as actor_id, cpc.created_at
    from public.club_post_comments cpc
    where cpc.club_post_id in (select id from post_ids)
  )
  select
    -- Pending/banned members never count as a "new member" -- same
    -- status='approved' filter ClubRepository.countMembers() already
    -- applies to the plain member-count. A brand-new Club's own owner
    -- (added by clubs_add_owner_membership) genuinely does count here
    -- if the Club itself was created within the window -- that's
    -- correct data, not a bug (see the Design doc's own note on this).
    (select count(*) from public.club_members
      where club_id = p_club_id and status = 'approved' and created_at >= v_cutoff),
    (select count(*) from public.club_posts
      where club_id = p_club_id and created_at >= v_cutoff),
    -- One combined total, not two separate numbers -- matches the
    -- Product spec's own wording ("จำนวน Like/Comment รวม").
    (
      (select count(*) from public.club_post_likes cpl
        where cpl.club_post_id in (select id from post_ids) and cpl.created_at >= v_cutoff)
      +
      (select count(*) from public.club_post_comments cpc
        where cpc.club_post_id in (select id from post_ids) and cpc.created_at >= v_cutoff)
    ),
    (select count(distinct actor_id) from actions where created_at >= v_cutoff);
end;
$$;

grant execute on function public.club_insights(uuid, int) to authenticated;

-- ============================================================
-- WYN-124: Club Invite Notification
-- ============================================================
-- See .wyn/tasks/approved/WYN-124-club-invite-notification.md and
-- .wyn/docs/design/wyn-124-club-invite-notification.md. Replaces
-- WYN-123's original invite mechanism (a Chat message via
-- get_or_create_conversation()+INSERT into messages, sharedContentType
-- = club) with a dedicated `club_invite` Notification row -- Founder
-- feedback, 2026-09-06: "คนที่ถูกเชิญควรไปอยู่หน้าการแจ้งเตือน ไม่ใช่
-- หน้าแชท". A Chat message accidentally made every club invite subject
-- to WYN-122's Chat Lockdown (get_or_create_conversation() raises
-- 'Chat is temporarily closed for testing' whenever
-- internal.chat_pair_allowed() is false), which is an unrelated
-- feature this one should never have depended on.
--
-- Re-validates, server-side, the same audience InviteToClubScreen's own
-- Followers+Following list already filters for -- an RPC call can't be
-- trusted to only ever originate from that one screen.
create or replace function public.invite_to_club(p_club_id uuid, p_invitee_id uuid)
returns void
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
  if p_invitee_id = v_me then
    raise exception 'Cannot invite yourself';
  end if;
  if public.club_role(p_club_id, v_me) is null then
    raise exception 'Must be an approved club member to invite';
  end if;
  if not exists (select 1 from public.profiles where id = p_invitee_id) then
    raise exception 'User not found';
  end if;
  if internal.is_blocked_either_way(v_me, p_invitee_id) then
    raise exception 'Cannot invite a blocked user';
  end if;
  -- Instagram Close Friends / X Community "Add People" hybrid (Founder
  -- decision, WYN-123's own Design doc) -- either direction of follow
  -- qualifies, mirrored server-side rather than trusted from whichever
  -- list the client happened to fetch the invitee from.
  if not exists (
    select 1 from public.follows
    where (follower_id = v_me and following_id = p_invitee_id)
       or (follower_id = p_invitee_id and following_id = v_me)
  ) then
    raise exception 'Can only invite followers or people you follow';
  end if;

  -- Same notification_enabled('club') gate notify_club_join_approved()
  -- uses, plus a 24h dedup per (recipient, club, actor) -- mirrors
  -- notify_club_post_new()'s 3h dedup shape (WYN-116), scaled up since
  -- invites happen far less often than posts but the same "don't let a
  -- retry or repeated taps spam the same person" concern applies.
  if internal.notification_enabled(p_invitee_id, 'club') and not exists (
    select 1 from public.notifications n
    where n.recipient_id = p_invitee_id
      and n.actor_id = v_me
      and n.club_id = p_club_id
      and n.type = 'club_invite'
      and n.created_at > now() - interval '24 hours'
  ) then
    insert into public.notifications (recipient_id, actor_id, type, club_id)
    values (p_invitee_id, v_me, 'club_invite', p_club_id);
  end if;
end;
$$;

grant execute on function public.invite_to_club(uuid, uuid) to authenticated;

-- ============================================================
-- WYN-118: Club Events
-- ============================================================
-- See .wyn/tasks/active/WYN-118-club-events.md and
-- .wyn/docs/design/wyn-118-club-events.md. Deliberately scoped to just
-- "create an event + RSVP + see who's going" per the Product spec's own
-- Risks note -- there is NO "notify before the event starts" reminder
-- in this section, and that is a considered scope cut, not an
-- oversight: such a reminder needs a real time-based cron/scheduled-job
-- mechanism (nothing in this schema fires on wall-clock time passing,
-- only on row insert/update -- see the `trending` category's own
-- comment above for this same "no cron infra anywhere in this project"
-- fact stated elsewhere), which is new infrastructure well beyond this
-- task's stated scope. See the Design doc's own reasoning.
create table if not exists public.club_events (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  creator_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  description text,
  starts_at timestamptz not null,
  location_type text not null check (location_type in ('online', 'offline')),
  -- A URL for an online event, a free-text address for an offline one --
  -- no format validation, no map/GPS integration, per the Product
  -- spec's own explicit "ไม่ต้องมี map integration ใน V1".
  location text not null,
  created_at timestamptz not null default now(),
  constraint club_events_title_length check (char_length(title) between 1 and 200),
  constraint club_events_description_length
    check (description is null or char_length(description) <= 2000),
  constraint club_events_location_length check (char_length(location) between 1 and 500)
);

-- Supports both "events for this club, soonest first" (Events tab) and
-- the upcoming/past split the UI renders as two sections of one list.
create index if not exists club_events_club_starts_idx
  on public.club_events (club_id, starts_at);

alter table public.club_events enable row level security;

create policy "Approved club members can view events"
  on public.club_events
  for select
  to authenticated
  using (public.club_role(club_id, auth.uid()) is not null);

-- Same permission tier as pin/unpin (canModeratePosts: owner/admin/
-- moderator) per the Product spec's own Acceptance Criteria -- any
-- staff member can create/edit/delete any event in the club, not just
-- ones they created themselves, mirroring how staff already manage
-- each other's pinned posts.
create policy "Club staff can create events"
  on public.club_events
  for insert
  to authenticated
  with check (
    creator_id = auth.uid()
    and public.club_role(club_id, auth.uid()) in ('owner', 'admin', 'moderator')
  );

create policy "Club staff can update events"
  on public.club_events
  for update
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin', 'moderator'))
  with check (public.club_role(club_id, auth.uid()) in ('owner', 'admin', 'moderator'));

create policy "Club staff can delete events"
  on public.club_events
  for delete
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin', 'moderator'));

-- Unlike drop_poll_votes/club_post_poll_votes, RSVPs are meant to be
-- visible to the whole club ("เห็นจำนวน+รายชื่อคนที่ตอบรับ" -- Product's
-- own Requirements), not private to the voter -- so the SELECT policy
-- here is club-membership-wide, not owner-row-only.
create table if not exists public.club_event_rsvps (
  event_id uuid not null references public.club_events (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  status text not null check (status in ('going', 'maybe', 'not_going')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create index if not exists club_event_rsvps_event_idx on public.club_event_rsvps (event_id);

alter table public.club_event_rsvps enable row level security;

create policy "Approved club members can view event RSVPs"
  on public.club_event_rsvps
  for select
  to authenticated
  using (
    exists (
      select 1 from public.club_events ce
      where ce.id = event_id and public.club_role(ce.club_id, auth.uid()) is not null
    )
  );

create policy "Users can RSVP as themselves"
  on public.club_event_rsvps
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Changing your mind is an UPDATE of the same row (upserted from the
-- client on conflict (event_id, user_id)), same shape as
-- club_post_poll_votes' own "re-voting" policy.
create policy "Users can change their own RSVP"
  on public.club_event_rsvps
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can remove their own RSVP"
  on public.club_event_rsvps
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- Same shape as validate_club_poll_vote() (WYN-115): the RLS insert
-- policy above only checks "is this your own row", not club
-- membership, so that check (plus the posting-block check every other
-- write-side club action already applies) lives here instead.
create or replace function public.validate_club_event_rsvp()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club_id uuid;
begin
  select club_id into v_club_id from public.club_events where id = new.event_id;

  if v_club_id is null then
    raise exception 'Event not found';
  end if;

  if public.club_role(v_club_id, new.user_id) is null then
    raise exception 'Must be an approved club member to RSVP';
  end if;

  if internal.is_posting_blocked(new.user_id) then
    raise exception 'Account is posting-restricted';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger club_event_rsvps_validate
  before insert or update on public.club_event_rsvps
  for each row execute function public.validate_club_event_rsvp();

-- Batch RSVP counts for every event on a page in one round trip --
-- mirrors get_club_poll_results()/club_insights()'s own "aggregate at
-- the DB layer, never sum raw rows client-side" rule. Deliberately NOT
-- `security definer`, unlike most RPCs in this file: running as the
-- invoker (the caller's own `authenticated` role) means
-- club_events'/club_event_rsvps' own RLS SELECT policies already do
-- exactly the right visibility filtering for free -- an event id the
-- caller isn't an approved member for simply contributes no row here,
-- with no need to re-derive that check inside this function.
create or replace function public.club_event_rsvp_counts(p_event_ids uuid[])
returns table (event_id uuid, going bigint, maybe bigint, not_going bigint)
language sql
stable
as $$
  select
    e.id,
    count(*) filter (where r.status = 'going'),
    count(*) filter (where r.status = 'maybe'),
    count(*) filter (where r.status = 'not_going')
  from public.club_events e
  left join public.club_event_rsvps r on r.event_id = e.id
  where e.id = any(p_event_ids)
  group by e.id;
$$;

grant execute on function public.club_event_rsvp_counts(uuid[]) to authenticated;

-- ============================================================
-- WYN-125: Developer account allowlist (staged rollout mechanism) --
-- see .wyn/tasks/active/WYN-125-staged-rollout-developer-first.md and
-- .wyn/docs/design/wyn-125-staged-rollout-developer-accounts.md.
-- Founder: deploy ไปหาบัญชีนักพัฒนา/ทีมภายในก่อน รอพอใจค่อยปล่อยผู้ใช้ทั่วไป.
-- (Originally drafted as WYN-124; renamed to WYN-125 on merge into main
-- -- see DECISIONS.md's "ID collision: WYN-124 ชนกันอีกครั้ง" entry --
-- because WYN-124 was independently assigned to Club Invite Notification
-- above by another session and merged first.)
--
-- Generic and reusable across every future feature (unlike WYN-122's
-- chat_lockdown_allowlist above, which is scoped to chat alone): a
-- single boolean per user (`is_developer_account()`), not a matrix of
-- per-feature flags -- any future feature that wants a staged rollout
-- calls this one RPC and decides for itself which of its own code
-- paths to gate, with no new table/function needed each time (Product
-- spec's Requirement 2, AI Design's decision #2). No feature is wired
-- to this flag yet as of this section landing -- it ships as a
-- standalone mechanism, on purpose (see the design doc's "States").
--
-- Same lockdown-from-client posture as chat_lockdown_allowlist: RLS
-- enabled, zero SELECT/INSERT/UPDATE/DELETE policies -- readable/
-- writable only via the Supabase Management API (service-role token),
-- through wyn125-apply-developer-accounts-schema.yml (ships this
-- mechanism) and wyn125-manage-developer-accounts.yml (adds/removes/
-- lists who's in it). No authenticated user can read this table
-- directly, not even their own row -- deliberate, so a regular user
-- can't enumerate who is a "developer account" either (Design Rule).
--
-- Fail-closed by construction, not convention: is_developer_account()
-- returns false whenever auth.uid() is null, the caller isn't in the
-- table, or the table is empty -- i.e. every one of today's users,
-- unconditionally, until Founder explicitly adds a row via the
-- management workflow. The only two possible return values are `true`
-- (only for an explicitly allowlisted row) and `false` (everyone/
-- everything else, including any error) -- no future feature that
-- wraps this flag can make its own bug surface to a regular user
-- through this function.
-- ============================================================

create table if not exists public.developer_accounts (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  label text,
  added_at timestamptz not null default now()
);

-- No client-facing SELECT/INSERT/UPDATE/DELETE policy at all -- see
-- comment above. Mirrors chat_lockdown_allowlist's own posture.
alter table public.developer_accounts enable row level security;

-- SECURITY DEFINER because developer_accounts has no SELECT policy for
-- the caller's own role at all (same reason internal.chat_pair_allowed()
-- above needs it). Deliberately takes no parameter and only ever checks
-- auth.uid() -- never another user's id -- so no authenticated caller
-- can use this to enumerate who else is a developer account (Design
-- Rule: "ห้าม expose สมาชิกใน developer_accounts ให้ client เห็นเป็น list
-- ได้ไม่ว่าทางใด").
create or replace function public.is_developer_account()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    exists (
      select 1 from public.developer_accounts where user_id = auth.uid()
    ),
    false
  );
$$;

-- QA lesson from WYN-122 Round 1 (internal.chat_pair_allowed() lacked
-- this same grant): unlike most other SECURITY DEFINER functions in
-- this file, which are only ever reached indirectly (from inside an
-- RLS policy, or from another SECURITY DEFINER function), this
-- function is called directly by the client as a plain RPC. Without
-- this explicit grant to `authenticated`, calling it would fail with
-- "permission denied for function is_developer_account" for every
-- single user -- a hard error, not a graceful fail-closed `false`.
grant execute on function public.is_developer_account() to authenticated;

-- ============================================================
-- WYN-113: Invite-Only Access Gate (Referral Code)
-- ============================================================
-- See .wyn/tasks/approved/WYN-113-invite-only-access-gate.md and
-- .wyn/docs/design/wyn-113-invite-only-access-gate.md. Goal: let the
-- Founder throttle new real-account signups (not guest browsing) and
-- measure viral coefficient, without deploying new code every time the
-- gate flips on/off (Product's Requirement 4).
--
-- Same single-row-toggle shape as chat_lockdown above (`id boolean
-- primary key default true` + a `check (id)` constraint enforcing
-- exactly one row) -- flipping `enabled` back to false is one UPDATE,
-- no deploy. **Ships defaulted to false/off** -- turning this on is a
-- Founder business decision (it blocks real new signups), not
-- something this migration should do unilaterally the moment it lands
-- in production; the Founder flips it via a dedicated management
-- workflow when Phase 2 of the GTM roadmap actually starts.
create table if not exists public.invite_gate_config (
  id boolean primary key default true,
  enabled boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint invite_gate_config_singleton check (id)
);

insert into public.invite_gate_config (id, enabled) values (true, false)
on conflict (id) do nothing;

-- No client-facing SELECT policy at all (same posture as
-- chat_lockdown/developer_accounts) -- read only via
-- is_invite_gate_enabled() below.
alter table public.invite_gate_config enable row level security;

-- Deliberately granted to `anon` as well as `authenticated` below --
-- the first function in this whole schema callable with no session at
-- all. Every other RLS policy/RPC in this file requires `authenticated`
-- because everything else happens *after* sign-in; this one has to run
-- *before* WelcomeScreen even offers a sign-in button, so there is no
-- session to require. Returns only a boolean -- no data leak, and
-- SECURITY DEFINER only to reach a table with no SELECT policy, not to
-- expose anything caller-specific.
create or replace function public.is_invite_gate_enabled()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select enabled from public.invite_gate_config where id = true),
    false
  );
$$;

grant execute on function public.is_invite_gate_enabled() to anon, authenticated;

-- One referral code per profile, auto-generated so every user can
-- invite others from day one (Requirement 1's "สร้างอัตโนมัติตอน signup
-- สำเร็จ" decision) -- never something the user has to opt into or
-- generate themselves. `unique` (not a smaller/prettier format) is the
-- only real constraint that matters here; 8 random hex chars gives
-- ~4.3 billion possibilities, so a collision retry loop is a formality,
-- not a load-bearing defense.
alter table public.profiles add column if not exists referral_code text unique;

create or replace function public.generate_referral_code()
returns text
language plpgsql
as $$
declare
  v_code text;
begin
  loop
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
    exit when not exists (
      select 1 from public.profiles where referral_code = v_code
    );
  end loop;
  return v_code;
end;
$$;

-- Not security definer -- runs as whatever role performs the INSERT
-- (`authenticated`, from AuthRepository's own profiles upsert calls),
-- which is enough: "Profiles are viewable by authenticated users" above
-- already lets it see every row for the uniqueness check.
create or replace function public.set_referral_code_on_profile()
returns trigger
language plpgsql
as $$
begin
  if new.referral_code is null then
    new.referral_code := public.generate_referral_code();
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_set_referral_code on public.profiles;
create trigger profiles_set_referral_code
  before insert on public.profiles
  for each row execute function public.set_referral_code_on_profile();

-- Backfill: every profile that existed before this migration ran gets
-- a code too, so an existing (pre-feature) user can start inviting
-- immediately rather than only users who sign up after this ships.
-- Row-by-row with its own exception handler -- not a single bulk
-- UPDATE -- because Postgres re-validates *every* check constraint on
-- a row for *any* UPDATE to it, regardless of which column changed.
-- This hit production directly: the official WYNOS account's own
-- `profiles` row was grandfathered past `profiles_username_not_reserved`
-- via that constraint's own `not valid` (see its comment above) when
-- the constraint was added, but a bulk backfill UPDATE re-triggers
-- validation anyway and a single failing row would abort the entire
-- statement, blocking every *other* profile's backfill too. Looping
-- means one already-known, already-accepted grandfathered row is
-- skipped (left without a referral_code, which is harmless -- nothing
-- reads referral_code as non-null-required) without blocking anyone
-- else's.
do $$
declare
  r record;
begin
  for r in select id from public.profiles where referral_code is null loop
    begin
      update public.profiles set referral_code = public.generate_referral_code()
      where id = r.id;
    exception when others then
      raise notice 'Skipping referral_code backfill for profile %: %', r.id, sqlerrm;
    end;
  end loop;
end;
$$;

-- Multi-use per referrer (Acceptance Criteria -- explicitly NOT
-- single-use, so one person can invite more than one friend), but
-- `new_user_id unique` caps each new account at redeeming exactly one
-- code ever -- otherwise one account could inflate several referrers'
-- counts by redeeming multiple codes for itself.
create table if not exists public.referral_redemptions (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  referrer_id uuid not null references public.profiles (id) on delete cascade,
  new_user_id uuid not null unique references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists referral_redemptions_referrer_idx
  on public.referral_redemptions (referrer_id);

-- No client-facing policy at all (same posture as
-- chat_lockdown_allowlist/developer_accounts) -- written only via
-- redeem_referral_code(), read only (as an aggregate count, never raw
-- rows) via my_referral_stats() below. V1 deliberately does not expose
-- *who* redeemed a code, only how many -- see the design doc's "out of
-- scope" list.
alter table public.referral_redemptions enable row level security;

-- Anon-callable, same reasoning as is_invite_gate_enabled() -- the
-- redeem-code screen must be able to validate a code before the
-- visitor has signed in at all. Only ever answers true/false; never
-- reveals whose code it is or anything else about the referrer.
create or replace function public.validate_referral_code(p_code text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles where referral_code = upper(p_code)
  );
$$;

grant execute on function public.validate_referral_code(text) to anon, authenticated;

-- Called once, right after a real (non-anonymous) account's `profiles`
-- row first exists (OnboardingFlow's Birthday step, immediately after
-- setDateOfBirth -- see auth_repository.dart's own doc comment on why
-- there). `on conflict (new_user_id) do nothing` makes a repeat call
-- for the same user (a retried onboarding step, or the resumable-
-- onboarding flow reaching Birthday again) a safe no-op rather than an
-- error or a double-counted redemption.
create or replace function public.redeem_referral_code(p_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referrer_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to redeem a referral code';
  end if;

  select id into v_referrer_id from public.profiles
    where referral_code = upper(p_code);

  if v_referrer_id is null then
    raise exception 'Invalid referral code';
  end if;

  if v_referrer_id = auth.uid() then
    raise exception 'Cannot redeem your own referral code';
  end if;

  insert into public.referral_redemptions (code, referrer_id, new_user_id)
  values (upper(p_code), v_referrer_id, auth.uid())
  on conflict (new_user_id) do nothing;
end;
$$;

grant execute on function public.redeem_referral_code(text) to authenticated;

-- Lets a user see their own referral code (to share) and how many
-- people have joined through it (Requirement 3's viral-coefficient
-- tracking) -- deliberately an aggregate count only, never a list of
-- who joined (see referral_redemptions' own comment on why).
create or replace function public.my_referral_stats()
returns table (referral_code text, redemption_count bigint)
language sql
security definer
set search_path = public
stable
as $$
  select p.referral_code, count(rr.id)
  from public.profiles p
  left join public.referral_redemptions rr on rr.referrer_id = p.id
  where p.id = auth.uid()
  group by p.referral_code;
$$;

grant execute on function public.my_referral_stats() to authenticated;

-- ============================================================
-- WYN-127: Club Channels
-- ============================================================
-- Discord-style rooms within a Club -- club_posts (WYN-014) already had
-- a single flat feed; this splits it by channel_id. See
-- .wyn/tasks/backlog/WYN-127-club-channels.md and
-- supabase/migrations_wyn127_club_channels.sql (the production ALTER
-- path -- this section is schema.sql's own "load into an empty
-- database" form of the exact same statements, so both stay in sync).

create table if not exists public.club_channels (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  name text not null,
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint club_channels_name_length check (char_length(name) between 1 and 50),
  -- Composite unique target for club_posts.channel_id's own FK below --
  -- guarantees a post's channel_id/club_id can never point at a channel
  -- belonging to a *different* Club.
  constraint club_channels_id_club_id_key unique (id, club_id)
);

-- Case-insensitive per-Club uniqueness -- Design's "กันชื่อว่าง/ซ้ำ".
create unique index if not exists club_channels_club_id_lower_name_key
  on public.club_channels (club_id, lower(name));

alter table public.club_channels enable row level security;

-- Read: same as clubs itself (WYN-014's "Clubs are viewable by
-- authenticated users") -- a channel's *name* carries no privacy
-- boundary of its own; the posts inside it stay gated by club_posts'
-- own club_role()-based SELECT policy exactly as before.
create policy "Club channels are viewable by authenticated users"
  on public.club_channels
  for select
  to authenticated
  using (true);

create policy "Club owners and admins can create channels"
  on public.club_channels
  for insert
  to authenticated
  with check (
    auth.uid() = created_by
    and public.club_role(club_id, auth.uid()) in ('owner', 'admin')
  );

create policy "Club owners and admins can rename channels"
  on public.club_channels
  for update
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

-- Deleting a channel cascade-deletes every post in it (club_posts.
-- channel_id's FK below is ON DELETE CASCADE) -- Founder's explicit
-- choice ("ประหยัดพื้นที่"), not a migrate-to-default-channel behavior.
create policy "Club owners and admins can delete channels"
  on public.club_channels
  for delete
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

-- Every new Club gets its "ทั่วไป" default channel automatically, same
-- trigger shape as clubs_add_owner_membership (WYN-014) far above.
create or replace function public.clubs_add_default_channel()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.club_channels (club_id, name, created_by)
  values (new.id, 'ทั่วไป', new.owner_id);
  return new;
end;
$$;

drop trigger if exists clubs_add_default_channel on public.clubs;
create trigger clubs_add_default_channel
  after insert on public.clubs
  for each row execute function public.clubs_add_default_channel();

-- Backfill, for schema.sql loaded against a database that already had
-- Clubs before this section existed -- a no-op on a genuinely empty
-- database (the normal case for this file).
insert into public.club_channels (club_id, name, created_by)
select c.id, 'ทั่วไป', c.owner_id
from public.clubs c
where not exists (
  select 1 from public.club_channels ch where ch.club_id = c.id
);

alter table public.club_posts add column if not exists channel_id uuid;

update public.club_posts cp
set channel_id = (
  select ch.id from public.club_channels ch
  where ch.club_id = cp.club_id
  order by ch.created_at asc
  limit 1
)
where cp.channel_id is null;

alter table public.club_posts drop constraint if exists club_posts_channel_id_club_id_fkey;
alter table public.club_posts
  add constraint club_posts_channel_id_club_id_fkey
  foreign key (channel_id, club_id) references public.club_channels (id, club_id) on delete cascade;

alter table public.club_posts alter column channel_id set not null;

create index if not exists club_posts_channel_id_idx
  on public.club_posts (channel_id, pinned, created_at);

-- create_poll_club_post() (WYN-115, far above) inserts into club_posts
-- directly and predates channel_id -- now NOT NULL, so this needs a
-- p_channel_id argument too. `create or replace function` can't add a
-- parameter ahead of an existing one with a default, so the old 5-arg
-- overload is dropped outright first (SCHEMA-003 lesson: leaving it
-- behind would keep a second, channel-less SECURITY DEFINER entry point
-- reachable).
drop function if exists public.create_poll_club_post(uuid, text, text[], int, uuid[]);

create or replace function public.create_poll_club_post(
  p_club_id uuid,
  p_channel_id uuid,
  p_content text,
  p_options text[],
  p_duration_days int,
  p_mentioned_user_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid := auth.uid();
  v_post_id uuid;
  v_options text[];
begin
  if v_author is null then
    raise exception 'Not authenticated';
  end if;

  if public.club_role(p_club_id, v_author) is null then
    raise exception 'Must be an approved club member to post';
  end if;

  if not exists (
    select 1 from public.club_channels where id = p_channel_id and club_id = p_club_id
  ) then
    raise exception 'Channel does not belong to this club';
  end if;

  if internal.is_posting_blocked(v_author) then
    raise exception 'Account is posting-restricted';
  end if;

  if p_content is null or length(trim(p_content)) = 0 then
    raise exception 'Poll question is required';
  end if;

  select array_agg(trim(o)) into v_options from unnest(p_options) as o;

  if not public.valid_poll_options(v_options) then
    raise exception 'Poll must have 2-4 non-empty, non-duplicate options (max 80 characters each)';
  end if;

  if p_duration_days not in (1, 3, 7) then
    raise exception 'Poll duration must be 1, 3, or 7 days';
  end if;

  insert into public.club_posts (club_id, channel_id, author_id, content, image_urls, link_url)
  values (p_club_id, p_channel_id, v_author, trim(p_content), null, null)
  returning id into v_post_id;

  insert into public.club_post_polls (club_post_id, options, expires_at)
  values (v_post_id, v_options, now() + make_interval(days => p_duration_days));

  insert into public.club_post_mentions (club_post_id, mentioned_user_id)
  select v_post_id, m
  from unnest(p_mentioned_user_ids) as m;

  return v_post_id;
end;
$$;

-- ============================================================
-- WYN-129: Club Role Badge
-- ============================================================
-- A purely cosmetic, Club-scoped identity layer -- completely separate
-- from club_role()/authorization. See
-- .wyn/tasks/backlog/WYN-129-club-role-badges.md and
-- supabase/migrations_wyn129_club_member_badges.sql (same statements,
-- kept in sync).
--
-- CRITICAL INVARIANT (Risks section): a badge must NEVER be queried
-- anywhere a permission check happens. Nothing in this section calls
-- club_role() to grant anything -- club_role() is only ever read here to
-- decide who may set/edit/remove *cosmetic* rows, the same way it's
-- already used to gate club_channels above -- and nothing that calls
-- club_role() to gate a real action anywhere else in this file
-- references club_member_badges. Keep it that way.

create table if not exists public.club_member_badges (
  club_id uuid not null references public.clubs (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  label text not null,
  -- Requirement 1: "เลือกจาก palette ที่กำหนดไว้ ไม่ใช่ color picker อิสระ"
  -- -- exactly the 3 Founder-approved colors, enforced at the DB layer,
  -- not just in the Flutter picker UI.
  color_key text not null check (color_key in ('gold', 'sage', 'plum')),
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint club_member_badges_label_length check (char_length(label) between 1 and 20),
  -- Requirement 4: at most 1 badge per member per Club.
  primary key (club_id, user_id)
);

alter table public.club_member_badges enable row level security;

-- Read: same posture as club_channels (WYN-127) -- a badge carries no
-- privacy boundary of its own; the real content it decorates (Members
-- tab, posts, comments) is already gated by its own visibility rules.
create policy "Club member badges are viewable by authenticated users"
  on public.club_member_badges
  for select
  to authenticated
  using (true);

-- Insert/update/delete: that Club's own Owner/Admin only, and only
-- targeting a currently-approved member of the *same* Club --
-- club_role(club_id, user_id) is not null re-derives the target's own
-- membership the same way club_role(club_id, auth.uid()) re-derives the
-- caller's, so a stranger/pending/banned user can never be badged.
create policy "Club owners and admins can set member badges"
  on public.club_member_badges
  for insert
  to authenticated
  with check (
    auth.uid() = created_by
    and public.club_role(club_id, auth.uid()) in ('owner', 'admin')
    and public.club_role(club_id, user_id) is not null
  );

-- Bug fix (.wyn/tasks/bugs/WYN-129-badge-update-target-membership-gap.md):
-- the `using` clause alone re-verifies only the *caller's* own role --
-- Postgres reuses `using` as the implicit `with check` when a `for
-- update` policy omits one, so without an explicit `with check` here an
-- Owner/Admin could UPDATE an existing badge row's `user_id` to point at
-- any other user at all (pending/banned/non-member), bypassing the
-- exact target-membership invariant the `insert` policy above already
-- enforces. The `with check` below mirrors that `insert` policy's own
-- `club_role(club_id, user_id) is not null` gate so the *target row's*
-- membership is re-derived on every UPDATE too, not just on INSERT.
create policy "Club owners and admins can edit member badges"
  on public.club_member_badges
  for update
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'))
  with check (
    public.club_role(club_id, auth.uid()) in ('owner', 'admin')
    and public.club_role(club_id, user_id) is not null
  );

create policy "Club owners and admins can remove member badges"
  on public.club_member_badges
  for delete
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

-- ============================================================
-- WYN-128: Club Group Chat
-- ============================================================
-- Real-time group chat, one room per WYN-127 channel -- a brand new
-- table, deliberately NOT touching conversations/conversation_participants/
-- messages (WYN-031) at all. See
-- .wyn/tasks/backlog/WYN-128-club-group-chat.md and
-- supabase/migrations_wyn128_club_channel_messages.sql (same statements,
-- kept in sync).

create table if not exists public.club_channel_messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.club_channels (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  content text,
  image_url text,
  reply_to_message_id uuid references public.club_channel_messages (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint club_channel_messages_have_content check (content is not null or image_url is not null),
  constraint club_channel_messages_content_length
    check (content is null or char_length(content) between 1 and 2000)
);

create index if not exists club_channel_messages_channel_id_idx
  on public.club_channel_messages (channel_id, created_at);

alter table public.club_channel_messages enable row level security;

-- Read/write gate: club_role() on the message's own channel's club_id --
-- exactly the sitting membership check every other Club RLS policy uses
-- (club_posts, club_channels), so a banned/removed member loses both
-- read and write access the moment their club_members row changes.
create policy "Approved club members can view channel messages"
  on public.club_channel_messages
  for select
  to authenticated
  using (
    exists (
      select 1 from public.club_channels ch
      where ch.id = channel_id
        and public.club_role(ch.club_id, auth.uid()) is not null
    )
  );

create policy "Approved club members can send channel messages as themselves"
  on public.club_channel_messages
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and not internal.is_posting_blocked(auth.uid())
    and exists (
      select 1 from public.club_channels ch
      where ch.id = channel_id
        and public.club_role(ch.club_id, auth.uid()) is not null
    )
  );

-- Delete: message author OR that channel's Club staff (owner/admin/
-- moderator) -- a plain hard DELETE, mirroring club_posts' own delete
-- policy (no soft-null-out RPC needed -- no View-Once/shared-content
-- state here that a hard delete could leave dangling).
create policy "Message authors and club staff can delete channel messages"
  on public.club_channel_messages
  for delete
  to authenticated
  using (
    auth.uid() = author_id
    or exists (
      select 1 from public.club_channels ch
      where ch.id = channel_id
        and public.club_role(ch.club_id, auth.uid()) in ('owner', 'admin', 'moderator')
    )
  );

-- Mirrors prevent_cross_conversation_reply() (WYN-031) exactly, scoped
-- to channel instead of conversation.
create or replace function public.prevent_cross_channel_message_reply()
returns trigger
language plpgsql
as $$
begin
  if new.reply_to_message_id is not null then
    if not exists (
      select 1 from public.club_channel_messages m
      where m.id = new.reply_to_message_id and m.channel_id = new.channel_id
    ) then
      raise exception 'Cannot reply to a message from a different channel';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists club_channel_messages_prevent_cross_channel_reply on public.club_channel_messages;
create trigger club_channel_messages_prevent_cross_channel_reply
  before insert on public.club_channel_messages
  for each row execute function public.prevent_cross_channel_message_reply();

-- Chat images reuse the *existing* `club-media` bucket and its existing
-- ">1 folder segment" policies from WYN-014 as-is -- a chat image at
-- `{club_id}/chat/{channel_id}/{user_id}-{timestamp}.*` is already
-- covered with zero new storage policy needed.

-- Requirement 6 / AC: unread badge -- one row per (channel, user),
-- mirroring conversations.user_a_last_read_at/user_b_last_read_at's role
-- for 1:1 chat, but as its own table since a channel has N members.
create table if not exists public.club_channel_message_reads (
  channel_id uuid not null references public.club_channels (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);

alter table public.club_channel_message_reads enable row level security;

create policy "Users can view their own channel read state"
  on public.club_channel_message_reads
  for select
  to authenticated
  using (auth.uid() = user_id);

-- No insert/update policy for the client -- mark_club_channel_read()
-- below is the only write path, mirroring mark_conversation_read()
-- (WYN-031).
create or replace function public.mark_club_channel_read(p_channel_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select club_id into v_club_id from public.club_channels where id = p_channel_id;
  if v_club_id is null or public.club_role(v_club_id, auth.uid()) is null then
    raise exception 'Not an approved member of this channel''s club';
  end if;

  insert into public.club_channel_message_reads (channel_id, user_id, last_read_at)
  values (p_channel_id, auth.uid(), now())
  on conflict (channel_id, user_id) do update set last_read_at = excluded.last_read_at;
end;
$$;

grant execute on function public.mark_club_channel_read(uuid) to authenticated;

-- Per-channel unread counts for every channel in p_club_id, for the
-- caller -- batched in one call. Excludes the caller's own messages
-- (sending doesn't make your own room "unread").
create or replace function public.get_unread_channel_counts(p_club_id uuid)
returns table (channel_id uuid, unread_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select ch.id,
    count(m.id) filter (
      where m.created_at > coalesce(r.last_read_at, 'epoch'::timestamptz)
        and m.author_id <> auth.uid()
    )
  from public.club_channels ch
  left join public.club_channel_message_reads r
    on r.channel_id = ch.id and r.user_id = auth.uid()
  left join public.club_channel_messages m
    on m.channel_id = ch.id
  where ch.club_id = p_club_id
    and public.club_role(p_club_id, auth.uid()) is not null
  group by ch.id;
$$;

grant execute on function public.get_unread_channel_counts(uuid) to authenticated;

-- ============================================================
-- WYN-128 fast-follow: report a Club Group Chat message
-- ============================================================
-- QA found club_channel_messages had zero moderation coverage --
-- neither the reports.target_type CHECK constraint nor submit_report()/
-- apply_moderation_action() knew this table existed. See
-- .wyn/tasks/bugs/WYN-128-group-chat-missing-report-action.md.
--
-- Mirrors the 'redrop' addition (WYN-034 section, far above) exactly:
-- dynamically find+drop whatever the current CHECK constraint name is
-- (safe no matter how many times this constraint has already been
-- widened) rather than assuming a specific name.
do $$
declare
  v_constraint_name text;
begin
  select tc.constraint_name into v_constraint_name
  from information_schema.table_constraints tc
  join information_schema.constraint_column_usage ccu
    on ccu.constraint_name = tc.constraint_name
   and ccu.constraint_schema = tc.constraint_schema
  where tc.table_schema = 'public'
    and tc.table_name = 'reports'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'target_type';

  if v_constraint_name is not null then
    execute format('alter table public.reports drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.reports
  add constraint reports_target_type_check
  check (target_type in (
    'user', 'drop', 'drop_comment', 'club', 'club_post',
    'club_post_comment', 'message', 'redrop', 'club_channel_message'
  ));

-- Full re-definition (not just the new branch) -- `create or replace`
-- always replaces the whole function body. Every branch above this
-- comment is byte-for-byte the same as the version further up this
-- file; only the new `club_channel_message` branch is new.
create or replace function public.submit_report(
  p_target_type text,
  p_target_id uuid,
  p_category text,
  p_detail text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reporter uuid := auth.uid();
  v_report_id uuid;
begin
  if v_reporter is null then
    raise exception 'Not authenticated';
  end if;

  if p_target_type = 'user' then
    if p_target_id = v_reporter then
      raise exception 'Cannot report yourself';
    end if;
    if not exists (select 1 from public.profiles where id = p_target_id) then
      raise exception 'Target user not found';
    end if;
  elsif p_target_type = 'drop' then
    if not exists (
      select 1 from public.drops
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Drop not found, or is your own';
    end if;
  elsif p_target_type = 'drop_comment' then
    if not exists (
      select 1 from public.drop_comments
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Comment not found, or is your own';
    end if;
  elsif p_target_type = 'club' then
    if not exists (
      select 1 from public.clubs
      where id = p_target_id and owner_id <> v_reporter
    ) then
      raise exception 'Club not found, or is your own';
    end if;
  elsif p_target_type = 'club_post' then
    if not exists (
      select 1 from public.club_posts
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Club post not found, or is your own';
    end if;
  elsif p_target_type = 'club_post_comment' then
    if not exists (
      select 1 from public.club_post_comments
      where id = p_target_id and author_id <> v_reporter
    ) then
      raise exception 'Club post comment not found, or is your own';
    end if;
  elsif p_target_type = 'message' then
    if not exists (
      select 1 from public.messages m
      join public.conversations c on c.id = m.conversation_id
      where m.id = p_target_id
        and m.sender_id <> v_reporter
        and v_reporter in (c.user_a_id, c.user_b_id)
    ) then
      raise exception 'Message not found, is your own, or you are not a participant';
    end if;
  elsif p_target_type = 'redrop' then
    if not exists (
      select 1 from public.redrops
      where id = p_target_id and redropper_id <> v_reporter
    ) then
      raise exception 'Redrop not found, or is your own';
    end if;
  elsif p_target_type = 'club_channel_message' then
    -- Same reasoning as the 'message' branch above: security definer
    -- bypasses club_channel_messages' own membership-gated SELECT
    -- policy, so the caller's membership in *that message's* Club must
    -- be re-checked explicitly here, not assumed from RLS.
    if not exists (
      select 1 from public.club_channel_messages m
      join public.club_channels ch on ch.id = m.channel_id
      where m.id = p_target_id
        and m.author_id <> v_reporter
        and public.club_role(ch.club_id, v_reporter) is not null
    ) then
      raise exception 'Channel message not found, is your own, or you are not a member of its club';
    end if;
  else
    raise exception 'Unsupported report target type: %', p_target_type;
  end if;

  insert into public.reports (reporter_id, target_type, target_id, category, detail)
  values (
    v_reporter,
    p_target_type,
    p_target_id,
    p_category,
    nullif(trim(coalesce(p_detail, '')), '')
  )
  returning id into v_report_id;

  return v_report_id;
end;
$$;

grant execute on function public.submit_report(text, uuid, text, text) to authenticated;

-- Full re-definition of apply_moderation_action() -- same reasoning as
-- submit_report() above: every branch except the new
-- 'club_channel_message' one is byte-for-byte the same as the version
-- further up this file.
create or replace function public.apply_moderation_action(
  p_report_id uuid,
  p_action_type text,
  p_reason text,
  p_duration_days integer default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reviewer uuid := auth.uid();
  v_reviewer_role text;
  v_report record;
  v_target_user uuid;
  v_target_content_type text;
  v_target_content_id uuid;
  v_expires_at timestamptz;
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_action_id uuid;
begin
  if v_reviewer is null then
    raise exception 'Not authenticated';
  end if;

  select platform_role into v_reviewer_role from public.profiles where id = v_reviewer;
  if v_reviewer_role is null or v_reviewer_role = 'user' then
    raise exception 'Not authorized';
  end if;

  if p_action_type not in ('no_action', 'warning', 'remove_content', 'restrict', 'suspend', 'ban') then
    raise exception 'Invalid action_type: %', p_action_type;
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  select * into v_report from public.reports where id = p_report_id for update;
  if v_report is null then
    raise exception 'Report not found';
  end if;
  if v_report.status not in ('pending', 'reviewing') then
    raise exception 'Report has already been actioned';
  end if;

  if v_report.target_type = 'user' then
    v_target_user := v_report.target_id;
  elsif v_report.target_type = 'drop' then
    select author_id into v_target_user from public.drops where id = v_report.target_id;
  elsif v_report.target_type = 'drop_comment' then
    select author_id into v_target_user from public.drop_comments where id = v_report.target_id;
  elsif v_report.target_type = 'club' then
    select owner_id into v_target_user from public.clubs where id = v_report.target_id;
  elsif v_report.target_type = 'club_post' then
    select author_id into v_target_user from public.club_posts where id = v_report.target_id;
  elsif v_report.target_type = 'club_post_comment' then
    select author_id into v_target_user from public.club_post_comments where id = v_report.target_id;
  elsif v_report.target_type = 'club_channel_message' then
    select author_id into v_target_user from public.club_channel_messages where id = v_report.target_id;
  else
    raise exception 'Unsupported report target type: %', v_report.target_type;
  end if;

  -- Remove Content only applies to content targets, per the Product
  -- spec ("เฉพาะ target ที่เป็นเนื้อหา ไม่ใช้กับ target ที่เป็น User/Club").
  if p_action_type = 'remove_content' and v_report.target_type in ('user', 'club') then
    raise exception 'Remove Content is not supported for target type %', v_report.target_type;
  end if;

  -- Every action except No Action needs a real account to act on -- if
  -- the target vanished before review (deleted by its own author, or by
  -- an earlier Remove Content against a different report on the same
  -- content), only No Action can still close the case.
  if v_target_user is null and p_action_type <> 'no_action' then
    raise exception 'Target no longer exists -- use No Action to close this report';
  end if;

  if p_action_type in ('restrict', 'suspend') then
    if p_duration_days is null or p_duration_days not in (1, 3, 7) then
      raise exception 'duration_days must be 1, 3, or 7 for % ', p_action_type;
    end if;
    v_expires_at := now() + (p_duration_days || ' days')::interval;
  else
    v_expires_at := null;
  end if;

  -- WYN-052: only a Drop gets restorable tracking -- other content
  -- types have no soft-delete infra to point this at (see the section
  -- comment above).
  if p_action_type = 'remove_content' and v_report.target_type = 'drop' then
    v_target_content_type := 'drop';
    v_target_content_id := v_report.target_id;
  end if;

  insert into public.moderation_actions (
    report_id, target_user_id, action_type, reason, duration_days, expires_at,
    reviewer_id, target_content_type, target_content_id
  ) values (
    p_report_id,
    v_target_user,
    p_action_type,
    v_trimmed_reason,
    case when p_action_type in ('restrict', 'suspend') then p_duration_days else null end,
    v_expires_at,
    v_reviewer,
    v_target_content_type,
    v_target_content_id
  )
  returning id into v_action_id;

  update public.reports
  set status = case when p_action_type = 'no_action' then 'dismissed' else 'actioned' end
  where id = p_report_id;

  if p_action_type = 'warning' then
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_target_user, null, 'moderation_warning', v_trimmed_reason, v_action_id, p_action_type);
  elsif p_action_type = 'remove_content' then
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_target_user, null, 'moderation_content_removed', v_trimmed_reason, v_action_id, p_action_type);

    -- WYN-052: Drop soft-deletes (restorable); drop_comment/club_post/
    -- club_post_comment/club_channel_message are unchanged, still an
    -- immediate hard DELETE (design doc's Screen 5 effect) -- a chat
    -- message has no restore path, same as a post comment.
    if v_report.target_type = 'drop' then
      update public.drops set deleted_at = now() where id = v_report.target_id and deleted_at is null;
    elsif v_report.target_type = 'drop_comment' then
      delete from public.drop_comments where id = v_report.target_id;
    elsif v_report.target_type = 'club_post' then
      delete from public.club_posts where id = v_report.target_id;
    elsif v_report.target_type = 'club_post_comment' then
      delete from public.club_post_comments where id = v_report.target_id;
    elsif v_report.target_type = 'club_channel_message' then
      delete from public.club_channel_messages where id = v_report.target_id;
    end if;
  end if;

  perform internal.log_audit_event(
    v_reviewer,
    'moderation_action_applied',
    v_target_user,
    jsonb_build_object('action_type', p_action_type, 'reason', v_trimmed_reason)
  );
end;
$$;

grant execute on function public.apply_moderation_action(uuid, text, text, integer) to authenticated;

-- ---------------------------------------------------------------------
-- WYN-130 -- Club Members tab showing "ghost" accounts (2026-09-07).
--
-- Founder's screenshot: a Club's About > สมาชิก (Members) list showing
-- several rows as a bare "@" with a "?" fallback avatar and no display
-- name. Same "ghost account" class the 2026-09-05 fix above solved for
-- suggested_users() -- AuthRepository.setDateOfBirth (the *first*
-- onboarding step) already upserts a bare `profiles` row (id only, no
-- username/display_name/avatar_url) before the Username step ever
-- runs, so a signup abandoned right there leaves that row behind
-- forever. That fix only covered Discovery's suggested_users() RPC --
-- it did nothing for Clubs, where the same incomplete profile shows up
-- a different way: nothing in the "Users can request or join clubs as
-- themselves" club_members insert policy (WYN-014, above) requires
-- profile_private.onboarding_completed, so any authenticated session
-- -- onboarded or not -- can insert an approved club_members row for a
-- public Club. ClubRepository.fetchApprovedMembers/fetchPendingMembers
-- (app/lib/features/club/data/club_repository.dart) then join that row
-- straight to `profiles`, and ClubMember.fromMap coalesces the null
-- username to '' -- exactly the bare "@" + "?" avatar rows in the
-- screenshot.
--
-- Can't fix this the same way suggested_users() did (a plain `exists`
-- against profile_private added straight into the query) -- the
-- Members tab's client-side select embeds `profiles` under the
-- *querying* user's own RLS, and profile_private's own SELECT policy
-- ("Users can view their own private profile fields", above) only lets
-- a user read their OWN onboarding_completed, never a fellow Club
-- member's. So this needs a SECURITY DEFINER RPC -- same mechanism
-- club_role()/club_insights() above already use to see across that
-- exact RLS boundary -- that re-implements the two club_members SELECT
-- policies it stands in for ("Approved members can view other approved
-- members" / "Club owners and admins can view pending requests")
-- rather than loosening either policy itself: no caller sees any row
-- they couldn't already see today, this only excludes the ghost rows
-- from what was already visible.
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.
create or replace function public.club_member_profiles(
  p_club_id uuid,
  p_status text,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  club_id uuid,
  user_id uuid,
  role text,
  status text,
  created_at timestamptz,
  username text,
  display_name text,
  avatar_url text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_status = 'approved' then
    -- Mirrors "Approved members can view other approved members":
    -- club_role() is non-null only for an approved membership, so this
    -- is the exact same condition, just evaluated once here instead of
    -- per-row inside a USING clause.
    if public.club_role(p_club_id, auth.uid()) is null then
      raise exception 'Not permitted to view this Club''s members';
    end if;
  elsif p_status = 'pending' then
    -- Mirrors "Club owners and admins can view pending requests".
    if coalesce(public.club_role(p_club_id, auth.uid()), '') not in ('owner', 'admin') then
      raise exception 'Not permitted to view this Club''s pending requests';
    end if;
  else
    raise exception 'Invalid status: %', p_status;
  end if;

  return query
  select
    cm.club_id, cm.user_id, cm.role, cm.status, cm.created_at,
    p.username, p.display_name, p.avatar_url
  from public.club_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.club_id = p_club_id
    and cm.status = p_status
    and exists (
      select 1 from public.profile_private pp
      where pp.id = cm.user_id and pp.onboarding_completed = true
    )
  order by cm.created_at asc
  limit p_limit offset p_offset;
end;
$$;

grant execute on function public.club_member_profiles(uuid, text, int, int) to authenticated;

-- ---------------------------------------------------------------------
-- WYN-130 (continued) -- same ghost-account exclusion, second call
-- site found by grepping for every other `profiles(username,
-- display_name, avatar_url)` embed in the app right after the fix
-- above: ClubEventRepository.fetchAttendees() (app/lib/features/club/
-- data/club_event_repository.dart) backs the RSVP attendee bottom
-- sheet ("เห็น...รายชื่อคนที่ตอบรับ") the exact same way
-- fetchApprovedMembers did -- a plain `club_event_rsvps` select embedding
-- `profiles` directly. validate_club_event_rsvp() (above) already
-- requires an *approved* club membership to RSVP at all, which is
-- exactly the same "any authenticated session, onboarded or not, can
-- become an approved club_members row" gap club_member_profiles()'s own
-- comment (above) describes -- so a ghost account that joined a public
-- Club can RSVP to its Events too, and would show up here as the same
-- bare "@" / "?" avatar row. Same SECURITY DEFINER approach, mirroring
-- "Approved club members can view event RSVPs" (above) instead of
-- loosening it.
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.
create or replace function public.club_event_attendee_profiles(
  p_event_id uuid,
  p_status text
)
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_url text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_club_id uuid;
begin
  select club_id into v_club_id from public.club_events where id = p_event_id;
  if v_club_id is null then
    raise exception 'Event not found';
  end if;

  -- Mirrors "Approved club members can view event RSVPs" exactly.
  if public.club_role(v_club_id, auth.uid()) is null then
    raise exception 'Not permitted to view this Event''s RSVPs';
  end if;

  if p_status not in ('going', 'maybe', 'not_going') then
    raise exception 'Invalid status: %', p_status;
  end if;

  return query
  select r.user_id, p.username, p.display_name, p.avatar_url
  from public.club_event_rsvps r
  join public.profiles p on p.id = r.user_id
  where r.event_id = p_event_id
    and r.status = p_status
    and exists (
      select 1 from public.profile_private pp
      where pp.id = r.user_id and pp.onboarding_completed = true
    );
end;
$$;

grant execute on function public.club_event_attendee_profiles(uuid, text) to authenticated;

-- WYN-133: Club Chat channel categories -- Discord-style grouping of
-- club_channels (WYN-127) under a named header, e.g. Founder-requested
-- after seeing a Discord screenshot with grouped channel lists. See
-- .wyn/tasks/backlog/WYN-133-club-chat-channel-navigation.md (requirement
-- 7) and .wyn/docs/design/wyn-133-club-chat-channel-navigation.md.
--
-- A category is purely organizational: deleting one never deletes its
-- channels (category_id's ON DELETE SET NULL below), and a channel with
-- no category is exactly today's pre-WYN-133 flat-list channel -- this
-- table is additive/opt-in, not a required migration for any existing
-- Club. Same permission shape as club_channels itself: any authenticated
-- user can read, only that Club's owner/admin can write.
create table if not exists public.club_channel_categories (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  name text not null,
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint club_channel_categories_name_length check (char_length(name) between 1 and 50)
);

-- Case-insensitive per-Club uniqueness, same shape as
-- club_channels_club_id_lower_name_key.
create unique index if not exists club_channel_categories_club_id_lower_name_key
  on public.club_channel_categories (club_id, lower(name));

alter table public.club_channel_categories enable row level security;

create policy "Club channel categories are viewable by authenticated users"
  on public.club_channel_categories
  for select
  to authenticated
  using (true);

create policy "Club owners and admins can create channel categories"
  on public.club_channel_categories
  for insert
  to authenticated
  with check (
    auth.uid() = created_by
    and public.club_role(club_id, auth.uid()) in ('owner', 'admin')
  );

create policy "Club owners and admins can rename channel categories"
  on public.club_channel_categories
  for update
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

create policy "Club owners and admins can delete channel categories"
  on public.club_channel_categories
  for delete
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

-- Nullable by design: every channel that exists before this migration (or
-- that's simply never assigned one) stays "ไม่มีกลุ่ม" with zero backfill
-- needed. ON DELETE SET NULL is what makes "ลบกลุ่มแล้วห้องไม่หาย" true at
-- the database level, for free, with no extra application logic --
-- deleting a category just clears category_id on its former channels.
-- Reuses club_channels' existing "Club owners and admins can rename
-- channels" UPDATE policy (an unrestricted-by-column USING clause) --
-- no new RLS policy needed to let an owner/admin move a channel between
-- categories.
alter table public.club_channels
  add column if not exists category_id uuid references public.club_channel_categories (id) on delete set null;

-- ============================================================
-- WYN-134: DM "New Message" Notification
-- ============================================================
-- See .wyn/tasks/active/WYN-134-dm-new-message-notification.md and
-- .wyn/docs/design/wyn-134-dm-new-message-notification.md. Closes a
-- known gap accepted since WYN-032: an 'active' (not 'pending') 1:1
-- conversation had no notification at all for a new incoming message
-- unless the recipient happened to have ConversationScreen open
-- (realtime only) -- unlike Club, which already got this via WYN-116.
-- No new column: reuses notifications.conversation_id, added by
-- WYN-032 for message_request.
--
-- Mirrors the 'redrop'/'club_channel_message' additions above:
-- dynamically find+drop whatever the current CHECK constraint name is
-- rather than assuming a specific name.
do $$
declare
  v_constraint_name text;
begin
  select tc.constraint_name into v_constraint_name
  from information_schema.table_constraints tc
  join information_schema.constraint_column_usage ccu
    on ccu.constraint_name = tc.constraint_name
   and ccu.constraint_schema = tc.constraint_schema
  where tc.table_schema = 'public'
    and tc.table_name = 'notifications'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'type';

  if v_constraint_name is not null then
    execute format('alter table public.notifications drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'like_drop', 'like_pop', 'comment_drop', 'comment_pop', 'follow',
    'club_join_request', 'club_join_approved', 'club_post_like', 'club_post_comment',
    'mention_drop', 'mention_club_post',
    'moderation_warning', 'moderation_content_removed',
    'appeal_approved', 'appeal_rejected',
    'message_request', 'redrop',
    'follow_request', 'follow_request_accepted',
    'system',
    'club_post_new', 'club_post_pinned',
    'club_invite',
    -- WYN-134: fired by notify_new_message() below.
    'new_message'
  ));

-- notify_new_message(): AFTER INSERT on messages -- mirrors
-- get_or_create_conversation()'s own message_request insert exactly
-- (same 'messages' notification_enabled category). Only fires for an
-- 'active' conversation -- a 'pending' one already got its one-time
-- message_request notification at creation (see that function) and
-- must not re-fire on every message the requester sends while
-- waiting on a decision. No block/posting-restriction check needed
-- here either: the messages INSERT policy already rejects a blocked-
-- either-way/posting-blocked sender before this trigger ever runs, so
-- a row only ever reaches here having already passed that gate.
create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation public.conversations;
  v_recipient uuid;
begin
  select * into v_conversation from public.conversations where id = new.conversation_id;
  if v_conversation is null or v_conversation.status <> 'active' then
    return new;
  end if;

  v_recipient := case when v_conversation.user_a_id = new.sender_id
                       then v_conversation.user_b_id
                       else v_conversation.user_a_id end;

  -- WYN-031: respects the recipient's own per-conversation mute.
  if exists (
    select 1 from public.conversation_mutes
    where conversation_id = new.conversation_id and user_id = v_recipient
  ) then
    return new;
  end if;

  if internal.notification_enabled(v_recipient, 'messages') then
    insert into public.notifications (recipient_id, actor_id, type, conversation_id)
    values (v_recipient, new.sender_id, 'new_message', new.conversation_id);
  end if;

  return new;
end;
$$;

drop trigger if exists messages_notify_new_message on public.messages;
create trigger messages_notify_new_message
  after insert on public.messages
  for each row execute function public.notify_new_message();

-- mark_conversation_read(): full re-definition (not just a new branch)
-- -- now also clears any unread new_message notification(s) for this
-- conversation, in the same transaction. This is the entire mechanism
-- behind "opened the conversation right when the message arrived never
-- visibly shows an unread badge" (see the design doc's "การตัดสินใจ
-- สำคัญ" section): ConversationScreen already calls this RPC on
-- initState, on every realtime message received while the screen is
-- open (_onRealtimeMessage), and on resume-from-background -- no
-- client change needed for this AC.
create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
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

  update public.conversations
  set user_a_last_read_at = case when user_a_id = v_me then now() else user_a_last_read_at end,
      user_b_last_read_at = case when user_b_id = v_me then now() else user_b_last_read_at end
  where id = p_conversation_id and v_me in (user_a_id, user_b_id);

  if not found then
    raise exception 'Conversation not found, or you are not a participant';
  end if;

  update public.notifications
  set is_read = true
  where recipient_id = v_me
    and conversation_id = p_conversation_id
    and type = 'new_message'
    and is_read = false;
end;
$$;

-- ============================================================
-- WYN-138: DM Message Actions -- Edit Message + Pin Message
-- ============================================================
-- See .wyn/tasks/active/WYN-138-dm-message-edit-pin.md and
-- .wyn/docs/design/wyn-138-dm-message-edit-pin.md.

alter table public.messages add column if not exists edited_at timestamptz;

-- edit_message(): mirrors delete_message()'s own shape exactly
-- (security definer, no client UPDATE policy on messages at all --
-- every existing-row mutation goes through an RPC like this one).
-- Restricted to plain-text messages only (Requirement: "แก้ไขได้เฉพาะ
-- ข้อความ text เท่านั้น") -- a message carrying an image and/or shared
-- content is rejected outright, even if it also has a text caption, to
-- avoid ambiguity over "editing just the caption".
create or replace function public.edit_message(p_message_id uuid, p_text text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trimmed text := trim(coalesce(p_text, ''));
begin
  if length(v_trimmed) = 0 then
    raise exception 'Message text cannot be empty';
  end if;

  update public.messages
  set text = v_trimmed, edited_at = now()
  where id = p_message_id
    and sender_id = auth.uid()
    and deleted_at is null
    and image_url is null
    and shared_content_id is null;

  if not found then
    raise exception 'Message not found, not yours, deleted, or not a plain text message';
  end if;
end;
$$;

grant execute on function public.edit_message(uuid, text) to authenticated;

-- message_pins: no client insert/update/delete policy -- pin_message()/
-- unpin_message() below are the only way to write this table (mirrors
-- messages/club_members' own "cross-row business logic (here: the
-- 3-per-conversation cap) belongs in an RPC, not a plain RLS check"
-- posture).
create table if not exists public.message_pins (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  message_id uuid not null references public.messages (id) on delete cascade,
  pinned_by uuid not null references public.profiles (id) on delete cascade,
  pinned_at timestamptz not null default now(),
  primary key (conversation_id, message_id)
);

create index if not exists message_pins_conversation_idx
  on public.message_pins (conversation_id, pinned_at desc);

alter table public.message_pins enable row level security;

create policy "Participants can view pinned messages in their conversations"
  on public.message_pins
  for select
  to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id and auth.uid() in (c.user_a_id, c.user_b_id)
    )
  );

-- pin_message(): either participant may pin (Requirement: DM has no
-- staff/admin hierarchy, unlike Club Chat -- see WYN-135), capped at 3
-- pinned messages per conversation. Read-then-check on the count
-- (not `select ... for update`) -- a race between both participants
-- pinning the 3rd slot at once could in theory land on 4, an accepted
-- low-risk trade-off (see the design doc's own edge-case note), unlike
-- club_invite_links' redeem path (WYN-136) where the usage cap is
-- locked tighter.
create or replace function public.pin_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_conversation_id uuid;
  v_deleted_at timestamptz;
  v_count int;
begin
  select conversation_id, deleted_at into v_conversation_id, v_deleted_at
  from public.messages where id = p_message_id;

  if v_conversation_id is null then
    raise exception 'Message not found';
  end if;
  if v_deleted_at is not null then
    raise exception 'Cannot pin a deleted message';
  end if;
  if not exists (
    select 1 from public.conversations c
    where c.id = v_conversation_id and v_me in (c.user_a_id, c.user_b_id)
  ) then
    raise exception 'Not a participant of this conversation';
  end if;

  select count(*) into v_count from public.message_pins where conversation_id = v_conversation_id;
  if v_count >= 3 then
    raise exception 'At most 3 pinned messages allowed per conversation';
  end if;

  insert into public.message_pins (conversation_id, message_id, pinned_by)
  values (v_conversation_id, p_message_id, v_me)
  on conflict (conversation_id, message_id) do nothing;
end;
$$;

grant execute on function public.pin_message(uuid) to authenticated;

-- unpin_message(): deliberately not restricted to whoever pinned it --
-- either participant can unpin, same "no hierarchy, 2 equal people"
-- reasoning as pin_message() above.
create or replace function public.unpin_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  delete from public.message_pins mp
  using public.conversations c
  where mp.message_id = p_message_id
    and mp.conversation_id = c.id
    and v_me in (c.user_a_id, c.user_b_id);

  if not found then
    raise exception 'Pinned message not found, or you are not a participant';
  end if;
end;
$$;

grant execute on function public.unpin_message(uuid) to authenticated;

-- delete_message(): full re-definition -- now also auto-unpins
-- (FK `on delete cascade` on message_pins.message_id can't help here,
-- since this is a soft-delete via UPDATE, not a real DELETE on
-- messages).
create or replace function public.delete_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.messages
  set text = null, image_url = null, shared_content_type = null, shared_content_id = null, deleted_at = now()
  where id = p_message_id and sender_id = auth.uid() and deleted_at is null;

  if not found then
    raise exception 'Message not found, already deleted, or not yours';
  end if;

  delete from public.message_pins where message_id = p_message_id;
end;
$$;

-- ============================================================
-- WYN-139: DM Presence -- Typing Indicator + Online/Last Seen
-- ============================================================
-- See .wyn/tasks/active/WYN-139-dm-presence-typing-online.md and
-- .wyn/docs/design/wyn-139-dm-presence-typing-online.md.
--
-- Deliberately a table separate from `profiles` -- that table's own
-- SELECT policy is `using (true)` (every authenticated user can read
-- every column of every row), so a `last_seen_at`/`show_online_status`
-- column living there directly would leak with no reciprocal check at
-- all. Mirrors `notification_settings`'s own shape: a table with a
-- strict "your own row only" SELECT policy, read-others only via a
-- SECURITY DEFINER RPC that enforces the real rule server-side.

create table if not exists public.user_presence (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  show_online_status boolean not null default true,
  last_seen_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.user_presence enable row level security;

create policy "Users can view their own presence row"
  on public.user_presence
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert their own presence row"
  on public.user_presence
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own presence row"
  on public.user_presence
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- touch_my_presence(): persists this user's own last_seen_at -- called
-- on AppLifecycleState.paused/detached (best-effort, same posture as
-- every other lifecycle hook in this app -- a killed-outright app
-- misses this call, an accepted known limitation).
create or replace function public.touch_my_presence()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_presence (user_id, last_seen_at)
  values (auth.uid(), now())
  on conflict (user_id) do update
    set last_seen_at = excluded.last_seen_at, updated_at = now();
end;
$$;

grant execute on function public.touch_my_presence() to authenticated;

-- get_conversation_partner_presence(): the one place a client can read
-- another user's presence -- enforces the reciprocal privacy check
-- (Requirement, WhatsApp-standard: turning your own visibility off also
-- hides everyone else's from you) in the same statement, so there is
-- exactly one place this rule can ever be wrong.
create or replace function public.get_conversation_partner_presence(p_conversation_id uuid)
returns table (show_online boolean, last_seen_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_other uuid;
  v_my_show boolean;
  v_other_show boolean;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;

  select case when user_a_id = v_me then user_b_id
              when user_b_id = v_me then user_a_id end
  into v_other
  from public.conversations
  where id = p_conversation_id and v_me in (user_a_id, user_b_id);

  if v_other is null then
    raise exception 'Conversation not found, or you are not a participant';
  end if;

  select coalesce(up.show_online_status, true) into v_my_show
  from public.user_presence up where up.user_id = v_me;
  select coalesce(up.show_online_status, true) into v_other_show
  from public.user_presence up where up.user_id = v_other;

  if coalesce(v_my_show, true) = false or coalesce(v_other_show, true) = false then
    return query select false, null::timestamptz;
    return;
  end if;

  -- Coding-time fix vs. the design doc's literal SQL (a `from
  -- user_presence where user_id = v_other` here returns *zero* rows,
  -- not a row with a null last_seen_at, for a partner who has never had
  -- a user_presence row written at all yet -- e.g. a brand new account
  -- that has been online continuously since signup and never once
  -- backgrounded the app to trigger touch_my_presence()). The design
  -- doc's own Edge Cases section explicitly expects a returned row with
  -- last_seen_at = null in that case ("last_seen_at เป็น null จริง"), not
  -- an empty result -- a scalar subquery guarantees exactly one row is
  -- always returned once reciprocal-check has passed, with last_seen_at
  -- naturally null when no row exists yet.
  return query
    select true, (select up.last_seen_at from public.user_presence up where up.user_id = v_other);
end;
$$;

grant execute on function public.get_conversation_partner_presence(uuid) to authenticated;

-- ============================================================
-- WYN-136: Club Invite Link (generate/revoke/expiration/max-uses)
-- ============================================================
-- See .wyn/tasks/active/WYN-136-club-invite-link.md and
-- .wyn/docs/design/wyn-136-club-invite-link.md. Founder locked "ทางเลือก
-- A" (2026-09-07, .wyn/company/DECISIONS.md): a valid invite link joins
-- a Private Club immediately, skipping Join Request/Approve entirely --
-- redeem_club_invite_link() below is written for that choice only.

create table if not exists public.club_invite_links (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  code text not null,
  created_by uuid not null references public.profiles (id) on delete cascade,
  expires_at timestamptz,
  max_uses integer,
  use_count integer not null default 0,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint club_invite_links_max_uses_positive check (max_uses is null or max_uses > 0)
);

create unique index if not exists club_invite_links_code_idx on public.club_invite_links (code);
create index if not exists club_invite_links_club_id_idx on public.club_invite_links (club_id, created_at desc);

alter table public.club_invite_links enable row level security;

create policy "Owners/admins can view their club's invite links"
  on public.club_invite_links
  for select
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

-- ไม่มี insert/update/delete policy ให้ client -- RPC ด้านล่างเท่านั้น
-- (เหมือน club_members ทุกจุด)

-- Requirement: "Track ว่าสมาชิกใหม่แต่ละคน join ผ่านลิงก์ไหน" -- เก็บ
-- data ไว้เฉยๆ ยังไม่ต้องมี UI แสดงผลรอบนี้ (Owner Insights ในอนาคต)
create table if not exists public.club_invite_link_uses (
  link_id uuid not null references public.club_invite_links (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  used_at timestamptz not null default now(),
  primary key (link_id, user_id)
);
-- ไม่มี SELECT policy เลยในรอบนี้ตามที่ Requirement บอกว่าไม่บังคับ UI --
-- เขียนได้ทางเดียวผ่าน redeem_club_invite_link() (security definer)
-- อ่านทีหลังผ่าน RPC ใหม่เมื่อ Owner Insights ต้องการจริง (ไม่ scope รอบนี้)
alter table public.club_invite_link_uses enable row level security;

-- RPC 1: create_club_invite_link() -- Owner/Admin เท่านั้น
create or replace function public.create_club_invite_link(
  p_club_id uuid,
  p_expires_in_days integer default null, -- null = ไม่มีวันหมดอายุ; ค่าที่ UI ให้เลือก: null/1/7/30
  p_max_uses integer default null          -- null = ไม่จำกัด; ค่าที่ UI ให้เลือก: null/10/50/100
)
returns public.club_invite_links
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_code text;
  v_row public.club_invite_links;
begin
  if coalesce(public.club_role(p_club_id, v_me), '') not in ('owner', 'admin') then
    raise exception 'Not permitted to create invite links for this club';
  end if;
  if p_max_uses is not null and p_max_uses <= 0 then
    raise exception 'max_uses must be positive';
  end if;

  loop
    v_code := substr(md5(random()::text || clock_timestamp()::text), 1, 10);
    begin
      insert into public.club_invite_links (club_id, code, created_by, expires_at, max_uses)
      values (
        p_club_id,
        v_code,
        v_me,
        case when p_expires_in_days is null then null
             else now() + (p_expires_in_days || ' days')::interval end,
        p_max_uses
      )
      returning * into v_row;
      exit;
    exception when unique_violation then
      -- ชนกันของ code (โอกาสน้อยมาก, 10 ตัวอักษรจาก md5) -- สุ่มใหม่แล้วลองอีกรอบ
      continue;
    end;
  end loop;

  return v_row;
end;
$$;

grant execute on function public.create_club_invite_link(uuid, integer, integer) to authenticated;

-- RPC 2: revoke_club_invite_link() -- Owner/Admin เท่านั้น
create or replace function public.revoke_club_invite_link(p_link_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_club_id uuid;
begin
  select club_id into v_club_id from public.club_invite_links where id = p_link_id;
  if v_club_id is null then
    raise exception 'Invite link not found';
  end if;
  if coalesce(public.club_role(v_club_id, v_me), '') not in ('owner', 'admin') then
    raise exception 'Not permitted to revoke invite links for this club';
  end if;

  update public.club_invite_links
  set revoked_at = now()
  where id = p_link_id and revoked_at is null;

  if not found then
    raise exception 'Invite link already revoked, or not found';
  end if;
end;
$$;

grant execute on function public.revoke_club_invite_link(uuid) to authenticated;

-- RPC 3: preview_club_invite_link() -- ทุกคนเรียกได้ รวม guest/anonymous
create or replace function public.preview_club_invite_link(p_code text)
returns table (
  status text, -- 'valid' | 'expired' | 'revoked' | 'exhausted' | 'not_found'
  club_id uuid,
  club_name text,
  club_privacy text,
  club_icon_url text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    case
      when l.id is null then 'not_found'
      when l.revoked_at is not null then 'revoked'
      when l.expires_at is not null and l.expires_at < now() then 'expired'
      when l.max_uses is not null and l.use_count >= l.max_uses then 'exhausted'
      else 'valid'
    end,
    c.id, c.name, c.privacy, c.icon_url
  from public.club_invite_links l
  right join (select p_code as code) req on true
  left join public.clubs c on c.id = l.club_id
  where l.code = req.code or l.code is null
  limit 1;
$$;

grant execute on function public.preview_club_invite_link(text) to authenticated;

-- RPC 4: redeem_club_invite_link() -- join จริง. Founder ยืนยันทางเลือก A
-- (2026-09-07, .wyn/company/DECISIONS.md): invite link ที่ valid =
-- อนุมัติล่วงหน้าในตัวเสมอ ไม่ว่า club จะเป็น public หรือ private -- `for
-- update` บนแถวลิงก์ตอน select กันสองคนกด max-uses ช่องสุดท้ายพร้อมกันแบบ
-- race (คุมเข้มกว่า pin_message ของ WYN-138 เพราะเป็นเรื่อง "จำนวนครั้ง
-- ใช้งานสูงสุด" ที่ Owner ตั้งใจจำกัดไว้จริงจัง).
create or replace function public.redeem_club_invite_link(p_code text)
returns uuid -- club_id เมื่อสำเร็จ
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_link public.club_invite_links;
  v_club public.clubs;
  v_already_approved boolean;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_link from public.club_invite_links where code = p_code for update;
  if v_link.id is null then raise exception 'Invite link not found'; end if;
  if v_link.revoked_at is not null then raise exception 'This invite link has been revoked'; end if;
  if v_link.expires_at is not null and v_link.expires_at < now() then
    raise exception 'This invite link has expired';
  end if;
  if v_link.max_uses is not null and v_link.use_count >= v_link.max_uses then
    raise exception 'This invite link has reached its usage limit';
  end if;

  select * into v_club from public.clubs where id = v_link.club_id;

  if exists (
    select 1 from public.club_members
    where club_id = v_club.id and user_id = v_me and status = 'banned'
  ) then
    raise exception 'You have been banned from this club';
  end if;

  -- Founder ยืนยันทางเลือก A (2026-09-07, .wyn/company/DECISIONS.md):
  -- invite link ที่ valid = อนุมัติล่วงหน้าในตัวเสมอ ไม่ว่า club จะเป็น public หรือ private
  insert into public.club_members (club_id, user_id, role, status)
  values (v_club.id, v_me, 'member', 'approved')
  on conflict (club_id, user_id)
  do update set status = 'approved'
  where public.club_members.status = 'pending';
  -- upgrade แถว pending เดิม (จาก join ปกติที่ยังไม่ได้รับอนุมัติ) เป็น approved ทันที
  -- ให้สอดคล้องกับเจตนาของทางเลือก A ("ลิงก์เชิญ = อนุมัติล่วงหน้าแล้ว") --
  -- ไม่ทำอะไรกับแถวที่เป็น approved/banned อยู่แล้ว (do update ...where... กรองไว้)

  select exists (
    select 1 from public.club_members
    where club_id = v_club.id and user_id = v_me and status = 'approved'
  ) into v_already_approved;

  -- นับ use_count/บันทึก attribution เฉพาะตอนเป็นการเข้าร่วมใหม่จริง
  -- (ไม่ใช่การกดลิงก์ซ้ำของสมาชิกเดิม/คนที่ pending อยู่แล้วจาก join ปกติ)
  if not exists (select 1 from public.club_invite_link_uses where link_id = v_link.id and user_id = v_me) then
    update public.club_invite_links set use_count = use_count + 1 where id = v_link.id;
    insert into public.club_invite_link_uses (link_id, user_id) values (v_link.id, v_me);
  end if;

  return v_club.id;
end;
$$;

grant execute on function public.redeem_club_invite_link(text) to authenticated;
-- ============================================================
-- WYN-148: Atomic and idempotent non-poll Drop publication
-- ============================================================

alter table public.drops
  add column if not exists publication_operation_id uuid;

create unique index if not exists drops_publication_operation_id_key
  on public.drops (publication_operation_id)
  where publication_operation_id is not null;

create or replace function public.drop_id_for_publication(p_operation_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select d.id from public.drops d
  where d.publication_operation_id = p_operation_id
    and d.author_id = auth.uid();
$$;

revoke all on function public.drop_id_for_publication(uuid) from public, anon;
grant execute on function public.drop_id_for_publication(uuid) to authenticated;

create or replace function public.publish_drop(
  p_operation_id uuid, p_image_url text, p_caption text, p_audience text,
  p_excluded_friend_ids uuid[] default '{}', p_images jsonb default '[]'::jsonb,
  p_mentioned_user_ids uuid[] default '{}', p_location text default null,
  p_location_lat double precision default null,
  p_location_lon double precision default null, p_location_place_id text default null,
  p_image_width integer default null, p_image_height integer default null,
  p_image_aspect_ratio text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid := auth.uid();
  v_drop_id uuid;
  v_image_count integer;
begin
  if v_author is null then raise exception 'Not authenticated'; end if;
  if p_operation_id is null then raise exception 'Publication operation ID is required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,0));
  select d.id into v_drop_id from public.drops d
  where d.publication_operation_id=p_operation_id and d.author_id=v_author;
  if v_drop_id is not null then return v_drop_id; end if;
  if internal.is_posting_blocked(v_author) then raise exception 'Account is posting-restricted'; end if;
  if p_audience not in ('everyone','friends','friends_except','close_friends','only_me') then raise exception 'Invalid audience'; end if;
  if p_image_url is null and nullif(trim(p_caption),'') is null then raise exception 'A Drop requires an image or caption'; end if;
  if p_caption is not null and char_length(trim(p_caption))>500 then raise exception 'Caption exceeds 500 characters'; end if;
  if (p_location_lat is null)<>(p_location_lon is null)
     or (p_location_lat is not null and p_location_lat not between -90 and 90)
     or (p_location_lon is not null and p_location_lon not between -180 and 180)
  then raise exception 'Invalid location coordinates'; end if;
  if p_images is null or jsonb_typeof(p_images)<>'array' then raise exception 'Images must be an array'; end if;
  v_image_count:=jsonb_array_length(p_images);
  if v_image_count>9 or (p_image_url is null and v_image_count<>0)
     or (p_image_url is not null and v_image_count not between 1 and 9)
  then raise exception 'Invalid image count'; end if;
  if exists (
    select 1 from jsonb_array_elements(p_images) with ordinality e(value,ordinal)
    where jsonb_typeof(value)<>'object' or nullif(value->>'image_url','') is null
       or (value->>'position') is null or (value->>'position')!~'^[0-9]+$'
       or (value->>'position')::integer<>ordinal-1
       or (value->>'position')::integer not between 0 and 8
       or ((value->>'image_width') is not null and (value->>'image_width')!~'^[1-9][0-9]*$')
       or ((value->>'image_height') is not null and (value->>'image_height')!~'^[1-9][0-9]*$')
  ) then raise exception 'Invalid image metadata'; end if;
  if v_image_count>0 and (p_images->0->>'image_url') is distinct from p_image_url then raise exception 'Primary image does not match image position zero'; end if;
  if p_audience<>'friends_except' and coalesce(cardinality(p_excluded_friend_ids),0)<>0 then raise exception 'Audience exclusions require friends_except'; end if;
  if coalesce(cardinality(p_excluded_friend_ids),0)<>coalesce((select count(distinct x) from unnest(p_excluded_friend_ids)x),0)
     or exists(select 1 from unnest(p_excluded_friend_ids)x where x=v_author
       or not exists(select 1 from public.profiles p where p.id=x)
       or not internal.is_mutual_follow(v_author,x))
  then raise exception 'Invalid audience exclusions'; end if;
  if coalesce(cardinality(p_mentioned_user_ids),0)<>coalesce((select count(distinct x) from unnest(p_mentioned_user_ids)x),0)
     or exists(select 1 from unnest(p_mentioned_user_ids)x where not exists(select 1 from public.profiles p where p.id=x))
  then raise exception 'Invalid mentioned users'; end if;
  insert into public.drops(author_id,image_url,caption,audience,publication_operation_id,
    location,location_lat,location_lon,location_place_id,image_width,image_height,image_aspect_ratio)
  values(v_author,p_image_url,nullif(trim(p_caption),''),p_audience,p_operation_id,
    p_location,p_location_lat,p_location_lon,p_location_place_id,p_image_width,p_image_height,p_image_aspect_ratio)
  returning id into v_drop_id;
  if p_audience='friends_except' then
    insert into public.drop_audience_exclusions(drop_id,excluded_user_id)
    select v_drop_id,x from unnest(p_excluded_friend_ids)x;
  end if;
  insert into public.drop_images(drop_id,image_url,position,image_width,image_height)
  select v_drop_id,e.value->>'image_url',(e.value->>'position')::integer,
    nullif(e.value->>'image_width','')::integer,nullif(e.value->>'image_height','')::integer
  from jsonb_array_elements(p_images)e(value);
  insert into public.drop_mentions(drop_id,mentioned_user_id)
  select v_drop_id,x from unnest(p_mentioned_user_ids)x
  where not internal.is_blocked_either_way(v_author,x)
    and internal.mention_allowed(x,v_author);
  return v_drop_id;
end;
$$;

revoke all on function public.publish_drop(uuid,text,text,text,uuid[],jsonb,uuid[],text,double precision,double precision,text,integer,integer,text) from public,anon;
grant execute on function public.publish_drop(uuid,text,text,text,uuid[],jsonb,uuid[],text,double precision,double precision,text,integer,integer,text) to authenticated;
