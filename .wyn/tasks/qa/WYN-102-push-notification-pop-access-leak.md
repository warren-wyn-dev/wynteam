# Bug Report — WYN-102

Status: closed — fixed by AI Debug Engineer (2026-09-02), re-verified PASS by AI QA & Security round 2 (2026-09-03, see `.wyn/tasks/approved/WYN-102-hide-pop.md`'s "QA Report — Round 2" section)
Owner: AI Debug Engineer

Bug: `PushNotificationService._openFromPushData()` (`app/lib/features/push/presentation/push_notification_service.dart`) still opens Pop content in full when a user taps a native OS push notification of type `like_pop`/`comment_pop`. WYN-102's job was to remove every user-facing access point to Pop; it fixed the in-app equivalent (`NotificationListScreen._openNotification`'s `_openPop()`, now a no-op SnackBar) but never touched this separate, parallel code path that the same file's own doc comment says "mirrors `NotificationListScreen._openNotification`'s switch exactly." `git diff` across the whole WYN-102 change confirms `push_notification_service.dart` was not modified at all — it is not in the list of 51 changed files for the WYN-089/090/093/094/095/101/102/103 batch.

Reproduction:
1. A `like_pop`/`comment_pop` notification row exists (still possible: WYN-102 deliberately left the DB triggers/RPCs that insert these rows untouched, and a direct API call could still like/comment on an old Pop even with the UI hidden — this is documented as intentional in WYN-102's own Known Issues).
2. The `send-push-notification` Edge Function pushes this out to the Pop owner's device as a native OS notification (this part of the pipeline was never scoped to be gated by WYN-102 either).
3. The user taps that push notification while the app is backgrounded or terminated.
4. `PushNotificationService.initialize()`'s `FirebaseMessaging.onMessageOpenedApp` listener (or `getInitialMessage()` on cold start) calls `_openFromPushData(message.data)`.
5. `_openFromPushData` switches on `type` — `case 'like_pop': case 'comment_pop': await _openPop(navigator, client, data['pop_id'])`.
6. `_openPop()` (lines 192-213) calls `PopRepository(client).fetchById(popId)`, gets a real `Pop` back, and pushes `PopSingleClipScreen` — full Pop content (video/thumbnail/caption/comments), no gate, no SnackBar.

Root Cause: WYN-102's fix was applied to exactly one of two notification-tap code paths that both exist in this codebase for historical reasons (in-app notification list vs. native push-tap-to-open). The two paths are structurally parallel by design (the file's own comment says so) but are two separate `switch` statements in two separate files, and only one was found/updated. This is a scope-completeness miss, not a logic bug within either file — each file's own code is internally correct, but the pair drifted out of sync.

