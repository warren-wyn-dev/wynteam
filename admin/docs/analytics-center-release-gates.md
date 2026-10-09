# WYNOS Admin — Phase 4 Analytics Center acceptance and release gates

**Status:** Draft initial implementation slice; code only, NOT released. Stacked on Workspace PR #1053. WYNOS Admin Production, Food, Merchant, Stripe and live data remain unchanged.

## First slice (delivered in feature PR)

- Authenticated **Admin-only** route `/analytics`. Both page and data loader check `requireAdminRole()` then reject non-Admin roles before any Finance/Merchant RPC executes. Sidebar and Overview link likewise filter to `admin`.
- Existing Social RPCs: `admin_dashboard_metrics()` for DAU/WAU/MAU, `admin_signup_counts()` for today/week/month/year signup counts, and `admin_dashboard_trends()` for 14-day DAU (only genuine supplied dates, no interpolation).
- Existing Food `admin_food_overview()`: today orders, active orders, total stores, today sales, and supplied daily-order counts for at most seven recent dates. Sales semantics follow the original Food dashboard ("delivered orders"); **no payment processing, refunds or order details**.
- Existing Merchant `admin_merchant_applications()`, max 200 records: server-only summary of rows returned (seen/pending/approved) after discarding applicant names, contacts, addresses and notes. This is a **sample of returned rows, NOT a certified platform total**. A full daily onboarding trend needs an approved dedicated aggregate RPC and is **not** fabricated.
- Each RPC is independent: if data are unavailable, section reports "unable to verify" and never shows fake zero. Strict nonnegative numeric and ISO-day validation rejects malformed, duplicate or missing data points. Zero is displayed only when actually returned.
- A compact, responsive, accessible bar visualization uses semantic numeric/date labels and no additional chart framework.
- No data export, PII drilldown, new database objects or writes, business mutation, Cron, extra infrastructure/spending or Deployment.

## Data contract and caveats

| Service / panel | Existing source | Display / meaning | Restrictions |
| --- | --- | --- | --- |
| Social active users | `admin_dashboard_metrics()` | DAU/WAU/MAU, RPC's rolling activity definitions | Not app-open events; don't sum DAU+WAU+MAU |
| Social signups | `admin_signup_counts()` | Today/week/month/year windows defined by the RPC | Overlapping periods; don't add together |
| Social DAU series | `admin_dashboard_trends()` | Supplied `dau_last_14d` counts by ISO date | Missing day stays missing |
| Food daily counts | `admin_food_overview()` | Orders today, active, stores and daily order counts | Source RPC date/time semantics must be QA-verified |
| Food sales | `admin_food_overview()` | `sales_today` in THB, source semantics | Admin only; not gross payment/settlement |
| Merchant applications | `admin_merchant_applications()` | Status counts **within up to 200 returned rows** | No total population assertion or trend |

**No fake blended "platform score"**: Cross-service numbers have different denominators and freshness times; charts compare values only within their own service. Every panel shows source and the time collection started (Asia/Bangkok display). The displayed time is **not** proof of a fresh complete backend snapshot.

## Before any Production release

1. Merge/release PR #1053 through its own security/staging gates first. Review this feature independently and retarget it to the resulting baseline; no merging it into #1053.
2. Verify each RPC and its response semantics in an **isolated approved Admin staging project**, with synthetic data, correct RLS roles and revoked staff accounts. Do not use Stripe Sandbox or the Production DB for preview QA.
3. E2E role matrix: guest/user -> login/denied; Moderator -> no Analytics nav or privileged RPC; Admin -> all approved source panels; direct `/analytics` access rejected for unauthorized sessions. Test network failures, malformed numbers/dates and >200 Merchant applications.
4. Validate exact metrics with known synthetic fixtures for Thai timezone edges (local midnight, DST not relevant in Bangkok, month/year boundaries), canceled vs delivered order classification, active order semantics, source lag and financial fields.
5. Confirm page behavior on phone (320/390px), iPad and desktop; keyboard navigation, focus, contrast, chart numeric accessibility, no horizontal overflow; no sensitive fields anywhere in rendered HTML/RSC/error logs.
6. Ensure source RPCs, particularly Merchant applicant data, are least-privilege and do not cause costly scans. Any efficient dedicated aggregate requires an approved **separate migration PR**, its own security test and rollback.
7. Admin tests, TypeScript, build, guest smoke and repository CI pass on exact reviewed SHA; obtain engineering/security approval; build isolated Preview, verify real Admin login; use existing Admin Vercel project only. Release plan and rollback must be approved before any Production change.

## Deferred beyond first slice

- Certified full Merchant onboarding totals/trend, new chart filters, downloadable exports, cross-period deltas, daily revenue financial definitions, aggregated cohorts across multiple products, and financial forecasts.
- No "0%" for an empty cohort; unknown remains unknown. Decisions on a canonical metric timezone, cutoff and cancellation/refund semantics need product/data sign-off.
- Do not invent artificial values or copy Production users/orders to staging.

## Rollout state

Feature remains in an unmerged Draft PR; no Deploy, DB mutation, Production integration, user-notification or external service changes. Authenticated UI, performance/RLS and data-contract checks remain blocked until safe staging exists.
