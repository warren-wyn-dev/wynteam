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

-- ------------------------------------------------------------
-- Fast-follow (QA finding): club_channel_messages had zero moderation
-- coverage -- reports.target_type didn't know this table existed. See
-- .wyn/tasks/bugs/WYN-128-group-chat-missing-report-action.md. Safe to
-- include in this not-yet-applied migration rather than a separate
-- follow-up file.
-- ------------------------------------------------------------
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
    and tc.table_name = 'reports'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'target_type';

  if v_constraint_name is not null then
    execute format('alter table public.reports drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.reports
  add constraint reports_target_type_check
  check (target_type in (
    'user', 'drop', 'drop_comment', 'club', 'club_post',
    'club_post_comment', 'message', 'redrop', 'club_channel_message'
  ));

-- Full re-definition of submit_report() -- see supabase/schema.sql's
-- copy (same statements, kept in sync) for the full comment history of
-- every branch; only 'club_channel_message' is new here.
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
  elsif p_target_type = 'message' then
    if not exists (
      select 1 from public.messages m
      join public.conversations c on c.id = m.conversation_id
      where m.id = p_target_id
        and m.sender_id <> v_reporter
        and v_reporter in (c.user_a_id, c.user_b_id)
    ) then
      raise exception 'Message not found, is your own, or you are not a participant';
    end if;
  elsif p_target_type = 'redrop' then
    if not exists (
      select 1 from public.redrops
      where id = p_target_id and redropper_id <> v_reporter
    ) then
      raise exception 'Redrop not found, or is your own';
    end if;
  elsif p_target_type = 'club_channel_message' then
    if not exists (
      select 1 from public.club_channel_messages m
      join public.club_channels ch on ch.id = m.channel_id
      where m.id = p_target_id
        and m.author_id <> v_reporter
        and public.club_role(ch.club_id, v_reporter) is not null
    ) then
      raise exception 'Channel message not found, is your own, or you are not a member of its club';
    end if;
  else
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
end;
$$;

grant execute on function public.submit_report(text, uuid, text, text) to authenticated;

-- Full re-definition of apply_moderation_action() -- see
-- supabase/schema.sql's copy for the full comment history; only the
-- 'club_channel_message' branches (target-user resolution + Remove
-- Content deletion) are new here.
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
  v_target_content_type text;
  v_target_content_id uuid;
  v_expires_at timestamptz;
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_action_id uuid;
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
  elsif v_report.target_type = 'club_channel_message' then
    select author_id into v_target_user from public.club_channel_messages where id = v_report.target_id;
  else
    raise exception 'Unsupported report target type: %', v_report.target_type;
  end if;

  if p_action_type = 'remove_content' and v_report.target_type in ('user', 'club') then
    raise exception 'Remove Content is not supported for target type %', v_report.target_type;
  end if;

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

  if p_action_type = 'remove_content' and v_report.target_type = 'drop' then
    v_target_content_type := 'drop';
    v_target_content_id := v_report.target_id;
  end if;

  insert into public.moderation_actions (
    report_id, target_user_id, action_type, reason, duration_days, expires_at,
    reviewer_id, target_content_type, target_content_id
  ) values (
    p_report_id,
    v_target_user,
    p_action_type,
    v_trimmed_reason,
    case when p_action_type in ('restrict', 'suspend') then p_duration_days else null end,
    v_expires_at,
    v_reviewer,
    v_target_content_type,
    v_target_content_id
  )
  returning id into v_action_id;

  update public.reports
  set status = case when p_action_type = 'no_action' then 'dismissed' else 'actioned' end
  where id = p_report_id;

  if p_action_type = 'warning' then
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_target_user, null, 'moderation_warning', v_trimmed_reason, v_action_id, p_action_type);
  elsif p_action_type = 'remove_content' then
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_target_user, null, 'moderation_content_removed', v_trimmed_reason, v_action_id, p_action_type);

    if v_report.target_type = 'drop' then
      update public.drops set deleted_at = now() where id = v_report.target_id and deleted_at is null;
    elsif v_report.target_type = 'drop_comment' then
      delete from public.drop_comments where id = v_report.target_id;
    elsif v_report.target_type = 'club_post' then
      delete from public.club_posts where id = v_report.target_id;
    elsif v_report.target_type = 'club_post_comment' then
      delete from public.club_post_comments where id = v_report.target_id;
    elsif v_report.target_type = 'club_channel_message' then
      delete from public.club_channel_messages where id = v_report.target_id;
    end if;
  end if;

  perform internal.log_audit_event(
    v_reviewer,
    'moderation_action_applied',
    v_target_user,
    jsonb_build_object('action_type', p_action_type, 'reason', v_trimmed_reason)
  );
end;
$$;

grant execute on function public.apply_moderation_action(uuid, text, text, integer) to authenticated;

commit;

-- VERIFY (run separately)
--
--   select count(*) from public.club_channel_messages where channel_id is null; -- expect 0 (NOT NULL anyway)
--   select * from public.get_unread_channel_counts('<a real club id>');