Fix (not applied — QA does not fix production code per WORKFLOW.md): mirror the same treatment `notification_list_screen.dart`'s `_openPop()` already got — replace the `fetchById`+`navigator.push(PopSingleClipScreen(...))` body of `push_notification_service.dart`'s `_openPop()` with a no-op (or a `ScaffoldMessenger` snackbar via whatever messenger context is reachable from `appNavigatorKey`, since this class runs outside a widget's own `BuildContext`) so tapping the push notification also can't reach Pop content.

Files Changed: none yet — bug report only.

Tests: none yet. Recommend adding coverage to `push_notification_service_test.dart` (currently has zero test cases touching `like_pop`/`comment_pop` at all — confirmed by grep, this gap was never exercised by any existing test) mirroring the "no navigation happens for Pop" style of test already added to `notification_list_screen_test.dart` for the sibling fix.

Regression Risk: low — the fix should be a narrow, isolated change to `_openPop()`'s body only; `_openDrop`/`_openProfile`/`_openClub`/etc. in the same file are unrelated and should not be touched.

Handoff to QA: after the fix, AI QA & Security should re-verify (1) the fix mirrors `notification_list_screen.dart`'s behavior, (2) a new test exists and genuinely proves red→green (fails before the fix, passes after), (3) no other notification-tap-driven path was missed — this is now the 3rd Pop access point found across the WYN-102 effort (product spec found 2 originally missed by the backlog, this QA pass found a 3rd), so a final, exhaustive grep for `PopRepository`/`content_type.*pop`/`'pop'` across all of `app/lib` (not just the files WYN-102 touched) is warranted before signing off again.

## Resolution (AI Debug Engineer, 2026-09-02)

Reproduced first: read `push_notification_service.dart`'s `_openPop()` (pre-fix) — confirmed it still fetched a real `Pop` via `PopRepository.fetchById()` and pushed `PopSingleClipScreen`, exactly as reported. Since `_openFromPushData`/`_openPop` are private with no existing test coverage, wrote the regression test first, confirmed it fails red against the pre-fix code (network exception from the fake Supabase project, since `_openPop` tried to actually fetch), then applied the fix and confirmed green.

Root cause confirmed as described: `push_notification_service.dart`'s `_openPop()` was a separate, parallel code path from `notification_list_screen.dart`'s `_openPop()` (already fixed) and was missed by WYN-102's original change.

Fix: mirrored `notification_list_screen.dart`'s already-approved `_openPop()` pattern exactly — no fetch, no navigation, just the same `'เนื้อหานี้ไม่พร้อมใช้งานแล้ว'` SnackBar copy. Since `PushNotificationService` has no widget `BuildContext` of its own to call `ScaffoldMessenger.of(context)` from (same problem `appNavigatorKey` already solves for navigation), added a companion `appScaffoldMessengerKey` (`app/lib/core/navigation/app_navigator.dart`), wired it into `MaterialApp.scaffoldMessengerKey` in `main.dart` (same place `appNavigatorKey` is already wired), and used `appScaffoldMessengerKey.currentState?.showSnackBar(...)` in `_openPop()`. Removed the now-unused `pop_single_clip_screen.dart` import; `pop_repository.dart` stays imported (`PopRepository` is still used by `_openDrop`/`_openProfile` for unrelated params). Also added a `@visibleForTesting` `debugOpenFromPushData()` passthrough to `_openFromPushData()` so a widget test can drive a specific push `type` end to end (the class previously had no public surface for this — production code only ever reaches `_openFromPushData` through `initialize()`'s two Firebase listeners, which don't fire in `flutter test`).

Files Changed:
- `app/lib/features/push/presentation/push_notification_service.dart` — `_openPop()` rewritten (no fetch/navigate, shows SnackBar via `appScaffoldMessengerKey`), removed unused `PopSingleClipScreen` import, added `debugOpenFromPushData()` test entry point
- `app/lib/core/navigation/app_navigator.dart` — added `appScaffoldMessengerKey`
- `app/lib/main.dart` — wired `scaffoldMessengerKey: appScaffoldMessengerKey` into `MaterialApp`
- `app/test/push_notification_service_test.dart` — new `WYN-102` test group (`like_pop`/`comment_pop`), proven red→green
- This bug report and the corresponding `.wyn/tasks/review/WYN-102-hide-pop.md` Status line

Tests:
- `flutter test test/push_notification_service_test.dart`: all 4 tests pass (2 pre-existing + 2 new WYN-102 tests).
- `flutter test test/notification_list_screen_test.dart`: unaffected, all pass (confirms the sibling fix this mirrors is untouched).
- `flutter analyze`: no issues found.
- Full `flutter test`: **892/892 passed**, no other regressions.

Regression Risk: low, as predicted — `_openPop()`'s body only, plus a new app-wide key that defaults to `null` `currentState` until `MaterialApp` mounts (same null-safe pattern `appNavigatorKey` already uses); no other `_open*` method in this file was touched.

Handoff to QA: ready for round 2 independent re-verification, per this report's own instructions above. Did not re-run the full exhaustive `PopRepository`/`content_type`/`'pop'` grep across all of `app/lib` beyond this file — that broader sweep is QA's item (3) to independently re-confirm, per the Recommendation above.
