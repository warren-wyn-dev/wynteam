# Task — WYN-077: WYNOS First Login / Account Onboarding

Status: **shipped and confirmed working in production** (2026-09-02) -- code merged (#210, #212), migration applied to the real Supabase project (`kqokpocajhfbidcxpvhh`, one round-trip fixing a real bug -- see #217), Google OAuth provider enabled, Founder confirmed the live flow works end to end
Owner: Founder (product + design spec provided directly) -> AI Coding (this session)
Feature: Extends WYN-002 (Authentication & Onboarding) / WYN-003 (User Profile) -- does NOT replace either. WYN-002's Google/Apple/email/phone sign-in, guest browsing (WYN-072), moderation gate (WYN-029/030), and Document Acceptance gate (WYN-046) are all unchanged.

## What changed

The old WYN-002 onboarding asked only for a username after sign-in. Founder
asked for a fuller, resumable First Login flow:

```
WELCOME -> GOOGLE AUTH -> BIRTHDAY -> USERNAME -> DISPLAY NAME -> PASSWORD
  -> PROFILE OPTIONAL -> FINISH -> HOME
```

- Password step is skipped for an account that already has a password
  (signed up via email+password, or already completed this step in a prior
  session) -- never asks twice.
- Every step writes to Supabase as soon as it's submitted (not held in
  memory), so closing the app mid-onboarding and reopening it resumes at
  the correct step (`OnboardingState.resumeStep`) instead of restarting or
  creating a duplicate account.
- Existing users (anyone who already has a `username`, i.e. finished the
  old WYN-002 flow) are backfilled as `onboarding_completed = true` in the
  schema migration -- they are never sent through this new flow.
- `AuthGate` now checks `onboarding_completed` (one query,
  `AuthRepository.fetchOnboardingState`) instead of `hasUsername` to
  decide Onboarding vs Home; the moderation/document-acceptance gates it
  already had stay ordered exactly as before, in front of this check.

## Database

`supabase/schema.sql` (appended, ordering-checked with
`python3 supabase/check_schema_ordering.py`):
- New table `public.profile_private` (date_of_birth, password_set,
  onboarding_completed, onboarding_completed_at) with owner-only RLS --
  birthday is privacy-sensitive and deliberately NOT a column on
  `public.profiles` (that table's own RLS policy lets any authenticated
  user read any row).
- `date_of_birth` check constraints: not in the future, minimum age 13
  (Founder decision, 2026-09-02 -- industry-standard minimum for a social
  platform; mirrored client-side in `BirthdayStep`/`kMinOnboardingAge`).
- `profiles_username_not_reserved` check constraint (admin/support/wynos/
  etc.) -- defense in depth alongside `AuthRepository.reservedUsernames`.
- Backfill: every existing account with a `username` gets
  `onboarding_completed = true` retroactively.

## Code

- `AuthRepository`: added `OnboardingState`/`fetchOnboardingState`,
  `setDateOfBirth`, `setDisplayName`, `setPassword` (sets a real password
  credential on the existing Google-authenticated Supabase Auth user via
  `updateUser` -- Google stays the identity provider, this does not create
  a second account), `saveOptionalProfile`, `completeOnboarding`,
  `reservedUsernames`. Removed `hasUsername` (superseded).
- `lib/features/auth/presentation/onboarding/`: new `OnboardingFlow`
  controller + `OnboardingScaffold` (shared Back/Title/description/
  progress/CTA chrome) + one widget per step
  (`BirthdayStep`/`UsernameStep`/`DisplayNameStep`/`PasswordStep`/
  `ProfileOptionalStep`/`FinishStep`). Fade+slide transitions between
  steps via `AnimatedSwitcher` (no new animation framework -- this app had
  no existing motion-system file to reuse).
- `AuthGate`: swapped its `hasUsername` FutureBuilder for
  `fetchOnboardingState`/`OnboardingFlow`; every other gate (moderation,
  document acceptance, guest bypass) untouched.
- Removed `username_setup_screen.dart` (superseded by `UsernameStep`
  inside the new flow).
- `LabeledField` (shared with EditProfileScreen/CreateClubScreen): added
  optional `obscureText`/`onSubmitted`/`keyboardType` params (default
  unchanged) for PasswordStep's fields.
- `WelcomeScreen`/`AuthMethodScreen` (email sign-in, guest browsing)
  intentionally left as-is per Founder's explicit answer (2026-09-02):
  keep existing entry points for beta testing rather than restricting
  Welcome to Google-only.

## Tests

- `test/onboarding_flow_test.dart` (new): Birthday validation (future
  date, under-13, invalid calendar date, valid date advances), Username
  (taken/invalid/available/normalize-to-lowercase/back), Display Name
  (Google-name prefill), Password (skipped when already set, disabled
  until length+match satisfied, submits), Profile Optional (skip vs
  saving a bio), Finish (completes onboarding, fires `onCompleted`),
  interrupted-onboarding resume to the correct step.
