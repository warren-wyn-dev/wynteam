-- =====================================================================
-- Web Beta2 — WYN-137: Club announcements
--
-- Founder decision (2026-09-20): a separate "Announcement" content type,
-- not a filter on pinned posts. Owner/Admin/Moderator post it; every
-- approved member reads it in the Club's own "ประกาศ" tab (Club-wide, not
-- tied to a channel) and is notified.
--
-- Schema choice: a new table instead of `club_posts.type`. Every existing
-- club_posts reader (Flutter and web feeds, likes, comments, insights,
-- the club_posts_notify_new trigger) would otherwise show announcements as
-- ordinary posts, and club_posts' own insert/update policies would let any
-- member create one or flip a post's type.
--
-- Production apply needs its own explicit Founder approval (AGENTS.md
-- Change Control). Additive and idempotent. The only change to an existing
-- object is widening notifications_type_check with 'club_announcement'
-- (read from the live constraint, so production-only types are kept).
--
-- Beta2 gate: while WYN-137 is developer-only, every write RPC refuses
-- non-developer accounts, and notifications go to developer members only.
-- The installed Flutter app throws on an unknown notification type and
-- would lose its whole notification list (see WYN-043), so releasing to
-- everyone needs a Flutter release that knows 'club_announcement' first.
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

-- Same audience as club_posts: approved members only. No client
-- insert/update/delete policy: the RPCs below are the only write path.
drop policy if exists "Approved club members read announcements" on public.club_announcements;
create policy "Approved club members read announcements"
  on public.club_announcements for select to authenticated
  using (public.club_role(club_id, (select auth.uid())) is not null);

-- ---------------------------------------------------------------------
-- Notification type. Rebuilt from the live constraint so any type that
-- exists only in production is kept; a no-op once the type is present.
-- ---------------------------------------------------------------------
do $$
declare
  v_def text;
begin
  select pg_get_constraintdef(c.oid) into v_def
  from pg_constraint c
  where c.conrelid = 'public.notifications'::regclass
    and c.conname = 'notifications_type_check';
  if v_def is null then
    raise exception 'notifications_type_check not found';
  end if;
  if position('''club_announcement''' in v_def) > 0 then
    return;
  end if;
  if position('ARRAY[' in v_def) = 0 then
    raise exception 'Unexpected notifications_type_check shape: %', v_def;
  end if;
  alter table public.notifications drop constraint notifications_type_check;
  execute 'alter table public.notifications add constraint notifications_type_check '
    || replace(v_def, 'ARRAY[', 'ARRAY[''club_announcement''::text, ');
end $$;

-- Same fan-out rules as notify_club_post_pinned() (WYN-116): approved
-- members except the author, 'club' preference on, Club not muted.
-- Beta2: developer members only (see the header).
create or replace function internal.notify_club_announcement(p_club_id uuid, p_author_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications (recipient_id, actor_id, type, club_id)
  select cm.user_id, p_author_id, 'club_announcement', p_club_id
  from public.club_members cm
  where cm.club_id = p_club_id
    and cm.status = 'approved'
    and cm.user_id <> p_author_id
    and exists (select 1 from public.developer_accounts d where d.user_id = cm.user_id)
    and internal.notification_enabled(cm.user_id, 'club')
    and not exists (
      select 1 from public.club_notification_mutes cnm
      where cnm.club_id = p_club_id and cnm.user_id = cm.user_id
    );
$$;

revoke all on function internal.notify_club_announcement(uuid, uuid) from public, anon, authenticated;

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
  v_body text := btrim(coalesce(p_body, ''));
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
  if char_length(v_body) not between 1 and 2000 then
    raise exception 'Announcement must be 1-2000 characters';
  end if;

  insert into public.club_announcements (club_id, author_id, body)
  values (p_club_id, v_me, v_body)
  returning id into v_id;

  perform internal.notify_club_announcement(p_club_id, v_me);
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
  v_body text := btrim(coalesce(p_body, ''));
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
--   drop function if exists internal.notify_club_announcement(uuid, uuid);
--   delete from public.notifications where type = 'club_announcement';
--   drop table if exists public.club_announcements;
--   (notifications_type_check may keep 'club_announcement'; it is harmless.)
