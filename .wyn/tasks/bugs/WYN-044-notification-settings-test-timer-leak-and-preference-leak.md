# Bug Report — WYN-044

Status: fixed, handed off to QA
Owner: AI Debug Engineer (done) → AI QA & Security (round 2, pending)

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

---

## Debug Output (AI Debug Engineer, 2026-08-23)

**Reproduction (own, independent from QA's)**: ran `flutter test test/notification_settings_screen_test.dart` against the pre-fix code (Flutter 3.47.1, `/opt/flutter`) — reproduced **7/7 failures**, exact same stack trace the bug report describes (`A Timer is still pending even after the widget tree was disposed` / `!timersPending`, bottoming out at `GoTrueClient.startAutoRefresh` → `new SupabaseClient` → a repository constructed inline inside each `testWidgets` body). Confirmed before touching any code.

### Fix 1 — test timer leak (`app/test/notification_settings_screen_test.dart`)

Applied exactly the fix the bug report specified: `RecordingNotificationSettingsRepository` and `_ControlledFetchRepository` are now both constructed exactly once in `setUpAll`, mirroring `settings_screen_test.dart`'s `RecordingProfileRepository` pattern in this same diff. Added a `setUp` block that resets `settings`/`fetchException`/`upsertCategoryException`/`upsertCategoryOverride`/`upsertCategoryArgs` before each test case, and gave `_ControlledFetchRepository` a mutable `future` field (reassigned per test, only used by the loading-spinner test) instead of taking it as a constructor argument. Re-ran the file after the fix: **7/7 pass**, 0 leaked-timer errors.

### Fix 2 — permission leak (`supabase/schema.sql`) — root cause refined beyond the original bug report

The bug report's prescribed fix ("remove `grant execute on function internal.notification_enabled(uuid, text) to authenticated;`, no caller needs it") is necessary but **was not sufficient on its own** — verified this empirically, not by assumption, per this role's "ห้ามเดา root cause" rule:

1. Applied only the prescribed removal first (deleted the `grant` line, changed nothing else).
2. Added a new SQL check (`CHECK20` in `wyn_044_notification_settings_test.sh`) that has Bob (an ordinary `authenticated` user) call `select internal.notification_enabled('<stranger's uuid>', 'likes')` directly.
3. Ran it: **the call still succeeded** (no permission error) — the leak was still open even with the grant line removed.

Root cause of *why* the prescribed fix alone didn't work, confirmed by reading this same file's own prior precedent (`.wyn/tasks/bugs/WYN-027-is-blocked-either-way-rpc-exposure.md`, which documents the identical class of bug in this schema before): PostgreSQL grants `EXECUTE` on a newly created function to `PUBLIC` by default, and `authenticated` already holds `usage` on the whole `internal` schema (`grant usage on schema internal to authenticated;`, added once for the RLS-embedded helpers that genuinely need it, e.g. `internal.is_blocked_either_way`). Schema `usage` + default `PUBLIC`-execute is already sufficient for any `authenticated` caller to invoke `internal.notification_enabled` directly by SQL — deleting only the *explicit* `grant ... to authenticated` line removes a statement that was actually redundant with the default, not the thing actually authorizing the call. WYN-027 already established that `internal`'s own non-exposure to PostgREST is what protects the *REST API* surface (that part of the original bug report's reasoning was correct: no live Supabase REST client can reach this function), but that does not protect a *direct SQL* caller — the exact vector both QA's original probe and my `CHECK20` used.

**Actual fix applied**: added an explicit `revoke execute on function internal.notification_enabled(uuid, text) from public;` after the function definition (on top of not re-adding the `grant ... to authenticated` line). `authenticated`/`anon` are both implicitly members of `PUBLIC`, so revoking from `PUBLIC` alone closes it for both without needing a separate revoke per role. Re-ran `CHECK20` after adding the `revoke`: **now correctly denied** (`insufficient_privilege`/permission-denied exception caught).

Verified this doesn't break any of the 16 real (`security definer`-nested) call sites: all of them run under the *definer's* privileges when they reach the nested call (the owner implicitly has execute on its own functions), not under the querying `authenticated` role — confirmed by re-running the full `wyn_044_notification_settings_test.sh` suite (CHECK01–19 all still pass) plus every other `supabase/tests/*.sh` script (0 regression).