- `test/auth_gate_test.dart` (updated): the 3 cases that used to assert
  `UsernameSetupScreen` now assert `OnboardingFlow`; moderation/
  acceptance-gate ordering assertions are otherwise unchanged.
- `test/support/recording_auth_repository.dart` (updated): added
  `onboardingStateResult` (replaces `hasUsernameResult`, defaults to
  "fully onboarded" so every unrelated existing test keeps passing
  unchanged) and recording overrides for every new onboarding method.

## Verification (2026-09-02, after PR #210 merged)

This sandbox had no Flutter SDK for the first pass (PR #210, commit
`fd8af81`) -- every file was reviewed manually instead, and every
less-certain `supabase_flutter`/`gotrue` API call (`UserAttributes`,
`AuthWeakPasswordException`, `User.appMetadata`/`userMetadata`
nullability, `updateUser`) was independently verified against the pinned
`gotrue: 2.27.2` package docs before use. As a follow-up (still this
Founder request, "ทำให้เสร็จทุกอย่าง"), downloaded the project's own exact
pinned Flutter SDK (3.47.1 stable, matching `.metadata`'s revision
`6655482ec0` byte-for-byte, sha256-verified) directly from
`storage.googleapis.com/flutter_infra_release` and ran the real thing for
the first time on this branch:

- `flutter analyze`: found 2 real issues on the first run --
  `ambiguous_import` (`onboarding_flow.dart` imported both
  `AuthRepository`'s and `ProfileRepository`'s separately-declared
  `UsernameTakenException` unprefixed) and `unused_field` (`_displayName`
  captured but never read). Both fixed (hid the unused import, wired
  `_displayName` into a personalized Finish greeting) -- **0 issues**
  after.
- `flutter test`: found `onboarding_flow_test.dart`'s own
  `_fakeProfileRepository()` helper was missing `autoRefreshToken: false`
  on its `SupabaseClient`, leaving GoTrueClient's auto-refresh Timer
  pending at every test's teardown (all 17 new tests failed on this one
  bug). Fixed -- **full suite: 888/888 tests pass, 0 failures**
  (`test/onboarding_flow_test.dart`'s own 17 included).

Fix commit: `aaf7aab` on `claude/wynos-first-login-onboarding-lhn507`
(PR #210 had already merged by the time these were found, so this
branch was restarted from `main` per this repo's merged-PR convention
and the fix pushed as a new PR).

## Production deploy (2026-09-02, Founder)

This sandbox has no network access to Supabase/Vercel/Google Cloud
Console at all (confirmed via direct test -- every request rejected at
the egress proxy with a policy denial, same as the WYN-072 incident's
"sandbox safety classifier บล็อกไว้ตามที่ตั้งใจ"), so every step below was
done by Founder directly against the real project, following SQL/
instructions prepared in this session:

1. **Migration applied** to Supabase project `kqokpocajhfbidcxpvhh` --
   hit a real bug on the first attempt: `profiles_username_not_reserved`
   (a plain `ADD CONSTRAINT`) failed immediately because a pre-existing
   production account already had a reserved-looking username (a seed/
   test account predating this rule). Fixed by adding the constraint
   `NOT VALID` instead (grandfathers existing rows, enforces only on
   future INSERT/UPDATE) and making the whole block idempotent
   (`drop ... if exists` before every policy/constraint, not just the
   table) so a corrected re-paste is always safe regardless of what
   partially committed before the failure -- see PR #217. Second run:
   **Success. No rows returned.**
2. **Google OAuth provider enabled** in Supabase Dashboard ->
   Authentication -> Providers -> Google, with the Client ID/Secret
   Founder provided (rotated after being shared in this chat -- see the
   credential-handling note below).
3. **Founder confirmed the live flow works end to end** on the real app
   (Google sign-in -> onboarding -> Home).

**Credential handling note**: Founder pasted a live Supabase Personal
Access Token, database password, Vercel deploy token, and Google OAuth
client secret directly into this chat at one point. None of it was ever
usable from this sandbox (network blocked, confirmed above), so none of
it was stored beyond a single session-scratch file that was deleted
immediately after confirming it couldn't be reached, and none of it was
ever committed to the repo. Founder rotated all of it afterward per this
session's own recommendation.

## Known issues / not done

- Username-availability checks (and auth generally) rely on Supabase's
  own built-in rate limiting; no bespoke rate-limit table was added for
  this task specifically (would be disproportionate scope for this
  change).
- `OnboardingScaffold`'s Profile Optional -> Password-skipped case shows
  progress as "4 of 4" (recalculated, not literally skipping a number) --
  intentional, not a bug.
- No formal AI QA & Security review round was run against this task
  (Founder verified the live flow directly instead). Worth doing a
  proper `/qa` pass later if this repo's usual QA-gate convention should
  apply retroactively.

Handoff: done. Live in production, confirmed working by Founder.
