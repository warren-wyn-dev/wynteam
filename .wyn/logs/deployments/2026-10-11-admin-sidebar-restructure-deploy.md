# Deployment Log — Admin Sidebar restructure (Admin production)

**Date**: 2026-10-11
**Approval**: Founder — "อนุญาต" in reply to the request "อนุมัติ merge และ deploy production" (2026-10-11),
then "อนุญาต" for the smoke test and this record.
**Scope**: `admin/` navigation only — no Auth, API, database, RLS or environment change.

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
