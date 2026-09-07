-- WYN-129: Club Role Badge
--
-- Adds `public.club_member_badges` -- a purely cosmetic, Club-scoped
-- identity layer, completely separate from `club_role()`/authorization.
-- See .wyn/tasks/backlog/WYN-129-club-role-badges.md.
--
-- CRITICAL INVARIANT (Risks section): a badge must NEVER be queried
-- anywhere a permission check happens. Nothing in this file calls
-- club_role(), and nothing that calls club_role() elsewhere in
-- schema.sql references this table. Keep it that way.
--
-- SAFETY: purely additive -- a brand new table, no existing table
-- touched. Re-runnable (`if not exists`/`or replace`/`drop policy if
-- exists` throughout).
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.

begin;

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

comment on table public.club_member_badges is
  'WYN-129: cosmetic-only Club identity badges. Never join/query this table '
  'in a permission check -- it has zero relationship to club_role().';

alter table public.club_member_badges enable row level security;

-- Read: same posture as club_channels (WYN-127) -- a badge carries no
-- privacy boundary of its own; the real content it decorates (Members
-- tab, posts, comments) is already gated by its own visibility rules.
drop policy if exists "Club member badges are viewable by authenticated users" on public.club_member_badges;
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
drop policy if exists "Club owners and admins can set member badges" on public.club_member_badges;
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
-- see supabase/schema.sql's identical policy for the full comment --
-- the `with check` below closes a gap where an Owner/Admin could UPDATE
-- an existing badge row's `user_id` to point at a non-member.
drop policy if exists "Club owners and admins can edit member badges" on public.club_member_badges;
create policy "Club owners and admins can edit member badges"
  on public.club_member_badges
  for update
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'))
  with check (
    public.club_role(club_id, auth.uid()) in ('owner', 'admin')
    and public.club_role(club_id, user_id) is not null
  );

drop policy if exists "Club owners and admins can remove member badges" on public.club_member_badges;
create policy "Club owners and admins can remove member badges"
  on public.club_member_badges
  for delete
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

commit;

-- VERIFY (run separately)
--
--   select count(*) from public.club_member_badges group by club_id, user_id
--     having count(*) > 1; -- expect 0 rows (enforced by the primary key anyway)
