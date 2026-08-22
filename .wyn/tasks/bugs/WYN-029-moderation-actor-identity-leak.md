# Bug Report — WYN-029

Status: bugs (NEW — found by AI QA & Security, independent round 1, 2026-08-22)
Owner: AI Debug Engineer

Bug: `apply_moderation_action()`'s Warning and Remove Content effects
insert a `notifications` row with `actor_id` set to the reviewing
moderator's own `auth.uid()` (the real human who took the action) — the
exact identity both the schema.sql comment and the Dart code comment
explicitly say must **never** surface to the target ("mirrors WYN-026's
reporter-identity protection, opposite direction... reviewer_id would
leak who reviewed them"). `moderation_actions.reviewer_id` itself *is*
correctly protected (no client SELECT policy grants any role, including
the target, access to that table at all) — but the same identity is
simultaneously written into `notifications.actor_id`, a column on a
table the target has full, ordinary, RLS-permitted row access to
(`using (auth.uid() = recipient_id)`, same policy every other
notification type relies on for the target to see their own
notifications at all).

`NotificationListScreen` does correctly avoid *displaying* the actor for
these two types (`_hidesActorIdentity()` swaps in a generic shield icon
and generic wording instead of interpolating the actor's name) — but
that is a UI-layer choice made by one specific screen, not an
access-control boundary. The underlying `WynNotification` object still
has `actorId`/`actorUsername`/`actorDisplayName` fully populated
(`notification_repository.dart`'s fetch query embeds
`actor:profiles!notifications_actor_id_fkey(id, username, display_name,
avatar_url)` unconditionally, for every type), and the same data is
reachable by anyone re-issuing the identical Supabase REST call
`NotificationListScreen` already makes, by inspecting that call's own
network response, or by any future/different code path that touches
`WynNotification`/the `notifications` table without independently
re-implementing `_hidesActorIdentity`'s guard. This is the same class of
mistake WYN-027 already taught this project once: a UI/client-side
omission is not a data-access boundary — see
`.wyn/tasks/bugs/WYN-027-is-blocked-either-way-rpc-exposure.md` for the
first occurrence.

Reproduction (verified against a fresh local PostgreSQL 16,
`supabase/schema.sql` loaded clean with `ON_ERROR_STOP=1`, queries run
as role `authenticated` with `request.jwt.claim.sub` set):

1. Seed a target user (`Alice`) and a moderator (`the_mod` /
   `platform_role = 'moderator'`, display name "Secret Moderator").
   Alice posts a Drop.
2. As the moderator: `submit_report('drop', <alice's drop>, 'spam',
   null)`, then `apply_moderation_action(<that report>, 'warning', 'do
   not post spam', null)`.
3. As Alice (the target, `request.jwt.claim.sub` = her own id), run the
   *exact* query shape `notification_repository.dart` uses against her
   own notifications:

```sql
select n.id, n.type, n.reason,
       p.id as actor_id, p.username as actor_username, p.display_name as actor_display_name
from public.notifications n
join public.profiles p on p.id = n.actor_id
where n.recipient_id = '<alice>' and n.type = 'moderation_warning';
```

Result: **one row, with `actor_username = 'the_mod'`, `actor_display_name
= 'Secret Moderator'`** — Alice, using nothing but her own ordinary,
fully-legitimate session, can directly identify which moderator reviewed
and warned her. The same applies to `moderation_content_removed`.

Root Cause: `apply_moderation_action()` (supabase/schema.sql, WYN-029
section) inserts `actor_id = v_reviewer` (i.e. `auth.uid()` of whoever
called the RPC) for both `moderation_warning` and
`moderation_content_removed`. `notifications.actor_id` is `not null`
and has no per-type visibility rule — RLS on `notifications` is
row-level (`auth.uid() = recipient_id`), not column-level, so there is
no way to make one column of an otherwise-visible row invisible via
policy. The design intent ("never surface") was implemented entirely at
the Dart presentation layer (`_hidesActorIdentity()` in
`notification_list_screen.dart`), which controls what one screen
*renders*, not what the underlying row *contains* or what a client can
*fetch*.

Fix: `notifications.actor_id`'s `not null` constraint needs to be
relaxed, and `apply_moderation_action()` needs to insert `NULL` for
`actor_id` on these two action types instead of `v_reviewer` — the true
reviewer identity is already correctly recorded for audit purposes in
`moderation_actions.reviewer_id` (never client-reachable), so nothing is
lost by not *also* writing it somewhere the target can read.

Concretely:
1. `alter table public.notifications alter column actor_id drop not null;` (verify no other code path relies on `actor_id` always being present — grep the Dart client and any other trigger function in this file for `actor_id` usage first, per this project's "grep, don't trust memory" convention from the WYN-027 fix).
2. In `apply_moderation_action()`, change the `warning`/`remove_content` `insert into public.notifications (...)` calls to insert `actor_id = null` (or omit the column, relying on the new nullable default) instead of `v_reviewer`.
3. PostgREST's embedded-resource syntax (`actor:profiles!notifications_actor_id_fkey(...)`) degrades gracefully to a null embed when the FK column itself is null — confirm this empirically against a real query, don't assume.
4. `WynNotification.fromMap` (`app/lib/features/notification/data/notification.dart`) currently does `actor['username'] as String? ?? ''` assuming `actor` itself is a non-null map — this will need a null-safe path for these two types (or generally, since `actor` can now legitimately be null). Decide whether `actorUsername`/`actorDisplayName`/`actorId` on `WynNotification` should become nullable, or whether a placeholder value is synthesized in the model layer — either is fine as long as it's still impossible to recover the real reviewer identity from the object, unlike today.
5. Once `actorId` can genuinely be null/absent for these two types, `NotificationListScreen`'s existing `_hidesActorIdentity()` UI logic can stay as extra defense-in-depth (belt-and-suspenders), but the actual privacy guarantee now holds even if that function is ever removed, forgotten on a new screen, or bypassed by a direct API call.

Do not reintroduce a "system account" pseudo-profile as an alternative
fix without checking `profiles.id references auth.users(id)` first — a
synthetic actor would need a real corresponding `auth.users` row created
out-of-band (by the Founder, similar to the first admin's
`platform_role`), which is a heavier, more operationally fragile fix
than simply allowing `actor_id` to be null for this one case.

Files Changed (expected): `supabase/schema.sql` (drop the `not null` on
`notifications.actor_id`, update `apply_moderation_action()`'s two
`insert into notifications` calls), `app/lib/features/notification/data/notification.dart`
(null-safety for `WynNotification.fromMap`'s actor fields).
`notification_list_screen.dart`'s `_hidesActorIdentity()`/rendering
logic likely does not need to change at all (it already renders
correctly without relying on the actor fields for these two types) but
re-run its tests regardless.

Tests: Verify against real Postgres, red→green:
1. Reproduce the leak above on the *pre-fix* schema (confirm red).
2. Apply the fix, re-run the identical query as the target — confirm `actor_id`/the embedded `actor` resolve to null/nothing.
3. Confirm `moderation_actions.reviewer_id` (the correct audit trail) is untouched and still correctly protected (no new SELECT access introduced for the target).
4. Re-run `supabase/tests/wyn_029_moderation_queue_test.sh` (the existing 32-check regression suite) plus `wyn_021_club_post_mentions_rls_test.sh`/`wyn_027_is_blocked_either_way_rpc_exposure_test.sh` — confirm no regression.
5. `flutter analyze`/`flutter test` — the two Dart files above will need their own test coverage for a null actor (extend `notification_list_screen_test.dart` with a case using a null/absent actor for `moderation_warning`/`moderation_content_removed`, proving the screen still renders correctly and doesn't crash on `WynNotification.fromMap`).

Regression Risk: Low-moderate. `actor_id` is read in exactly one place
in the Dart client (`WynNotification.fromMap`) and referenced by name in
one SQL function (`apply_moderation_action()`) for the two new types —
every *other* notification type's `insert into notifications` call
already always supplies a real actor and is unaffected by relaxing the
column's nullability. The main risk is the `fromMap` null-safety change
touching a shared model class used by every notification type — verify
the existing (larger) `flutter test` suite for notifications still
passes in full, not just the two new test cases.

Handoff to QA: Once fixed, send back to AI QA & Security for round 2 —
must re-verify directly against real Postgres (not just read the diff)
that the reproduction above is now blocked, re-run the full WYN-029
independent verification (32-check regression script + a fresh review
of the Acceptance Criteria), and confirm no regression across the wider
notification system (every other notification type's actor display
must be completely unaffected).