### Fix 3 — invalid category fail-open (`supabase/schema.sql`)

Converted `internal.notification_enabled` from `language sql` to `language plpgsql` (required — plain SQL functions can't `RAISE`) and added an upfront guard:
```sql
if p_category not in
    ('likes', 'comments', 'follows', 'messages', 'club', 'trending', 'system') then
  raise exception 'internal.notification_enabled: unknown category %', p_category;
end if;
```
before the existing `coalesce(...)` lookup, rather than adding an `else` inside the `case` itself (a bare `case ... else` can't `RAISE` in an expression context either — this is an equivalent, and arguably clearer, place for the same guard). Added `CHECK21` to `wyn_044_notification_settings_test.sh` calling `internal.notification_enabled(<alice's uuid>, 'not_a_real_category')` and asserting an exception is raised (as the function owner, not role `authenticated`, since `CHECK20` above already proved an ordinary user can't reach this function directly at all anymore regardless of category validity). Confirmed pass.

### Full verification (all independent, against real Postgres/Flutter, not assumed from the diff)

- `flutter test` (full suite, `app/`): **674/674 passed**, 0 failures (the bug report's "667/667" figure was written against an earlier commit; the current branch has more tests than that baseline — what matters is 0 failures, confirmed).
- `flutter analyze`: 0 issues.
- `python3 supabase/check_schema_ordering.py`: OK, no forward references.
- `supabase/tests/wyn_044_notification_settings_test.sh` (extended, 21 checks: original 19 + new CHECK20/CHECK21): **21/21 PASS**.
- All 17 scripts in `supabase/tests/` (including `wyn_044_...` above): **17/17 PASS**, 0 regression from the two `schema.sql` changes.

### Files Changed (actual)
- `app/test/notification_settings_screen_test.dart` — timer-leak fix (Fix 1).
- `supabase/schema.sql` — `internal.notification_enabled`: removed the redundant `grant ... to authenticated`, added an explicit `revoke execute ... from public` (Fix 2, refined beyond the original bug report's prescription), converted `language sql` → `language plpgsql` with an upfront category-validation guard that raises on an unrecognized category (Fix 3).
- `supabase/tests/wyn_044_notification_settings_test.sh` — added `CHECK20` (direct cross-user call now denied) and `CHECK21` (invalid category now raises), updated the header comment's check list.

### Regression Risk
Low, as originally assessed, with one addition: the `revoke execute ... from public` statement is new (not in the original bug report's prescribed fix) but is scoped to the exact same single helper function, and was verified not to affect any of the 16 real call sites (all execute as the SECURITY DEFINER owner, never as `authenticated`, when reaching the nested call) via the full regression suite above.

### Lessons learned
Recorded in `.wyn/learning/LESSONS_LEARNED.md` and `.wyn/learning/MISTAKES.md`: a bug report's prescribed fix must still be verified empirically even when the root-cause narrative reads correctly — "remove the unnecessary grant" sounds sufficient but silently assumed Postgres/PostgREST's default-deny posture, which this same schema already had a documented counter-example for (WYN-027). Any future `internal.*` (or similarly schema-isolated) SECURITY DEFINER helper that must be *direct-SQL-unreachable*, not just REST-API-unreachable, needs an explicit `revoke execute ... from public`, not just the absence of a `grant`.

**Handoff to QA**: send back to AI QA & Security for round 2 — re-verify independently (not just trust this report) that (a) all 7 `notification_settings_screen_test.dart` cases pass with 0 leaked timers, (b) the cross-user direct-SQL probe (`CHECK20`) and the invalid-category probe (`CHECK21`) both now fail/raise as expected, (c) do the same red→green proof style this project's WORKFLOW.md expects if time allows (revert `schema.sql` only, re-run `wyn_044_notification_settings_test.sh`, confirm `CHECK20`/`CHECK21` fail on the pre-fix code, then restore and confirm pass again). `updated_at` staleness (finding 4) remains explicitly out of scope, unfixed by design (no AC depends on it).
