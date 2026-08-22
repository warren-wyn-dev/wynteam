# Bug Report — WYN-029

Status: bugs (FIXED by AI Debug Engineer, 2026-08-22 — awaiting AI QA & Security independent round 2 verification)
Owner: AI Debug Engineer (เสร็จ) → AI QA & Security (รอบ 2 — pending)

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

---

## Debug Output (AI Debug Engineer)

**Reproduction (own, independent from QA's)**: this sandbox has local
PostgreSQL 16 available and already online (`service postgresql status`
showed `16/main (port 5432): online`). Built the same stub harness this
project's prior WYN-021/WYN-027/WYN-029 sessions used (`auth.users`/
`auth.uid()`/`auth.role()`, `storage.buckets`/`storage.objects`/
`storage.foldername()`, roles `authenticated`/`anon`), loaded
`supabase/schema.sql` clean (`ON_ERROR_STOP=1`, 0 errors) into a fresh
throwaway DB, then reproduced the exact scenario from this report: Alice
posts a Drop, the moderator (`the_mod` / `platform_role = 'moderator'`,
display name "Secret Moderator") submits a report against it and applies
`'warning'`. As Alice (`request.jwt.claim.sub` = her own id, role
`authenticated`), re-ran the exact query shape
`notification_repository.dart` uses (`notifications` joined to
`profiles` on `actor_id`) — got back **`actor_username = 'the_mod'`,
`actor_display_name = 'Secret Moderator'`**, confirming the leak exactly
as reported, independently, before touching any code. Also confirmed the
sanity control the report implies but doesn't explicitly test: Alice's
raw `select count(*) from public.moderation_actions` as herself returns
**0** — the audit-trail table is correctly protected; the bug is
specifically the duplicated identity that also ends up in
`notifications.actor_id`.

