# Design — WYN-124: Club Invite Notification

## Decision: Notification, not Chat message

WYN-123's original launch sent a club invite as a Chat message
(`getOrCreateConversation()` + `sendMessage(sharedContentType: club)`).
Founder feedback after real production testing (2026-09-06):
"คนที่ถูกเชิญควรไปอยู่หน้าการแจ้งเตือน ไม่ใช่หน้าแชท" — the invite must
land in the recipient's Notification tab, not their Chat inbox.

This also happened to fix an unrelated coupling bug: a Chat message
requires `get_or_create_conversation()`, which raises when WYN-122's
Chat Lockdown is enabled and the pair isn't allowlisted. A club invite
has nothing to do with Chat Lockdown and should never have been subject
to it.

## New Notification type: `club_invite`

Mirrors `club_join_approved`'s shape exactly — `recipient_id` (the
invitee), `actor_id` (the inviter), `club_id`. No new column needed:
`WynNotification.clubId`/`clubName` already exist and already fetch the
club's name via the same embed every other Club notification type uses.

Message (mirrors `club_join_approved`'s own wording pattern):
> `{actorName} ชวนคุณเข้าร่วม {clubName}`

Tap destination: opens `ClubPage` on the default Posts tab (index 0) —
same as `club_join_approved`. The recipient hasn't joined yet, so the
Club page's own membership UI (join button / pending state) is what
handles "what happens next," not this notification.

## RPC: `invite_to_club(p_club_id, p_invitee_id)`

`security definer`, re-validates everything server-side rather than
trusting the client's own Followers/Following filter:

1. Caller authenticated, not inviting self.
2. Caller is an approved member of the club (`club_role()` is not
   null) — only members can invite people in.
3. Invitee exists.
4. Neither side has blocked the other.
5. Invitee is a follower of the caller **or** the caller follows the
   invitee (either direction) — WYN-123's Founder decision, "ทั้งสองทาง
   (Followers + Following)", now enforced server-side too, not just by
   which list `InviteToClubScreen` fetched the profile from.

If all checks pass, and `internal.notification_enabled(invitee, 'club')`
is true, and no `club_invite` notification already exists for this
exact (actor, recipient, club) triple within the last 24 hours (dedup —
mirrors `notify_club_post_new()`'s 3h dedup, scaled up since invites
are much rarer than posts), inserts one `notifications` row.

Deliberately does **not** raise or return an error when
`notification_enabled` is false or the dedup window blocks it — same
"silent no-op, not a client-visible failure" posture
`notify_club_join_approved()` already uses for its own
`notification_enabled` check. The inviter always sees success (the
invite honestly did everything it's supposed to); whether the
recipient sees it is up to their own settings/recent-activity, same as
every other notification type.

## Why not keep the Chat message too

Considered sending both (Notification + Chat message as a durable
record). Rejected: doubles the surface area for the same one action,
re-introduces the exact Chat Lockdown coupling this task exists to
remove, and a club invite is not a conversation — nothing about it
benefits from also living in the Chat inbox. The Notification list
already keeps its own history the same way `club_join_approved` does.

## Client changes

- `ClubRepository.inviteToClub({clubId, inviteeId})` — thin RPC
  wrapper, same shape as `approveMember`/`rejectMember`/etc.
- `InviteToClubScreen` takes `clubRepository` instead of
  `chatRepository` — its own UI (idle → sending → เชิญแล้ว, per-row
  state, error snackbar) is unchanged, only what `_invite()` calls
  underneath changes.
- `NotificationListScreen`/`push_notification_service.dart`/the Edge
  Function's `messageFor()` all get one new case each, following the
  exact pattern every prior notification type used.
