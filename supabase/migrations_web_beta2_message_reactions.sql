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

revoke all on public.message_reactions from anon;
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
  if not public.is_developer_account() then
    raise exception 'Reactions are not available yet';
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

revoke all on public.message_hides from anon;
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
  if not public.is_developer_account() then
    raise exception 'Delete for me is not available yet';
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
