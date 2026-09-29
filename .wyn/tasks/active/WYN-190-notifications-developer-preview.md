# WYN-190 — Notifications Developer Preview

Status: Active
Date: 2026-09-29
Owner: WYN Engineering
Rollout: Developer accounts only

## Founder direction

เปิดระบบ Notifications แบบครบวงจรบน WYNOS Web ผ่าน Developer Preview/Feature Flag ก่อน โดยผู้ใช้ทั่วไปต้องคงพฤติกรรมเดิม และไม่มี Email Notifications.

## Scope

- In-App notifications: reuse existing notification center/read state/grouping.
- Realtime: enable `public.notifications` in Supabase Realtime, but only developer accounts attach the live channel in the web client.
- Web Push: reuse FCM + existing service worker/deep-link flow.
- Developer-only Push preferences by category: likes, comments/mentions, follows, messages, Club, trending, system/admin.
- Quiet Hours: pause Push only; In-App and unread badge continue normally.
- Anti-spam/dedupe: retain existing database dedupe/collapse-key behavior.
- System/Admin notifications: retain existing server-side flow.
- Delivery tracking + bounded retry for developer accounts.
- No Email Notifications.

## Non-developer behavior

When `is_developer_account() == false`, advanced controls are hidden, Realtime channel is not attached, and the existing Push/poll/focus fallback behavior remains unchanged.

## Acceptance criteria

1. Developer accounts can configure Push categories and Quiet Hours.
2. Regular users do not see advanced settings.
3. Realtime INSERT/UPDATE updates developer notification badges without exposing cross-user rows.
4. Regular-user badge behavior remains compatible with the existing Push + polling fallback.
5. Push respects developer category settings and Quiet Hours.
6. Push delivery attempts for developer accounts record pending/retrying/sent/failed/skipped state without exposing the table to clients.
7. Retry is bounded and limited to transient FCM transport failures.
8. Existing deep links, FCM collapse keys, duplicate suppression and system/admin notification paths remain intact.
9. Thai/English UI coverage passes.
10. No Email notification channel is added.
11. CI, Deno checks/tests, schema ordering and web regression suites pass before release.
12. Production rollout remains controlled and reversible.
