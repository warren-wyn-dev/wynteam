# WYN-190 — Notifications Developer Preview release runbook

Date: 2026-09-29
Scope: WYNOS Web, developer accounts only
Email Notifications: explicitly excluded

## Production order

1. Web gate first
   - Production must serve the Next.js build containing `attachDeveloperRealtime()`.
   - `is_developer_account()` must fail closed before any Notifications Realtime publication is enabled.
   - Do not apply the WYN-190 database migration while production still serves a build that subscribes every account to Notifications Realtime.

2. Apply WYN-190 schema
   - Run `.github/workflows/wyn190-notifications-preview-control.yml`.
   - Action: `apply_schema`.
   - Confirmation: `APPLY-WYN-190`.
   - This adds Push preference/Quiet Hours columns, internal delivery telemetry, and publication membership for `public.notifications`.

3. Deploy Push Edge Function
   - Run `.github/workflows/deploy-edge-functions.yml`.
   - Function: `send-push-notification`.
   - Its own Deno check/tests must pass immediately before deployment.

4. Verify
   - Run WYN-190 control with action `verify`, confirmation `VERIFY`.
   - Confirm developer account allowlist is non-empty only if the Founder intentionally added developers.
   - Confirm `notification_push_deliveries` has RLS enabled and anon/authenticated have no SELECT privilege.
   - Confirm `public.notifications` is in `supabase_realtime`.

5. Developer smoke test
   - Developer account opens Settings > Notifications.
   - Advanced Push-by-category and Quiet Hours controls are visible.
   - Regular account does not see advanced controls and does not attach Notifications Realtime.
   - Create one social event (like/comment/follow) targeting the developer account.
   - Verify badge/list update, target deep link, and Web Push if browser permission is enabled.
   - Disable that category and verify In-App behavior remains governed by the existing notification setting while the advanced Push channel is suppressed.
   - Enable Quiet Hours for the current local time and verify Push is skipped while In-App/badge still update.

## Fast rollback

If Realtime creates an incident:
- Run WYN-190 control action `disable_realtime`.
- Confirmation: `DISABLE-WYN-190`.
- This removes only `public.notifications` from the Realtime publication.
- Existing polling, focus refresh and Web Push fallback stay available.

If Push policy/delivery tracking creates an incident:
- Re-deploy the previous known-good `send-push-notification` Edge Function version.
- Do not drop the delivery table or preference columns during an incident; leaving additive schema in place is safer than destructive rollback.

If Web UI creates an incident:
- Roll back the Vercel production deployment to the previous known-good deployment.
- Keep Realtime disabled until the developer-gated web build is restored.

## Safety invariants

- No Email notification path is added.
- WYN-157 RESTRICTIVE guest-write policies remain intact.
- WYN-125 developer allowlist keeps its established RLS contract: direct authenticated SELECT returns zero rows instead of permission failure; the app uses `is_developer_account()`.
- Raw FCM token values are never copied into delivery telemetry.
- Regular users keep existing notification behavior until the Founder explicitly widens rollout.
