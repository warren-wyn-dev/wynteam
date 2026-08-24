# Product + Design Task — WYN-054

Status: backlog
Owner: AI Product Manager + AI Design (combined, continuing straight through WYN-052/023/053)

Feature: Audit Log — Master Spec section 42: "ทุก Admin Action สำคัญต้องบันทึก: Admin, Action, Target, Time, Reason, Previous State, New State — ห้าม Admin ปกติลบ Audit Log"

Goal: give Admin/Moderator a read screen for `public.audit_log`, which every privileged action since WYN-048 already writes to (`moderation_action_applied`, `appeal_decided`, `system_notification_sent`, `account_deleted`, `data_exported`, `admin_user_action_applied`, `admin_user_unbanned`, `admin_content_removed`, `admin_content_restored`, and this session's own new `admin_announcement_sent` from WYN-055) but that **nothing can currently read** — `audit_log` was deliberately built with zero SELECT policy of any kind. Its own schema comment says exactly this, verbatim: "There is no Admin UI with proper per-role access control built yet (WYN-054, Phase 7, is what adds the screen that reads this table) ... Until WYN-054 ships, this table is readable only via direct SQL access." This task is that screen.

Problem: `admin/app/(admin)/audit-log/page.tsx` is still WYN-049's placeholder, and there is no read path into `audit_log` at all yet from any client.

Scope decision: add exactly one new object — `public.admin_audit_log`, a plain VIEW mirroring `moderation_queue`/`admin_user_moderation_history`'s exact established pattern (no `security_invoker`, re-implements its own visibility with `where internal.current_platform_role() <> 'user'` in the view body, so a client hitting `/rest/v1/audit_log` directly still sees nothing — that table keeps zero policies of its own, unchanged). Visibility threshold matches every other admin view in this schema (admin OR moderator, not admin-only) — there is no third tier to split on, and every event type logged today is already the direct result of an admin/moderator action or a compliance-relevant self-service action (account_deleted/data_exported) that Admin staff legitimately need visibility into for support/incident-response, per WYN-048's own original framing. Actor identity (`actor_username_snapshot`) is shown plainly — same reasoning WYN-051 already established for `admin_user_moderation_history`: the "never let the target learn who acted" rule protects the *target* from seeing this, not other Admin/Moderator staff from seeing each other's actions (ordinary accountability).

"Previous State/New State" from the Master Spec's one-liner: already covered by the existing `detail` jsonb column, which every event type already populates with everything relevant (e.g. `moderation_action_applied`'s `{action_type, reason}`) — no schema change needed, `detail` is shown as-is.

No delete/update path is added anywhere (Master Spec: "ห้าม Admin ปกติลบ Audit Log") — the view is SELECT-only by construction (a view has no delete unless explicitly made updatable, and this one isn't), and `audit_log` itself still has zero policies for any client mutation. Immutability was already true before this task; this task doesn't touch it.

Requirements:
- R1. `public.admin_audit_log` VIEW: `id, actor_id, actor_username_snapshot, event_type, target_id, detail, created_at`, `where internal.current_platform_role() <> 'user'`, `grant select ... to authenticated`.
- R2. `/audit-log` page: table of every row, newest first, columns Actor/Event/Target/Detail/Time — `event_type` shown with a Thai label (mirrors the `ACTION_LABEL`-constant pattern already used in `/users/[id]`/`/moderation/[id]`), `detail` rendered as compact formatted JSON (it's heterogeneous per event type — a generic viewer, not a bespoke renderer per event type, keeps this from ballooning into 9+ special cases).
- R3. A simple event-type filter (dropdown), since 9 event types in one flat list gets noisy fast — no date-range filter this round (Non-goal, `created_at` sort is enough for V1; add later if Founder wants it).
- R4. No pagination this round — same `limit(200)`-ish ceiling precedent as WYN-051/052's search results (`limit 30`), scaled up since this is a chronological log meant to be skimmed, not searched by keyword. Note as a fast-follow if the log grows large enough to need it.

Acceptance Criteria:
- [ ] `/audit-log` lists every row from every event type logged so far, newest first
- [ ] Filtering by event type works
- [ ] A `user`-role account (or no `profiles` row) reading `admin_audit_log` directly gets nothing back (view-level gate holds)
- [ ] `audit_log` itself still has zero client mutation path of any kind (regression check — nothing in this task should add one)
- [ ] `next build`/`npm run lint` clean

Dependencies: WYN-048 (`audit_log`, `internal.log_audit_event()`), WYN-049 (admin shell)

Priority: P2 (Phase 7 roadmap order, alongside WYN-053/055)

Risks: low — read-only addition, same VIEW-over-RLS-gap pattern already used twice successfully (`moderation_queue`, `admin_user_moderation_history`). Main risk was over-scoping into a bespoke renderer per event type or a delete/redaction UI that Master Spec explicitly forbids — both rejected above.

Recommendation: approve — implement directly.

Handoff: AI Coding — `supabase/schema.sql` (the VIEW only), `admin/app/(admin)/audit-log/page.tsx`, `admin/lib/admin-audit-log.ts`.

## Coding + QA (2026-08-24)

`public.admin_audit_log` VIEW added exactly as scoped (mirrors `moderation_queue`/`admin_user_moderation_history`'s pattern precisely) — `audit_log` itself untouched, still zero client-facing policy of any kind. `admin/lib/admin-audit-log.ts` (`fetchAuditLog(eventType?)`, `limit(200)`), `audit-log/page.tsx` + `event-type-filter.tsx` (Select dropdown, 10 event types + "ทุกประเภท") + `results.tsx` (generic table, `detail` jsonb rendered as formatted `<pre>` rather than a bespoke renderer per event type — 10 event types today, more will come from future tasks, and a per-type renderer would need updating every time one is added).

New regression test `wyn_054_055_audit_log_announcements_test.sh` (17 checks, combined with WYN-055 since WYN-055's own checks need something in the audit log to read back through this view) — **CHECK1/2 seed a real row via `admin_apply_user_action()` (WYN-051) rather than a raw INSERT**, since `internal.log_audit_event()` isn't grantable to `authenticated` at all (by design, per its own schema comment) — proving the view actually surfaces a row written by an existing, real privileged action, not a fabricated test fixture. Verified admin AND moderator both see it, `user`-role/no-profile both see nothing.

`next build`/`npm run lint`: clean. Guest redirect verified. Full 25-suite SQL regression run: all pass.

Recommendation: approve.

Final Status: **PASS**
