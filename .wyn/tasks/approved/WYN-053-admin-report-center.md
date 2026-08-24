# Product + Design Task — WYN-053

Status: backlog
Owner: AI Product Manager + AI Design (combined, low session quota — same session continuing straight through WYN-052/WYN-023)

Feature: WYN Admin Report Center — Master Spec section 41: "Reports → Priority → Risk Classification → Reviewer → Action → Appeal"

Goal: bring the report queue (WYN-029's `moderation_queue`/`apply_moderation_action()`, already fully built and already has a Flutter in-app UI for moderators — `app/lib/features/moderation/`) to the Admin web surface. Today an Admin/Moderator must use the mobile app to see the report queue at all; WYN-051/052 only cover taking *direct* action on a specific user/Drop already known, not triaging the queue itself.

Problem: `admin/app/(admin)/reports/page.tsx` is still WYN-049's placeholder. The `moderation_queue` VIEW already returns every report regardless of `target_type` (user/drop/drop_comment/club/club_post/club_post_comment/message/redrop — 8 types, `reports_target_type_check`), but nothing on the web reads it unfiltered — WYN-051's `/users/[id]` and WYN-052's `/moderation/[id]` each only read it pre-filtered to one specific target.

Scope decision (V1): **no new SQL at all** — `moderation_queue` and `apply_moderation_action()` already do everything this needs.
1. Screen 1 (`/reports`): a single table of every report, all 8 target types together, default filtered to `pending`/`reviewing` (open cases) with a status filter to see `actioned`/`dismissed` too. Sorted oldest-first (FIFO — this is "Priority" for V1: there is no severity/risk score anywhere in the schema to sort by instead, and inventing one is a separate task if Founder wants it later). "Risk Classification" is the existing `category` column (spam/harassment/violence/etc.), shown as a column — already exactly what WYN-026's report categories are for.
2. Row click routing:
   - `target_type = 'user'` → `/users/{target_id}` (WYN-051, already has full action UI + this report visible in its own Reports table there)
   - `target_type = 'drop'` → `/moderation/{target_id}` (WYN-052, same reasoning)
   - every other type (`drop_comment`/`club`/`club_post`/`club_post_comment`/`message`/`redrop`) → new `/reports/{id}` detail page (below)
3. Screen 2 (`/reports/[id]`, new): **no rich content preview** for these 6 types this round (Non-goal, explicit) — building an admin-bypass RPC per table (6 more security-reviewed RPCs, mirroring `admin_get_drop()`'s reasoning each time) is a task-sized decision on its own, not a natural extension of "show a queue." Shows report fields only (`target_type`/`target_id`/`category`/`detail`/`created_at`/`status`) plus a generic action bar: `apply_moderation_action(report_id, action_type, reason, duration_days)` — No Action/Warning/Restrict/Suspend/Ban always available, Remove Content only for the 3 content types (`drop_comment`/`club_post`/`club_post_comment`) per the RPC's own existing validation (`'Remove Content is not supported for target type %'` for `user`/`club`; `message`/`redrop` have no Remove Content path in the RPC either, so it's excluded for those two as well — reuses the RPC's own rules, doesn't re-decide them).
4. Reuses `ActionDialog` (WYN-051/052) directly — same 6-action set the Flutter `ModerationActionSheet` already offers, same reason-required/duration-for-restrict-suspend rules the RPC already enforces.

Acceptance Criteria:
- [ ] `/reports` shows every open report across all 8 target types, oldest first
- [ ] Status filter shows actioned/dismissed reports too
- [ ] Clicking a `user`/`drop` report row goes to the existing `/users/[id]`/`/moderation/[id]` pages
- [ ] Clicking any other report row goes to `/reports/[id]` showing its raw fields
- [ ] Taking an action on `/reports/[id]` calls `apply_moderation_action()` correctly (Remove Content option only appears for `drop_comment`/`club_post`/`club_post_comment`)
- [ ] A `user`-role account (or no `profiles` row) cannot read `moderation_queue` (already enforced by the existing VIEW — verify it still holds, not re-implement)
- [ ] `next build`/`npm run lint` clean

Dependencies: WYN-029 (`moderation_queue`, `apply_moderation_action()`), WYN-049 (admin shell), WYN-051 (`ActionDialog`, table pattern), WYN-052 (`/moderation/[id]` routing target)

Priority: P2 (Phase 7 roadmap order)

Risks: low — zero new SQL, every RPC/view already shipped and QA'd. Main risk is scope creep into "build a preview for every content type," explicitly rejected above.

Recommendation: approve — implement directly, no architecture question needs Founder sign-off this round (unlike WYN-052).

Handoff: AI Coding — `admin/app/(admin)/reports/page.tsx` (table + status filter), `admin/app/(admin)/reports/[id]/page.tsx` (new, generic detail + action bar), `admin/lib/admin-reports.ts` (data layer: `fetchQueue(status)`, `fetchReport(id)`), reuse `ActionDialog`.

## Coding + QA (2026-08-24)

Zero new SQL, exactly as scoped — `moderation_queue`/`apply_moderation_action()` reused as-is. `admin/lib/admin-reports.ts` (`fetchQueue`/`fetchReport`), `admin/lib/admin-reports-actions.ts` (`applyModerationAction` wrapping the RPC), Screen 1 (`reports/page.tsx` + `status-filter.tsx` + `results.tsx`, status tabs open/actioned/dismissed/all, oldest-first) — rows are click-through via a small new `ClickableRow` client component (a `<tr onClick>` wrapper) rather than wrapping each `<td>` in its own `Link`, avoiding 5x duplicated markup per row. `hrefFor()` routes `user`/`drop` reports straight to `/users/[id]`/`/moderation/[id]` (WYN-051/052), everything else to the new generic `/reports/[id]`. Screen 2 (`reports/[id]/page.tsx`) shows raw report fields + `ReportActionsBar` (new component) offering the same 6 actions the Flutter `ModerationActionSheet` already offers — confirmed against that file directly that report-driven Ban never used typed-confirmation (only WYN-051's *direct* admin action Ban does, a newer, separate safeguard), so a plain `ActionDialog` here is correct, not a scope cut. Remove Content only rendered for `drop_comment`/`club_post`/`club_post_comment`, matching the RPC's own existing target-type validation exactly (not re-decided here).

`next build`/`npm run lint`: clean. Verified no `service_role` string in `.next/static`. Guest redirect verified on both new routes (dev server + dummy env vars, deleted after) — 307 to `/login`, same as every existing route.

Recommendation: approve.

Final Status: **PASS**
