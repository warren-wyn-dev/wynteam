# WYNOS Web Beta 1 — New-user reactivation Push rollout

Date: 2026-09-29  
Scope: `wynos.online` / WYNOS Web Beta 1 only

## Product decision

Explicit production request in the current Founder session: implement and put the signup-only reactivation notification flow on `wynos.online` Web Beta 1.

Cadence:
- 24 hours after signup
- 3 days after signup
- 7 days after signup
- every 7 days thereafter
- stop immediately after the account becomes active

No Email notifications.

## Implementation

- New private state: `internal.web_reactivation_state`
- New authenticated self-only RPC: `mark_web_reactivation_activated()`
- New service-role-only RPCs: `claim_due_web_reactivations()`, `complete_web_reactivation()`
- New isolated Edge Function: `send-web-reactivation-push`
- Sends only `push_tokens.platform = 'web'`; Android/iOS are not included
- Push click routes to `/home`
- Quiet Hours and system/push-system preference are honored
- Additional global delivery window: 09:00–21:00 Asia/Bangkok
- The latest reactivation Push replaces the previous reactivation banner for that user
- Only profiles created in the 24 hours before rollout are backfilled; older accounts are not bulk-enrolled
- A return after onboarding, or remaining in the Web app for 10 minutes, marks the campaign activated/stopped

## Scheduler authentication

The hourly pg_cron caller does not embed an API key.

- Postgres generates a random scheduler token internally.
- Raw token is stored only in Supabase Vault.
- Only its SHA-256 hash is stored in `internal.web_reactivation_cron_auth`.
- The Edge Function accepts the Vault token in `x-wynos-cron-token` and validates it through a service-role-only RPC.
- Edge Function `verify_jwt=false` is intentional because custom scheduler authentication is enforced before any claim/send action.

## Production rollout evidence

- Migration transaction dry-run on the production schema: passed.
- `web_beta1_reactivation_push`: applied successfully.
- `web_beta1_reactivation_cron_auth`: applied successfully.
- `send-web-reactivation-push`: deployed ACTIVE, version 2.
- Cron job `wynos-web-reactivation-push`: active, `17 * * * *`.
- Manual authenticated scheduler health invocation: HTTP 200 with `{"ok":true,"claimed":0,"sent":0,"failed":0}`.
- At rollout verification: 7 profiles were enrolled from the last-24-hour safety window; 0 were due.
- Supabase security advisor was reviewed after DDL. No new anonymous access was granted by this feature; existing project-wide advisor findings remain separate work.

## Tests

- Edge Function Deno check/test: green in CI.
- Reactivation message rotation unit tests added.
- Service-worker reactivation click routing regression added.
- Production DB migration dry-run passed before apply.
- Production Cron → Edge → RPC health path passed without sending a Push.

## Rollback

1. Unschedule `wynos-web-reactivation-push`.
2. Disable/remove `send-web-reactivation-push`.
3. Revert the Web service-worker/activation heartbeat commit.
4. Drop `profiles_enroll_web_reactivation` and the reactivation RPCs.
5. Drop the private reactivation state/auth tables if full data cleanup is explicitly approved.

Rollback steps 4–5 are schema-destructive and therefore require a separate explicit Founder approval.
