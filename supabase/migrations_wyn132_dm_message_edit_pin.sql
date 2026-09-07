-- WYN-132: DM Message Actions -- Edit Message + Pin Message (1:1 Chat)
--
-- Adds `messages.edited_at` + `edit_message()` RPC (mirrors
-- `delete_message()`'s own shape: security definer, no client UPDATE
-- policy -- every existing-row mutation on `messages` goes through an
-- RPC like this one), plus a brand new `public.message_pins` table +
-- `pin_message()`/`unpin_message()` RPCs (capped at 3 pinned messages
-- per conversation). Also redefines `delete_message()` so a soft-deleted
-- message is auto-unpinned (FK `on delete cascade` can't help here,
-- since delete is a soft UPDATE, not a real DELETE on `messages`).
--
-- See .wyn/tasks/active/WYN-132-dm-message-edit-pin.md and
-- .wyn/docs/design/wyn-132-dm-message-edit-pin.md for the full spec.
--
-- SAFETY: additive column + 1 brand new table + 3 RPC (re)definitions.
-- No existing column/table dropped or renamed. Re-runnable throughout
-- (`if not exists`/`or replace`).
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.

begin;

alter table public.messages add column if not exists edited_at timestamptz;

-- edit_message(): mirrors delete_message()'s own shape exactly
-- (security definer, no client UPDATE policy on messages at all --
-- every existing-row mutation goes through an RPC like this one).
-- Restricted to plain-text messages only (Requirement: "แก้ไขได้เฉพาะ
-- ข้อความ text เท่านั้น") -- a message carrying an image and/or shared
-- content is rejected outright, even if it also has a text caption, to
-- avoid ambiguity over "editing just the caption".
create or replace function public.edit_message(p_message_id uuid, p_text text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trimmed text := trim(coalesce(p_text, ''));
begin
  if length(v_trimmed) = 0 then
    raise exception 'Message text cannot be empty';
  end if;

  update public.messages
  set text = v_trimmed, edited_at = now()
  where id = p_message_id
    and sender_id = auth.uid()
    and deleted_at is null
    and image_url is null
    and shared_content_id is null;

  if not found then
    raise exception 'Message not found, not yours, deleted, or not a plain text message';
  end if;
end;
$$;

grant execute on function public.edit_message(uuid, text) to authenticated;

-- message_pins: no client insert/update/delete policy -- pin_message()/
-- unpin_message() below are the only way to write this table (mirrors
-- messages/club_members' own "cross-row business logic (here: the
-- 3-per-conversation cap) belongs in an RPC, not a plain RLS check"
-- posture).
create table if not exists public.message_pins (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  message_id uuid not null references public.messages (id) on delete cascade,
  pinned_by uuid not null references public.profiles (id) on delete cascade,
  pinned_at timestamptz not null default now(),
  primary key (conversation_id, message_id)
);

create index if not exists message_pins_conversation_idx
  on public.message_pins (conversation_id, pinned_at desc);

alter table public.message_pins enable row level security;

drop policy if exists "Participants can view pinned messages in their conversations" on public.message_pins;
create policy "Participants can view pinned messages in their conversations"
  on public.message_pins
  for select
  to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id and auth.uid() in (c.user_a_id, c.user_b_id)
    )
  );

-- pin_message(): either participant may pin (Requirement: DM has no
-- staff/admin hierarchy, unlike Club Chat -- see WYN-135), capped at 3
-- pinned messages per conversation. Read-then-check on the count
-- (not `select ... for update`) -- a race between both participants
-- pinning the 3rd slot at once could in theory land on 4, an accepted
-- low-risk trade-off (see the design doc's own edge-case note), unlike
-- club_invite_links' redeem path (WYN-130) where the usage cap is
-- locked tighter.
create or replace function public.pin_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_conversation_id uuid;
  v_deleted_at timestamptz;
  v_count int;
begin
  select conversation_id, deleted_at into v_conversation_id, v_deleted_at
  from public.messages where id = p_message_id;

  if v_conversation_id is null then
    raise exception 'Message not found';
  end if;
  if v_deleted_at is not null then
    raise exception 'Cannot pin a deleted message';
  end if;
  if not exists (
    select 1 from public.conversations c
    where c.id = v_conversation_id and v_me in (c.user_a_id, c.user_b_id)
  ) then
    raise exception 'Not a participant of this conversation';
  end if;

  select count(*) into v_count from public.message_pins where conversation_id = v_conversation_id;
  if v_count >= 3 then
    raise exception 'At most 3 pinned messages allowed per conversation';
  end if;

  insert into public.message_pins (conversation_id, message_id, pinned_by)
  values (v_conversation_id, p_message_id, v_me)
  on conflict (conversation_id, message_id) do nothing;
end;
$$;

grant execute on function public.pin_message(uuid) to authenticated;

-- unpin_message(): deliberately not restricted to whoever pinned it --
-- either participant can unpin, same "no hierarchy, 2 equal people"
-- reasoning as pin_message() above.
create or replace function public.unpin_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  delete from public.message_pins mp
  using public.conversations c
  where mp.message_id = p_message_id
    and mp.conversation_id = c.id
    and v_me in (c.user_a_id, c.user_b_id);

  if not found then
    raise exception 'Pinned message not found, or you are not a participant';
  end if;
end;
$$;

grant execute on function public.unpin_message(uuid) to authenticated;

-- delete_message(): full re-definition -- now also auto-unpins
-- (FK `on delete cascade` on message_pins.message_id can't help here,
-- since this is a soft-delete via UPDATE, not a real DELETE on
-- messages).
create or replace function public.delete_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.messages
  set text = null, image_url = null, shared_content_type = null, shared_content_id = null, deleted_at = now()
  where id = p_message_id and sender_id = auth.uid() and deleted_at is null;

  if not found then
    raise exception 'Message not found, already deleted, or not yours';
  end if;

  delete from public.message_pins where message_id = p_message_id;
end;
$$;

commit;

-- VERIFY (run separately)
--
--   select count(*) from public.message_pins group by conversation_id
--     having count(*) > 3; -- expect 0 rows
