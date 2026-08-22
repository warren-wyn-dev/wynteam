# Bug Report — WYN-024 / DS-009

Status: bugs
Owner: AI Debug Engineer
Bug: Three defects found in the WYN-024 (Bottom Nav V1.0.0 Restructure) + DS-009 (Rainbow Accent) delivery — one build-blocking, one a visible layout regression on Home (present by default), one a new-test-file infra bug. None were caught by Coding because no Flutter/Dart SDK was available in that session; this QA round installed Flutter 3.47.1 from `storage.googleapis.com` (reachable through this environment's proxy, unlike `github.com`) specifically to run `flutter analyze`/`flutter test` for the first time on this delivery.

## Bug 1 (Critical — build-blocking): invalid `const` on `Semantics(...)`

Reproduction:
```
cd app
flutter analyze
```
Result:
```
error • The constructor being called isn't a const constructor. Try removing 'const' from the constructor invocation
  • lib/features/root/presentation/root_shell.dart:301:12 • const_with_non_const
```

Root Cause: `RootShell._buildDropAction()` (`app/lib/features/root/presentation/root_shell.dart:301`) returns `const Semantics(...)`, but `Semantics`' constructor is not `const` in this Flutter SDK (3.47.1). This is a hard compile error — the whole `app/` package fails to build, so nothing downstream (any screen, any test) can run at all until this is fixed.

Fix (verified locally by QA, then reverted before handing back — not committed): drop the `const` keyword on that one `Semantics(...)` invocation. `flutter analyze` goes from 1 error to 0 (two harmless `prefer_const_constructors` info-lints appear on the now-non-const children instead, which are cosmetic).

Files Changed (expected): `app/lib/features/root/presentation/root_shell.dart`

---

## Bug 2 (Major — visible on Home by default): Rainbow accent dot overflows the feed-mode segment

Reproduction:
```
cd app
flutter test test/home_feed_screen_test.dart
```
Failing (before Bug 1's fix; same failure persists after fixing Bug 1 alone):
- `shows the empty state when there is no content` (never even switches segments — "สำหรับคุณ" is the default-active one)
- `switching to "จาก Club ของคุณ" shows Club posts instead of Drop/Pop`
- `shows a join-prompt message on "จาก Club ของคุณ" when the user has no joined-club posts`
- (plus 1-2 more that appear to fail due to the same uncaught rendering exception leaking across test boundaries under `flutter_test`'s error handling — the underlying assertion is identical in every case)

Console shows, on first render already:
```
A RenderFlex overflowed by 11 pixels on the right.
Row Row:file:///home/user/wynteam/app/lib/features/home/presentation/home_feed_screen.dart:370:13
constraints: BoxConstraints(0.0<=w<=140.0, 0.0<=h<=40.0)
```

Root Cause: `HomeFeedScreen._segment()` (added for DS-009's Rainbow accent) renders the *active* segment's label as `Row(mainAxisSize: min, children: [6px dot, 4px SizedBox, Text(label)])` instead of a bare `Text(label)`. `SegmentedButton` gives each segment a tight, roughly-equal width budget (~140px in the test viewport) sized off the *plain-text* label — it has no idea the active one will render wider once selected. The extra ~10px the dot+spacing add is enough to overflow that budget **for whichever segment happens to be active**, including the shortest label ("สำหรับคุณ") on first load — this is not an edge case, it is the default state of the Home screen. In a real build this renders as the yellow/black overflow warning stripe across the feed-mode toggle every time the app opens; `flutter test` treats the layout assertion as a test failure.

Fix (verified locally by QA, then reverted before handing back — not committed): wrap the label `Text` in `Flexible` with `overflow: TextOverflow.ellipsis`, and swap `SizedBox(width: WynSpacing.space1)` for a smaller `SizedBox(width: 3)` (`space1` is 4px; even 1px matters against an 11px overflow). With both changes, `flutter test test/home_feed_screen_test.dart` passes 0 failures. **Re-derive the exact minimal fix independently rather than trusting these numbers blindly** — QA's fix was a quick diagnostic patch to confirm root cause, not a design-reviewed solution; in particular, confirm with AI Design whether ellipsis truncation of "จาก Club ของคุณ" (the widest label) reads acceptably, since QA did not visually inspect it, only confirmed the overflow assertion clears.

Files Changed (expected): `app/lib/features/home/presentation/home_feed_screen.dart` (`_segment` method only)

Regression Risk if fixed as above: low — purely a layout tweak to a decorative element added this same round, no logic changes.

---

## Bug 3 (Major, test-only — but blocks all coverage of new nav logic): `RootShell`'s repositories (and their `SupabaseClient` auto-refresh Timers) are built fresh per-test instead of once in `setUpAll`

Reproduction:
```
cd app
flutter test test/root_shell_test.dart
```
All 6 tests in this new file fail with:
```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═════
A Timer is still pending even after the widget tree was disposed.
'!timersPending'
```
Stack traces point at every `RecordingXRepository(...)` constructor call inside `root_shell_test.dart`'s `buildShell()` helper (line ~47-53), each of which constructs a fresh `SupabaseClient(...)` → `GoTrueClient` → a periodic auto-refresh `Timer`.

Root Cause: `buildShell()` is called *inside* each `testWidgets(...)` callback, so every test spins up 8 brand-new `SupabaseClient`s (and their Timers) instead of reusing ones built once. This is the exact anti-pattern this codebase's own `home_feed_screen_test.dart` documents in a comment citing `drop_comment_like_test.dart` (WYN-005): *"why every repo (and its underlying SupabaseClient auto-refresh Timer) is built once in `setUpAll` rather than inside individual testWidgets callbacks"* — and it's referenced again in `.wyn/learning/PATTERNS.md`. `root_shell_test.dart` is a new file this round and didn't follow it.

Fix: move the `RecordingDropRepository()`, `RecordingPopRepository()`, `RecordingFollowRepository()`, `RecordingProfileRepository(...)`, `RecordingSavedRepository()`, `RecordingClubRepository()`, `RecordingClubPostRepository()`, `RecordingZokyRepository()` construction into a `setUpAll` block (mirroring `home_feed_screen_test.dart`'s own `sharedXRepository` pattern), and have `buildShell()` reference those shared instances. Only `RecordingNotificationRepository`/`RecordingHomeRepository` need to vary per-test (they're the ones QA's tests pass different fixtures into) — those two can stay as `late` variables assigned fresh in each test body, or also hoisted with per-test overrides the same way `home_feed_screen_test.dart` already does it for `RecordingHomeRepository`.

Files Changed (expected): `app/test/root_shell_test.dart` only — this is a test-infra defect, not an application bug. It does **not** by itself prove or disprove whether `RootShell`'s actual nav-mapping/badge logic is correct; that still needs to be re-verified once the Timer leak is fixed and the tests can actually run to completion.

Regression Risk: none (test-only).

---

## Tests

QA ran, with Flutter 3.47.1 freshly installed this session (not present before):
- `cd app && flutter analyze` — 1 error (Bug 1)
- `cd app && flutter test` — 5 failing test *files worth* of output pointing at 3 distinct roots (Bug 1 blocks `root_shell_test.dart` entirely; Bug 2 causes 4 failures in `home_feed_screen_test.dart`; Bug 3, once Bug 1 is fixed in isolation, then surfaces as all 6 `root_shell_test.dart` tests failing on the Timer assertion instead)
- QA temporarily patched Bug 1 + Bug 2 locally (not committed, reverted with `git checkout --` before finishing) to confirm: with those two patched, `flutter analyze` → 0 errors, `flutter test test/home_feed_screen_test.dart` → 0 failures. Bug 3 was diagnosed by reading the stack trace only (not patched) — its fix is well-understood from the existing pattern elsewhere in this codebase and didn't need a speculative patch to confirm.
- `cd seller_app && flutter analyze` — clean. `flutter test test/design/token_sync_test.dart` — 4/4 pass (the `wyn_colors.dart` mirror added for DS-009's `rainbowAccent` token is in sync).
- Confirmed no `supabase/schema.sql` changes in this delivery (no DB/RLS re-verification needed this round).
- Confirmed Pop/ZOKY screens/files are untouched and have zero remaining call sites in `app/lib` outside their own definitions (correctly unmounted, not orphaned-but-still-linked).

## Regression Risk

All three fixes are narrowly scoped to files touched this same round (`root_shell.dart`, `home_feed_screen.dart`, `root_shell_test.dart`) — no schema, no other screens. Low risk to re-test once fixed.

## Handoff to QA

After fixing all 3: re-run `flutter analyze` (expect 0 errors) and `flutter test` (expect 0 failures) independently — do not trust Debug's own numbers, per WORKFLOW.md. Also worth a fresh look at the "จาก Club ของคุณ" segment specifically once Bug 2's fix lands, since that's the widest label and the one most likely to still look visually tight even after the overflow assertion clears.
