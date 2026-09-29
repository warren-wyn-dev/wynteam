-- WYNOS Web Beta1 public release of previously developer-gated web features.
-- Founder decision 2026-09-29:
--   1) release chatThreads, clubChatActions and clubAnnouncements to all eligible users;
--   2) suspend the Web Beta2 development track;
--   3) continue future web development under WYNOS Web Beta1, developer-first.
--
-- This migration intentionally preserves all existing authorization, membership,
-- moderation, ownership, RLS and RPC permission checks. It removes ONLY the
-- developer-account rollout gates. Existing objects are recreated idempotently.

-- ---------------------------------------------------------------------
-- WYN-159: Threads-style chat reactions + delete-for-me
-- ---------------------------------------------------------------------
-- =====================================================================
-- Web Beta2 — WYN-159: chat message reactions + "delete for me"
--
-- Founder request (2026-09-27): hold menu like the reference screenshot,
-- with an emoji bar (❤️ 😂 😮 😢 😡 👍) and "ลบสำหรับคุณ".
-- Production apply needs its own explicit Founder approval (AGENTS.md
-- Change Control). Additive and idempotent: two new tables and three
-- RPCs; no existing table, row, policy or function is changed.
--
-- Beta2 gate: while WYN-159 is developer-only, every write RPC below
-- refuses non-developer accounts (public.is_developer_account()), so the
-- feature cannot be reached by calling the API directly. Releasing it
-- means a follow-up migration that drops those checks.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Reactions: one emoji per person per message.
-- ---------------------------------------------------------------------
create table if not exists public.message_reactions (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  emoji text not null check (emoji in ('❤️', '😂', '😮', '😢', '😡', '👍')),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create index if not exists message_reactions_message_idx
  on public.message_reactions (message_id);

alter table public.message_reactions enable row level security;

revoke all on public.message_reactions from anon, authenticated;
grant select on public.message_reactions to authenticated;
grant all on public.message_reactions to service_role;

-- Readable by the two participants of the message's conversation only.
-- No client insert/update/delete policy: set_message_reaction() is the
-- only write path (same posture as messages/message_pins).
drop policy if exists "Participants read reactions in their conversations" on public.message_reactions;
create policy "Participants read reactions in their conversations"
  on public.message_reactions for select to authenticated
  using (
    exists (
      select 1
      from public.messages m
      join public.conversations c on c.id = m.conversation_id
      where m.id = message_id
        and (select auth.uid()) in (c.user_a_id, c.user_b_id)
    )
  );

-- p_emoji null removes the caller's reaction; the same emoji again is a no-op.
create or replace function public.set_message_reaction(p_message_id uuid, p_emoji text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (
    select 1
    from public.messages m
    join public.conversations c on c.id = m.conversation_id
    where m.id = p_message_id
      and m.deleted_at is null
      and v_me in (c.user_a_id, c.user_b_id)
  ) then
    raise exception 'Message not found, deleted, or not in your conversation';
  end if;

  if p_emoji is null then
    delete from public.message_reactions where message_id = p_message_id and user_id = v_me;
    return;
  end if;

  insert into public.message_reactions (message_id, user_id, emoji)
  values (p_message_id, v_me, p_emoji)
  on conflict (message_id, user_id) do update set emoji = excluded.emoji, created_at = now();
end;
$$;

revoke all on function public.set_message_reaction(uuid, text) from public, anon;
grant execute on function public.set_message_reaction(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- "Delete for me": hides a message from one participant only.
-- ---------------------------------------------------------------------
create table if not exists public.message_hides (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  hidden_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create index if not exists message_hides_user_idx
  on public.message_hides (user_id, message_id);

alter table public.message_hides enable row level security;

revoke all on public.message_hides from anon, authenticated;
grant select on public.message_hides to authenticated;
grant all on public.message_hides to service_role;

-- Each person sees only their own hides; the other participant never
-- learns that a message was hidden.
drop policy if exists "Users read their own hidden messages" on public.message_hides;
create policy "Users read their own hidden messages"
  on public.message_hides for select to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.hide_message_for_me(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (
    select 1
    from public.messages m
    join public.conversations c on c.id = m.conversation_id
    where m.id = p_message_id
      and v_me in (c.user_a_id, c.user_b_id)
  ) then
    raise exception 'Message not found or not in your conversation';
  end if;

  insert into public.message_hides (message_id, user_id)
  values (p_message_id, v_me)
  on conflict (message_id, user_id) do nothing;
end;
$$;

revoke all on function public.hide_message_for_me(uuid) from public, anon;
grant execute on function public.hide_message_for_me(uuid) to authenticated;

-- Live reaction updates in an open conversation.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'message_reactions'
     ) then
    execute 'alter publication supabase_realtime add table public.message_reactions';
  end if;
end $$;

-- Rollback (Founder-approved only):
--   drop function if exists public.hide_message_for_me(uuid);
--   drop function if exists public.set_message_reaction(uuid, text);
--   drop table if exists public.message_hides;
--   drop table if exists public.message_reactions;


-- ---------------------------------------------------------------------
-- WYN-135: Club chat edit / pin / search
-- ---------------------------------------------------------------------
-- WYN-135 / WYNOS Web Beta 2: edit, pin and search Club channel messages.
-- STAGED ONLY. Founder approval and disposable-database QA are required
-- before this migration may run on the shared production Supabase database.
-- Web Beta 1 and the Flutter app are not modified by this migration until
-- the approved rollout; all new write/search RPCs are developer-gated.
--
-- Search: PostgreSQL full-text, not a leading-wildcard ILIKE table scan.
-- 'simple' full-text supports tokenized languages; an indexed pg_trgm
-- substring fallback supports Thai text without spaces. The two GIN indexes
-- avoid unindexed leading-wildcard ILIKE scans.

alter table public.club_channel_messages
  add column if not exists edited_at timestamptz;
alter table public.club_channel_messages
  add column if not exists pinned_at timestamptz;
alter table public.club_channel_messages
  add column if not exists pinned_by uuid references public.profiles(id) on delete set null;

-- pg_trgm may already be installed in a different schema on other projects.
-- Discover the installed operator class and schema-qualify it when indexing.
create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
do $$
declare
  v_schema text;
begin
  select n.nspname into v_schema
  from pg_opclass o join pg_namespace n on n.oid = o.opcnamespace
  where o.opcname = 'gin_trgm_ops'
  limit 1;
  if v_schema is null then raise exception 'pg_trgm GIN operator class unavailable'; end if;
  execute format(
    'create index if not exists club_channel_messages_trgm_idx on public.club_channel_messages using gin (content %I.gin_trgm_ops)',
    v_schema
  );
end $$;

create index if not exists club_channel_messages_fts_idx
  on public.club_channel_messages using gin
  (to_tsvector('simple'::regconfig, coalesce(content, '')));

create index if not exists club_channel_messages_pinned_idx
  on public.club_channel_messages (channel_id, pinned_at desc)
  where pinned_at is not null;

-- Direct UPDATE remains denied to authenticated users by the existing
-- club_channel_messages RLS policies. Editing is RPC-only so ownership,
-- current membership and the Beta2 gate are checked on the server.
create or replace function public.edit_club_channel_message(
  p_message_id uuid, p_content text
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_author uuid;
  v_club uuid;
  v_original text;
  v_body text := btrim(coalesce(p_content, ''));
begin
  if v_me is null then raise exception 'Not authenticated'; end if;
  select m.author_id, ch.club_id, m.content into v_author, v_club, v_original
  from public.club_channel_messages m
  join public.club_channels ch on ch.id = m.channel_id
  where m.id = p_message_id
  for update of m;
  if not found or v_author <> v_me or v_original is null
    or public.club_role(v_club, v_me) is null then
    raise exception 'Message not found or not yours to edit';
  end if;
  if internal.is_posting_blocked(v_me) then
    raise exception 'Posting is restricted for this account';
  end if;
  -- Check server-side: tabs/newlines and common Unicode space characters
  -- (including NBSP, zero-width space and BOM) must not become blank edits.
  if char_length(v_body) not between 1 and 2000
    or regexp_replace(v_body,
      U&'[[:space:]\00A0\1680\2000-\200B\2028\2029\202F\205F\3000\FEFF]',
      '', 'g') = '' then
    raise exception 'Message must be 1-2000 characters';
  end if;
  -- Editing changes staff-approved content; require staff to re-pin it.
  update public.club_channel_messages
  set content = v_body, edited_at = now(), pinned_at = null, pinned_by = null
  where id = p_message_id;
end;
$$;

-- Serialize pin operations by locking the CHANNEL, not the individual
-- message; simultaneous staff pins cannot pass the three-pin cap.
create or replace function public.set_club_channel_message_pin(
  p_message_id uuid, p_pin boolean
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_channel uuid;
  v_club uuid;
  v_pinned_at timestamptz;
begin
  if v_me is null then raise exception 'Not authenticated'; end if;
  if p_pin is null then raise exception 'Pin choice is required'; end if;
  select m.channel_id into v_channel
  from public.club_channel_messages m where m.id = p_message_id;
  if not found then raise exception 'Message not found'; end if;

  select ch.club_id into v_club
  from public.club_channels ch where ch.id = v_channel for update;
  if not found
    or coalesce(public.club_role(v_club, v_me), '') not in
      ('owner', 'admin', 'moderator') then
    raise exception 'Only Club staff can pin messages';
  end if;
  select m.pinned_at into v_pinned_at
  from public.club_channel_messages m
  where m.id = p_message_id and m.channel_id = v_channel
  for update;
  if not found then raise exception 'Message not found'; end if;

  if p_pin and v_pinned_at is null and
    (select count(*) from public.club_channel_messages
     where channel_id = v_channel and pinned_at is not null) >= 3 then
    raise exception 'Pin limit reached: unpin an older message first';
  end if;
  update public.club_channel_messages
    set pinned_at = case when p_pin then coalesce(pinned_at, now()) else null end,
        pinned_by = case when p_pin then coalesce(pinned_by, v_me) else null end
    where id = p_message_id;
end;
$$;

-- Search only the channel currently open and only for approved members.
-- SECURITY DEFINER protects the caller from accessing other channels by
-- guessing UUIDs; the explicit channel/member/developer checks are required.
create or replace function public.search_club_channel_messages(
  p_channel_id uuid, p_query text, p_limit integer default 30
) returns table (
  id uuid, content text, created_at timestamptz, author_id uuid
)
language plpgsql stable security definer set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_club uuid;
  v_term text := btrim(coalesce(p_query, ''));
  v_query tsquery;
  v_escaped text;
begin
  if v_me is null then raise exception 'Not authenticated'; end if;
  select ch.club_id into v_club
  from public.club_channels ch where ch.id = p_channel_id;
  if not found or public.club_role(v_club, v_me) is null then
    raise exception 'Not an approved member of this channel';
  end if;
  if v_term = '' then return; end if;
  if char_length(v_term) > 120 then raise exception 'Search is too long'; end if;
  v_query := websearch_to_tsquery('simple'::regconfig, v_term);
  -- Empty full-text queries (for punctuation) still use literal substring search.
  -- Escape wildcards so the substring fallback is literal, not caller-
  -- controlled pattern syntax. For 1–2 character Thai queries the channel_id
  -- B-tree limits an ILIKE scan; longer terms can use the pg_trgm GIN index.
  v_escaped := replace(replace(replace(v_term, chr(92), chr(92)||chr(92)),
                        '%', chr(92)||'%'), '_', chr(92)||'_');
  return query
    select m.id, m.content, m.created_at, m.author_id
    from public.club_channel_messages m
    where m.channel_id = p_channel_id
      and (
        to_tsvector('simple'::regconfig, coalesce(m.content, '')) @@ v_query
        or m.content ilike '%' || v_escaped || '%' escape chr(92)
      )
    order by m.created_at desc, m.id desc
    limit least(greatest(coalesce(p_limit, 30), 1), 30);
end;
$$;

revoke all on function public.edit_club_channel_message(uuid, text)
  from public, anon;
revoke all on function public.set_club_channel_message_pin(uuid, boolean)
  from public, anon;
revoke all on function public.search_club_channel_messages(uuid, text, integer)
  from public, anon;
grant execute on function public.edit_club_channel_message(uuid, text)
  to authenticated;
grant execute on function public.set_club_channel_message_pin(uuid, boolean)
  to authenticated;
grant execute on function public.search_club_channel_messages(uuid, text, integer)
  to authenticated;

-- Schema readiness is installed LAST. Web Beta2 checks this RPC before
-- enabling the developer UI, so a merge cannot expose a half-installed API.
create or replace function public.club_chat_actions_available()
returns boolean language sql stable security definer set search_path = public
as $wynready$ select auth.uid() is not null $wynready$;
revoke all on function public.club_chat_actions_available() from public, anon;
grant execute on function public.club_chat_actions_available() to authenticated;

-- Founder-directed rollback ONLY, after checking developer edits/pins:
--   drop function if exists public.club_chat_actions_available();
--   drop function if exists public.search_club_channel_messages(uuid,text,integer);
--   drop function if exists public.set_club_channel_message_pin(uuid,boolean);
--   drop function if exists public.edit_club_channel_message(uuid,text);
--   drop index if exists public.club_channel_messages_pinned_idx;
--   drop index if exists public.club_channel_messages_fts_idx;
--   drop index if exists public.club_channel_messages_trgm_idx;
--   alter table public.club_channel_messages drop column if exists pinned_by,
--       drop column if exists pinned_at, drop column if exists edited_at;
-- Leave pg_trgm installed: other objects may come to depend on the extension.
-- Never execute rollback automatically or while pinned/edited data is needed.


-- ---------------------------------------------------------------------
-- WYN-137: Club announcements
-- ---------------------------------------------------------------------
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
  if coalesce(public.club_role(p_club_id, v_me), '') not in ('owner', 'admin', 'moderator') then
    raise exception 'Only Club staff can post announcements';
  end if;
  -- Same moderation restriction as creating a club post.
  if internal.is_posting_blocked(v_me) then
    raise exception 'Posting is restricted for this account';
  end if;
  -- Must contain something visible: whitespace and invisible format
  -- characters (zero-width, joiners, direction marks, BOM, fillers) alone
  -- are refused.
  if char_length(v_body) not between 1 and 2000
     or regexp_replace(v_body, '[[:space:]\u00a0\u00ad\u034f\u061c\u115f\u1160\u17b4\u17b5\u180b-\u180e\u200b-\u200f\u202a-\u202e\u2060-\u206f\u3000\u3164\ufe00-\ufe0f\ufeff\uffa0]', '', 'g') = '' then
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
  select * into v_row from public.club_announcements where id = p_announcement_id;
  if v_row.id is null
     or v_row.author_id <> v_me
     or coalesce(public.club_role(v_row.club_id, v_me), '') not in ('owner', 'admin', 'moderator') then
    raise exception 'Announcement not found or not yours to edit';
  end if;
  if internal.is_posting_blocked(v_me) then
    raise exception 'Posting is restricted for this account';
  end if;
  -- Must contain something visible: whitespace and invisible format
  -- characters (zero-width, joiners, direction marks, BOM, fillers) alone
  -- are refused.
  if char_length(v_body) not between 1 and 2000
     or regexp_replace(v_body, '[[:space:]\u00a0\u00ad\u034f\u061c\u115f\u1160\u17b4\u17b5\u180b-\u180e\u200b-\u200f\u202a-\u202e\u2060-\u206f\u3000\u3164\ufe00-\ufe0f\ufeff\uffa0]', '', 'g') = '' then
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

