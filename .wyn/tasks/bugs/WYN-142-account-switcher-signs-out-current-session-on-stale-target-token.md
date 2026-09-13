# Bug Report — WYN-142 (Account Switcher can silently sign the user out of their own, still-valid session)

Status: fixed, pending QA re-verification with a real Flutter toolchain (see Tests below)
Owner: AI Debug Engineer
Founder report (2026-09-13): "เช็คทั้งระบบ หาบั๊คให้หน่อย เหมือนระบบ มันชอบเด้งออก" ("check the whole system, find bugs — it feels like the system likes to bounce/kick me out"). No exact repro steps were given, so this was a whole-system investigation, not a single reported flow.

Bug: `AccountSwitcherRepository.switchTo()` (`app/lib/features/account_switcher/data/account_switcher_repository.dart`) can destroy the user's **currently active, perfectly valid** session — not just fail the switch — whenever the account being switched *to* has a stale stored refresh token (rotated/revoked elsewhere: another device signed into the same account, an admin action, the token going stale between capture and switch, ...). The user is bounced straight from whatever screen they were on to `WelcomeScreen`, exactly matching "ระบบมันชอบเด้งออก" — and it is triggered by ordinary use of a feature the Founder has actively been iterating on (multi-account switching, per the 2026-09-03/09-05 comments already in `auth_gate.dart`), not an exotic edge case.

