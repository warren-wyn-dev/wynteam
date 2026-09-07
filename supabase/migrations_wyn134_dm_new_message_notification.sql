-- WYN-134: DM "New Message" Notification
--
-- Closes a known gap accepted since WYN-032: an 'active' (not
-- 'pending') 1:1 conversation had no notification at all for a new
-- incoming message unless the recipient happened to have
-- ConversationScreen open (realtime only) -- unlike Club, which
-- already got this via WYN-116. No new column: reuses
-- notifications.conversation_id, added by WYN-032 for
-- message_request.
--
-- This block was extracted verbatim from supabase/schema.sql (the
-- WYN-134 section) -- unlike WYN-136/138/139, AI Coding did not create
-- a standalone migrations_wyn134_*.sql file (it only exists baked into
-- schema.sql). AI Deploy & DevOps extracted this file byte-identical
-- from schema.sql for the Founder's convenience running it via
-- Supabase Dashboard -> SQL Editor, and independently re-tested that
-- it applies cleanly against a throwaway "pre-Phase-A production"
-- database -- see .wyn/logs/deployments/2026-09-07-wyn-134-136-137-138-139-phase-a-go-live-package.md.
--
-- See .wyn/tasks/approved/WYN-134-dm-new-message-notification.md and
-- .wyn/docs/design/wyn-134-dm-new-message-notification.md for the
-- full spec.
--
-- SAFETY: additive to the notifications_type_check CHECK constraint
-- (dynamically finds+drops whatever the current constraint name is,
-- same pattern as the 'redrop'/'club_channel_message' additions
-- elsewhere in schema.sql) + a new trigger on `messages` + a full
-- re-definition of the pre-existing `mark_conversation_read()` RPC
-- (adds a 4th UPDATE clearing new_message notifications, does not
-- remove or change any of its existing behavior -- verified by
-- regression test, see supabase/tests/wyn_134_dm_new_message_notification_test.sh).
-- Re-runnable throughout (`create or replace`/`drop trigger if
-- exists`/dynamic constraint-name lookup).
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.

begin;

-- Mirrors the 'redrop'/'club_channel_message' additions elsewhere in
-- schema.sql: dynamically find+drop whatever the current CHECK
-- constraint name is rather than assuming a specific name.
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
    and tc.table_name = 'notifications'
    and tc.constraint_type = 'CHECK'
    and ccu.column_name = 'type';

  if v_constraint_name is not null then
    execute format('alter table public.notifications drop constraint %I', v_constraint_name);
  end if;
end;
$$;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'like_drop', 'like_pop', 'comment_drop', 'comment_pop', 'follow',
    'club_join_request', 'club_join_approved', 'club_post_like', 'club_post_comment',
    'mention_drop', 'mention_club_post',
    'moderation_warning', 'moderation_content_removed',
    'appeal_approved', 'appeal_rejected',
    'message_request', 'redrop',
    'follow_request', 'follow_request_accepted',
    'system',
    'club_post_new', 'club_post_pinned',
    'club_invite',
    -- WYN-134: fired by notify_new_message() below.
    'new_message'
  ));

-- notify_new_message(): AFTER INSERT on messages -- mirrors
-- get_or_create_conversation()'s own message_request insert exactly
-- (same 'messages' notification_enabled category). Only fires for an
-- 'active' conversation -- a 'pending' one already got its one-time
-- message_request notification at creation (see that function) and
-- must not re-fire on every message the requester sends while
-- waiting on a decision. No block/posting-restriction check needed
-- here either: the messages INSERT policy already rejects a blocked-
-- either-way/posting-blocked sender before this trigger ever runs, so
-- a row only ever reaches here having already passed that gate.
create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation public.conversations;
  v_recipient uuid;
begin
  select * into v_conversation from public.conversations where id = new.conversation_id;
  if v_conversation is null or v_conversation.status <> 'active' then
    return new;
  end if;

  v_recipient := case when v_conversation.user_a_id = new.sender_id
                       then v_conversation.user_b_id
                       else v_conversation.user_a_id end;

  -- WYN-031: respects the recipient's own per-conversation mute.
  if exists (
    select 1 from public.conversation_mutes
    where conversation_id = new.conversation_id and user_id = v_recipient
  ) then
    return new;
  end if;

  if internal.notification_enabled(v_recipient, 'messages') then
    insert into public.notifications (recipient_id, actor_id, type, conversation_id)
    values (v_recipient, new.sender_id, 'new_message', new.conversation_id);
  end if;

  return new;
end;
$$;

drop trigger if exists messages_notify_new_message on public.messages;
create trigger messages_notify_new_message
  after insert on public.messages
  for each row execute function public.notify_new_message();

-- mark_conversation_read(): full re-definition (not just a new branch)
-- -- now also clears any unread new_message notification(s) for this
-- conversation, in the same transaction. This is the entire mechanism
-- behind "opened the conversation right when the message arrived never
-- visibly shows an unread badge" (see the design doc's "การตัดสินใจ
-- สำคัญ" section): ConversationScreen already calls this RPC on
-- initState, on every realtime message received while the screen is
-- open (_onRealtimeMessage), and on resume-from-background -- no
-- client change needed for this AC.
create or replace function public.mark_conversation_read(p_conversation_id uuid)
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

  update public.conversations
  set user_a_last_read_at = case when user_a_id = v_me then now() else user_a_last_read_at end,
      user_b_last_read_at = case when user_b_id = v_me then now() else user_b_last_read_at end
  where id = p_conversation_id and v_me in (user_a_id, user_b_id);

  if not found then
    raise exception 'Conversation not found, or you are not a participant';
  end if;

  update public.notifications
  set is_read = true
  where recipient_id = v_me
    and conversation_id = p_conversation_id
    and type = 'new_message'
    and is_read = false;
end;
$$;

commit;

-- VERIFY (run separately)
--
--   select conname from pg_constraint where conname = 'notifications_type_check'; -- expect 1 row
--   select tgname from pg_trigger where tgname = 'messages_notify_new_message'; -- expect 1 row
