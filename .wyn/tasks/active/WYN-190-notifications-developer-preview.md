# WYN-190 — Notifications Developer Preview

Status: Completed — released to all Web accounts 2026-09-30
Date: 2026-09-29
Owner: WYN Engineering
Rollout: All signed-in WYNOS Web accounts

## Founder direction

ระบบ Notifications แบบครบวงจรผ่าน Developer Preview แล้ว และ Founder อนุมัติให้เปิดกับผู้ใช้ WYNOS Web ทุกบัญชีเมื่อ 2026-09-30 โดยยังไม่มี Email Notifications.

## Scope

- In-App notifications: reuse existing notification center/read state/grouping.
- Realtime: `public.notifications` is published to Supabase Realtime and every signed-in web account attaches its recipient-scoped live channel.
- Web Push: reuse FCM + existing service worker/deep-link flow.
- Push preferences by category for every Web account: likes, comments/mentions, follows, messages, Club, trending, suggestions, followed-post updates, posting prompts and system/security.
- Quiet Hours: pause Push only; In-App and unread badge continue normally.
- Anti-spam/dedupe: retain existing database dedupe/collapse-key behavior.
- System/Admin notifications: retain existing server-side flow.
- Delivery tracking + bounded retry for every Web Push recipient.
- No Email Notifications.

## Public release behavior

Advanced Push controls, Quiet Hours and Realtime are available to every signed-in Web account. Push/poll/focus remain independent fallback/recovery paths.

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
