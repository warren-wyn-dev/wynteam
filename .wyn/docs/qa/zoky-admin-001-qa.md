# QA & Security — ZOKY-ADMIN-001 แยก ZOKY Admin ออกจาก WYNOS Admin

Date: 2026-10-25 · Branch: `claude/zoky-admin-split-proposal` · Spec: `.wyn/docs/product/zoky-admin-001-split-proposal.md`
Verdict: **PASS for code review / merge — staging and production verification still required** (no live Supabase or Vercel access in the build session)

## Evidence (run locally)

| Check | Result |
|---|---|
| `zoky-admin`: lint / `next typegen` + `tsc` / `next build` (23 routes + `/team`) | PASS (1 pre-existing lint warning in moved `food-banner-manager.tsx`) |
| `admin`: lint / `tsc` / `next build` | PASS |
| WYNOS Admin redirects: 15 old Food/Merchant/dashboard URLs → matching ZOKY Admin URL, query kept; `/food/places` → `/maps/places`; Maps/Users stay | PASS (`next start` + curl) |
| ZOKY Admin unauthenticated `/`, `/food`, `/team` → `/login`; login renders at 375px and 1280px without horizontal scroll | PASS (curl + Playwright screenshot) |
| `supabase/tests/zoky_admin_team_test.sh` (PostgreSQL 16) | PASS 75/75 |
| Refusal reasons checked by hand (not masked by other SQL errors) | PASS |
| `wyn_219_admin_permissions_foundation_test.sh`, `wyn_219_step2_remaining_systems_test.sh` | PASS |
| `web/tests` source tests pointing at moved files (node) | PASS 11/11; 2 Playwright spec assertions verified by string check (8/8) |
| `tools/check_production_secret_scoping.py`, `tools/check_wynos_release_freeze.py` (+ its test), `supabase/check_schema_ordering.py` | PASS |

## Security review

- **AuthN/AuthZ:** ZOKY Admin gate (login action + layout) = super admin, ZOKY Team Lead or WYN-219 `food`/`merchant`; fails closed; no `platform_role` fallback. Every moved page keeps its own `adminCan` check; every RPC unchanged (`internal.has_admin_permission`).
- **Privilege delegation (HIGH risk, proposal §5):** DB refuses a Lead granting account/social/maps, changing own/other Lead/super admin rows, appointing Leads, calling the WYN-219 grant RPC, writing `admin_permissions` or reading `internal.zoky_team_leads`; a food:edit member cannot manage the team; anon has no EXECUTE. All covered by the 75-check test. → **No open CRITICAL/HIGH in code review**; re-test on staging with real accounts required before release.
- **Enumeration:** `admin_zoky_find_user` = exact username, ≤1 row, Lead/super admin only.
- **Redirects:** fixed destination origin (`NEXT_PUBLIC_ZOKY_ADMIN_URL`, default `https://zoky-admin.wynos.online`), no user-controlled host → no open redirect; 307 so rollback is not cached.
- **Secrets:** only public Supabase URL/publishable key; workflows use the protected `production` environment; values never printed.
- **Release safety:** WYNOS Admin consolidated release fails unless `zoky-admin.wynos.online/login` answers and stays under the release freeze. ZOKY Admin production is a Founder exception to the freeze (2026-10-25, `.wyn/company/APPROVALS.md`): typed exception + production confirmations and the protected environment (enforced by `tools/check_wynos_release_freeze.py`).

## Not verified (must be done on staging)

1. Real login with: super admin, Lead without permissions, Lead with food:edit, merchant:view member, social-only moderator (must be refused), user (refused).
2. Every moved page with real data (orders, refunds, stores, coupons, campaigns, ads, finance, delivery, menu, verification).
3. Team page flows against the applied migration; Roles & Permissions appoint/remove Lead.
4. Cross-app links (store → `/users/:id`, `/maps/places`, audit log).
5. Mobile drawer/sidebar on real devices.

## Release order

1. `zoky-admin-apply-team.yml` (migration) → 2. `zoky-admin-bootstrap.yml` (Vercel project) → 3. `deploy-zoky-admin.yml` production with `ZOKY_ADMIN_EXCEPTION_APPROVED` (Founder exception, attaches domain) → post-deploy checks above → 4. WYNOS Admin consolidated release (redirects) once the freeze clears.
