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

-- WYN-004 (Feed & Post) — posts, likes, comments
-- Run once per environment after the WYN-002/WYN-003 statements above.
--
-- author_id/user_id reference public.profiles (not auth.users directly) so
-- PostgREST can embed author info in one query (e.g.
-- `.select('*, author:profiles(username, display_name, avatar_url)')`)
-- instead of doing a separate profile lookup per post/comment.

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  text_content text,
  image_url text,
  created_at timestamptz not null default now(),
  -- Rejects '' as well as NULL (length 0 is not "between 1 and 500"), so
  -- the app must send null for "no text", not '' -- see the WYN-003
  -- display_name lesson in .wyn/learning/MISTAKES.md.
  constraint posts_text_content_length
    check (text_content is null or char_length(text_content) between 1 and 500),
  -- A post needs at least a real (non-empty) text or an image.
  constraint posts_have_content
    check (text_content is not null or image_url is not null)
);

alter table public.posts enable row level security;

create policy "Posts are viewable by authenticated users"
  on public.posts
  for select
  to authenticated
  using (true);

create policy "Users can create their own posts"
  on public.posts
  for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Users can delete their own posts"
  on public.posts
  for delete
  to authenticated
  using (auth.uid() = author_id);

create table if not exists public.likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.likes enable row level security;

create policy "Likes are viewable by authenticated users"
  on public.likes
  for select
  to authenticated
  using (true);

create policy "Users can like posts as themselves"
  on public.likes
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can remove their own likes"
  on public.likes
  for delete
  to authenticated
  using (auth.uid() = user_id);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  text_content text not null,
  created_at timestamptz not null default now(),
  constraint comments_text_content_length
    check (char_length(text_content) between 1 and 500)
);

alter table public.comments enable row level security;

create policy "Comments are viewable by authenticated users"
  on public.comments
  for select
  to authenticated
  using (true);

create policy "Users can comment as themselves"
  on public.comments
  for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Users can delete their own comments"
  on public.comments
  for delete
  to authenticated
  using (auth.uid() = author_id);

-- Post images: public bucket, each user may only write to their own
-- folder ({user_id}/...), same pattern as the avatars bucket. Each image
-- gets a unique filename (see PostRepository.createPost) since, unlike
-- avatars, post images are never overwritten -- no update policy needed.
insert into storage.buckets (id, name, public)
values ('post-images', 'post-images', true)
on conflict (id) do nothing;

create policy "Post images are publicly accessible"
  on storage.objects
  for select
  using (bucket_id = 'post-images');

create policy "Users can upload their own post images"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
