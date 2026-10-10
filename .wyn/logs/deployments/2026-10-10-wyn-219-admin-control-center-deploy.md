# Deployment Log — WYN-219 Admin Control Center (Admin production + permissions foundation + Maps)

**Date**: 2026-10-10
**Approval**: Founder — "อนุญาตทั้งหมด" then "ทำให้เสร็จ100%" / "ลองขึ้นProduction ให้หน่อย" (2026-10-10).
**QA note**: production was approved by the Founder before a separate staging QA run of
`.wyn/docs/qa/wyn-219-admin-staging-checklist.md`. Automated checks below passed; the manual
checklist is still recommended on production now.

## What went live

| Step | Run | Result |
|---|---|---|
| Admin permissions foundation (DB) — `wyn219-apply-admin-permissions-foundation.yml`, super admin `@wynos_s`, promoted to platform admin (Founder decision) | [38065051686](https://github.com/warren-wyn-dev/wynteam/actions/runs/38065051686) | success — one super admin, super admin is platform admin, role guard trigger re-enabled, moderators seeded `social:edit`, no direct writes, anon cannot call grant/helper |
| Admin app → Vercel production (`deploy-admin.yml`, commit `4a12204`) | [38069054399](https://github.com/warren-wyn-dev/wynteam/actions/runs/38069054399) | success — https://admin-lilac-seven-85.vercel.app (Vercel Authentication on) |
| WYN-219 step 2 Maps (DB) — `wyn219-apply-step2-maps.yml` | [38069181181](https://github.com/warren-wyn-dev/wynteam/actions/runs/38069181181) | success — 0 Maps functions on platform_role, 9 on `maps` permission, 2 storage policies updated, grants kept |

Admin now includes: grouped navigation by WYNOS system (#1076), Team Permissions page for the super
admin (#1080), user search filter hardening (#1081), permission-aware Maps menu/page and Food store
page (#1086).

Earlier attempts (no changes made, all rolled back or refused before deploy):
- Foundation run 38062568745 — audit_log constraint shape in production (fixed in #1087).
- Foundation runs 38063029781 (`warren`) and 38064416103 (`wynos_s`) — account not a platform admin; promotion added in #1088.
- Admin production run 38065280630 — Vercel `api-deployments-free-per-day` quota.

## Effect for staff

- `@wynos_s` is the only super admin and keeps full access everywhere.
- **WYNOS Maps** admin (Places, place photos, suggestions) now requires `maps:view` / `maps:edit`.
  Other platform admins and moderators no longer see Maps until the super admin grants it on
  **ระบบ → Team Permissions**.
- All other systems still use the previous admin/moderator checks (step 2 continues per system:
  Merchant → Food → Social → Account → central).

## Rollback

- Maps: apply `supabase/rollbacks/20261010160000_wyn219_step2_maps_permissions_rollback.sql`.
- Admin app: redeploy the previous production deployment in Vercel (or `deploy-admin.yml` from the
  prior commit).
- Foundation: additive; see the migration header (nothing outside Maps reads it yet).

## Follow-up

- Run the staging QA checklist against production Admin with `@wynos_s`.
- Grant Maps access to anyone who still needs it.
- Next step 2 system: Merchant.
