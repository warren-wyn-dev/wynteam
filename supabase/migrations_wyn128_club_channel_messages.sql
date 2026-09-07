-- WYN-128: Club Group Chat
--
-- Adds `public.club_channel_messages` (real-time group chat, one room
-- per WYN-127 channel) + `public.club_channel_message_reads` (per-user
-- last-read timestamp per channel, backing the unread badge --
-- Requirement 6/AC). See .wyn/tasks/backlog/WYN-128-club-group-chat.md
-- and .wyn/company/APPROVALS.md's 2026-09-07 entry (Founder: "ทำต่อให้
-- เสร็จเลย").
--
-- Deliberately does NOT touch `conversations`/`conversation_participants`/
-- `messages` (WYN-031) at all -- see the Product spec's own Recommendation
-- for why a brand new table is safer than extending the 1:1 schema.
--
-- Reuses the existing `club-media` storage bucket/policies as-is (see
-- the comment above the image path convention below) -- no new storage
-- bucket or policy needed.
--
-- SAFETY: purely additive -- 2 brand new tables, no existing table
-- touched. Re-runnable throughout.
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.

begin;

create table if not exists public.club_channel_messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.club_channels (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  content text,
  image_url text,
  reply_to_message_id uuid references public.club_channel_messages (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint club_channel_messages_have_content check (content is not null or image_url is not null),
  constraint club_channel_messages_content_length
    check (content is null or char_length(content) between 1 and 2000)
);

create index if not exists club_channel_messages_channel_id_idx
  on public.club_channel_messages (channel_id, created_at);

alter table public.club_channel_messages enable row level security;

-- Read/write gate: club_role() on the message's own channel's club_id --
-- exactly the sitting membership check every other Club RLS policy uses
-- (club_posts, club_channels), so a banned/removed member loses both
-- read and write access the moment their club_members row changes,
-- same as it already does for posts (AC: "คนที่ยังไม่ join หรือถูก ban
-- ... เข้าห้องแชทไม่ได้เลย").
drop policy if exists "Approved club members can view channel messages" on public.club_channel_messages;
create policy "Approved club members can view channel messages"
  on public.club_channel_messages
  for select
  to authenticated
  using (
    exists (
      select 1 from public.club_channels ch
      where ch.id = channel_id
        and public.club_role(ch.club_id, auth.uid()) is not null
    )
  );

drop policy if exists "Approved club members can send channel messages as themselves" on public.club_channel_messages;
create policy "Approved club members can send channel messages as themselves"
  on public.club_channel_messages
  for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and not internal.is_posting_blocked(auth.uid())
    and exists (
      select 1 from public.club_channels ch
      where ch.id = channel_id
        and public.club_role(ch.club_id, auth.uid()) is not null
    )
  );

-- Delete: message author OR that channel's Club staff (owner/admin/
-- moderator) -- Requirement 4, "เทียบเท่าสิทธิ์ลบโพสต์ที่มีอยู่แล้ว".
-- A plain hard DELETE (mirrors club_posts' own delete policy), not the
-- soft-null-out delete_message() RPC 1:1 chat uses -- there is no
-- View-Once/shared-content state here that a hard delete could leave
-- dangling, so club_posts' simpler shape is the right one to mirror.
drop policy if exists "Message authors and club staff can delete channel messages" on public.club_channel_messages;
create policy "Message authors and club staff can delete channel messages"
  on public.club_channel_messages
  for delete
  to authenticated
  using (
    auth.uid() = author_id
    or exists (
      select 1 from public.club_channels ch
      where ch.id = channel_id
        and public.club_role(ch.club_id, auth.uid()) in ('owner', 'admin', 'moderator')
    )
  );

-- Mirrors prevent_cross_conversation_reply() (WYN-031) exactly, scoped
-- to channel instead of conversation.
create or replace function public.prevent_cross_channel_message_reply()
returns trigger
language plpgsql
as $$
begin
  if new.reply_to_message_id is not null then
    if not exists (
      select 1 from public.club_channel_messages m
      where m.id = new.reply_to_message_id and m.channel_id = new.channel_id
    ) then
      raise exception 'Cannot reply to a message from a different channel';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists club_channel_messages_prevent_cross_channel_reply on public.club_channel_messages;
create trigger club_channel_messages_prevent_cross_channel_reply
  before insert on public.club_channel_messages
  for each row execute function public.prevent_cross_channel_message_reply();

-- Chat images reuse the *existing* `club-media` bucket and its existing
-- ">1 folder segment" policies from WYN-014 as-is (see supabase/
-- schema.sql's "Club post images are visible to approved club members"/
-- "Approved club members can upload post images") -- those policies
-- only check folder depth + club_role() against the first path segment,
-- not what the path's remaining segments mean, so a chat image at
-- `{club_id}/chat/{channel_id}/{user_id}-{timestamp}.*` is already
-- covered with zero new storage policy needed. No bucket/policy
-- statements in this migration for that reason.

-- Requirement 6 / AC: unread badge. One row per (channel, user) --
-- mirrors conversations.user_a_last_read_at/user_b_last_read_at's role
-- for 1:1 chat, but as its own table (not 2 columns) since a channel has
-- N members, not 2.
create table if not exists public.club_channel_message_reads (
  channel_id uuid not null references public.club_channels (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);

alter table public.club_channel_message_reads enable row level security;

drop policy if exists "Users can view their own channel read state" on public.club_channel_message_reads;
create policy "Users can view their own channel read state"
  on public.club_channel_message_reads
  for select
  to authenticated
  using (auth.uid() = user_id);

-- No insert/update policy for the client -- mark_club_channel_read()
-- below is the only write path, mirroring mark_conversation_read()
-- (WYN-031).
create or replace function public.mark_club_channel_read(p_channel_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select club_id into v_club_id from public.club_channels where id = p_channel_id;
  if v_club_id is null or public.club_role(v_club_id, auth.uid()) is null then
    raise exception 'Not an approved member of this channel''s club';
  end if;

  insert into public.club_channel_message_reads (channel_id, user_id, last_read_at)
  values (p_channel_id, auth.uid(), now())
  on conflict (channel_id, user_id) do update set last_read_at = excluded.last_read_at;
end;
$$;

grant execute on function public.mark_club_channel_read(uuid) to authenticated;

-- Per-channel unread counts for every channel in p_club_id, for the
-- caller -- batched in one call (ClubPostsTab's channel switcher needs
-- every channel's count at once, mirroring how it already batches every
-- channel's name in one fetchChannels() call). Excludes the caller's
-- own messages (sending doesn't make your own room "unread").
create or replace function public.get_unread_channel_counts(p_club_id uuid)
returns table (channel_id uuid, unread_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select ch.id,
    count(m.id) filter (
      where m.created_at > coalesce(r.last_read_at, 'epoch'::timestamptz)
        and m.author_id <> auth.uid()
    )
  from public.club_channels ch
  left join public.club_channel_message_reads r
    on r.channel_id = ch.id and r.user_id = auth.uid()
  left join public.club_channel_messages m
    on m.channel_id = ch.id
  where ch.club_id = p_club_id
    and public.club_role(p_club_id, auth.uid()) is not null
  group by ch.id;
$$;

grant execute on function public.get_unread_channel_counts(uuid) to authenticated;

commit;

-- VERIFY (run separately)
--
--   select count(*) from public.club_channel_messages where channel_id is null; -- expect 0 (NOT NULL anyway)
--   select * from public.get_unread_channel_counts('<a real club id>');
