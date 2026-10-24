# WYNOS Android v1.0.0 Beta 1 — Social stability and Web parity QA

Status: **code hardening in Draft PR #1157; not production- or Play-ready**. Date: 2026-10-14.
Scope: native `android/` using **the same backend** as `wynos.online`, not `food-android/`.
This checklist is a manual acceptance gate, **not evidence that it has already passed**.

## Automated checks required
- GitHub Android PR checks: `assembleDebug testDebugUnitTest lintDebug bundleRelease`.
- New logout regressions: remote sign-out failure falls back to clearing local session, irrecoverable failure cannot pretend logout succeeded, and failed push-token removal blocks account change.
- New feed regression: slow older page results cannot replace a newer refreshed timeline.
- PR remains Draft until checks are green **and physical-device scenarios below pass**. Do not treat green CI as a successful connected device run.

## Connected-APK prerequisites
Use the protected `android-qa` Environment on exactly
`fix/android-beta1-play-api36-20261013`, with **only** the public Supabase
Project URL and publishable/anon client key for the same project as Web.
Use a **manual workflow_dispatch** of `.github/workflows/android.yml`.
Follow `docs/engineering/ANDROID_BETA1_CONNECTED_QA.md`.
Only use dedicated, authorized QA users and synthetic posts/photos/messages.
Never supply credentials, refresh tokens or a privileged Supabase key in logs, screenshots or PR comments.

## Physical device acceptance (compare Android to wynos.online using same QA accounts)

| Area | Pass criteria | Failure evidence to record |
| --- | --- | --- |
| Cold start | Splash -> Welcome or signed-in route without early exit on Pixel 5/Android 12; repeat after force-close | Model, OS, safe QA crash fingerprint |
| Shared sign-in | Test user A logs into Web and Android; Android profile/user ID matches; force-close/reopen restores only A | Redacted error text and route |
| Feed | For You/Following display the same accessible, non-deleted QA posts as Web; refresh reflects a newly published Web post; slow pagination does not replace refreshed results | Post IDs, request sequence, no private screenshots |
| Reactions | Like, save, repost and follow from Android appear on Web and vice versa after refresh; server errors do not leave false optimistic state | Expected/actual counts and account |
| Posting | Android text post and authorized small test image appear on Web; edits/deletes reflect correctly; retries do not create duplicates | Synthetic post ID / operation ID only |
| Profile | Name, bio, avatar and follow state match Web after change/reopen; do not leak previous account after switching | Redacted field mismatch |
| Chat | A and B can exchange authorized test messages; requests, read states, inbox, offline/reconnect and permissions match Web; no duplicate sends | Redacted conversation ID / UI state |
| Account isolation | Switch A -> B -> A; no A's feed personalization, profile, chat, drafts or push alerts appear as B | Steps, observed screen without private content |
| Logout failure | Simulate network outage: never display signed-out Welcome while A's local Supabase session is still active; retry when connected | Observed result; do not publish tokens |
| Deep links | Opening a permitted `wynos.online` post, quote or club link navigates correctly for the signed-in account | URL route type and destination |

For each failed case, record: build artifact/run ID + Git SHA, phone model, OS version,
Thai/English setting, test account alias, precise steps, expected/actual result,
and a redacted screenshot or DEBUG-only crash fingerprint.

## Blocking before release
- Verify a **fresh** manually built connected QA APK on physical devices.
- Test Android 12 and Android 16 (system insets, predictive Back, keyboard and media).
- Validate network loss/retry and recovery, cross-account visibility and Supabase RLS.
- Finish Android Google OAuth (currently unavailable), FCM/push setup/permission and deep-link QA.
- Review privacy policy, UGC/child safety, data retention/deletion, Play Data Safety, signing and testing-track requirements.
- Obtain separate explicit Founder approval for merge, signed AAB and Play release.

No live social posts, purchases, backend/database changes, web deployment,
merge, Play upload or signed release are performed by adding this QA plan.
