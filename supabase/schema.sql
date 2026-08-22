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
  if v_author_id is not null and v_author_id <> new.user_id then
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
  if v_author_id is not null and v_author_id <> new.user_id then
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
  if v_author_id is not null and v_author_id <> new.author_id then
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
  if v_author_id is not null and v_author_id <> new.author_id then
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
  insert into public.notifications (recipient_id, actor_id, type)
  values (new.following_id, new.follower_id, 'follow');
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
    and cm.user_id <> new.user_id;
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
  insert into public.notifications (recipient_id, actor_id, type, club_id)
  values (new.user_id, auth.uid(), 'club_join_approved', new.club_id);
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
  if v_author_id is not null and v_author_id <> new.user_id then
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
  if v_author_id is not null and v_author_id <> new.author_id then
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
  if v_author_id is not null and new.mentioned_user_id <> v_author_id then
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
  if v_author_id is not null and new.mentioned_user_id <> v_author_id then
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
  else
    -- Includes 'message' -- reserved for WYN-031/032 (Phase 2), no
    -- table exists yet to validate against, so reject rather than
    -- accept an unverifiable target.
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
  );

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
    insert into public.notifications (recipient_id, actor_id, type, reason)
    values (v_target_user, null, 'moderation_warning', v_trimmed_reason);
  elsif p_action_type = 'remove_content' then
    -- Notification inserted *before* the delete below on purpose: both
    -- drop_id/club_post_id etc. are left null on this notification (see
    -- the notifications_type_check migration further down), so nothing
    -- here references the row about to be deleted and there is no
    -- on-delete-cascade ordering hazard either way -- but inserting
    -- first keeps the "notify, then remove" sequence readable as the
    -- two-step user-facing effect the design doc describes.
    insert into public.notifications (recipient_id, actor_id, type, reason)
    values (v_target_user, null, 'moderation_content_removed', v_trimmed_reason);

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
      where target_user_id = auth.uid() and action_type = 'restrict' and expires_at > now()
    ),
    (
      select reason from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'restrict' and expires_at > now()
      order by created_at desc limit 1
    ),
    (
      select expires_at from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'restrict' and expires_at > now()
      order by created_at desc limit 1
    ),
    exists (
      select 1 from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'suspend' and expires_at > now()
    ),
    (
      select reason from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'suspend' and expires_at > now()
      order by created_at desc limit 1
    ),
    (
      select expires_at from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'suspend' and expires_at > now()
      order by created_at desc limit 1
    ),
    exists (
      select 1 from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'ban'
    ),
    (
      select reason from public.moderation_actions
      where target_user_id = auth.uid() and action_type = 'ban'
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
    'moderation_warning', 'moderation_content_removed'
  ));

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
