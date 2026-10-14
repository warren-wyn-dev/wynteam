# Native WYNOS Account registration — staging QA gate

This change extends PR #1177's **existing** Kotlin/Jetpack Compose app using
the **existing shared Supabase Auth**, without another user database.

## Behavior
- Native sign-in and password recovery remain available.
- Native sign-up displays an email/confirmed-password form **only** in an
  explicitly enabled **debug APK connected to a non-production Supabase project**.
- Registration uses Supabase Auth `signUpWith(Email)`; no service role,
  database insert, fake web Origin, or new backend endpoint is required.
- The form validates email shape and matching passwords of 8–128 characters;
  Supabase server rules and email confirmation remain authoritative.
- If Supabase returns no session (email confirmation required), users see a
  localized confirmation notice and must verify email before signing in.
- If staging auth intentionally creates a session on signup, the app loads
  that account's own orders and addresses via existing RLS reads.

## Opt in — staging debug only

For a debug build, set all three (not set in CI):

```text
WYNOS_FOOD_SUPABASE_URL=https://<non-production-project-ref>.supabase.co
WYNOS_FOOD_STAGING_PROJECT_REF=<same non-production-project-ref>
WYNOS_FOOD_ACCOUNT_SIGNUP_STAGING=true
```

Supply that staging project's **publishable client key** separately via
`WYNOS_FOOD_SUPABASE_PUBLISHABLE_KEY`. The staging ref must be 20 lowercase
letters/numbers and **must not** be `kqokpocajhfbidcxpvhh` (production).
Release builds always set `ACCOUNT_SIGNUP_ALLOWED=false` regardless of env.

## Still required before production use

- Verify that the staging project's redirect URL and email-confirmation
  template do not point to the production sign-in flow.
- Use authorized QA email identities to test signup, confirmation, duplicate
  email behavior, password policy, expired links, and session recovery.
- Confirm shared WYNOS Account provisioning/profile triggers, signup rate
  limits, and anti-abuse rules match the website.
- Review Data Safety, privacy, deletion, Google Sign-In if required, and
  accessibility. No real order creation or Stripe payment is enabled.
- CI checks compilation/unit tests/lint only. These checks are not a substitute
  for emulator and authenticated staging E2E testing.
