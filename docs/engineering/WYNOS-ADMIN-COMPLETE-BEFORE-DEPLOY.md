# WYNOS Admin — Finish All Work Before Coordinated Production Release

Date: 2026-10-13 · Owner intent: **complete the agreed Admin/Food/Merchant capabilities and QA first; release once as a coordinated event, not feature-by-feature**.

## Release freeze

- **No Production deployment or promotion** for Admin, Consumer Web/Food, Merchant or Maps until the acceptance matrix below is green and approved.
- The WYN-158 Consumer Web production workflow was changed to `workflow_dispatch` only by PR #1141. All normal GitHub PR CI and browser regression remain enabled. Admin deployment workflows were already manual-only.
- Previously queued actions cannot be canceled solely by changing workflow YAML. Audit any pre-existing runs and check Vercel domain aliases before the final release.
- The previously scheduled automation that attempted a next-day release was disabled by request.
- Do not apply **further Production Supabase migrations** during this freeze. Prior migrations (delivery, menu editor, banners, featured stores, reviews, and store operational controls) were already applied before this freeze; no records were changed automatically.
- A coordinated release necessarily consists of **at least two scoped Vercel project deployments** (Admin project `prj_Ca3SJBvzn0K4w8t0bwQn13EDbVh5` and Consumer Web project `prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`), executed in **one gated release window**, not one Vercel API operation.
- Current Vercel Free deployment cap: `api-deployments-free-per-day` (100 requests/rolling day as reported by GitHub Actions release run #38377259203). Avoid repeated builds. Do not bypass by creating a new project or team.

## Existing foundations — not sufficient for acceptance by themselves

| Capability | Reviewed repository/backend | Production QA |
|---|---|---|
| Admin control inventory and existing Admin pages | Implemented in `admin/` | Production link exists; item-level business behaviour varies |
| Merchant delivery fee / radius settings | Admin RPC and editor, SQL tests | Admin page exists; authenticated save not yet smoke-tested |
| Merchant existing menu editing | Admin RPC and editor, SQL tests | Admin page exists; full merchant menu CRUD and options not done |
| Food campaign live terms 100/40 | Admin reads actual DB campaign | Test checkout and merchant funding allocation |
| Food home banners | DB RPC/storage + Admin and Web UI merged | Admin/Web Production deployment pending |
| Food featured stores | DB RPC + Admin and Web UI merged | Admin/Web Production deployment pending |
| Food review moderation | DB RPC and Admin page merged | Admin Production deployment pending |
| Merchant open/close / temporary close / prep time | DB RPC and Admin page merged | Admin Production deployment pending |

**Do not call the entire project complete based on existing links or successful CI alone.**

## Scope to finish in the same release candidate

### Food — Customer-facing and operations
- [ ] Home page controls: published stores, feature ordering, banner image/schedule/link, categories, search filters, language policy, disabled/closed states. Include guest and authenticated UI, mobile QA, analytics/impression/click attribution.
- [ ] Orders: full timeline, item/option snapshots, receipt/slip, status transitions, cancelled orders, idempotency, retry and stale updates.
- [ ] Customer permissions/support: scoped customer access with PII redaction, case intake, conversation, status, evidence, compensation and appeals.
- [ ] Payment/refund/dispute: Stripe customer charge lifecycle, merchant direct-charge configuration, PromptPay slips, webhooks, refunds and disputes with strict authorisation and bank/Stripe reconciliation. No administrator-initiated money move without dual approval.
- [ ] Promotions/fees: first-order food subtotal ≥฿100/฿40 off once, merchant funds discount; small-order fee ฿15 on pre-discount food subtotal under ฿60; stacking rules, campaign scheduling, audit, budget limits and checkout snapshot.
- [ ] Notifications: in-app/Web Push/realtime, scheduling and quiet hours, anti-spam and per-user opt-out. **No email notifications**.
- [ ] Trust & reliability: review/report moderation, merchant incident escalation, fraud signal triage, stuck order investigation, geographical outages, reversible emergency stop.

### Merchant — Store controls
- [ ] Store enrollment/verification including documents, ownership, staffing and multi-branch isolation; per-role access checks.
- [ ] Menu CRUD, category reordering, add-on groups/options (size, spice, toppings), images with preview/progress/failure/removal, availability and stock concurrency.
- [ ] Order acceptance, preparation, dispatch, pickup and handover, with store-defined working hours/holidays, self-delivery first and Rider future compatible.
- [ ] Merchant-specific GP/commission, campaign participation, coupons, ads, settlements, payouts, connected accounts and financial reporting as **children of Merchant**, separated from customer payment/refund logic.
- [ ] Delivery self-service: delivery zones, radius, accurate road distance where required, fixed rate / per-km pricing and test quotes; ability to copy/print delivery information appropriately.
- [ ] Emergency store pause, audit trail, post-incident recovery and notification.

### Shared Admin / Platform / AI
- [ ] Unified RBAC and SSO, superadmin restrictions, least privilege, 2FA review, audit immutability, data export controls.
- [ ] Rule inheritance (platform → region → store → item), effective dates, dry-run/preview, history, change approvals and rollback.
- [ ] Reconciliation dashboards for orders, charges, refunds, discounts, GP, settlement/payout and suspicious/stuck operations.
- [ ] AI Secretary: read-only analysis first; tool allowlist, tenant isolation and explicit human approval before any privileged mutation or financial action.
- [ ] Maps integration and place moderation, permissions and connectivity on shared APIs without replacing current map UI or data.

## Safety and correctness invariants (release blockers)

1. **Production unchanged while building:** feature branches and CI only; no live store updates, financial changes, DB migrations or Vercel promotions.
2. **Stripe/financial workflows:** webhook signatures, replay resistance, idempotency keys, immutable order snapshots, refunds ≤ captured amounts, currency, merchant funding and ledger reconciliation; test sandboxes first.
3. **Authorization:** every read and write checks role and tenant ownership in DB; no browser service-role key; PII minimization; RLS and anon-execute grants tested.
4. **Food checkout:** price, delivery, discounts and fees are calculated on the server from identical policies shown in Admin; test edge cases and stale menu/fee updates.
5. **Rider is not yet operating:** current merchant self-delivery remains the default. Future Rider customer pricing: first 2 km ฿10, above 2 km +฿0.50 per started 100 m and final price rounded up to full baht; do not invent rider compensation.
6. **No silent state changes:** importing/schema migrations create new structures and preserve actual stores/orders/users unless explicitly approved in a separately tested data migration.
7. **Rollback:** executable forward/rollback plans, data preservation, safe sequence for API + DB + web rollback, documented cutover owner.

## Definition of complete for every backlog item

- [ ] Designed API contract and tenant/permission model, rollback/migration plan.
- [ ] Backend + Admin UX + Food/Merchant consumer experience wired to **the same real data and business rules**.
- [ ] Server-side validation, abuse control, audit, concurrence/idempotence and role/PII tests.
- [ ] CI: lint, TypeScript, real PostgreSQL RLS tests, Web/Flutter regression and mobile/browser QA.
- [ ] Staging authenticated E2E smoke using test accounts; include error/denied/retry tests.
- [ ] Peer review, security/performance review, user-acceptance walkthrough and sign-off.
- [ ] Included in the pinned **final release manifest** with version and verified rollback.

## Coordinated final release gate (not authorized to run until all boxes pass)

1. Declare a release-candidate commit; freeze feature merges that affect Admin, Food and Merchant.
2. Verify migrations against a nonproduction clone or representative sanitized DB; back up Production before migrations.
3. Verify all CI/QA, security scan and browser smoke. Explicitly review Supabase security advisors.
4. Confirm Vercel Free quota reset or a suitable plan and protected production reviewer approvals.
5. Stage separate scoped **Admin** and **Web** production builds without assigning domains, from the *same approved release SHA*. Validate preview/staged logins, Food guest/auth, Merchant, read-only finance endpoints and source versions.
6. Apply coordinated approved Production migrations once and verify idempotently.
7. Promote both staged READY builds in one controlled maintenance/release window; verify `admin.wynos.online`, `food.wynos.online`, `merchant.wynos.online`, `wynos.online`, `maps.wynos.online` and relevant API health.
8. Validate orders, payments, delivery and permissions using non-financial canary checks / safe synthetic transactions. Keep rollback artifacts available.
9. Mark each feature completed only after domain+session+DB proof; otherwise rollback affected release and keep issue open.

## Tracking

Parent epic: https://github.com/warren-wyn-dev/wynteam/issues/1126

Current code freeze: https://github.com/warren-wyn-dev/wynteam/pull/1141

Vercel daily-quota failure: https://github.com/warren-wyn-dev/wynteam/actions/runs/38377259203

All new tickets link to the parent epic and are completed only when the acceptance definition above has been met.