Reproduction: Traced statically against the actual pinned `gotrue` package source (version `2.27.2`, confirmed in `app/pubspec.lock`, downloaded via `pub.dev`'s archive API and read directly — not guessed):

1. `AccountSwitcherRepository.switchTo(account, client)` (unpatched) does:
   ```dart
   final response = await client.auth.setSession(account.refreshToken);
   ```
   with no `try`/`catch` around it.
2. `setSession(refreshTokenOnly)` routes to `GoTrueClient._callRefreshToken` → `_doRefresh(refreshToken)` (`gotrue_client.dart`). This method operates on the client's **single, process-wide `_currentSession`**, not a session scoped to the token passed in.
3. When the server rejects `account.refreshToken` with any `AuthApiException` other than the one narrow, explicitly-whitelisted `code == 'refresh_token_already_used'` case, `_doRefresh`'s catch block runs:
   ```dart
   if (error is! AuthRetryableFetchException) {
     if (!_isDisposed && _sessionVersion == versionBeforeRefresh) {
       _removeSession();
       notifyAllSubscribers(
         AuthChangeEvent.signedOut,
         signOutReason: SignOutReason.sessionExpired,
       );
     }
   } ...
   rethrow;
   ```
   `_removeSession()` wipes the **previously active session** (the account the user was actually using a moment ago — `switchTo` hasn't replaced it yet), and `signedOut` is broadcast on `onAuthStateChange` to every listener in the process.
4. `AuthGate`'s listener (`auth_gate.dart:258-263`) treats `signedOut` as always "relevant" and does `Navigator.of(context).popUntil((route) => route.isFirst)`; `build()` then sees `currentSession == null` and renders `WelcomeScreen`.
5. `nothing in the app ever reads `SignOutReason`` (confirmed: zero matches for `SignOutReason` in `app/lib`), so there is no code anywhere able to distinguish "the user explicitly signed out" from "the switcher's own failed refresh attempt just destroyed an unrelated, still-valid session."

Not run against a real Flutter toolchain in this session (none available in this sandbox — same limitation every prior task in this repo hit, e.g. WYN-077). This is a static trace of deterministic behavior in the actual pinned `gotrue` source (not assumed/paraphrased from docs), plus a new regression test (see Tests) written against that same real `gotrue`/`SupabaseClient` code via `package:http/testing.dart`'s `MockClient` — but neither has been executed by a real `flutter test` run yet. Flagging this explicitly for QA/CI to confirm, per this repo's own established convention for sandbox-limited fixes.

Root Cause: `switchTo()` unconditionally called `client.auth.setSession(account.refreshToken)` and assumed a failure there would only affect the switch attempt. It doesn't — `setSession` mutates the one shared client-wide session, and a non-retryable rejection makes `gotrue` itself remove *whatever session was active before the call* and broadcast a global `signedOut`, which `AuthGate` (correctly, for a real sign-out) always treats as "go to Welcome." The method never accounted for the *target* account's token being invalid.

Fix: Wrap the `setSession` call in a `try`/`catch`. On failure, best-effort restore the session that was active immediately before the switch attempt (using the refresh token this method already persists to secure storage one line earlier, which is still fresh at that point), then `rethrow` so the existing UI error handling in `AccountSwitcherSheet._switchTo` (`'สลับบัญชีไม่สำเร็จ ลองใหม่อีกครั้ง'`) still fires exactly as it already does for every other switch failure. If the restore attempt itself also fails, the user is genuinely signed out and `WelcomeScreen` is the correct state — no behavior change from before in that case.

Files Changed:
- `app/lib/features/account_switcher/data/account_switcher_repository.dart` (`switchTo`, plus doc comment explaining the bug and fix)
- `app/pubspec.yaml` (added `http` to `dev_dependencies` — already present transitively via `supabase_flutter`, needed as a direct dependency for the new test to import `package:http/testing.dart`, same reasoning already documented in this file for the existing `web` dependency)
- `app/test/account_switcher_repository_test.dart` (two new tests under a `switchTo` group, plus `_fakeAuthClient`/`_refreshSuccessJson`/`_refreshTokenNotFoundJson` helpers)

Tests: Added `app/test/account_switcher_repository_test.dart`'s new `switchTo` group:
1. `'restores the previously active session instead of leaving the user signed out when the target account's stored token is stale'` — the actual regression test. Builds a real `SupabaseClient`/`GoTrueClient` wired to a fake HTTP transport (`package:http/testing.dart`'s `MockClient`, injected via `SupabaseClient`'s own `httpClient` constructor parameter — no mocking framework or app-level fake needed) that accepts the "current" account's token but rejects the target account's token with a real gotrue `refresh_token_not_found` error shape. Asserts `switchTo` still throws (so the caller's existing error UI still fires) **and** that `client.auth.currentSession` still belongs to the original account afterward — the behavior this bug broke.
2. `'persists the new refresh token on a successful switch'` — confirms the fix's added `try`/`catch` didn't change the existing happy path (still switches session, still persists the newly-rotated token for the target account, still leaves the account switched-away-from's own stored token untouched).

**Not run against a real Flutter toolchain in this session** (no `flutter`/`dart` binary available in this sandbox — confirmed via `which flutter dart`, both absent) — reasoning verified instead by reading the actual pinned `gotrue`/`supabase` package source directly (downloaded from `pub.dev`'s archive API at the exact locked versions, `gotrue 2.27.2` / `supabase 2.16.1`) and hand-tracing both the failure path and the new test's mock request/response shapes against that real source line-by-line. `flutter analyze`/`flutter test` could not be run — needs a real toolchain (CI or a dev machine) to confirm both compile and pass before this can be considered closed.

Regression Risk: Low. The change is additive (a `try`/`catch` and a best-effort restore) around one existing call in one method; nothing about the successful-switch path changed, and the second new test explicitly guards that. The restore path only ever runs when `setSession(account.refreshToken)` has already failed, so it cannot introduce a new failure mode on the success path. Worst case if the restore itself also fails: identical to today's existing (broken) behavior — user lands on `WelcomeScreen` — not worse.

Handoff to QA: Please re-verify with a real `flutter pub get && flutter analyze && flutter test` run (this sandbox has no Flutter toolchain, see Tests above) — in particular confirm the two new `switchTo` tests both compile and pass, and manually exercise the Account Switcher against a real Supabase project if possible: sign into two accounts on one device, then simulate a stale target token (e.g. sign the target account in on a second device/browser first to rotate its refresh token, or wait out its expiry) and confirm switching to it now shows the existing "สลับบัญชีไม่สำเร็จ" error while the originally active account stays signed in, instead of bouncing to Welcome.
