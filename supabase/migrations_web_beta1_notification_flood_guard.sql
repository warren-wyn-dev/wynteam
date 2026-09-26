-- =====================================================================
-- Web Beta1 QA — WEB-B1-QA-02: notification / Push flood guard
--
-- Founder runs this via the Supabase Dashboard SQL editor; no AI applies
-- production SQL (AGENTS.md Change Control). Idempotent: safe to re-run.
--
-- Problem: follow → unfollow → follow (or like → unlike → like, request →
-- cancel → request, repost → undo → repost) inserts a brand-new
-- notifications row every time. Each row fires the send-push-notification
-- Database Webhook with the row id as collapse key, so one account could
-- flood another user's phone with unlimited Push banners.
--
-- Fix: a BEFORE INSERT trigger on public.notifications silently skips an
-- insert when the SAME actor already notified the SAME recipient about the
-- SAME target with the SAME toggleable type in the last 10 minutes.
-- Returning NULL from a BEFORE row trigger drops only this row — the like /
-- follow itself still succeeds, and because no row is written the Push
-- webhook never fires.
--
-- Not deduplicated (each one is distinct content or must always arrive):
-- comments, mentions, messages, message requests, club posts / pins /
-- invites / approvals, moderation, appeals and system notices.
-- =====================================================================

create or replace function internal.skip_duplicate_toggle_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.actor_id is null
     or new.type not in (
       'follow', 'follow_request', 'follow_request_accepted',
       'like_drop', 'like_pop', 'club_post_like', 'redrop',
       'club_join_request'
     ) then
    return new;
  end if;

  if exists (
    select 1
    from public.notifications n
    where n.recipient_id = new.recipient_id
      and n.actor_id = new.actor_id
      and n.type = new.type
      and n.drop_id is not distinct from new.drop_id
      and n.pop_id is not distinct from new.pop_id
      and n.club_id is not distinct from new.club_id
      and n.club_post_id is not distinct from new.club_post_id
      and n.created_at > now() - interval '10 minutes'
  ) then
    return null;
  end if;

  return new;
end;
$$;

revoke all on function internal.skip_duplicate_toggle_notification() from public, anon, authenticated;

drop trigger if exists notifications_skip_duplicate_toggle on public.notifications;
create trigger notifications_skip_duplicate_toggle
  before insert on public.notifications
  for each row execute function internal.skip_duplicate_toggle_notification();

-- The duplicate lookup is (recipient, actor, type, recent). The existing
-- notifications_recipient_created_idx (recipient_id, created_at desc) already
-- narrows it to one recipient's last 10 minutes; this index makes it exact.
create index if not exists notifications_recipient_actor_type_created_idx
  on public.notifications (recipient_id, actor_id, type, created_at desc);
