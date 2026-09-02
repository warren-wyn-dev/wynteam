# Bug Report — WYN-081

Status: bugs
Owner: AI Debug Engineer
Bug: `ExploreClubsScreen._reload()` (`app/lib/features/club/presentation/explore_clubs_screen.dart:76-78`) still uses `setState(() => _loadFuture = _load())` — an arrow-body closure whose body is an assignment expression, which evaluates to (and therefore returns) the `Future<_Sections>` produced by `_load()`. `setState()`'s callback is declared as `VoidCallback` but Dart's void-context rule lets a non-void return value through at compile time; at runtime Flutter's own `State.setState()` implementation asserts that the callback did not return a `Future` and throws `FlutterError: setState() callback argument returned a Future.` when it does (debug/checked mode, which is how `flutter test`, `flutter run --debug`, and every real device the Founder tests on all run by default).

This exact bug class — same file even — is what WYN-081's own Coding Output says it found and fixed in "5 places" (`view_profile_screen.dart`, `club_page.dart`, `my_moderation_action_screen.dart`, plus the 2 brand-new `_onRefresh()` methods it wrote for `explore_clubs_screen.dart`/`my_clubs_screen.dart`, written correctly with a block body from the start). It missed that `explore_clubs_screen.dart` already had a *second*, pre-existing method with the same shape — `_reload()` — sitting right next to the `_onRefresh()` it was adding, in the very file it was editing.

`_reload()` is not dead code: it is called from two real, always-reachable user actions:
- `_join(Club club)` (line ~130), after a successful `joinClub()` call, inside a `try { ... _reload(); } catch (_) { ScaffoldMessenger...showSnackBar('เข้าร่วม Club ไม่สำเร็จ ลองใหม่อีกครั้ง') }` block — so `_reload()`'s thrown `FlutterError` is caught by this `catch (_)`, and the user is shown a **false "Join failed" error** even though `ClubRepository.joinClub()` already succeeded moments earlier.
- `_openCreateClub()` (line ~117), unconditionally after returning from Create Club — not wrapped in any try/catch at that call site, so the thrown error is not silently absorbed the same way there.

Reproduction: (verified independently in this sandbox with a widget test, `flutter test`)
1. Open Explore Clubs with at least one joinable public club shown.
2. Tap "เข้าร่วม" (Join) on any club row.
3. `ClubRepository.joinClub()` resolves successfully (confirmed via the fake repository's own `joinClubCalls` counter incrementing to 1).
4. `_join()`'s `_reload()` call throws `setState() callback argument returned a Future`, caught by `_join()`'s own `catch (_)`.
5. `ScaffoldMessenger` shows **"เข้าร่วม Club ไม่สำเร็จ ลองใหม่อีกครั้ง"** (Join failed, try again) — despite the join having actually succeeded — and the screen's `_loadFuture` is never refreshed (`_load()` never actually re-ran because `setState()` bailed out via the assertion before completing), so `fetchPendingClubIds()`/discoverable-club membership state also stays stale.

I confirmed this is genuinely reproducible, not theoretical, with a real widget test run in this sandbox (`flutter test`, debug/checked mode — the same mode `flutter test` and every real device use):
```
joinClubCalls=1 exception=null
failed snackbar present: true
```
`exception=null` via `tester.takeException()` because the thrown `FlutterError` is already caught and swallowed by `_join()`'s own `catch (_)` before it ever reaches the top of the widget tree — the same "existing tests never caught it because exceptions get silently swallowed somewhere" pattern WYN-081's own commit message (`563049e`) describes for the other 5 instances it did find and fix.

Root Cause: `_reload()`'s closure passed to `setState()` is an arrow body (`() => _loadFuture = _load()`), not a block body (`() { _loadFuture = _load(); }`). An assignment expression `_loadFuture = _load()` evaluates to the RHS value (`Future<_Sections>`), so the arrow closure implicitly returns it. Flutter's `State.setState(VoidCallback fn)` runs `fn()` and then (in debug mode) asserts `result is! Future`, throwing if it is. This is the exact same root cause WYN-081 itself diagnosed and fixed at 5 other call sites in this same task — just missed at this 6th, pre-existing one, in the same file the task was already editing.

Fix: Change `_reload()`'s `setState` callback from an arrow body to a block body, identical to the fix already applied to the sibling `_reload()` methods in `view_profile_screen.dart` / `club_page.dart` / `my_moderation_action_screen.dart` / `my_clubs_screen.dart`:

```dart
void _reload() {
  setState(() {
    _loadFuture = _load();
  });
}
```

Files Changed (expected): `app/lib/features/club/presentation/explore_clubs_screen.dart` only (the `_reload()` method, lines ~76-78) — pure syntax fix, no behavior change intended beyond removing the crash/false-failure. No schema/backend change.

Tests: A permanent regression test already exists and currently fails (red) against the bug — `app/test/explore_clubs_screen_test.dart`, test `'QA (WYN-081): a successful Join does not show the "เข้าร่วม Club ไม่สำเร็จ" failure snackbar'` (added during this QA round). After the fix:
1. Re-run `flutter test test/explore_clubs_screen_test.dart` — this test must go green (no failure snackbar after a successful Join, `joinClubCalls == 1`).
2. Re-run the full `flutter test` suite to confirm no other regression (was 917/917 passing before this test was added; expect 918/918 — or whatever the count is once WYN-081's fix lands — with only this one previously-red test flipping green, everything else unchanged).
3. Manually re-audit `explore_clubs_screen.dart`/`my_clubs_screen.dart`/`club_page.dart`/`my_moderation_action_screen.dart`/`view_profile_screen.dart` once more (`grep -n "setState(() =>" app/lib/features/club app/lib/features/profile app/lib/features/moderation`) to confirm there is no 7th instance of this same arrow-body-returns-a-Future shape anywhere else before closing this out — this QA round's own `grep -rn "setState(() => .*= .*());" app/lib/` found no other instance where the RHS is an async call (every other match assigns a synchronous value), but a fresh independent check is worth doing given this is the second time this exact pattern has been missed in the same PR.

Regression Risk: Low — this is a one-line syntax fix (arrow body → block body) with identical runtime behavior once fixed (same as the other 5 already-fixed sites), no API/schema/UI change.

Handoff to QA: Once fixed, send back to AI QA & Security for round 2 — must independently re-run `explore_clubs_screen_test.dart` (not just trust this report), re-verify the Join flow no longer shows the false failure snackbar, and re-confirm the rest of WYN-081's acceptance criteria (Profile header pull-to-refresh, ExploreClubsScreen/MyClubsScreen/Top100Screen `RefreshIndicator`s) are unaffected, per `.wyn/company/WORKFLOW.md`'s regression-test-memory convention.
