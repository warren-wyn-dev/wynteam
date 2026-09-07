-- WYN-133 (requirement 7): Club Chat channel categories
--
-- Adds `public.club_channel_categories` and `club_channels.category_id` so
-- a Club's chat rooms can be grouped under a Discord-style header (e.g.
-- "ทั่วไป", "ฟีดแบ็กแอป"), exactly as requested in
-- .wyn/tasks/backlog/WYN-133-club-chat-channel-navigation.md (requirement
-- 7). See .wyn/docs/design/wyn-133-club-chat-channel-navigation.md.
--
-- SAFETY: additive only, no destructive step, no backfill needed.
--   * `club_channel_categories` is a brand new table.
--   * `category_id` is added nullable -- every existing channel (and
--     every new channel that's never assigned one) simply stays
--     "ไม่มีกลุ่ม" with zero migration needed. Categories are opt-in.
--   * `on delete set null` is what makes "ลบกลุ่มแล้วห้องไม่หาย" true at
--     the database level -- deleting a category only clears
--     `category_id` on its former channels, never deletes them.
--   * Reuses `club_channels`' existing "Club owners and admins can rename
--     channels" UPDATE policy to let an owner/admin move a channel
--     between categories -- no new policy needed on `club_channels`
--     itself, only on the new table.
--
-- Re-runnable: every statement is `if not exists`/`or replace`, every
-- policy is dropped before being recreated.
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.

begin;

create table if not exists public.club_channel_categories (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  name text not null,
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint club_channel_categories_name_length check (char_length(name) between 1 and 50)
);

comment on table public.club_channel_categories is
  'WYN-133: Discord-style named groupings of club_channels rows within a Club, e.g. "ทั่วไป". Purely organizational -- deleting one never deletes its channels.';

create unique index if not exists club_channel_categories_club_id_lower_name_key
  on public.club_channel_categories (club_id, lower(name));

alter table public.club_channel_categories enable row level security;

drop policy if exists "Club channel categories are viewable by authenticated users" on public.club_channel_categories;
create policy "Club channel categories are viewable by authenticated users"
  on public.club_channel_categories
  for select
  to authenticated
  using (true);

drop policy if exists "Club owners and admins can create channel categories" on public.club_channel_categories;
create policy "Club owners and admins can create channel categories"
  on public.club_channel_categories
  for insert
  to authenticated
  with check (
    auth.uid() = created_by
    and public.club_role(club_id, auth.uid()) in ('owner', 'admin')
  );

drop policy if exists "Club owners and admins can rename channel categories" on public.club_channel_categories;
create policy "Club owners and admins can rename channel categories"
  on public.club_channel_categories
  for update
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

drop policy if exists "Club owners and admins can delete channel categories" on public.club_channel_categories;
create policy "Club owners and admins can delete channel categories"
  on public.club_channel_categories
  for delete
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

alter table public.club_channels
  add column if not exists category_id uuid references public.club_channel_categories (id) on delete set null;

commit;
