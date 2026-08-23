# Bug Report — WYN-044

Status: bugs
Owner: AI Debug Engineer

Bug: Independent QA (2026-08-23) ran `flutter test` for the first time against WYN-044's diff (commit `f21acac`) and found **7/7 tests failing** in the new `app/test/notification_settings_screen_test.dart` — reproducible on 2 independent runs, not flaky. Full report: see the QA agent's output recorded in this session (Final Status: FAIL). Summary of the 4 findings, ranked by severity:

1. **Major (blocking)** — all 7 tests in `notification_settings_screen_test.dart` throw `A Timer is still pending even after the widget tree was disposed` / `!timersPending` from `flutter_test`'s binding. None of the actual `expect(...)` assertions in the test bodies fail — this is a test-infrastructure leak, not a functional defect in the shipped feature.
2. **Low (security)** — `internal.notification_enabled(p_user_id, p_category)` is `security definer` with `grant execute ... to authenticated`, and has no check that the caller is `p_user_id` itself. QA confirmed by direct SQL: an ordinary `authenticated` user can call it with a *different* user's id and read that user's real per-category notification preference, even though a direct `select * from notification_settings where user_id = <other>` is correctly blocked by RLS.
3. **Minor** — the same helper's `case p_category when ... end` has no `else` branch, so an unrecognized/empty/NULL `p_category` silently falls through to `coalesce(..., true)` (fail-open, no error) instead of raising. Not currently exploitable (all 16 real call sites pass correct literals), but a future typo'd call site would silently no-op forever with no signal.
4. **Minor, non-blocking** — `notification_settings.updated_at` never advances on `upsert` (no trigger, client doesn't set it). No Acceptance Criteria depends on it; noted for awareness only, not required to fix.

Reproduction:
```
cd app
flutter pub get
flutter test test/notification_settings_screen_test.dart
```
All 7 cases fail identically:
```
A Timer is still pending even after the widget tree was disposed.
'package:flutter_test/src/binding.dart':
Failed assertion: line 2543 pos 12: '!timersPending'
```
Stack trace in every case bottoms out at `GoTrueClient.startAutoRefresh` → `new SupabaseClient` → a `RecordingNotificationSettingsRepository`/`_ControlledFetchRepository` constructed **inline inside the `testWidgets(...)` body** of each individual test case (lines 39/80/101/118/138/186 of `app/test/notification_settings_screen_test.dart`). Every `new SupabaseClient(...)` starts GoTrue's periodic auto-refresh `Timer`; nothing cancels it before that test's widget tree is disposed, tripping `flutter_test`'s leaked-timer invariant.

Root Cause: This project has an established, documented convention — construct any `Recording*Repository` that wraps a `SupabaseClient` exactly once in `setUpAll`, then reassign its mutable fields per test case, specifically *because* of this exact GoTrue timer leak (see `.wyn/learning/PATTERNS.md`, and `RecordingProfileRepository`/`RecordingMuteRepository`/`RecordingZokyRepository` elsewhere in `app/test/`). `app/test/settings_screen_test.dart` — edited in this *same* WYN-044 change — correctly follows the convention (`RecordingProfileRepository` built in `setUpAll`). `app/test/notification_settings_screen_test.dart`, written new in this same change, does not: every one of its 6 `testWidgets` blocks constructs its own repository inline instead. The file even has a `setUpAll` block (for `initFakeSupabaseSession`), so the convention wasn't followed inconsistently within the same file, not merely unknown to the author.

For finding 2 (permission leak): `grant execute on function internal.notification_enabled(uuid, text) to authenticated` (end of the WYN-044 section in `supabase/schema.sql`) is unnecessary — every real caller (13 trigger functions + `accept_follow_request`/`get_or_create_conversation`/`send_system_notification`) is itself already `security definer`, running as the function owner, so none of them need `authenticated` to hold direct EXECUTE on this helper. The grant was added by copy-pattern from every other `internal.*` helper in this file (`internal.drop_author_id`, `internal.current_platform_role`, `internal.is_drop_deleted` all have the identical grant) without checking whether *this particular* helper's callers actually need it — unlike those three, which are called directly by RLS policies evaluated as the querying `authenticated` role (so they genuinely need the grant), `internal.notification_enabled` is only ever called from inside other `security definer` function bodies.

For finding 3: same helper, no `else` branch on the `case` — an oversight, not a considered decision (nothing in the Product/Design spec calls for silent fail-open on an invalid category).

Fix:
1. `app/test/notification_settings_screen_test.dart`: move `RecordingNotificationSettingsRepository` construction into `setUpAll`, reassign its `settings`/`fetchException`/`upsertCategoryException`/`upsertCategoryOverride` fields per test case (mirror `settings_screen_test.dart`'s exact pattern in this same diff, and `RecordingProfileRepository`'s usage elsewhere). The `_ControlledFetchRepository` (used only by the loading-spinner test, which needs to observe an in-progress fetch) needs the same treatment or an equivalent fix — construct it once, not per-test, or give it the same `setUpAll`-constructed-`SupabaseClient` it currently builds inline.
2. `supabase/schema.sql`: remove `grant execute on function internal.notification_enabled(uuid, text) to authenticated;` (no caller needs it — verify by confirming all 16 gated call sites are themselves `security definer`, then re-run the RLS/leak probe QA used to confirm the leak is closed: an ordinary `authenticated` user calling `select internal.notification_enabled('<other-user-id>', 'likes')` directly must now fail with a permission-denied error, not return a value).
3. `supabase/schema.sql`: add an `else raise exception 'internal.notification_enabled: unknown category %', p_category` branch to the `case` (or equivalent), then confirm the 16 existing gated call sites still pass their SQL regression tests unaffected (they all use correct literals already, so this should be a no-op for them).

Files Changed (expected):
- `app/test/notification_settings_screen_test.dart`
- `supabase/schema.sql`

Tests: After the fix, re-run `flutter test` (full suite, must be 667/667 clean, not just the one file), re-run `supabase/tests/wyn_044_notification_settings_test.sh` plus all other existing SQL regression scripts (zero regression expected — the two SQL changes only affect direct-call authorization and invalid-input handling, not any of the 16 already-tested gate points), and add a new SQL check proving a non-owner `authenticated` call to `internal.notification_enabled()` with someone else's `p_user_id` is now rejected (extend `wyn_044_notification_settings_test.sh` rather than creating a new script, since this is the same task's table/helper).

Regression Risk: Low. The test-file fix touches only test code, not production code. The two schema changes are narrowly scoped to a single helper function that is not called by any Flutter client code directly (only by other `security definer` functions and, until this fix, by nobody legitimately as a direct `authenticated` caller) — revoking a grant nothing legitimate uses, and adding a stricter `else` branch to a `case` whose existing branches are all exercised correctly by the 16 real call sites, should not change behavior for any already-passing test.

Handoff to QA: Re-run independently: `flutter analyze` + full `flutter test` (667/667 expected), all `supabase/tests/*.sh` + `check_schema_ordering.py`, and specifically re-attempt the cross-user `internal.notification_enabled()` probe that found the Low finding — confirm it now fails with a permission error. Re-verify the Minor `p_category` finding raises instead of fail-open. `updated_at` staleness is explicitly not required to be fixed (Product/Design spec has no requirement on it) — do not block on it if still unfixed.
