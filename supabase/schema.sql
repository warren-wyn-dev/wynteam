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
  constraint club_posts_image_urls_length
    check (image_urls is null or array_length(image_urls, 1) between 1 and 10),
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
-- ZOKY-001: Marketplace Foundation (WYN Platform expansion)
-- ============================================================
-- Browse-only round -- no Cart/Checkout/Order yet (ZOKY-003). Every
-- table below is read-only to clients: select-all-authenticated like
-- clubs/drops/pops, but deliberately *no* insert/update/delete policy
-- at all, because there's no Seller workflow yet to decide who may
-- write a store/product (that's ZOKY Sellers by WYN, Phase 4 -- see
-- .wyn/docs/product/zoky-platform-roadmap.md). Sample data for this
-- round is seeded through Supabase Studio directly, not through the
-- client.

-- Fixed commerce category list (unlike clubCategories, which is a
-- pure Dart constant, this is a real FK table because products.
-- category_id needs referential integrity) -- seeded below since the
-- set is fixed for this round, same spirit as a CHECK-constrained enum
-- elsewhere in this schema, just modeled as rows instead of a CHECK
-- list because it's referenced by foreign key.
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

alter table public.categories enable row level security;

create policy "Categories are viewable by authenticated users"
  on public.categories
  for select
  to authenticated
  using (true);

insert into public.categories (name) values
  ('Fashion'), ('Electronics'), ('Beauty'), ('Home & Living'),
  ('Sports & Outdoor'), ('Toys & Hobbies'), ('Food & Beverage'),
  ('Books & Stationery'), ('Health')
on conflict (name) do nothing;

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  description text,
  logo_url text,
  banner_url text,
  created_at timestamptz not null default now(),
  constraint stores_name_length check (char_length(name) between 1 and 100)
);

alter table public.stores enable row level security;

create policy "Stores are viewable by authenticated users"
  on public.stores
  for select
  to authenticated
  using (true);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  category_id uuid references public.categories (id) on delete set null,
  name text not null,
  description text,
  price numeric(12, 2) not null,
  original_price numeric(12, 2),
  stock int not null default 0,
  image_urls text[] not null,
  created_at timestamptz not null default now(),
  constraint products_name_length check (char_length(name) between 1 and 200),
  constraint products_price_nonnegative check (price >= 0),
  constraint products_original_price_gte_price
    check (original_price is null or original_price >= price),
  constraint products_stock_nonnegative check (stock >= 0),
  constraint products_image_urls_length check (array_length(image_urls, 1) between 1 and 10)
);

create index if not exists products_store_id_idx on public.products (store_id);
create index if not exists products_category_id_idx on public.products (category_id);
create index if not exists products_created_at_idx on public.products (created_at desc);

alter table public.products enable row level security;

create policy "Products are viewable by authenticated users"
  on public.products
  for select
  to authenticated
  using (true);

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  variant_type text not null check (variant_type in ('color', 'size')),
  variant_value text not null,
  price_delta numeric(12, 2),
  stock int not null default 0,
  constraint product_variants_stock_nonnegative check (stock >= 0),
  constraint product_variants_unique_value unique (product_id, variant_type, variant_value)
);

alter table public.product_variants enable row level security;

create policy "Product variants are viewable by authenticated users"
  on public.product_variants
  for select
  to authenticated
  using (true);

-- ============================================================
-- ZOKY-003: Cart & Checkout & Order (WYN Platform expansion)
-- ============================================================
-- Cart is plain per-row CRUD (a client may freely insert/update/delete
-- its own cart_items -- no RPC needed, since nothing here is
-- security/atomicity-critical: the only value that must be trustworthy
-- is checked again, server-side, at order-creation time). Orders and
-- order_items are the opposite -- no insert/update/delete policy for
-- clients at all, because creating/mutating one always involves
-- business logic (stock check + deduction + fee calculation) that must
-- run atomically and can't be trusted to a raw client write, same
-- reasoning as club_members' role/status transitions (WYN-014).

-- Editable platform-wide settings, e.g. the marketplace fee percentage.
-- A real config table (not a Dart constant) so the Founder can change
-- it without an app release -- see .wyn/tasks/backlog/
-- ZOKY-003-cart-checkout-order.md, Requirements. Each Order snapshots
-- the fee percent it used at creation time (see orders.fee_percent
-- below) rather than re-reading this table later, so a future change
-- here never alters an already-placed Order's historical total.
create table if not exists public.platform_config (
  key text primary key,
  value text not null
);

alter table public.platform_config enable row level security;

create policy "Platform config is viewable by authenticated users"
  on public.platform_config
  for select
  to authenticated
  using (true);

insert into public.platform_config (key, value) values
  ('zoky_marketplace_fee_percent', '10')
on conflict (key) do nothing;

-- variant_selection defaults to '' (not null) rather than being
-- nullable, specifically so the unique constraint below treats "same
-- product, no variant chosen" as one line consistently -- Postgres
-- unique constraints treat every NULL as distinct from every other
-- NULL, so a nullable column here would let "Add to Cart" on the same
-- no-variant product create a new row every time instead of
-- incrementing quantity on the existing one.
create table if not exists public.cart_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  variant_selection text not null default '',
  quantity int not null default 1,
  created_at timestamptz not null default now(),
  constraint cart_items_quantity_positive check (quantity > 0),
  constraint cart_items_unique_line unique (user_id, product_id, variant_selection)
);

create index if not exists cart_items_user_id_idx on public.cart_items (user_id);

alter table public.cart_items enable row level security;

create policy "Users can view their own cart items"
  on public.cart_items
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert their own cart items"
  on public.cart_items
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own cart items"
  on public.cart_items
  for update
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can delete their own cart items"
  on public.cart_items
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- One row per store per checkout (Product spec: "1 Order ต่อ 1
-- ร้านค้า") -- a cart spanning 3 stores becomes 3 Order rows when the
-- buyer confirms checkout, created together atomically by
-- create_orders() below. status is deliberately a 3-value enum this
-- round (pending/delivered/cancelled) -- there's no separate
-- "shipped" state because there's no ZOKY Sellers by WYN app yet to
-- ever actually set one; see the Product spec's Risks section.
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles (id) on delete cascade,
  store_id uuid not null references public.stores (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'delivered', 'cancelled')),
  recipient_name text not null,
  recipient_phone text not null,
  shipping_address text not null,
  subtotal numeric(12, 2) not null,
  fee_percent numeric(5, 2) not null,
  fee_amount numeric(12, 2) not null,
  total numeric(12, 2) not null,
  created_at timestamptz not null default now(),
  constraint orders_subtotal_nonnegative check (subtotal >= 0),
  constraint orders_fee_percent_nonnegative check (fee_percent >= 0),
  constraint orders_fee_amount_nonnegative check (fee_amount >= 0),
  constraint orders_total_nonnegative check (total >= 0)
);

