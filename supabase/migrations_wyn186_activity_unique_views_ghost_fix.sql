-- WYN-185 (WYNOS Web Beta1, item 8): Post Detail's "ดูกิจกรรม" (Activity)
-- sheet currently only has Likes/ReDrops tabs, computed via raw client-side
-- joins with no ghost-account filtering, and has no notion of a
-- unique-viewer count at all. This migration adds what's missing without
-- touching WYN-083's view_count/drop_views behavior (Founder confirmed,
-- 2026-09-21: keep the uncapped/repeat-counting total as-is for
-- ranking/trending; add a *separate* unique-viewer count for display only).
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it; no
-- AI applies production SQL (per AGENTS.md Change Control).

-- 1) Unique-viewer count, separate from drop_view_count() (WYN-083's
-- uncapped/repeat-counting total, left untouched -- still what ranking/
-- trending and the on-post view badge use). This is purely an additional
-- number for the Activity sheet's Views tab, so a user opening the same
-- post 50 times doesn't read as "50 people saw this."
create or replace function public.drop_unique_viewer_count(p_drop_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(distinct viewer_id)::integer
  from public.drop_views
  where drop_id = p_drop_id;
$$;

revoke all on function public.drop_unique_viewer_count(uuid) from public;
grant execute on function public.drop_unique_viewer_count(uuid) to authenticated;

-- 2) Ghost-account-filtered Activity lists (Likes/Reposts/Comments), same
-- class of fix as WYN-130's club_member_profiles()/club_event_attendee_
-- profiles(): a `profiles` row can exist with no username/display_name at
-- all (AuthRepository.setDateOfBirth upserts a bare row before the
-- Username onboarding step ever runs) -- the web client's previous raw
-- `.from("profiles").select(...).in("id", ids)` join rendered these as a
-- bare "@" handle with a "W" fallback avatar in the Activity sheet, one
-- more call site of the same underlying gap. Mirrors each source table's
-- own SELECT policy exactly (drop_likes: unrestricted; redrops/
-- drop_comments: excludes blocked-either-way authors) rather than
-- loosening or tightening what a caller could already see -- this only
-- excludes the ghost rows from what was already visible, same posture as
-- WYN-130.
create or replace function public.drop_activity_profiles(
  p_drop_id uuid,
  p_kind text,
  p_limit int default 100
)
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  is_verified boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.drops d where d.id = p_drop_id) then
    return;
  end if;

  if p_kind = 'like' then
    return query
    select p.id, p.username, p.display_name, p.avatar_url, p.is_verified, dl.created_at
    from public.drop_likes dl
    join public.profiles p on p.id = dl.user_id
    where dl.drop_id = p_drop_id
      and exists (
        select 1 from public.profile_private pp
        where pp.id = dl.user_id and pp.onboarding_completed = true
      )
    order by dl.created_at desc
    limit p_limit;
  elsif p_kind = 'redrop' then
    return query
    select p.id, p.username, p.display_name, p.avatar_url, p.is_verified, r.created_at
    from public.redrops r
    join public.profiles p on p.id = r.redropper_id
    where r.drop_id = p_drop_id
      and not internal.is_blocked_either_way(auth.uid(), r.redropper_id)
      and exists (
        select 1 from public.profile_private pp
        where pp.id = r.redropper_id and pp.onboarding_completed = true
      )
    order by r.created_at desc
    limit p_limit;
  elsif p_kind = 'comment' then
    -- One row per commenter (their most recent comment), not one row per
    -- comment -- Activity lists *people*, the comments themselves already
    -- show in the post's own comment thread.
    return query
    select p.id, p.username, p.display_name, p.avatar_url, p.is_verified, c.created_at
    from (
      select distinct on (dc.author_id) dc.author_id, dc.created_at
      from public.drop_comments dc
      where dc.drop_id = p_drop_id
        and not internal.is_blocked_either_way(auth.uid(), dc.author_id)
      order by dc.author_id, dc.created_at desc
    ) c
    join public.profiles p on p.id = c.author_id
    where exists (
      select 1 from public.profile_private pp
      where pp.id = c.author_id and pp.onboarding_completed = true
    )
    order by c.created_at desc
    limit p_limit;
  else
    raise exception 'Invalid kind: %', p_kind;
  end if;
end;
$$;

revoke all on function public.drop_activity_profiles(uuid, text, int) from public;
grant execute on function public.drop_activity_profiles(uuid, text, int) to authenticated;

-- 3) DB-level guard so `username` can never be stored as an empty string
-- (display_name already has this -- profiles_display_name_length, above --
-- username never did). NULL is untouched -- that's the legitimate
-- "onboarding not finished yet" state; this only blocks the empty-string
-- case, which is always a bug, never a valid value. `not valid` grandfathers
-- any row already in this shape (same pattern as
-- profiles_username_not_reserved above) so this can't fail to apply against
-- production over some pre-existing row -- it enforces on every INSERT/
-- UPDATE from this point forward.
alter table public.profiles
  drop constraint if exists profiles_username_not_empty;
alter table public.profiles
  add constraint profiles_username_not_empty
  check (username is null or char_length(username) >= 3) not valid;
