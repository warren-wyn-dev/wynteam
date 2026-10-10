# WYNOS Admin: isolated staging, UI and access review checklist

> Scope: WYNOS **Admin web app only**. Planning and offline QA; this file does not
> change deployments, accounts, data, orders, payments or scheduler settings.

## Action Center integration candidate (2026-10-10)

This **stacked draft branch** adds the role-scoped `/action-center` route to the Phase 1 Admin workspace. It reads current Social moderation-queue work, Merchant application-count work, and Admin-only Food active-order totals from existing approved data sources. Every source can fail independently; it does not represent an outage as zero tasks, return applicant/customer PII, or write any orders/refunds.

Release still requires free-only local synthetic Admin/Moderator role QA; the branch and its PR do not authorize Production deployment or database mutation.

## Free-only restriction — Founder decision (2026-10-10)

**No paid services, upgrades or spending.** Use the [free-only QA runbook](./free-only-qa-plan.md) to run synthetic Auth/role tests against local Supabase CLI + Docker, using the existing GitHub CI and disposable PostgreSQL containers.
Production and Stripe Sandbox stay active and untouched. Do not pause them to free a Supabase project slot.
Do not use Production, Stripe Sandbox or an inaccessible shared Supabase staging instance for QA. The local preflight command `npm run check:free-local-qa` rejects non-loopback targets.
Local integrated role testing can replace some hosted-staging evidence, but cannot validate domain binding, hosted Preview environment or real Production operator sessions. Those remain distinct gates; an unavailable free resource is not permission to omit security testing.
No Vercel/Supabase billing change or domain transfer is authorized.

## Central Control Phase 1 — truthful service coverage (2026-10-10)

This PR organizes **existing** Admin routes for Social, Food, Merchant and shared staff tools.
It does not give an operator new powers by reorganizing navigation.

- **Social** (`wynos.online`): existing accounts, reports, moderation and announcements; Social metrics stay on `/social`.
- **Food** (`food.wynos.online`): existing store, order and promotion operations. Sensitive order and advertising routes stay Admin-only server-side. No payment rule changes.
- **Merchant** (`merchant.wynos.online`): existing application reviews, not unrestricted merchant impersonation.
- **Shared**: existing staff audit history; no new export or permission grant.
- **Maps** (`maps.wynos.online`) and **WYNOS Account**: visible as **non-interactive planned cards** on Overview, with no operational links, actions or new RPC privileges. This does not implement Maps moderation, cross-service rights or SSO.

Do not present planned services as operational, or present service-only metrics as cross-platform totals.
Production `admin.wynos.online` domain attachment is a separate infrastructure change; a READY Vercel Preview does not prove the custom domain is configured.

Release gates remain: current PR-head CI, isolated local Supabase/Auth role tests with `profiles.platform_role` (or no-cost isolated staging), Admin/Moderator/User browser QA, responsive checks, hosted environment review where available, and rollback plan.
Do not use Production or Stripe Sandbox as staging. No Supabase migration, PR merge, domain mutation or Production deployment is authorized by this PR update.

## Full-coverage Central Control follow-up (2026-10-10)

Founder scope is **every WYNOS service and administrative detail**, implemented via reviewed capabilities, not unlimited staff privilege.
See [Central Control master specification](./central-control-master-spec.md) for service-by-service inventory, role/approval matrix, API contracts, auditing, staging release gates and rollout.

New read-only `/control-map` shows existing Admin routes and planned capabilities.
Only authorized existing routes create clickable links; planned capabilities are not granted, triggered or linked.
The route is protected by server-side `requireAdminRole()` and is included in guest smoke tests.
**This is a roadmap and inventory feature, not the complete administrative backend.**

## Current environment findings (2026-10-09)

| Area | Observed condition | Release gate |
| --- | --- | --- |
| Admin Vercel Preview | A prior build was READY at an older commit; subsequent builds may hit Hobby quota | Build and verify **exact PR head** |
| Admin Preview backend | Configured to Stripe Sandbox `pcatuxtenluqzjzzwsvl` | **Incorrect** for Admin login: `profiles.platform_role` missing |
| WYNOS Web Beta 2 Staging | Project `yydgdapzlrjmlrjgijkj` is INACTIVE/inaccessible | Do not upgrade or pause active projects; use separate free local Supabase QA until a legitimate no-cost isolated option exists |
| WYNOS Production backend | Project `kqokpocajhfbidcxpvhh` is ACTIVE | **Do not use** to test Admin Preview; preserve all live data |
| Security QA PR #1051 | Separate, draft; tests isolated; migrations un-applied | Review independently and do not apply on Production during UI QA |

The release preflight at `scripts/check-admin-environment.mjs` and automatic
Vercel build guard at `scripts/check-admin-build.mjs` reject mismatched backends.
They inspect only the Supabase **project URL host**, never fetch credentials
or connect to the database. The tests are offline.

### When a genuinely isolated Admin staging backend is available

1. Confirm the staging project is **ACTIVE** and has the required WYNOS schema,
   `public.profiles.platform_role` and role/RLS functions. Check this in staging
   only, not by copying Production user records.
2. Create **synthetic, non-Production** test users (Admin, Moderator and an
   ordinary User) using the staging Auth configuration. Do not reuse real
   customer/admin passwords, tokens, email addresses or Stripe Sandbox users.
3. Configure GitHub Actions **only for Admin Preview**:
   `ADMIN_STAGING_SUPABASE_URL`,
   `ADMIN_STAGING_SUPABASE_PUBLISHABLE_KEY`, and repository variable
   `ADMIN_PREVIEW_SUPABASE_PROJECT_REF` equal to the audited isolated staging
   reference. Keep existing Production secrets unchanged. Store keys only in
   secret managers; do not commit credentials.
