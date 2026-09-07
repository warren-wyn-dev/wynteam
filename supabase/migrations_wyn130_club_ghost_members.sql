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
-- Identical copy of the block appended to the end of schema.sql --
-- kept here on its own so it can be applied by itself without
-- scrolling/copying out of the full 14,000+ line file. Same statements,
-- safe to run any number of times (create or replace function).
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
