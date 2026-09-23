# Web Beta1 — email/password security rollout

This change is backward compatible with the current email-confirmation-disabled
environment. It does not change WYNOS Web Beta1's product version, existing
sessions, old passwords or any database/Verified values.

## Changes

- New email/password signups require at least 12 characters on every current
  Next.js email signup entry point, and in the shared signup repository.
- Existing accounts may still **sign in** with their existing passwords;
  only new passwords must satisfy the stronger policy.
- Signup uses `emailRedirectTo = https://<site>/auth/callback`.
- With email confirmation enabled, signup stops before profile writes, shows
  the confirmation instructions and clears passwords from React state.
- The new browser callback consumes the confirmation code using the same
  Supabase browser client (including the multi-account PKCE storage), clears
  sensitive callback query parameters and resumes onboarding at step 1.
- Signup draft persistence continues storing only username, display name and
  birth date in sessionStorage, never passwords. Confirmation links opened in
  another browser/device may require the user to sign in and re-enter step 1.

## Required Supabase Dashboard configuration (not SQL migrations)

The connected Supabase tooling cannot change hosted Auth configuration.
Do **not** enable email confirmation until the callback route is deployed
and its redirect is allowlisted.

1. In Supabase Auth -> URL Configuration, add
   `https://wynos.online/auth/callback` to Redirect URLs. Add the selected
   preview/test URL separately only if staging verification requires it.
2. In Auth -> Providers -> Email, set minimum password length to **12**.
   This is server-side enforcement, including REST signups that bypass UI.
   Existing passwords remain valid for sign-in.
3. Confirm outbound email delivery and email templates before switching
   on **Confirm email** in Auth -> Providers -> Email. The hosted Free plan
   has restrictions on default email sending; use a configured SMTP provider
   if necessary.
4. Test a new email/password account end-to-end in staging:
   sign up -> confirmation message -> email link -> /auth/callback ->
   /signup/step-1 -> profile + date of birth -> optional profile ->
   homepage. Confirm Google login and existing password login still work.
5. Activate confirmation in production only after staging passes.
   If the provider remains unconfirmed, this code preserves the existing
   immediate-session registration path.

## CI and production gates

- `npm run check` and browser test `signup-security.spec.ts` must pass.
- Confirm in production that an 11-character signup password is rejected
  by the Supabase **Auth API** (not just the web form).
- Check Auth logs for successful confirmation callbacks and signup rate
  limiting. Do not log passwords, PKCE codes, callback URLs or tokens.
- Production Auth dashboard changes require Founder approval. No database
  schema modification or automatic version bump is needed for this patch.

Reference: https://supabase.com/docs/guides/auth/password-security
Reference: https://supabase.com/docs/guides/auth/server-side/advanced-guide

## Password recovery callback (2026-09-23)

- Password-reset messages must now target `https://wynos.online/reset-password`, not `/login`.
- The new screen exchanges only the one-time recovery credentials (PKCE code,
  recovery token_hash, or implicit recovery tokens), verifies the user with
  Supabase Auth, removes sensitive URL fragments and shows a Thai form.
- The same twelve-character minimum applies to new passwords. Existing
  passwords remain usable for login until the account owner changes them.
- The Auth policy workflow allowlists `/reset-password` **only after** a
  successful production deployment, avoiding a live redirect to a missing route.
- Old emails containing the former `/login` destination do not gain a new
  destination retroactively. Request a **fresh** reset email after deployment.
- Retest on real iPhone Safari and Android Chrome (email-link handoff can have
  different cookie/PKCE storage from the browser that requested the reset).
