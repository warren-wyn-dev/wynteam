# WYNOS Admin — All-phases integration QA report

**Date:** 2026-10-09  
**Branch:** `qa/admin-all-phases-integration-20261009`  
**Base:** Workspace UI PR #1053 (not merged)  
**Purpose:** Verify cross-feature compatibility of seven Draft feature PRs without changing those PR branches, `main`, Vercel, Supabase, Food/Merchant, real users or payments.

## Branch contents

| Phase | Feature | Source PR | Integrated QA destination | Access |
| --- | --- | --- | --- | --- |
| 1 | Action Center | #1055 | `/action-center` | Admin/Moderator (role-filtered) |
| 1 | Audit Log Plus | #1056 | `/audit-log` | Admin/Moderator (source-RLS controlled) |
| 2 | Global Search | #1057 | `/search` | Admin/Moderator (no Food searches for Moderator) |
| 2 | System Health | #1058 | `/system-health` | Admin/Moderator, read only |
| 3 | Admin Security Center | #1059 | `/security-center` | Admin/Moderator, feature flag **OFF** |
| 3 | Admin Notifications | #1060 | `/admin-notifications` | Admin/Moderator, feature flag **OFF** |
| 4 | Analytics Center | #1061 | `/analytics` | Admin only, feature flag **OFF** |

**Merged for QA only:** `admin/lib/admin-nav.ts`, `admin/app/(admin)/page.tsx` and `.github/workflows/ci.yml` contain the combined behavior. `admin/components/admin/header.tsx` uses the Global Search entry while retaining the existing single Workspace selector. Existing contextual Sidebar and mobile bottom navigation remain intact.

**Review caution:** This integration branch is **not** the implementation baseline. Every feature PR must still get its own review, merge plan, security approval, and release/rollback steps. No deployment or release of this QA branch is authorized.

## Automated checks

- [x] Collected exact source heads from all 7 feature PRs; copied their unique file blobs without modifying the feature branches
- [x] Composed shared Workspace menu and Overview quick links, keeping Phase 3/4 flags OFF
- [x] Expanded guest smoke to 26 Admin destinations, including all 7 feature routes
- [x] Updated combined-CI route-string expectations in five feature suites; feature PR tests remain unchanged
- [x] Added `admin/tests/integration-all-phases.test.mjs`: route/menu uniqueness, flags, auth boundaries, single Workspace selector and malicious-input handling
- [ ] Latest integration branch CI fully successful: [GitHub Actions](https://github.com/warren-wyn-dev/wynteam/actions/workflows/ci.yml) — check exact current SHA and final job conclusions
- [ ] **Signed-in browser QA:** isolated staging not ready; no actual Admin/Moderator/User E2E, role-appropriate database data, keyboard-only/screen-reader testing or phone/desktop visual QA yet

## Browser + security test matrix (blocked until approved isolated Staging)

| Scenario | Admin | Moderator | Ordinary user / guest |
| --- | --- | --- | --- |
| Login and changing Workspaces | Allowed | Allowed | Redirect / deny |
| Action Center reports / Merchant / Food | Authorized data only | No privileged Food order/finance | Denied |
| Audit Log filters and cursor | Authorized rows only | Authorized rows only | Denied |
| Global Search result categories | Profiles + authorized Food lookups | Profiles only; **no Food request** | Denied |
| System Health read-only cards | Permitted | Permitted | Denied |
| Security Center (flag OFF) | Hidden / 404 | Hidden / 404 | Redirect / deny |
| Security Center (staging flag ON) | Own MFA/AAL only | Own MFA/AAL only | Denied |
| Admin Notifications (flag OFF) | Hidden / 404 | Hidden / 404 | Redirect / deny |
| Admin Notifications (staging flag ON) | Source-based pending-work snapshot | No Merchant applicant data | Denied |
| Analytics (flag OFF) | Hidden / 404 | Hidden / 404 | Redirect / deny |
| Analytics (staging flag ON) | Authorized panels incl. financial data | 404 and no privileged RPC | Denied |

## High-value cross-feature E2E acceptance cases

1. Select Overview → Social → Food → Central, checking contextual navigation and active route on desktop, tablet and 320/390px mobile. Workspace chooser stays **only in top header**.
2. Navigate from Action Center report to report detail, then return; malformed/stale/deleted record never exposes data of another user.
3. Run Global Search from Header, ensure results correspond to actual RLS/roles, including normal Thai combining marks, 3–48 chars, privacy restrictions and bounded queries.
4. Open Audit Log filters and paginate with exact timestamp+UUID cursor; malformed cursor must be rejected; actor/private detail JSON must never appear in browser output.
5. Simulate one failed source RPC in Action Center, Audit, Search, System Health and Analytics. The affected panel shows **unknown/unavailable**, never a fake 0; healthy panels still render.
6. Disable all Phase 3/4 flags (default). Confirm link absent and direct routes blocked; enabling only on isolated test build never changes MFA enrollment or notification state.
7. Compare analytics against synthetic, independently known Social counts, Food statuses/sales and <=200 sampled Merchant rows; no cross-service sum, private financial fields to Moderator, or applicant PII.
8. Refresh, sign out, revoke role, and try direct URLs and database RPCs. Old sessions, client hiding and cached page fragments must not bypass server/RLS roles.
9. Inspect browser/server logs for secrets and runtime errors, verify keyboard focus labels and mobile safe areas. No Production tenant data should be present in fixtures.
10. Record exact integrated source SHA and approved feature flags for each tested artifact; validate rollback of Admin-only UI route changes before any future release.

## Known restrictions, not test passes

- Supabase Staging resource is inactive in the Free organization with Production and Stripe Sandbox active. Never repoint Preview to Production/Sandbox, pause active projects, upgrade plans or spend budget automatically.
- A Vercel Hobby Preview quota limit has previously blocked creation of new Admin previews. No live Preview is created by this QA branch.
- System Health v1 is only **HTTP/Supabase reachability**, not transaction health, uptime/SLA or real incident history.
- Admin Notifications v1 is a pending-work snapshot, not push delivery nor persistent unread state.
- Security Center v1 only shows the current operator's Auth-provided factor/AAL state; no enrollment, step-up or account recovery yet.
- Merchant Analytics uses up to 200 RPC rows, not a certified population total; no fabricated Merchant growth chart.
- PR #1051 security/shared database migration remains separate and unapplied. No Prod or Stripe Sandbox changes are part of the QA scope.

## Exit criteria

The integration QA branch can be called **offline CI PASS** only when the exact most recent QA SHA has clean Admin Lint, Tests, TypeScript, Next.js Build and 26-route guest smoke. Full integration/Release readiness still requires the isolated authenticated Admin/Moderator/User browser matrix and critical/high security review, the individual PR review gates, founder release approval and rollback readiness. **Never merge or deploy this temporary QA PR.**
