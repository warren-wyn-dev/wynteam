-- =====================================================================
-- Web Beta2 — WYN-137: Club announcements
--
-- Founder decision (2026-09-20): a separate "Announcement" content type,
-- not a filter on pinned posts. Owner/Admin/Moderator post it; every
-- approved member reads it in the Club's own "ประกาศ" tab (Club-wide, not
-- tied to a channel). Member notifications come with the release.
--
-- Schema choice: a new table instead of `club_posts.type`. Every existing
-- club_posts reader (Flutter and web feeds, likes, comments, insights,
-- the club_posts_notify_new trigger) would otherwise show announcements as
-- ordinary posts, and club_posts' own insert/update policies would let any
-- member create one or flip a post's type.
--
-- Production apply needs its own explicit Founder approval (AGENTS.md
-- Change Control). Additive and idempotent: one new table and three RPCs.
-- No existing table, row, policy, constraint or function is changed.
--
-- Beta2 gate: while WYN-137 is developer-only, the RPCs and the read
-- policy refuse non-developer accounts. No notifications are sent yet
-- (Founder, 2026-09-27): web and the Flutter app share the notifications
-- table and the installed Flutter app cannot parse a new type (WYN-043).
-- Member notifications come with the release, in a follow-up migration.
-- =====================================================================

create table if not exists public.club_announcements (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  edited_at timestamptz
);

create index if not exists club_announcements_club_created_idx
  on public.club_announcements (club_id, created_at desc);

alter table public.club_announcements enable row level security;

revoke all on public.club_announcements from anon, authenticated;
grant select on public.club_announcements to authenticated;
grant all on public.club_announcements to service_role;

-- Same audience as club_posts: approved members only, never from an author
-- blocked either way. Beta2: developer accounts only, so the table cannot be
-- read through the API before release. No client insert/update/delete
-- policy: the RPCs below are the only write path.
drop policy if exists "Approved club members read announcements" on public.club_announcements;
create policy "Approved club members read announcements"
  on public.club_announcements for select to authenticated
  using (
    public.club_role(club_id, (select auth.uid())) is not null
    and not internal.is_blocked_either_way((select auth.uid()), author_id)
    and public.is_developer_account()
  );

-- ---------------------------------------------------------------------
-- Write RPCs. Permissions follow the spec: Owner/Admin/Moderator post;
-- the author edits their own while still staff; the author or an
-- Owner/Admin deletes. coalesce() guards the NULL-role bypass (WYN-050).
-- ---------------------------------------------------------------------
create or replace function public.create_club_announcement(p_club_id uuid, p_body text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_body text := regexp_replace(coalesce(p_body, ''), '^[[:space:]\u00a0\u200b]+|[[:space:]\u00a0\u200b]+$', '', 'g');
  v_id uuid;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_developer_account() then
    raise exception 'Announcements are not available yet';
  end if;
  if coalesce(public.club_role(p_club_id, v_me), '') not in ('owner', 'admin', 'moderator') then
    raise exception 'Only Club staff can post announcements';
  end if;
  -- Same moderation restriction as creating a club post.
  if internal.is_posting_blocked(v_me) then
    raise exception 'Posting is restricted for this account';
  end if;
  if char_length(v_body) not between 1 and 2000 then
    raise exception 'Announcement must be 1-2000 characters';
  end if;

  insert into public.club_announcements (club_id, author_id, body)
  values (p_club_id, v_me, v_body)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.update_club_announcement(p_announcement_id uuid, p_body text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_body text := regexp_replace(coalesce(p_body, ''), '^[[:space:]\u00a0\u200b]+|[[:space:]\u00a0\u200b]+$', '', 'g');
  v_row public.club_announcements;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_developer_account() then
    raise exception 'Announcements are not available yet';
  end if;
  select * into v_row from public.club_announcements where id = p_announcement_id;
  if v_row.id is null
     or v_row.author_id <> v_me
     or coalesce(public.club_role(v_row.club_id, v_me), '') not in ('owner', 'admin', 'moderator') then
    raise exception 'Announcement not found or not yours to edit';
  end if;
  if internal.is_posting_blocked(v_me) then
    raise exception 'Posting is restricted for this account';
  end if;
  if char_length(v_body) not between 1 and 2000 then
    raise exception 'Announcement must be 1-2000 characters';
  end if;

  update public.club_announcements
  set body = v_body, edited_at = now()
  where id = p_announcement_id;
end;
$$;

create or replace function public.delete_club_announcement(p_announcement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_row public.club_announcements;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_developer_account() then
    raise exception 'Announcements are not available yet';
  end if;
  select * into v_row from public.club_announcements where id = p_announcement_id;
  if v_row.id is null
     or (v_row.author_id <> v_me
         and coalesce(public.club_role(v_row.club_id, v_me), '') not in ('owner', 'admin')) then
    raise exception 'Announcement not found or not yours to delete';
  end if;

  delete from public.club_announcements where id = p_announcement_id;
end;
$$;

revoke all on function public.create_club_announcement(uuid, text) from public, anon;
revoke all on function public.update_club_announcement(uuid, text) from public, anon;
revoke all on function public.delete_club_announcement(uuid) from public, anon;
grant execute on function public.create_club_announcement(uuid, text) to authenticated;
grant execute on function public.update_club_announcement(uuid, text) to authenticated;
grant execute on function public.delete_club_announcement(uuid) to authenticated;

-- Rollback (Founder-approved only):
--   drop function if exists public.delete_club_announcement(uuid);
--   drop function if exists public.update_club_announcement(uuid, text);
--   drop function if exists public.create_club_announcement(uuid, text);
--   drop table if exists public.club_announcements;
