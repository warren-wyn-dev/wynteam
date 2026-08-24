# Product + Design Task — WYN-055

Status: backlog
Owner: AI Product Manager + AI Design (combined, continuing straight through WYN-052/023/053/054)

Feature: WYN Official Announcement — Master Spec section 43: "Admin สร้างประกาศ: System Update, Policy Update, Maintenance, Important Announcement — กำหนดกลุ่มผู้รับได้"

Goal: let Admin broadcast a system notification to a group of users at once. `send_system_notification()` (WYN-043) already exists but is single-recipient only — built for one-off "notify this one user" cases, not a broadcast tool. This task adds the group-send primitive and the compose UI.

Problem: `admin/app/(admin)/announcements/page.tsx` is still WYN-049's placeholder. There is no bulk-send path — doing this from the client by fetching every profile id and calling `send_system_notification()` once per user would be hundreds/thousands of round trips and isn't atomic.

Scope decisions:
1. **New RPC, not a loop over the existing one**: `admin_send_announcement(p_category text, p_message text, p_audience text)` — single `insert into notifications select ... from profiles where <audience filter> and internal.notification_enabled(id, 'system')` (one statement, same 'system' notification type/category `send_system_notification()` already uses — no new notification type, no new user-facing rendering path, `NotificationListScreen` needs zero changes). **Admin-only** (not moderator) — matches `send_system_notification()`'s own existing restriction and the Master Spec's literal "Admin สร้างประกาศ" wording.
2. **"กำหนดกลุ่มผู้รับได้" (audience targeting), grounded in what actually exists**: there is no cohort/segment/region model anywhere in this schema to target by, and inventing one (fake "beta users" or similar) would be make-believe. The one real, already-meaningful split available is `profiles.platform_role` — so `p_audience` is `'all'` / `'users'` (platform_role = 'user' only) / `'staff'` (moderator+admin) — a genuine 3-way choice, not a placeholder. Broader audience targeting (by activity, region, follower count, etc.) is a fast-follow if Founder wants real segmentation later; noted, not built.
3. **The 4 categories from the Master Spec** (System Update/Policy Update/Maintenance/Important Announcement) are metadata for the sender's own record-keeping and the History list's filter — they are **not** surfaced differently to the recipient (the notification itself is the same plain 'system' type/rendering every other system notification already uses; no per-category icon/styling was ever specced for the in-app notification list, and inventing one now would be a Design decision this task doesn't need to make to satisfy the Master Spec's actual ask). Stored in the RPC call's `audit_log.detail` only.
4. **History, not a new table**: every send is already logged via `internal.log_audit_event()` (new event type `admin_announcement_sent`, `detail = {category, message, audience, recipient_count}`) — the page's History section reads this straight from `admin_audit_log` (WYN-054's new view, filtered to this one event type) rather than inventing parallel storage. This is why WYN-054 is a dependency, not just adjacent Phase 7 work.

Requirements:
- R1. `admin_send_announcement(p_category, p_message, p_audience)` RPC — `coalesce(internal.current_platform_role(), '') <> 'admin'` guard (WYN-050's lesson), validates category/audience against fixed sets, message non-blank, bulk-inserts respecting each recipient's own notification preference, logs one audit event with the real recipient count, returns that count.
- R2. Extend `audit_log_event_type_check` with `'admin_announcement_sent'`.
- R3. `/announcements` page: compose form (category select, audience select, message textarea) — confirmation dialog before sending (mirrors `ActionDialog`'s reason-required shape, except the "reason" here *is* the message) showing the resolved recipient count is not possible to preview cheaply without a second query, so the dialog instead confirms audience name in plain Thai ("ส่งถึงผู้ใช้ทั่วไปทุกคน" / "ส่งถึงทีมงานทุกคน" / "ส่งถึงทุกคน") before sending, then shows the actual count returned on success.
- R4. History section below the form: table of past announcements (category/audience/message/recipient_count/sent time) from `admin_audit_log` filtered to `admin_announcement_sent`, newest first.

Acceptance Criteria:
- [ ] Sending an announcement inserts one `notifications` row per matching, opted-in recipient and none for opted-out ones
- [ ] Audience filter (`all`/`users`/`staff`) actually changes who receives it
- [ ] A `moderator`-role account is rejected (admin-only, unlike every other RPC this Phase built so far)
- [ ] A `user`-role account or no-`profiles`-row account is rejected
- [ ] History shows every past send with the correct recipient count
- [ ] `next build`/`npm run lint` clean

Dependencies: WYN-043 (`notifications`, `internal.notification_enabled()`, the `'system'` type/category), WYN-048 (`audit_log`), WYN-054 (`admin_audit_log` view, for History), WYN-050 (`coalesce()` role-guard lesson)

Priority: P2 (Phase 7 roadmap order)

Risks: **admin-only, not moderator** — double-check the RPC guard specifically, since every other Phase 7 RPC so far (WYN-050/051/052) uses `not in ('admin', 'moderator')` and it would be an easy copy-paste mistake to reuse that here instead of the tighter admin-only check this task actually needs. Bulk insert performance is fine at V1 scale (a single `insert ... select`, not a loop) but would need batching if the user base ever reaches a size where a single transaction inserting one row per user becomes a real concern — not now.

Recommendation: approve — implement directly. Do WYN-054 first (History has nothing to read from otherwise).

Handoff: AI Coding — `supabase/schema.sql` (RPC + constraint), `admin/app/(admin)/announcements/page.tsx`, `admin/lib/admin-announcements.ts`.

## Coding + QA (2026-08-24)

`admin_send_announcement(p_category, p_message, p_audience)` — **admin-only guard verified deliberately different from every other Phase 7 RPC** (`<> 'admin'`, not `not in ('admin', 'moderator')`) — the exact copy-paste risk the Risks section called out, checked directly with a moderator-rejection test case (CHECK5) rather than just trusting the code once written. Single `insert into notifications select ... from profiles where <case p_audience> and internal.notification_enabled(id, 'system')` — one statement, not a loop. `audit_log_event_type_check` extended with `admin_announcement_sent`.

Web: `admin/lib/admin-announcements.ts` (`fetchAnnouncementHistory()`, reads `admin_audit_log` filtered to the new event type — no parallel table), `admin/lib/admin-announcements-actions.ts` (`sendAnnouncement()`), `announcements/compose-form.tsx` (category/audience/message + confirm dialog showing the resolved audience name in Thai before sending, actual recipient count shown after) — confirm dialog built directly rather than reusing `ActionDialog` (different field shape: category+audience+message, not just a reason), `announcements/history.tsx` (table from `admin_audit_log`).

`wyn_054_055_audit_log_announcements_test.sh` (shared with WYN-054, 17 checks total) covers: `all`/`users`/`staff` audience actually filters correctly (verified with a seeded opted-out user who is correctly excluded from `all` too, not just `users`), moderator/user/no-profile all rejected, invalid category/audience/blank message all rejected, and every successful send writes exactly one `admin_audit_log` row with the correct `recipient_count` in `detail`, readable back through WYN-054's view.

`next build`/`npm run lint`: clean. Full 25-suite SQL regression run: all pass. Guest redirect verified.

Recommendation: approve.

Final Status: **PASS**