create index if not exists orders_buyer_id_idx on public.orders (buyer_id, created_at desc);

alter table public.orders enable row level security;

create policy "Buyers can view their own orders"
  on public.orders
  for select
  to authenticated
  using (auth.uid() = buyer_id);

-- Deliberately no insert/update/delete policy at all -- every Order is
-- created by create_orders() and every status transition goes through
-- cancel_order()/confirm_order_received() (all three security definer,
-- below), so a client can never issue a raw insert/update against
-- orders no matter what values it sends.

-- Snapshots product_name/unit_price (and image_url) at the moment of
-- purchase rather than joining products live, because a product's
-- name/price can change (or the product can be deleted -- product_id
-- is on delete set null, not cascade, so the Order itself survives)
-- after the Order is placed, and an Order's historical record must
-- never change retroactively. variant_selection is copied the same
-- way cart_items stores it -- still preview/display-only, never
-- affects stock (see products.stock below).
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  product_name text not null,
  variant_selection text not null default '',
  unit_price numeric(12, 2) not null,
  quantity int not null,
  image_url text,
  constraint order_items_quantity_positive check (quantity > 0),
  constraint order_items_unit_price_nonnegative check (unit_price >= 0)
);

create index if not exists order_items_order_id_idx on public.order_items (order_id);

alter table public.order_items enable row level security;

-- order_items has no buyer_id column of its own, so scoping is via a
-- join back to the owning order -- same "scope through the parent
-- row" shape as club_post_comments scoping through club_posts.
create policy "Buyers can view their own order items"
  on public.order_items
  for select
  to authenticated
  using (
    exists (
      select 1 from public.orders
      where orders.id = order_items.order_id
        and orders.buyer_id = auth.uid()
    )
  );

-- No insert/update/delete policy -- rows are only ever created by
-- create_orders() (security definer), same as order_items' parent.

