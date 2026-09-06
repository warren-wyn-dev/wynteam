# Deployment Log — WYN-124: Club Invite Notification

**Release**: WYN-124 (Club Invite Notification) + preventive WYN-117 (Club Owner Insights) schema apply
**Date**: 2026-09-06

## QA Status
PASS — see `.wyn/tasks/approved/WYN-124-club-invite-notification.md`. Real GitHub Actions CI (`ci.yml` run [34045906026](https://github.com/warren-wyn-dev/wynteam/actions/runs/34045906026)): `flutter analyze` clean, `flutter test` 1303/1303 PASS, Deno `check`+`test` PASS, `check_schema_ordering.py` PASS.

## Build Status
No separate build step for this change — Flutter web build happens inside `deploy-web.yml` itself.

## Deployment Target
- Database (Supabase production): `wyn124-apply-club-invite-schema.yml` run [34046250136](https://github.com/warren-wyn-dev/wynteam/actions/runs/34046250136) — success
- Also applied in this session (preventive, same "schema merged but never applied" gap found and fixed after WYN-116's P0 earlier today): `wyn117-apply-club-insights-schema.yml` run [34045904789](https://github.com/warren-wyn-dev/wynteam/actions/runs/34045904789) — success
- Web (wynos.online, Vercel production): `deploy-web.yml` run [34046365617](https://github.com/warren-wyn-dev/wynteam/actions/runs/34046365617) — success, commit `76856f7`

## Changes
- `invite_to_club()` RPC — replaces WYN-123's chat-message-based invite with a `club_invite` Notification (server-side re-validation of the same membership/follow/block rules)
- `notifications_type_check` widened to include `'club_invite'`
- Client: `ClubRepository.inviteToClub`, `InviteToClubScreen` (now takes `clubRepository` instead of `chatRepository`), `NotificationType.clubInvite` + tap/message handling in `NotificationListScreen`, push-tap deep link, and the send-push-notification Edge Function's Thai message template
- Preventive: `club_insights()` (WYN-117) applied to production before any Club owner opened the new Insights tab and hit the same class of P0 WYN-115/116 caused earlier today

## Deployment Result
All 3 workflow runs succeeded. Production verification (`select conname, pg_get_constraintdef(...)`/`select routine_name from information_schema.routines`) inside `wyn124-apply-club-invite-schema.yml` confirms the constraint and RPC are live. `curl -o /dev/null -w '%{http_code}' https://wynos.online/` → `200`.

## Production Verification
Automated only so far (curl + the apply-workflow's own post-apply queries) — proves the site is up and the DB objects exist, not that the invite flow itself works end-to-end for a real user. Per `.wyn/company/WORKFLOW.md`, this task stays in `approved/`, not `completed/`, until the Founder confirms hands-on in the app: inviting someone (any account, not just @warren) now shows up as a Notification, not a Chat message, and works regardless of Chat Lockdown state.

## Rollback Plan
- Web: Vercel Instant Rollback to the previous production deployment (pre-`76856f7`), or `git revert` the `feat(club): WYN-124` commit (`a5b5a3c`) on `main` and redeploy.
- Database: `invite_to_club()` and the widened constraint are purely additive — no rollback needed even if the client is rolled back (an unused RPC/constraint value is harmless). If the RPC itself needed disabling, `revoke execute on function public.invite_to_club(uuid, uuid) from authenticated;` is sufficient and reversible.

## สถานะ Task
`.wyn/tasks/approved/WYN-124-club-invite-notification.md` — QA PASS, deployed to production. Not yet moved to `completed/`, pending Founder's own hands-on confirmation in the app.
