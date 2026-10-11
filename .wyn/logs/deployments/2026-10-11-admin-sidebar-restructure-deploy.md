# Deployment Log — Admin Sidebar restructure (Admin production)

**Date**: 2026-10-11
**Approval**: Founder — "อนุญาต" in reply to the request "อนุมัติ merge และ deploy production" (2026-10-11),
then "อนุญาต" for the smoke test and this record.
**Scope**: the original release (PR #1096) is `admin/` navigation only, with no Auth, API, database, RLS or
environment change. The follow-up below adds more controlled changes: a Dashboard behaviour fix (#1102),
the production custom domain `admin.wynos.online` (#1099), and a build that includes #1104
(Merchant Finance: new read-only RPC and migration).

## What went live

| Step | Run | Result |
|---|---|---|
| PR #1096 merged to `main` (merge commit `4cbf8c5`) | CI [38108840833](https://github.com/warren-wyn-dev/wynteam/actions/runs/38108840833) | all checks green (Admin, Flutter, Supabase SQL/RLS, Deno, schema) |
| Admin preview (`deploy-admin.yml`, target preview, branch head `93b2942`) | [38108853990](https://github.com/warren-wyn-dev/wynteam/actions/runs/38108853990) | success — https://admin-mvavp3mfm-warren14.vercel.app |
| Admin app → Vercel production (`deploy-admin.yml`, `main` @ `4cbf8c5`) | [38109352021](https://github.com/warren-wyn-dev/wynteam/actions/runs/38109352021) | success — https://admin-eh6q1bwn4-warren14.vercel.app, aliased https://admin-lilac-seven-85.vercel.app (Vercel Authentication on) |

Admin now includes: Dashboard รวม on top; collapsible sections WYNOS Account / Social / Food / Merchant /
Maps / อื่นๆ; Stores, Coupons, Campaigns, Ads and Promo Notifications under WYNOS Merchant (URLs and
permissions unchanged); per-system dashboards at `/dashboard/[system]`; unbuilt features shown as
"เร็วๆ นี้"; mobile drawer. Details: `.wyn/docs/qa/admin-sidebar-restructure-qa.md`.

## Verification

- Production build output lists every previous route plus `/dashboard/[system]`; deployment Ready in 44s.
- Pre-merge: lint, typecheck, build and 81/81 Playwright E2E against a local mock Supabase.
- **Not yet verified from the agent sandbox:** `admin.wynos.online` is not reachable from it (TLS connect
  refused by the sandbox network) and the Vercel URLs require Vercel Authentication. Founder to check on
  production: menu sections, the 5 system dashboards against real data, and the mobile drawer.

## Rollback

Revert merge commit `4cbf8c5` and run `deploy-admin.yml` (production), or promote the previous production
deployment in Vercel. No data or schema to roll back.

## Follow-up — Dashboard รวม fix (PR #1102), admin.wynos.online, and the 28b2df0 release

- Founder report: Dashboard รวม (`/`) showed "โหลดข้อมูลไม่สำเร็จ". Root cause: the production
  `admin_dashboard_trends()` (WYN-219 step 2) no longer returns `dau_last_14d`, so the DAU chart threw on
  every load. This predates the sidebar change. Reproduced locally against a mock returning the
  production shape.
- Fix (PR #1102, approved "อนุญาต"): the DAU chart reads `admin_activity_trend(14)`. Metrics, trends and
  signups now load independently, and the Feed panel needs `social:view`. No RPC or schema change.
- `admin.wynos.online` was attached to the Admin Vercel project (PR #1099, approved, recorded in
  APPROVALS.md; run 38111279950). DNS was not changed.
- Deploy run 38112932614 (`d6d17ec`) failed on Vercel `api-deployments-free-per-day`. Retry
  [38125094225](https://github.com/warren-wyn-dev/wynteam/actions/runs/38125094225) succeeded at
  `main` @ `28b2df0`.
- That artifact also contains PR #1104 (Merchant Finance, Founder approval in DECISIONS.md, merged by
  another session). Its migration `20261011120000_admin_merchant_finance_overview.sql` is additive
  and read-only (one RPC). It was applied by `admin-apply-merchant-finance.yml`, run
  [38114995748](https://github.com/warren-wyn-dev/wynteam/actions/runs/38114995748) (success,
  `28b2df0`), before this deploy.
- PR #1100 updated the existing `admin-vercel-logs-check.yml` (added in `ce0cba9`): it now reads
  retained runtime logs with redaction instead of `vercel inspect --logs`.

### Verification

- Unauthenticated smoke test: `/login` 200 "WYN Admin"; `/`, `/dashboard/food` and
  `/merchant/finance` return 307 → `/login`.
- **Founder verified (2026-10-11, logged in on admin.wynos.online): "เปิดละ โอเค".** Production verification is
  complete. The note below records the state before that check.
- ~~Production verification is NOT complete.~~ The fixed Dashboard รวม and the Merchant Finance page
  have not yet rendered with a logged-in session against production data. The agent has no Admin
  account. The Founder must log in and confirm both before this release counts as verified. If either
  fails, run `admin-vercel-logs-check.yml` within 1h to get the redacted error.

### Rollback for the 28b2df0 release

- App: promote the previous production deployment in Vercel (Instant Rollback), or revert the merge
  commits `d6d17ec` (#1102) and/or `28b2df0` (#1104) and run `deploy-admin.yml`.
- Database (#1104 only): run `supabase/rollbacks/20261011120000_admin_merchant_finance_overview_rollback.sql`
  (drops the read-only RPC; the page then shows "not installed"). #1102 and #1096 have no DB changes.
- Domain: remove `admin.wynos.online` from the Admin project in Vercel.

## Follow-up release: brand rename to "WYNOS Admin" (#1107)

- Founder approval: "อนุญาต" (2026-10-11) for merge + production deploy of PR #1107.
- First attempt, run [38126503044](https://github.com/warren-wyn-dev/wynteam/actions/runs/38126503044),
  failed on the Vercel Hobby `api-deployments-free-per-day` quota (Founder chose to stay on Hobby).
- Deployed by run [38143528093](https://github.com/warren-wyn-dev/wynteam/actions/runs/38143528093)
  (success) from `main` @ `f9bfb08`. No `admin/` changes landed between `1dd1d7c` (#1107) and
  `f9bfb08`; the only new commits were the Food splash (#1103, `food/`), which this workflow does not build.
- Smoke test: `https://admin.wynos.online/login` serves `<title>WYNOS Admin</title>`; `/` returns 307 → `/login`.
- Rollback: Vercel Instant Rollback to the `28b2df0` deployment, or revert `1dd1d7c` and run
  `deploy-admin.yml`. Text-only change; no DB, auth or permission changes.