**Root cause confirmed by reading the code, not guessed**: grepped the
whole `schema.sql` for `actor_id` (18 occurrences) and confirmed every
`insert into public.notifications (recipient_id, actor_id, ...)` site
except the two WYN-029 ones (`notify_drop_like`, `notify_pop_like`,
`notify_drop_comment`, `notify_pop_comment`, `notify_follow`, the WYN-015
Club triggers, the ZOKY-005 R1 order triggers, WYN-020/021 mention
triggers) always supplies a real, non-null actor id (`new.user_id`,
`new.author_id`, `v_reviewer`, etc.) — confirming the bug report's claim
that relaxing the column's `not null` constraint is safe for every other
type. Grepped the Dart client for `actorId`/`actor_id`/`actorUsername`/
`actorDisplayName` and confirmed the only place `notification.dart`'s
`actor_id` gets read is `WynNotification.fromMap`'s `final actor =
map['actor'] as Map<String, dynamic>;` (a non-nullable cast that would
throw a type error the moment `actor_id`/the embed is ever null), and
that `notification_list_screen.dart`'s `_messageFor`/`_openNotification`/
row-rendering logic for `moderationWarning`/`moderationContentRemoved`
never actually uses `actorId`/`actorUsername`/`actorDisplayName` (only
`reason`), confirming the report's claim that no rendering-logic change
is needed there — only null-safety on the shared model.

**Fix applied** — exactly the direction this report recommended, nothing
heavier:
1. `supabase/schema.sql`: dropped `notifications.actor_id`'s `not null`
   constraint (kept the FK itself). Changed both
   `apply_moderation_action()` insert sites (`warning`,
   `remove_content`) to insert `actor_id = null` instead of `v_reviewer`.
   `v_reviewer` itself is untouched everywhere else in the function
   (still used for the `moderation_actions.reviewer_id` insert and the
   moderator-role check) — this is a 2-line behavioral change plus
   comments, not a refactor.
2. `app/lib/features/notification/data/notification.dart`: made
   `actorId`/`actorUsername` nullable on `WynNotification` (previously
   `required`/non-nullable — every other field the model already treats
   as optional stayed as-is). `fromMap` now reads `map['actor'] as
   Map<String, dynamic>?` (nullable cast) and every `actor?['...']`
   field with `?.`, instead of a hard non-null cast. `actorNameOrUsername`
   (a getter `_messageFor` calls unconditionally for every notification
   type, including the 2 moderation ones, even though the result is
   unused there) now returns `''` instead of crashing when
   `actorUsername` is null, rather than calling
   `displayNameOrUsername()` with a non-null-asserted null.
3. `app/lib/features/notification/presentation/notification_list_screen.dart`:
   two call sites needed a null-safety touch-up for the now-nullable
   type, not a logic change — `_openProfile(notification.actorId!)` for
   the `follow` case (follow always has a real actor;
   `notify_follow()`'s trigger guarantees it, and `follow` never reaches
   the moderation branch), and `fallbackText: notification.actorUsername
   ?? ''` for the `AvatarCircle` in the "not hidden" render branch (also
   never actually null in practice, since `_hidesActorIdentity()` routes
   the 2 null-actor types to the shield-icon branch instead). Confirmed
   by re-reading the full file that `_hidesActorIdentity()`,
   `_messageFor`, and `_openNotification`'s moderation-type handling
   needed **zero** logic changes, exactly as the bug report predicted —
   only these 2 type-safety touch-ups.

**PostgREST embedded-resource degradation, confirmed empirically, not
assumed**: no live PostgREST server is available in this sandbox (only
the Dart `postgrest` client package, no server binary), so — following
the same empirical-substitute approach this project's WYN-027 Debug
session used for RLS-boundary claims it couldn't test through a live
Supabase project either — verified the actual SQL-level mechanism
PostgREST's embed generates for a nullable FK: ran both the exact inner
`join` from this report's reproduction (`notifications n join profiles p
on p.id = n.actor_id`) and a `left join` (the standard SQL shape a
nullable-FK embed degrades to) against the post-fix schema, as Alice.
Inner join: **0 rows** (the identity is unreachable through that exact
query shape — the leak is closed). Left join: **1 row**, with
`actor_id`, `actor_id_join`, `actor_username`, and `actor_display_name`
all **NULL** — confirming a null `actor_id` produces a notification row
with a null embedded `actor` object (exactly what
`WynNotification.fromMap`'s new nullable-cast path is written to
handle), not an error or a dropped row.

**Verified against real Postgres, red→green, independently reproduced
both directions**:
- Pre-fix (current HEAD before this session's changes): the reproduction
  above leaked `the_mod`/`Secret Moderator` to Alice, exactly as
  reported.
- Post-fix: identical query returns 0 rows for the inner join; the left
  join shows the notification row with a fully-null actor.
  `moderation_actions` stayed 0 rows for Alice throughout (unaffected).
- `bash supabase/tests/wyn_029_moderation_queue_test.sh` (existing 32
  checks) — **PASS** before any of my changes (confirms the pre-existing
  suite doesn't already cover this gap, matching the bug report).
- Extended that same persisted script with 4 new checks (`CHECK7e`/
  `CHECK7f` for `moderation_warning`, `CHECK21b`/`CHECK21c` for
  `moderation_content_removed`) — `CHECK7e`/`CHECK21b` assert
  `actor_id is null` directly; `CHECK7f`/`CHECK21c` re-run the exact
  join-based reproduction as the target role, asserting 0 rows. Did the
  project's standard `git stash`/`git stash pop` proof with this exact
  persisted script (not a throwaway variant): `git stash push --
  supabase/schema.sql` (reverting only the schema fix, keeping the new
  checks) → ran the script → **4 checks failed** (`CHECK7e`/`CHECK7f`/
  `CHECK21b`/`CHECK21c`, all "expected X, got Y" mismatches from the
  still-non-null `actor_id`) → `git stash pop` (fix restored) → ran
  again → **all 36 checks passed**.
- Re-ran `supabase/tests/wyn_021_club_post_mentions_rls_test.sh` (5/5)
  and `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh`
  (9/9) against the fixed schema — no cross-task regression.
- Reloaded the complete fixed `schema.sql` standalone into one more
  fresh DB (0 errors, `ON_ERROR_STOP=1`) as a final sanity check.

**Dart-side red→green, done independently of the SQL proof above**:
added `app/test/notification_test.dart` (new — this project had no
dedicated `WynNotification` model test file yet, unlike sibling models
such as `drop_test.dart`; followed that file's existing
`Drop.fromMap`-testing convention) covering `WynNotification.fromMap`
with a populated actor (regression control), a `null` `actor` key, and
an entirely absent `actor` key — plus `actorNameOrUsername` with a null
`actorUsername`. Extended `notification_list_screen_test.dart` with a
new fixture pair (`moderationWarningNullActorNotification`/
`moderationContentRemovedNullActorNotification`, deliberately *not*
reusing the existing fixtures that carry a real reviewer identity — this
project's own convention distinguishes "the UI hides a real value" tests
from "the underlying value is genuinely absent" tests, see WYN-021's
distinction between an outright-blocked outsider vs. a pending/banned
member in its own QA round 2) and one new `testWidgets` case proving the
screen renders both moderation types correctly with `tester.takeException()
== null`, no `AvatarCircle`, the shield icon, and a tap that still
no-ops — using the actual post-fix null-actor shape, not the
hidden-real-actor shape the pre-existing tests already covered.

Proved these specific new tests exercise the fix, not just pass
incidentally: `git stash push -- app/lib/features/notification/data/notification.dart
app/lib/features/notification/presentation/notification_list_screen.dart`
(reverting only the Dart fix, keeping the new tests) → `flutter test
test/notification_test.dart test/notification_list_screen_test.dart` →
**compilation failure** (`Required named parameter 'actorId' must be
provided` at every new call site that omits it) — the new tests cannot
even compile against the pre-fix, non-nullable `WynNotification`,
confirming they're load-bearing. `git stash pop` (fix restored) → same
command → **all tests pass** (32/32 in
`notification_list_screen_test.dart`, 6/6 in the new
`notification_test.dart`).

**Full suite**: `flutter analyze` — clean, no issues. `flutter test` —
**433/433 passed** (up from 426 at HEAD before this session, the 7 new
tests: 1 in `notification_list_screen_test.dart` + 6 in
`notification_test.dart`), 0 failures — confirms the shared
`WynNotification` model change didn't regress any other notification
type's own tests (order/club/mention/like/comment/follow types all
untouched, all still pass with their existing non-null actor fixtures).

**Files Changed**: `supabase/schema.sql` (dropped `notifications.actor_id`'s
`not null` constraint; `apply_moderation_action()`'s `warning`/
`remove_content` insert sites now write `actor_id = null` instead of
`v_reviewer`), `app/lib/features/notification/data/notification.dart`
(`actorId`/`actorUsername` now nullable; `fromMap` and
`actorNameOrUsername` made null-safe), `app/lib/features/notification/presentation/notification_list_screen.dart`
(2 null-safety touch-ups, zero logic changes),
`supabase/tests/wyn_029_moderation_queue_test.sh` (4 new persisted
checks), `app/test/notification_list_screen_test.dart` (1 new test + 2
new fixtures), `app/test/notification_test.dart` (new file, 6 tests).
Did not touch `.wyn/tasks/review/WYN-029-moderation-queue.md`'s status —
left for AI QA & Security's own round-2 verification per this task's
instructions.

**Regression Risk**: Low, as the bug report anticipated. The nullable-
column change only affects the 2 notification types that now
deliberately use it; every other type's insert site was grepped and
confirmed unaffected both before writing the fix and again by the full
`flutter test` suite passing in full afterward. The Dart model change
touches a shared class every notification type uses, which is why the
full 433-test suite (not just the 7 new/touched tests) was run, not a
narrower subset.

**Considered and rejected**: a synthetic "system account" profile as an
alternative to a nullable `actor_id`, per this task's explicit "What NOT
to do" — confirmed the reason it's the wrong call before dismissing it,
not just citing the instruction: `profiles.id references auth.users(id)
on delete cascade` (`supabase/schema.sql`), so a synthetic actor would
need a real, out-of-band-created `auth.users` row (the same operational
step the first admin's `platform_role` promotion requires), making it
heavier and more fragile than simply allowing `actor_id` to be null for
a case where null is semantically exactly correct (no actor should be
attributable at all).

**Lessons learned**: recorded in `.wyn/learning/LESSONS_LEARNED.md` and
`.wyn/learning/MISTAKES.md` — same class of mistake as WYN-027
(UI/client-side omission is not a data-access boundary), but this
occurrence is the "sibling" version: a *new* denormalized copy of an
already-correctly-protected identity (`moderation_actions.reviewer_id`)
was introduced on a *different*, more permissively-visible table
(`notifications`) without re-deriving whether the same protection
still applied there. Any future feature that denormalizes a sensitive
identity onto a second table for convenience must re-check that
table's own RLS/visibility model independently — "the source table is
protected" does not transitively protect a copy on a different table.

**Handoff to QA**: send back to AI QA & Security for round 2 — must
re-verify directly against real Postgres independently (not just trust
this report) that (a) the leak reproduction is now blocked (both the
inner-join and left-join checks), (b) all 36 checks in
`wyn_029_moderation_queue_test.sh` pass, (c) `wyn_021_club_post_mentions_rls_test.sh`/
`wyn_027_is_blocked_either_way_rpc_exposure_test.sh` show no cross-task
regression, and (d) the wider notification system (every other type's
actor display) is unaffected — plus a fresh walk of WYN-029's
Requirements/Design/Acceptance Criteria, per this project's standard
workflow. All 3 SQL scripts are re-runnable directly (`bash
supabase/tests/wyn_029_moderation_queue_test.sh`, etc.) if this
sandbox's local Postgres is still available in QA's session. Task status
in `.wyn/tasks/review/WYN-029-moderation-queue.md` is left as-is for QA
to update after their own independent round-2 verification — not
updated by this Debug session.