-- Checks out every cart_items row currently belonging to the caller,
-- grouped into one Order per store, in a single transaction: every
-- product touched is locked up front (in a stable id-ordered sequence,
-- to avoid deadlocking against a concurrent checkout locking an
-- overlapping product set in a different order) so the stock reads
-- below can't race against another transaction between the check and
-- the deduction -- see .wyn/tasks/backlog/ZOKY-003-cart-checkout-
-- order.md, Risks ("race condition ตอนหลาย order พร้อมกันแย่ง stock
-- เดียวกัน"). Raises a distinguishable 'INSUFFICIENT_STOCK:<name>'
-- message (parsed client-side into a typed exception, see
-- ZokyRepository.createOrders) rather than a generic error, so the UI
-- can name the specific product that's short instead of a vague
-- failure. Stock is deducted from products.stock only -- variant-level
-- stock isn't a real SKU-level count yet (see ZOKY-001), so it's never
-- touched here.
--
-- SELLER-002 addition (2026-08-15): also rejects a line whose product
-- has since been soft-deleted (is_active = false) by its seller, even
-- if it's still sitting in the buyer's cart from before that happened
-- -- see .wyn/tasks/backlog/SELLER-002-product-management.md,
-- Requirements #6. This is a single extra `if` added to the existing
-- per-line loop below (checked ahead of the stock check, since "no
-- longer for sale" is the more fundamental reason to reject the line)
-- -- the locking/ordering logic above and the rest of the function are
-- untouched, per that task's explicit warning not to disturb ZOKY-003's
-- already-QA'd atomicity guarantees. Deliberately *not* a parseable
-- 'PRODUCT_INACTIVE:<name>' prefix like INSUFFICIENT_STOCK -- there's
-- no product-specific UI copy required for this case (see the Product
-- spec's Acceptance Criteria), so it falls through
-- ZokyRepository.createOrders' plain `rethrow` and surfaces as the
-- existing generic "สั่งซื้อไม่สำเร็จ ลองใหม่อีกครั้ง" message in
-- ZokyCheckoutSummaryScreen -- no Dart change needed on the Customer
-- side for this to work correctly.
create or replace function public.create_orders(
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text
)
returns setof uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fee_percent numeric(5, 2);
  v_store_id uuid;
  v_item record;
  v_order_id uuid;
  v_subtotal numeric(12, 2);
  v_fee_amount numeric(12, 2);
  v_image_url text;
begin
  if length(trim(p_recipient_name)) = 0 then
    raise exception 'Recipient name is required';
  end if;
  if length(trim(p_recipient_phone)) = 0 then
    raise exception 'Recipient phone is required';
  end if;
  if length(trim(p_shipping_address)) = 0 then
    raise exception 'Shipping address is required';
  end if;

  if not exists (select 1 from public.cart_items where user_id = auth.uid()) then
    raise exception 'Cart is empty';
  end if;

  select coalesce(value::numeric, 10) into v_fee_percent
  from public.platform_config
  where key = 'zoky_marketplace_fee_percent';

  if v_fee_percent is null then
    v_fee_percent := 10;
  end if;

  perform 1
  from public.products
  where id in (select product_id from public.cart_items where user_id = auth.uid())
  order by id
  for update;

  for v_store_id in
    select distinct p.store_id
    from public.cart_items ci
    join public.products p on p.id = ci.product_id
    where ci.user_id = auth.uid()
  loop
    v_subtotal := 0;

    -- SELLER-003 (2026-08-15): status literal changed from 'pending' to
    -- 'paid' -- same state, new name (see the migration comment near the
    -- end of this file, ahead of the SELLER-003 section) -- nothing else
    -- in this function (locking, loop structure, stock/is_active checks)
    -- is touched.
    insert into public.orders (
      buyer_id, store_id, status, recipient_name, recipient_phone,
      shipping_address, subtotal, fee_percent, fee_amount, total
    ) values (
      auth.uid(), v_store_id, 'paid', p_recipient_name, p_recipient_phone,
      p_shipping_address, 0, v_fee_percent, 0, 0
    )
    returning id into v_order_id;

    for v_item in
      select ci.id as cart_item_id, ci.product_id, ci.variant_selection, ci.quantity,
             p.name as product_name, p.price, p.stock, p.image_urls, p.is_active
      from public.cart_items ci
      join public.products p on p.id = ci.product_id
      where ci.user_id = auth.uid() and p.store_id = v_store_id
    loop
      if not v_item.is_active then
        raise exception 'Product is no longer available: %', v_item.product_name;
      end if;

      if v_item.stock < v_item.quantity then
        raise exception 'INSUFFICIENT_STOCK:%', v_item.product_name;
      end if;

      v_image_url := case
        when array_length(v_item.image_urls, 1) > 0 then v_item.image_urls[1]
        else null
      end;

      insert into public.order_items (
        order_id, product_id, product_name, variant_selection, unit_price, quantity, image_url
      ) values (
        v_order_id, v_item.product_id, v_item.product_name, v_item.variant_selection,
        v_item.price, v_item.quantity, v_image_url
      );

      update public.products
      set stock = stock - v_item.quantity
      where id = v_item.product_id;

      delete from public.cart_items where id = v_item.cart_item_id;

      v_subtotal := v_subtotal + (v_item.price * v_item.quantity);
    end loop;

    v_fee_amount := round(v_subtotal * v_fee_percent / 100, 2);

    update public.orders
    set subtotal = v_subtotal,
        fee_amount = v_fee_amount,
        total = v_subtotal + v_fee_amount
    where id = v_order_id;

    return next v_order_id;
  end loop;

  return;
end;
$$;

-- Buyer-only, and only while still 'paid' (SELLER-003, 2026-08-15) --
-- was gated on 'pending' before this task (ZOKY-003's original 3-state
-- design, before there was a Seller app to ever move an order past that
-- one middle state; 'paid' is that same state's new name, see the
-- migration comment near the end of this file). Once a seller starts
-- processing an order (see seller_start_processing below), the buyer
-- can no longer cancel it themselves -- from that point on only the
-- seller can, via seller_cancel_order below (see the Product spec's
-- Requirements #4 for the reasoning). Restocks every item back onto
-- products.stock; skips a line whose product was since deleted
-- (product_id is null after on delete set null) since there's nothing
-- to restock. Locking/loop structure below is untouched by this task.
create or replace function public.cancel_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
begin
  if not exists (
    select 1 from public.orders
    where id = p_order_id and buyer_id = auth.uid() and status = 'paid'
  ) then
    raise exception 'Order not found or cannot be cancelled';
  end if;

  for v_item in
    select product_id, quantity from public.order_items
    where order_id = p_order_id and product_id is not null
  loop
    update public.products
    set stock = stock + v_item.quantity
    where id = v_item.product_id;
  end loop;

  update public.orders set status = 'cancelled' where id = p_order_id;
end;
$$;

-- Buyer-only, and only while still 'shipped' (SELLER-003, 2026-08-15) --
-- was gated on 'pending' before this task, back when "delivered" was
-- reached directly from pending with no separate "shipped" step (there
-- was no Seller app yet to ever set one). Now that seller_ship_order
-- below is the only way an order reaches 'shipped', this is still the
-- only transition into 'delivered' that exists -- just one step later
-- in the flow than before.
create or replace function public.confirm_order_received(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
  set status = 'delivered'
  where id = p_order_id and buyer_id = auth.uid() and status = 'shipped';

  if not found then
    raise exception 'Order not found or cannot be marked as received';
  end if;
end;
$$;

-- ============================================================
-- ZOKY-004: Review (WYN Platform expansion)
-- ============================================================
-- Unlike orders/order_items above, reviews is a single-table write with
-- no multi-row business logic (no stock/fee to compute atomically), so
-- a plain RLS insert policy with an `exists` gate is enough -- no
-- security-definer RPC needed, same reasoning as club_post_comments'
-- membership-gated insert policy (WYN-014). The gate itself is the
-- security-critical part: a review may only be inserted for an
-- order_item the caller actually bought AND whose order has reached
-- 'delivered' (see .wyn/tasks/backlog/ZOKY-004-review.md,
-- Requirements) -- never trusted from anything the client merely
-- claims. average rating is intentionally never stored anywhere here;
-- every screen that shows one computes avg()/count() live at read
-- time (see .wyn/docs/design/zoky-004-review.md's warning to Coding)
-- -- the opposite principle from orders.fee_percent's snapshot, and
-- deliberately so: a fee must never change after the fact, but a
-- product's rating must always reflect its current reviews.
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null unique references public.order_items (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  rating int not null,
  text_content text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reviews_rating_range check (rating between 1 and 5)
);

create index if not exists reviews_product_id_idx on public.reviews (product_id, created_at desc);
create index if not exists reviews_user_id_idx on public.reviews (user_id);

alter table public.reviews enable row level security;

-- Reviews are ordinary public content, same as Drop/Pop/Club posts --
-- readable by any authenticated user regardless of whether they wrote
-- it or bought the product themselves.
create policy "Reviews are viewable by authenticated users"
  on public.reviews
  for select
  to authenticated
  using (true);

-- The delivered-order-ownership gate: order_item_id must belong to an
-- order_items row whose product_id matches the one being reviewed (so
-- a client can't submit a review against a different product than the
-- order_item actually snapshots) and whose parent order is the
-- caller's own and already delivered.
create policy "Buyers can review their own delivered order items"
  on public.reviews
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where oi.id = order_item_id
        and oi.product_id = product_id
        and o.buyer_id = auth.uid()
        and o.status = 'delivered'
    )
  );

-- Deleting a review never re-checks the order's status -- once a
-- review has legitimately passed the insert gate above, the order it
-- came from can only ever stay 'delivered' (orders' 3-state design
-- has no transition back out of delivered), and delete has no "new
-- row" whose columns could be retargeted, so plain ownership is
-- enough here.
--
-- Editing is a different story: without an explicit WITH CHECK,
-- Postgres reuses this policy's USING expression as the check on the
-- *new* row too (see the Postgres RLS docs on CREATE POLICY) -- and
-- `auth.uid() = user_id` alone says nothing about order_item_id/
-- product_id, so a bare `using` clause here would let a user edit
-- their own already-legitimate review to retarget it at any
-- product/order_item, including ones they never bought or had
-- delivered (found in QA round 1, see .wyn/tasks/bugs/
-- ZOKY-004-review-update-rls-gap.md). The WITH CHECK below mirrors
-- the insert policy's exists() gate exactly, so whatever
-- order_item_id/product_id the row carries after an update, it must
-- still be a delivered purchase the caller owns.
create policy "Users can update their own reviews"
  on public.reviews
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where oi.id = order_item_id
        and oi.product_id = product_id
        and o.buyer_id = auth.uid()
        and o.status = 'delivered'
    )
  );

create policy "Users can delete their own reviews"
  on public.reviews
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- ============================================================
-- SELLER-001: ZOKY Sellers by WYN — Foundation
-- ============================================================
-- Only 2 additive RLS changes this round -- see .wyn/tasks/backlog/
-- SELLER-001-foundation.md, Database. No new tables: `stores`/
-- `orders`/`order_items` already exist (ZOKY-001/ZOKY-003). No write
-- policy for orders/order_items -- status transitions (SELLER-003)
-- still have to go through a security-definer RPC, same reasoning as
-- create_orders()/cancel_order()/confirm_order_received() already
-- being the only way a client can touch those tables at all.

-- `stores` previously had select-only RLS (any authenticated user, for
-- ZOKY Marketplace browsing) with no way for a client to ever create
-- one -- that's exactly the gap SELLER-001's "สมัครร้าน" flow needs to
-- close. `owner_id` is scoped in both `using` and `with check` for the
-- update policy, per the ZOKY-004 QA lesson that update/delete
-- policies need an explicit `with check` and can't just rely on
-- `using` alone once a policy exists that isn't a bare `auth.uid() =
-- <column>` shape reused verbatim for both -- here it *is* that exact
-- shape for both insert and update, so this mirrors it deliberately
-- rather than by omission (see .wyn/learning/LESSONS_LEARNED.md,
-- 2026-08-15).
create policy "Sellers can create their own store"
  on public.stores
  for insert
  to authenticated
  with check (auth.uid() = owner_id);

create policy "Sellers can update their own store"
  on public.stores
  for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- `orders` previously had exactly one select policy, scoped to the
-- buyer (`auth.uid() = buyer_id`). Postgres RLS combines multiple
-- permissive policies for the same command with OR, so this new
-- policy is purely additive -- it can only let a seller see *more*
-- rows (their own store's orders, regardless of who the buyer is),
-- never fewer, and the buyer policy above is untouched. Scoped via a
-- join back to `stores.owner_id = auth.uid()` rather than trusting a
-- client-supplied store_id filter directly, per the Product spec's
-- Risks ("query filter ต้อง join ผ่าน stores เสมอ ไม่ใช่แค่เช็ค
-- store_id ตรง ๆ").
create policy "Sellers can view orders for their own store"
  on public.orders
  for select
  to authenticated
  using (
    exists (
      select 1 from public.stores
      where stores.id = orders.store_id
        and stores.owner_id = auth.uid()
    )
  );

-- Same shape as order_items' existing buyer-scoped select policy
-- (join back to the parent order), except the ownership check chains
-- one hop further through orders -> stores to reach owner_id. Also
-- purely additive alongside the existing buyer policy for the same
-- reason as orders' seller policy above.
create policy "Sellers can view order items for their own store's orders"
  on public.order_items
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.orders o
      join public.stores s on s.id = o.store_id
      where o.id = order_items.order_id
        and s.owner_id = auth.uid()
    )
  );

-- ============================================================
-- SELLER-002: ZOKY Sellers by WYN — Product Management
-- ============================================================
-- Closes the gap SELLER-001 deliberately left open: `products`/
-- `product_variants` have had select-all-authenticated RLS since
-- ZOKY-001 but *no* insert/update/delete policy for a client at all,
-- because there was no Seller workflow yet to decide who may write one
-- -- see .wyn/tasks/backlog/SELLER-002-product-management.md,
-- Database. The create_orders() edit above (is_active check) is part
-- of this same task -- see the comment directly above that function.

-- Soft-delete flag -- see the Product spec's Requirements #4 for the
-- full reasoning (cart_items.product_id is `on delete cascade`, so a
-- hard-delete would silently vanish a product from other buyers'
-- carts with no explanation; order_items.product_id is `on delete set
-- null` and already snapshots product_name/unit_price/image_url, so
-- order history is unaffected either way). `sku` is a plain optional
-- free-text field, not unique -- see that same doc's Risks
-- ("SKU ไม่บังคับ unique").
alter table public.products add column if not exists is_active boolean not null default true;
alter table public.products add column if not exists sku text;

-- `products` insert/update -- mirrors `stores`' SELLER-001 shape
-- (`with check` on insert, both `using`+`with check` on update, per
-- the ZOKY-004 QA lesson -- see .wyn/learning/LESSONS_LEARNED.md,
-- 2026-08-15) except the ownership check joins back to `stores` via
-- `store_id` instead of comparing `owner_id` directly, since `products`
-- has no `owner_id` column of its own. Deliberately **no delete
-- policy** -- see the Product spec's Requirements #4 ("Soft-delete
-- เท่านั้น"); "deleting" a product from the seller's product list is
-- `setProductActive(id, false)`, a plain update, never a delete.
create policy "Sellers can create products for their own store"
  on public.products
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.stores
      where stores.id = products.store_id
        and stores.owner_id = auth.uid()
    )
  );

create policy "Sellers can update their own store's products"
  on public.products
  for update
  to authenticated
  using (
    exists (
      select 1 from public.stores
      where stores.id = products.store_id
        and stores.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.stores
      where stores.id = products.store_id
        and stores.owner_id = auth.uid()
    )
  );

-- `product_variants` insert/update/delete -- same ownership shape as
-- `products` above, except the `exists` join chains one hop further
-- (`product_variants.product_id -> products.store_id ->
-- stores.owner_id`), same pattern order_items' seller select policy
-- (SELLER-001) already uses for a 2-hop join. Unlike `products`,
-- **delete is allowed** here -- the Product spec's Requirements #4
-- confirms no FK from `cart_items`/`order_items` ever points at
-- `product_variants.id` (`variant_selection` is a free-text snapshot,
-- not a foreign key), so removing a variant a seller no longer offers
-- is a real, safe hard-delete.
create policy "Sellers can create variants for their own store's products"
  on public.product_variants
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.products p
      join public.stores s on s.id = p.store_id
      where p.id = product_variants.product_id
        and s.owner_id = auth.uid()
    )
  );

create policy "Sellers can update variants of their own store's products"
  on public.product_variants
  for update
  to authenticated
  using (
    exists (
      select 1 from public.products p
      join public.stores s on s.id = p.store_id
      where p.id = product_variants.product_id
        and s.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.products p
      join public.stores s on s.id = p.store_id
      where p.id = product_variants.product_id
        and s.owner_id = auth.uid()
    )
  );

create policy "Sellers can delete variants of their own store's products"
  on public.product_variants
  for delete
  to authenticated
  using (
    exists (
      select 1 from public.products p
      join public.stores s on s.id = p.store_id
      where p.id = product_variants.product_id
        and s.owner_id = auth.uid()
    )
  );

-- Stock may only ever move through these two RPCs, never a raw
-- `update ... set stock = <absolute value>` from a client -- see the
-- Product spec's Requirements #5 (race condition with
-- create_orders()'s own `for update` stock deduction). Both take a
-- **delta**, not an absolute value, and re-derive ownership from
-- `auth.uid()` every call rather than trusting anything the client
-- claims, same as club_role()-gated RPCs (WYN-014). `update ... set
-- stock = stock + p_delta ... returning stock into v_new_stock` is a
-- single atomic statement -- Postgres holds the row lock for its
-- whole duration, so two concurrent adjustments serialize correctly
-- with no lost update, no separate read-then-write step needed. If
-- the resulting stock would go negative, the exception raised after
-- the update rolls back that update too (same technique
-- create_orders() already relies on for its own mid-loop exceptions),
-- so the CHECK constraint (products_stock_nonnegative /
-- product_variants_stock_nonnegative) is never actually the thing that
-- rejects the call -- this RPC raises a clean, distinguishable
-- 'INSUFFICIENT_STOCK' message first, which SellerRepository.
-- adjustProductStock/adjustVariantStock catch and translate to
-- "สต็อกไม่พอ" instead of surfacing a raw Postgres error (per the
-- Design spec's StockAdjustmentSheet States). Deliberately no
-- column-level GRANT/REVOKE on the `stock` column (the Product spec
-- calls this optional, "defense-in-depth" -- see its Risks) -- this
-- round enforces "stock is delta-only" at the Dart/UI layer instead
-- (no call site anywhere sends an absolute `stock` value through a raw
-- update; see SellerRepository.updateProduct's comment on this).
create or replace function public.adjust_product_stock(p_product_id uuid, p_delta int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_stock int;
begin
  if not exists (
    select 1 from public.products p
    join public.stores s on s.id = p.store_id
    where p.id = p_product_id and s.owner_id = auth.uid()
  ) then
    raise exception 'Product not found or access denied';
  end if;

  update public.products
  set stock = stock + p_delta
  where id = p_product_id
  returning stock into v_new_stock;

  if v_new_stock < 0 then
    raise exception 'INSUFFICIENT_STOCK';
  end if;

  return v_new_stock;
end;
$$;

create or replace function public.adjust_variant_stock(p_variant_id uuid, p_delta int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_stock int;
begin
  if not exists (
    select 1 from public.product_variants v
    join public.products p on p.id = v.product_id
    join public.stores s on s.id = p.store_id
    where v.id = p_variant_id and s.owner_id = auth.uid()
  ) then
    raise exception 'Variant not found or access denied';
  end if;

  update public.product_variants
  set stock = stock + p_delta
  where id = p_variant_id
  returning stock into v_new_stock;

  if v_new_stock < 0 then
    raise exception 'INSUFFICIENT_STOCK';
  end if;

  return v_new_stock;
end;
$$;

-- Product images: public bucket (unlike club-media -- `products` has
-- had select-all-authenticated RLS with no privacy boundary since
-- ZOKY-001, same reasoning as drop-images/pop-videos being public).
-- Path convention: `{store_id}/{timestamp}-{n}.*` (not `{user_id}/...`
-- like avatars/drop-images) so the ownership check below can scope
-- through `stores.owner_id` the same way the insert/update/delete
-- policies above do, rather than through the uploader's own id --
-- a store's images belong to the *store*, not personally to whichever
-- of its (currently always exactly one, per the Product spec's V1
-- assumption) owner happened to upload them.
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

create policy "Product images are publicly accessible"
  on storage.objects
  for select
  using (bucket_id = 'product-images');

create policy "Sellers can upload their own store's product images"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.stores
      where stores.id = ((storage.foldername(name))[1])::uuid
        and stores.owner_id = auth.uid()
    )
  );

create policy "Sellers can update their own store's product images"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.stores
      where stores.id = ((storage.foldername(name))[1])::uuid
        and stores.owner_id = auth.uid()
    )
  )
  with check (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.stores
      where stores.id = ((storage.foldername(name))[1])::uuid
        and stores.owner_id = auth.uid()
    )
  );

create policy "Sellers can delete their own store's product images"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.stores
      where stores.id = ((storage.foldername(name))[1])::uuid
        and stores.owner_id = auth.uid()
    )
  );

-- ============================================================
-- SELLER-003: ZOKY Sellers by WYN — Order Management
-- ============================================================
-- Expands orders.status from the 3-value enum ZOKY-003 shipped with
-- (pending/delivered/cancelled) to the full 8-value set master prompt
-- Section 10 specifies, now that ZOKY Sellers by WYN (SELLER-001/002)
-- exists to actually trigger the middle states -- see .wyn/tasks/
-- backlog/SELLER-003-order-management.md, Requirements #1. No RLS
-- write policy is added for orders/order_items here -- every status
-- transition (buyer-side and seller-side alike) still goes exclusively
-- through a security-definer RPC, same as ZOKY-003/SELLER-001 already
-- established. reviews (ZOKY-004) is deliberately untouched by this
-- whole section -- its insert/update policies gate on the literal
-- 'delivered' string, which keeps its exact meaning in the new 8-value
-- model (see the Product spec, Requirements #3).
--
-- Migration runs in this exact order so no existing 'pending' row is
-- ever left violating the new, narrower CHECK constraint mid-migration:
--   1. remap every existing 'pending' row to 'paid' first. This project
--      has no real payment gateway (see .wyn/company/DECISIONS.md,
--      2026-08-15), so "pending" always meant "Order created, nothing
--      blocking it" -- exactly what 'paid' means in the new model, not
--      'pending_payment' (which would mean "still waiting to be paid",
--      untrue of any order this codebase has ever created). Idempotent
--      by construction -- once no row is still 'pending', reruns are a
--      no-op. delivered/cancelled rows are never touched by this
--      statement at all.
--   2. verify the existing status CHECK constraint's real name via
--      information_schema before dropping it -- never hardcode a
--      guessed name (see the Product spec's Risks, "ห้ามเดาชื่อ CHECK
--      constraint เดิม").
--   3. add the new 8-value CHECK constraint back.
--   4. change the column default from 'pending' to 'paid' to match.
--   5. add shipping_provider/tracking_number (nullable text) -- written
--      together by seller_ship_order below, read-only everywhere else.
update public.orders set status = 'paid' where status = 'pending';

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
    and tc.table_name = 'orders'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'status'
  limit 1;

  if v_constraint_name is not null then
    execute format('alter table public.orders drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.orders
  add constraint orders_status_check
  check (status in (
    'pending_payment', 'paid', 'seller_processing', 'ready_to_ship',
    'shipped', 'delivered', 'cancelled', 'refunded'
  ));

alter table public.orders alter column status set default 'paid';

alter table public.orders add column if not exists shipping_provider text;
alter table public.orders add column if not exists tracking_number text;

-- The 5 seller-side status-transition RPCs below all share the same
-- shape: a single atomic UPDATE whose WHERE clause carries both the
-- ownership check (join back to stores.owner_id = auth.uid(), same
-- pattern adjust_product_stock/adjust_variant_stock (SELLER-002)
-- already use) and the required source status, so "not found" covers
-- every rejection reason at once (wrong owner, wrong order, or wrong
-- current status to transition from) -- mirrors confirm_order_received
-- above's exact shape. None of these touch create_orders'/cancel_order's/
-- confirm_order_received's own locking or loop structure at all -- see
-- the Product spec's Requirements #4 and Risks.

-- paid -> seller_processing.
create or replace function public.seller_start_processing(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
  set status = 'seller_processing'
  where id = p_order_id
    and status = 'paid'
    and exists (
      select 1 from public.stores
      where stores.id = orders.store_id
        and stores.owner_id = auth.uid()
    );

  if not found then
    raise exception 'Order not found or cannot start processing';
  end if;
end;
$$;

-- seller_processing -> ready_to_ship.
create or replace function public.seller_mark_ready_to_ship(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
  set status = 'ready_to_ship'
  where id = p_order_id
    and status = 'seller_processing'
    and exists (
      select 1 from public.stores
      where stores.id = orders.store_id
        and stores.owner_id = auth.uid()
    );

  if not found then
    raise exception 'Order not found or cannot be marked ready to ship';
  end if;
end;
$$;

-- ready_to_ship -> shipped, recording the shipping info in the same
-- statement. Both p_shipping_provider/p_tracking_number are required at
-- the UI layer (SellerOrderDetailScreen disables the confirm button
-- until both are non-empty) but not enforced not-null here at the DB
-- level, deliberately -- see the Design spec, Screen:
-- SellerOrderDetailScreen ("DB จะไม่บังคับ not-null เพื่อไม่ปิดทางแก้ไข
-- ในอนาคตถ้าต้อง backfill").
create or replace function public.seller_ship_order(
  p_order_id uuid,
  p_shipping_provider text,
  p_tracking_number text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
  set status = 'shipped',
      shipping_provider = p_shipping_provider,
      tracking_number = p_tracking_number
  where id = p_order_id
    and status = 'ready_to_ship'
    and exists (
      select 1 from public.stores
      where stores.id = orders.store_id
        and stores.owner_id = auth.uid()
    );

  if not found then
    raise exception 'Order not found or cannot be marked as shipped';
  end if;
end;
$$;

-- Seller-side cancel: from paid/seller_processing/ready_to_ship only
-- (once shipped, the buyer is the only one left who can act, via
-- confirm_order_received -- there's no seller-side cancel past that
-- point). Mirrors cancel_order() above's exact shape (existence+
-- ownership check, then restock loop, then the status update as a
-- separate final statement) rather than the single-UPDATE shape of the
-- other 4 RPCs in this section, specifically so the restock loop can
-- run in between -- same reason cancel_order() itself isn't a single
-- UPDATE either.
create or replace function public.seller_cancel_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
begin
  if not exists (
    select 1 from public.orders o
    join public.stores s on s.id = o.store_id
    where o.id = p_order_id
      and s.owner_id = auth.uid()
      and o.status in ('paid', 'seller_processing', 'ready_to_ship')
  ) then
    raise exception 'Order not found or cannot be cancelled';
  end if;

  for v_item in
    select product_id, quantity from public.order_items
    where order_id = p_order_id and product_id is not null
  loop
    update public.products
    set stock = stock + v_item.quantity
    where id = v_item.product_id;
  end loop;

  update public.orders set status = 'cancelled' where id = p_order_id;
end;
$$;

-- Seller-only, from shipped/delivered only -- a pure bookkeeping flag
-- ("we've refunded this buyer") since there's no real payment gateway
-- in this project to actually move money back (see .wyn/company/
-- DECISIONS.md, 2026-08-15, item 6). Deliberately does **not** restock
-- -- unlike seller_cancel_order/cancel_order above, the goods have
-- already physically left the store by the time an order reaches
-- shipped/delivered, so restocking here would claim inventory the
-- store doesn't actually have back on hand; see the Product spec's
-- Requirements #4.
create or replace function public.seller_mark_refunded(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
  set status = 'refunded'
  where id = p_order_id
    and status in ('shipped', 'delivered')
    and exists (
      select 1 from public.stores
      where stores.id = orders.store_id
        and stores.owner_id = auth.uid()
    );

  if not found then
    raise exception 'Order not found or cannot be marked as refunded';
  end if;
end;
$$;

-- ============================================================
-- ZOKY-005 R1: Order Notifications (2026-08-16)
-- ============================================================
-- Closes the gap ZOKY-005's Product spec documents: every other
-- interaction in this project (Like/Comment/Follow/Club events) has
-- had a notification trigger since WYN-012/WYN-015, but orders never
-- did -- a seller had no way to learn about a new order except by
-- opening the app and checking the Orders tab, and a buyer had no way
-- to learn their order shipped/was cancelled/was refunded except the
-- same. order_id is added via `alter table` (not inline in the
-- original `create table public.notifications` far above) for the
-- same reason club_id/club_post_id were (WYN-015): this section runs
-- after `public.orders` exists, not before.
alter table public.notifications
  add column if not exists order_id uuid references public.orders (id) on delete cascade;

-- Same dynamic-constraint-name lookup as the orders.status migration
-- above -- never hardcode a guessed name (see that migration's own
-- comment and .wyn/tasks/backlog/SELLER-003-order-management.md,
-- Risks, which this mirrors).
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
    -- ZOKY-005 R1: order_delivered_confirmed intentionally omitted --
    -- that transition is always the buyer's own action
    -- (confirm_order_received), so there's no one else left to notify
    -- about it. See .wyn/tasks/backlog/ZOKY-005-customer-seller-backend-
    -- integration.md, Requirements R1.
    'new_order', 'order_shipped', 'order_cancelled', 'order_refunded'
  ));

-- Fires once per Order row create_orders() inserts (one per store in
-- the buyer's cart, ZOKY-003) -- recipient is that store's owner, actor
-- is the buyer. Guards a store owner buying from their own store (not
-- normally reachable via the customer app today, but not structurally
-- prevented at the DB level either) the same way every other notify_*
-- trigger guards self-notification.
create or replace function public.notify_new_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
begin
  select owner_id into v_owner_id from public.stores where id = new.store_id;
  if v_owner_id is not null and v_owner_id <> new.buyer_id then
    insert into public.notifications (recipient_id, actor_id, type, order_id)
    values (v_owner_id, new.buyer_id, 'new_order', new.id);
  end if;
  return new;
end;
$$;

create trigger orders_notify_new_order
  after insert on public.orders
  for each row execute function public.notify_new_order();

-- ready_to_ship -> shipped, only ever reached via seller_ship_order
-- above -- recipient is the buyer, actor is the store owner.
create or replace function public.notify_order_shipped()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
begin
  select owner_id into v_owner_id from public.stores where id = new.store_id;
  if v_owner_id is not null and v_owner_id <> new.buyer_id then
    insert into public.notifications (recipient_id, actor_id, type, order_id)
    values (new.buyer_id, v_owner_id, 'order_shipped', new.id);
  end if;
  return new;
end;
$$;

create trigger orders_notify_shipped
  after update on public.orders
  for each row
  when (old.status = 'ready_to_ship' and new.status = 'shipped')
  execute function public.notify_order_shipped();

-- Cancellation can be triggered by either party (cancel_order is
-- buyer-only, seller_cancel_order is seller-only, see above) so unlike
-- every other trigger in this section the notification's direction
-- isn't fixed by which columns changed -- it depends on who called the
-- RPC. auth.uid() still resolves to the original calling user inside
-- this trigger even though both RPCs run security definer, same
-- reasoning notify_club_join_approved's comment (WYN-015) already
-- documents for that trigger.
create or replace function public.notify_order_cancelled()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
begin
  select owner_id into v_owner_id from public.stores where id = new.store_id;
  if auth.uid() = new.buyer_id then
    if v_owner_id is not null and v_owner_id <> new.buyer_id then
      insert into public.notifications (recipient_id, actor_id, type, order_id)
      values (v_owner_id, new.buyer_id, 'order_cancelled', new.id);
    end if;
  elsif v_owner_id is not null and auth.uid() = v_owner_id and v_owner_id <> new.buyer_id then
    insert into public.notifications (recipient_id, actor_id, type, order_id)
    values (new.buyer_id, v_owner_id, 'order_cancelled', new.id);
  end if;
  return new;
end;
$$;

create trigger orders_notify_cancelled
  after update on public.orders
  for each row
  when (old.status <> 'cancelled' and new.status = 'cancelled')
  execute function public.notify_order_cancelled();

-- Seller-only (seller_mark_refunded above) -- recipient is always the
-- buyer, actor is always the store owner, same fixed direction as
-- notify_order_shipped.
create or replace function public.notify_order_refunded()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
begin
  select owner_id into v_owner_id from public.stores where id = new.store_id;
  if v_owner_id is not null and v_owner_id <> new.buyer_id then
    insert into public.notifications (recipient_id, actor_id, type, order_id)
    values (new.buyer_id, v_owner_id, 'order_refunded', new.id);
  end if;
  return new;
end;
$$;

create trigger orders_notify_refunded
  after update on public.orders
  for each row
  when (old.status <> 'refunded' and new.status = 'refunded')
  execute function public.notify_order_refunded();

-- ============================================================
-- SELLER-004: ZOKY Sellers by WYN — Store Management
-- ============================================================
-- Purely additive: 3 new nullable `stores` columns for the fields
-- CreateStoreScreen (SELLER-001) never collected, plus a new public
-- storage bucket for logo/banner uploads. See .wyn/tasks/backlog/
-- SELLER-004-store-management.md, Database.
--
-- No RLS policy changes to `stores` itself -- the existing update
-- policy from SELLER-001 (`using (auth.uid() = owner_id) with check
-- (auth.uid() = owner_id)`) is a row-level policy with no per-column
-- scoping, so it already covers these 3 new columns (and logo_url/
-- banner_url/name/description) automatically. This is the first
-- SELLER task that doesn't touch a single RLS policy on its main
-- table.

alter table public.stores add column if not exists address text;
alter table public.stores add column if not exists contact_phone text;
alter table public.stores add column if not exists business_hours text;

alter table public.stores
  add constraint stores_address_length
  check (address is null or char_length(address) <= 300);

alter table public.stores
  add constraint stores_contact_phone_length
  check (contact_phone is null or char_length(contact_phone) <= 50);

alter table public.stores
  add constraint stores_business_hours_length
  check (business_hours is null or char_length(business_hours) <= 200);

-- Store logo/banner: public bucket (same reasoning as product-images
-- above -- `stores` has had select-all-authenticated RLS with no
-- privacy boundary since ZOKY-001, unlike club-media's private/
-- approved-members-only scope). 1 bucket shared by both image kinds,
-- distinguished by path prefix (mirrors club-media's own "1 bucket, 2
-- image kinds" shape rather than product-images' "1 bucket, 1 kind").
-- Path convention: `{store_id}/logo-{timestamp}.*` /
-- `{store_id}/banner-{timestamp}.*` -- ownership scoped through
-- `stores.owner_id`, identical pattern to product-images' policies
-- above (a store's images belong to the store, not personally to
-- whichever owner happened to upload them).
insert into storage.buckets (id, name, public)
values ('store-media', 'store-media', true)
on conflict (id) do nothing;

create policy "Store media is publicly accessible"
  on storage.objects
  for select
  using (bucket_id = 'store-media');

create policy "Sellers can upload their own store's media"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'store-media'
    and exists (
      select 1 from public.stores
      where stores.id = ((storage.foldername(name))[1])::uuid
        and stores.owner_id = auth.uid()
    )
  );

create policy "Sellers can update their own store's media"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'store-media'
    and exists (
      select 1 from public.stores
      where stores.id = ((storage.foldername(name))[1])::uuid
        and stores.owner_id = auth.uid()
    )
  )
  with check (
    bucket_id = 'store-media'
    and exists (
      select 1 from public.stores
      where stores.id = ((storage.foldername(name))[1])::uuid
        and stores.owner_id = auth.uid()
    )
  );

create policy "Sellers can delete their own store's media"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'store-media'
    and exists (
      select 1 from public.stores
      where stores.id = ((storage.foldername(name))[1])::uuid
        and stores.owner_id = auth.uid()
    )
  );

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
    'new_order', 'order_shipped', 'order_cancelled', 'order_refunded',
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
    'new_order', 'order_shipped', 'order_cancelled', 'order_refunded',
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

-- Enables realtime for the `messages` table -- guarded so schema.sql
-- still applies cleanly against a bare local Postgres test harness
-- (supabase/tests/*.sh's stub never creates the `supabase_realtime`
-- publication, only a real Supabase project does by default).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    execute 'alter publication supabase_realtime add table public.messages';
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
    'new_order', 'order_shipped', 'order_cancelled', 'order_refunded',
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
-- WYN-038: View Counting System (Drop) -- unique viewer, rate limit,
-- velocity cap
-- ============================================================

-- One row per (Drop, viewer) pair ever recorded -- the primary key
-- itself IS the unique-viewer/lifetime dedup mechanism (Product's own
-- design): a second insert attempt for the same pair always conflicts,
-- so "has this viewer ever seen this Drop" needs no separate flag or
-- session-scoped client state, unlike Pop's WYN-006 view_count (a bare
-- +1 counter with no dedup at all -- see this task's Product spec
-- "Problem" section for why that gap is *not* being carried forward
-- here; Pop's own view_count is explicitly out of scope this round).
create table if not exists public.drop_views (
  drop_id uuid not null references public.drops (id) on delete cascade,
  viewer_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (drop_id, viewer_id)
);

-- Read hot-path for record_drop_view()'s rate-limit/velocity-cap
-- window queries below -- both filter on created_at (one further
-- scoped to viewer_id, the other to drop_id, both already covered by
-- the primary key/its implicit index), so a plain created_at index
-- keeps "how many rows in the last N seconds" cheap as this table
-- grows without bound (there is no purge/archival job yet -- see this
-- task's Product spec Risks).
create index if not exists drop_views_created_at_idx
  on public.drop_views (created_at);

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
-- the only place the unique-viewer/self-view/rate-limit/velocity-cap
-- rules are enforced. A raw client insert would bypass every one of
-- those checks, so there is deliberately no way to perform one --
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

  -- (b) The Drop's own author viewing their own Drop never counts --
  -- cheapest, most direct anti-inflation measure (Product's "Self-view
  -- exclusion"). The client already skips calling this RPC at all for
  -- its own Drop (DropDetailScreen); this check is defense-in-depth
  -- against a direct RPC call that bypasses that client-side skip.
  if v_drop.author_id = v_me then
    return;
  end if;

  -- (c) Rate limit, per account: at most 20 new View rows from this
  -- account in the trailing 60 seconds.
  select count(*) into v_account_recent_count
  from public.drop_views
  where viewer_id = v_me and created_at > now() - interval '60 seconds';
  if v_account_recent_count >= 20 then
    return;
  end if;

  -- (d) Velocity cap, per Drop: at most 50 new View rows landing on
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

  -- Every check above passed -- record the View. ON CONFLICT DO
  -- NOTHING is a second, belt-and-suspenders dedup layer on top of the
  -- primary key itself (guards a race between two concurrent calls for
  -- the same (drop_id, viewer_id) pair, e.g. a double-tap into the
  -- screen before the first call resolves).
  insert into public.drop_views (drop_id, viewer_id)
  values (p_drop_id, v_me)
  on conflict (drop_id, viewer_id) do nothing;
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
    'new_order', 'order_shipped', 'order_cancelled', 'order_refunded',
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
    'new_order', 'order_shipped', 'order_cancelled', 'order_refunded',
    'mention_drop', 'mention_club_post',
    'moderation_warning', 'moderation_content_removed',
    'appeal_approved', 'appeal_rejected',
    'message_request', 'redrop',
    'follow_request', 'follow_request_accepted',
    'system'
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
  if internal.current_platform_role() <> 'admin' then
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
-- for WYN Shop, but ZOKY/Marketplace was pulled out of the app
-- already (WYN-024, parked for V2), so there is nothing for it to
-- cover yet.
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
create or replace function public.admin_dashboard_metrics()
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
  reports_pending bigint
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
    (select count(*) from public.reports where status = 'pending');
end;
$$;

grant execute on function public.admin_dashboard_metrics() to authenticated;

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
