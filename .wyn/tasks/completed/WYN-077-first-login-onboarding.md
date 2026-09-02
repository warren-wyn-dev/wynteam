# Task — WYN-077: WYNOS First Login / Account Onboarding

Status: implemented, pending real QA/deploy (no Flutter SDK or Supabase project available in this session's sandbox -- see Known Issues below)
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

## Known issues / not done in this session

- **No Flutter SDK available in this sandbox** -- `flutter analyze`/
  `flutter test`/`flutter build` could not be run here at all (previous
  WYN-002 sessions at least had `flutter analyze`/`test`; this one has
  neither). Every new/changed file was reviewed manually line-by-line
  instead, and every less-certain `supabase_flutter`/`gotrue` API call
  (`UserAttributes`, `AuthWeakPasswordException`, `User.appMetadata`/
  `userMetadata` nullability, `updateUser`) was independently verified
  against the pinned `gotrue: 2.27.2` package docs before use. Still,
  **running `flutter analyze` and `flutter test` on a machine with the
  Flutter SDK is the required next step before this merges**.
- **No Supabase project available** -- same limitation WYN-002 has
  documented from the start. The schema migration needs to be applied
  (`supabase/schema.sql`'s new section, from the `profile_private` table
  onward) to a real project, and the full flow needs one real
  device/browser run against it, before production deploy.
- Username-availability checks (and auth generally) rely on Supabase's
  own built-in rate limiting; no bespoke rate-limit table was added for
  this task specifically (would be disproportionate scope for this
  change).
- `OnboardingScaffold`'s Profile Optional -> Password-skipped case shows
  progress as "4 of 4" (recalculated, not literally skipping a number) --
  intentional, not a bug.

Handoff: needs `flutter analyze`/`flutter test` + AI QA & Security review
on a machine with the Flutter SDK, then the schema migration applied to a
real Supabase project, before AI Deploy & DevOps can ship this.
