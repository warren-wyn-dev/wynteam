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

## Step 2 — remaining systems (2026-10-10, PR #1091, commit `85ac787`)

Founder instruction: "จัดการข้อ1-2ให้หมดเลย" (finish moving every system to per-system permissions).
Applied one system at a time with `wyn219-apply-step2-system.yml`, each verified before the next
(0 functions left on `platform_role` for that system, views/policies/food helper checked):

| System | Run | Result |
|---|---|---|
| Merchant | [38071707698](https://github.com/warren-wyn-dev/wynteam/actions/runs/38071707698) | success |
| Food | [38071748434](https://github.com/warren-wyn-dev/wynteam/actions/runs/38071748434) | success |
| Social | [38071778738](https://github.com/warren-wyn-dev/wynteam/actions/runs/38071778738) | success |
| Account | [38071826093](https://github.com/warren-wyn-dev/wynteam/actions/runs/38071826093) | success |
| central (dashboards, audit log) | [38071871360](https://github.com/warren-wyn-dev/wynteam/actions/runs/38071871360) | success |

Admin app → Vercel production (`deploy-admin.yml`, commit `85ac787`):
[38071640710](https://github.com/warren-wyn-dev/wynteam/actions/runs/38071640710) — **failed, Vercel
`api-deployments-free-per-day` quota**. Production Admin still runs the previous build (`4a12204`).
The database enforces the new permissions regardless; the old build shows pages by
admin/moderator role, so until the redeploy:
- `@wynos_s` (super admin) works everywhere as before.
- Moderators keep Social (seeded `social:edit`); Food/Merchant/Account pages show errors for them.
- Other platform admins see pages that fail to load until granted (Founder decision: they get nothing).
- Staff granted a permission who are not admin/moderator cannot sign in until the new build is live.

### Effect for staff (after step 2)

- Every Admin system needs a per-system permission granted on **ระบบ → Team Permissions**.
- Dashboard needs any permission; the audit log is super admin only.
- Moderators (`social:edit`) can now also send announcements.
- Announcement and inactive-reminder history is visible to the super admin only.

### Rollback

Per system, apply the matching file in `supabase/rollbacks/2026101017*_rollback.sql` in reverse
order (central → Account → Social → Food → Merchant).

### Follow-up

- Re-run `deploy-admin.yml` (production) once the Vercel quota resets.
- Founder: manual QA with `@wynos_s` (`.wyn/docs/qa/wyn-219-admin-staging-checklist.md`) and grant
  permissions to staff who still need access.

