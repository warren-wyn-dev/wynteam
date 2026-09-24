-- SECURITY HOTFIX: public post permissions honor author blocks; public club
-- photos must be referenced by visible posts (never club chat images).
-- Previous unsafe nested-path policy is superseded by this migration.
-- WYN-185 (WYNOS Web Beta1, item 2): Public Clubs must be readable
-- (details, member count, posts) by any authenticated user WITHOUT an
-- approved membership. Today "WYNOS Feedback" (a public club) shows 0
-- members and no posts before joining, then the real numbers appear right
-- after — not a display bug, an RLS bug: club_posts and the club-media
-- storage bucket were built members-only-visible at the DB layer (see the
-- comment above the `club-media` bucket insert in schema.sql), and the web
-- client computes member_count with a raw `count` query against
-- club_members, which the existing SELECT policies only let an approved
-- member (or the club's owner/admin, for pending rows) see any rows of.
--
-- Posting and Club Chat stay members-only — this migration only widens
-- READ access, and only for clubs where privacy = 'public'. Private clubs
-- are completely unaffected: every policy/function below either checks
-- privacy = 'public' explicitly or reuses club_role(), which already
-- returns null for a non-member regardless of privacy.
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it; no
-- AI applies production SQL (per AGENTS.md Change Control).

-- 1) Club posts: additive policy alongside the existing members-only one
-- (RLS ORs every matching SELECT policy together, so this never narrows
-- what a member of a private club could already see).
drop policy if exists "Public club posts are viewable by any authenticated user" on public.club_posts;
create policy "Public club posts are viewable by any authenticated user"
  on public.club_posts
  for select
  to authenticated
  using (
    exists (
      select 1 from public.clubs c
      where c.id = club_posts.club_id and c.privacy = 'public'
    )
    and not internal.is_blocked_either_way((select auth.uid()), club_posts.author_id)
  );

-- 2) Club post images: same widening for the storage bucket, mirroring
-- "Club post images are visible to approved club members" above it.
-- Cover/icon images already have no membership gate at all (single-segment
-- paths), so this only touches the >1-segment (post image) path shape.
drop policy if exists "Public club post images are visible to any authenticated user" on storage.objects;
create policy "Public club post images are visible to any authenticated user"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'club-media'
    and exists (
      select 1 from public.club_posts cp
      join public.clubs c on c.id = cp.club_id
      where cp.club_id::text = (storage.foldername(storage.objects.name))[1]
        and c.privacy = 'public'
        and cp.image_urls @> array[storage.objects.name]::text[]
        and not internal.is_blocked_either_way((select auth.uid()), cp.author_id)
    )
  );

-- 3) Member count: deliberately a dedicated SECURITY DEFINER function
-- rather than a loosened club_members SELECT policy. The Founder's ask is
-- specifically "จำนวนสมาชิก" (the count) for a public club preview, not the
-- member roster (club_member_profiles() above keeps requiring an approved
-- membership for that, unchanged) — a raw RLS loosening on club_members
-- would leak the *roster*, not just a number, to any authenticated user.
-- Mirrors club_role()'s existing security-definer-crosses-RLS pattern.
create or replace function public.club_member_count(p_club_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.club_members cm
  where cm.club_id = p_club_id
    and cm.status = 'approved'
    and (
      exists (select 1 from public.clubs c where c.id = p_club_id and c.privacy = 'public')
      or public.club_role(p_club_id, auth.uid()) is not null
    );
$$;

revoke all on function public.club_member_count(uuid) from public;
revoke all on function public.club_member_count(uuid) from anon;
grant execute on function public.club_member_count(uuid) to authenticated;

-- 4) Batched sibling of club_member_count() for club *lists* (Explore
-- Clubs, My Clubs, search) -- avoids one RPC round-trip per club the way
-- the web client's mapClubs() already batches signed-URL/membership
-- lookups for the exact same reason.
create or replace function public.club_member_counts(p_club_ids uuid[])
returns table (club_id uuid, member_count integer)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, count(cm.user_id)::integer
  from public.clubs c
  left join public.club_members cm
    on cm.club_id = c.id
    and cm.status = 'approved'
  where c.id = any(p_club_ids)
    and (
      c.privacy = 'public'
      or public.club_role(c.id, auth.uid()) is not null
    )
  group by c.id;
$$;

revoke all on function public.club_member_counts(uuid[]) from public;
revoke all on function public.club_member_counts(uuid[]) from anon;
grant execute on function public.club_member_counts(uuid[]) to authenticated;