4. Update the existing Vercel **Admin** project *Preview* environment with the
   isolated staging URL/publishable key and
   `ADMIN_PREVIEW_SUPABASE_PROJECT_REF`. Do not alter its Production variables
   or Deployment Protection.
5. Run the manual `Deploy Admin` workflow with target `preview`. It runs a
   preflight before building. Direct Vercel auto-builds run the build guard.
   Neither guard grants access by itself.
6. Use Vercel's authorized Preview access. Test Admin, Moderator and User roles
   against staging, with no real transactions or privileged business mutations.
7. Only after review, CI, complete authenticated UI QA and rollback readiness
   should a separate authorized Admin-only Production release be considered.

The existing Stripe Sandbox is reserved for payments and is **not an Admin
staging substitute**. Do not unpause/upgrade any Supabase project automatically.

## Route and role matrix

| Workspace | Route | Guest | Admin | Moderator |
| --- | --- | --- | --- | --- |
| Overview | `/` | Redirect to `/login` | Allowed | Allowed |
| Social | `/social` | Redirect | Allowed | Allowed |
| Social | `/users` | Redirect | Allowed | Allowed |
| Social | `/moderation` | Redirect | Allowed | Allowed |
| Social | `/reports` | Redirect | Allowed | Allowed |
| Social | `/announcements` | Redirect | Allowed | Allowed (subject to server RPC) |
| Food | `/food` | Redirect | Allowed | Allowed (server RPC-scoped) |
| Food | `/food/orders` | Redirect | Allowed | Denied sensitive details |
| Food | `/food/campaigns` | Redirect | Allowed | View-only (RPC enforced) |
| Food | `/food/coupons` | Redirect | Allowed | View-only (RPC enforced) |
| Food | `/food/notifications` | Redirect | Allowed | View-only (RPC enforced) |
| Food | `/food/ads` | Redirect | Allowed | Denied financial details |
| Food | `/food/places` | Redirect | Allowed | Check database-granted role |
| Merchant | `/merchants` | Redirect | Allowed | Verify actual role scope |
| Central | `/audit-log` | Redirect | Allowed | Allowed (RPC/RLS scoped) |

Other deep links to check after authenticating: `/users/[id]`,
`/moderation/[id]`, `/reports/[id]`, `/food/orders/[id]`, and
`/food/stores/[id]`. Verify non-existent IDs fail without exposing any
other person's data. Only Admin may see customer payment/contact details.

## UI acceptance checklist: laptop, iPad and phone

- [ ] At 1440px, 1024px, 768px, 390px and 320px: no unwanted page-wide
      horizontal scrolling; text, labels, forms and dialog actions stay visible
- [ ] Single Workspace selector at top; desktop sidebar and mobile bottom
      navigation contain **only the selected Workspace's** menu items
- [ ] Every route has exactly one `aria-current="page"` link; long menu
      labels and active location remain visible after changing Workspace
- [ ] Mobile bottom navigation honors safe area and does not cover content;
      scroll position resets when switching Workspace
- [ ] Login: invalid credentials, missing/denied profile and schema/network
      failure yield distinct safe feedback; never display secrets
- [ ] Empty, loading, failed-fetch and retry states are legible on each page
- [ ] Filter buttons, Search and Back links work and retain/clear parameters
      correctly; no false success from a write RPC
- [ ] Keyboard focus and screen-reader labels work on dropdowns,
      navigation, forms and dialogs; role labels remain clear
- [ ] Social dashboard retains existing metrics behavior; Overview does not
      mislabel Social-only metrics as cross-platform totals
- [ ] Sign-out invalidates session; guest and ordinary User cannot load
      privileged routes or invoke privileged RPCs

## What CI can and cannot prove now

CI: `npm run lint`, `npm run test:workspaces`, TypeScript, offline
`next build`, an anonymous **22-route** redirect smoke, plus the existing
Flutter/Edge/PostgreSQL checks. This checks code and guest routing; it is
**not** evidence of real signed-in QA or Production health. The backend,
auth-provider and responsive viewport checks above require an isolated local Supabase Auth stack or available no-cost staging. Hosted Preview and DNS still need separate verification.

## Security PR #1051 — intentionally separate

PR #1051 hardens the Food promotion scheduler and several staff-only
database views. It includes isolated PostgreSQL role regression tests and
a rollback SQL file, but has **not** been deployed. Do not combine its
migration with Workspace UI rollout or enable marketing cron automatically.
Evaluate its `SECURITY DEFINER` function permissions, staff role semantics,
exposed views and rollback behavior in an isolated test database before any
Production change. No checkout, order, payment, campaign, Stripe or Merchant
schema change is authorized by this QA plan.

## Admin-only rollout / rollback

- Record exact approved PR head, CI run, reviewer approvals and currently
  serving Admin Production deployment ID before proceeding
- Deploy only to the existing Vercel Admin project
  `prj_Ca3SJBvzn0K4w8t0bwQn13EDbVh5`, never create a second project
  to bypass the Hobby quota
- Prefer a staged Production build without alias reassignment, smoke test
  that exact artifact, then promote only after the final gate
- Verify login and workspace switching with real authorized operator
  sessions, plus Vercel runtime errors, after promotion
- If failing, restore previous known-good Admin deployment/alias according
  to the Vercel rollback procedure; do not touch Food/Merchant applications
  or shared database as part of an Admin UI rollback
