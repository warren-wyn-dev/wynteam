# WYNOS Admin Central Control — whole-platform master specification

Status: **Founder direction / implementation backlog; not a claim of deployed functionality**.
Date: 2026-10-10. Target: existing `admin` Next.js/Vercel project, intended custom domain `admin.wynos.online`.
Web-first: use common backend/API contracts; Social `wynos.online`, Food `food.wynos.online`, Merchant `merchant.wynos.online`, Maps `maps.wynos.online`.

## 1. Product outcome

A signed-in, authorized WYNOS operator should be able to discover, inspect, configure, moderate, and—where explicitly permitted—perform business operations for **every supported WYNOS service from Admin**. The dashboard must not pretend all capabilities exist today. Every business-changing action needs a supported backend operation, scoped authorization, validation, audit trail, failure handling, and tested rollback or compensation.

**"Control everything" is functional coverage, not unrestricted staff privilege:** do not expose user passwords, authentication tokens, API keys, raw payment credentials, unrelated private messages, or sensitive financial details to broad staff roles. Never bypass RLS by putting service-role credentials in a browser. No silent impersonation, backdoor account access, wholesale deletes, undocumented fund movement, or arbitrary SQL execution from an Admin UI.

This document is a **release contract**, not an instruction to auto-enable risky features. Existing admin/moderator permissions stay unchanged until separate security review and migration.

## 2. Service/workspace inventory

| Workspace | Operator view and actions required | Current basis / important gaps |
| --- | --- | --- |
| Global Overview | Cross-service status, work queue, alerts, bounded metrics with source+timestamp, drilldowns and incident states | PR #1053 workspace UI; #1055 Action Center, #1058 System Health, #1061 Analytics draft; no fabricated totals |
| Social | Search/manage accounts and roles, reports, moderation decisions, posts/replies/clubs, visibility/suspensions, account appeals, Verified grants/revocations with reasons, official notices, abuse controls | Existing users/moderation/reports/announcements routes; many detailed actions need reviewed RPCs/QA |
| Food | Store approvals and publication, menu/order oversight, refund/dispute workflows, delivery/service areas, store suspension, coupons, promos, first-order offers, Food push/in-app campaigns, advertising, order troubleshooting, audit of price/fees | Existing Food routes; prohibit silent order/payment writes. First-order 100/40 stays disabled until deliberate Admin activation and merchant re-consent |
| Merchant | Applications, approval/rejection, merchant business identity, per-store team and access, menu categories/items/options, uploads/media states, store compliance and operations, orders and payouts; support without impersonation | Existing application review; does **not** yet provide full store administration |
| Maps | Places registry, edit suggestions, duplicates, photos, classification, coordinate corrections, place ownership, reports, moderation, map sources/tiles/routing provider status and quotas, protected service coverage | Food Places does not equal a Maps Admin backend. No new write route until dedicated scoped APIs |
| WYNOS Account | Single account directory with per-service evidence and account IDs, service access scopes, login/session and security state, account restrictions, verified identity workflow, consent/privacy requests, safe account merges and deletion lifecycle | PR #1063 read-only evidence panel (OFF by default) is **not** SSO. Implement true cross-service SSO separately |
| Payments & Finance | Stripe payment status/webhook diagnostics, settlement/reconciliation, merchant disbursement, fee and commission schedules, tax/ledger exports, refund authorization, refunds/chargebacks, financial anomalies | PR #1028 large draft + #1040 webhook safety; **no automatic paid operations**. Two-person approval for exceptional money-moving actions |
| Notifications | In-app and Web Push templates, rules, audiences, quiet hours, delivery status, throttling, subscription health, broadcast approvals, user choices, official messages | **No email notifications**, per WYNOS product scope. Admin Notifications #1060 is preview/read-only, not a delivery system |
| Support, Safety & Policy | Ticket/dispute queues, content/merchant appeals, cross-service incident cases, identity redaction, evidence retention, anti-fraud flags, role-scoped activity history, case resolution | Extend existing reports/audit logs only via approved data access |
| Platform & Engineering | Product flags, rollout percentage, content policy settings, maintenance banners/mode, public configuration, feature availability per Web/Android/iOS, rate limits, app health, errors, queues/cron, API quota, tracing, job retry/disable | Never allow arbitrary environment-secret read/edit or unreviewed deployments from generic staff screens. Controls must have safe bounded APIs |
| Staff & Audit | Staff invitation and role assignments, permission matrix, MFA posture, approvals, immutable audit trail, sensitive exports, audit search, incident emergency access | Existing `admin`/`moderator` roles. Future higher tier must be separately approved and verified; #1051 and #1059 are security drafts |

### Interaction completeness for every screen

A complete operator experience includes list/search/filter/sort, detail, valid actions, confirmation with consequences, actor reason, permission error, loading/empty/error states, mobile responsiveness, keyboard/screen reader access, localized Thai/English, retry where safe, event/status history and support/rollback information. An attractive tile without a real API is not feature-complete.

## 3. Permission and action policy

**Current production roles:** `admin` and `moderator`. The label `Super Admin` may be designed for a future phase, but is not an existing elevated grant. Add a future role only through separately reviewed schema, RLS/RPC and migration with automated authorization tests. Do not equate visibility of a menu with permission to execute its action.

Classify actions by severity:

1. **Read:** permission-filtered scoped summaries and details; minimize personally identifying information, purpose-limit exports.
2. **Routine write:** review report, approve merchant application, publish official announcement, etc. Require server authorization, validated target state, bounded reason, idempotency, append-only audit record.
3. **High impact:** ban/unban, changing public visibility, changing staff access, cross-service account restriction, platform-wide flag, bulk messaging. Require explicit reason, reauthentication/MFA for appropriate operations, protected confirmation and audit.
4. **Financial/irreversible:** refund, settlement payout, fee/commission change, sensitive export, permanent deletion/retention exception. Require distinct elevated permission, two-person approval where appropriate, limit, anti-replay/idempotency, external-provider reconciliation and compensation plan. "Approval" must be checked on the server.

Base authorization on **actor + action + resource + scope + state**, not just `platform_role`. Validate owner/store/tenant/service binding. Return no sensitive fields to a Moderator if not required for their task. Rate-limit staff operations and exports.

## 4. Admin command/API contract

Do not make each screen write directly to arbitrary tables. Use auditable server endpoints/RPCs per domain. Recommended operation contract:

- `action_key`, immutable `request_id`/idempotency key, `target_type` + `target_id`, `expected_version`/optimistic concurrency token, explicit input schema, normalized reason, optional approved case ID.
- Server obtains the authenticated operator identity independently of any browser claims, authorizes that exact operation+scope, validates state transitions, and commits atomically where possible.
- Append action attempt/result to an **audited, minimally exposed history** with actor, scope, reason, timestamps, before/after field allowlist (redacted), correlation ID, outcome, provider reference, approval metadata and rollback/compensation state.
- Avoid log values that expose passwords, sessions, bearer tokens, full addresses/phones/payment slips. Define retention/access rules.
- Use dual-write/outbox event patterns for side effects; reconcile Stripe/provider callbacks. No "success" UI before the backend confirms durable success.
- UI receives normalized `success|pending_approval|denied|stale|failed` states with accessible, actionable error copy. Network retries must not duplicate orders, refunds, pushes or approvals.
- Feature flags default OFF for new write paths, have named operator/reviewer, audit change, stage rollout and kill switch.

**Data access design:** preserve a shared Supabase Auth user ID for all services, but **do not claim complete SSO** until cross-subdomain session/callback, scopes, revocation and privacy tests exist. Avoid copying sensitive customer data into Admin local storage.

## 5. Security, operations, availability

- Test anonymous, regular user, moderator, admin, revoked admin, unexpected role, stale session, direct RPC access and cross-tenant writes in isolated PostgreSQL and browser QA.
- Verify real signed-in Admin and Moderator sessions on **isolated** staging. Production and Stripe Sandbox are not substitutes. Staging presently blocked by the two-active-project Supabase Free limit; do not pause either without explicit Founder approval.
- Require current head lint, TypeScript, unit, permissions, Next.js build, guest protection, responsive mobile/browser and integration tests. GitHub CI green is **not** equal to integrated authenticated staging QA.
- Separate Admin Vercel project and `admin.wynos.online` verified DNS/domain attachment; configure intended rootDirectory, protected Preview and health/smoke routes. Record exact deployment SHAs, approval, flags and rollback.
- Do not import QA-only integration branch #1062 into Production. Review individually: #1053 workspaces, #1051 staff/security, #1055-#1061 operational slices, #1063 account evidence, #1028 finance, #1040 webhook hardening.
- Audit and observe every high-impact operation; alerts for spike/failure, customer-impacting rollback and access-review schedules.
- Platform Web may ship ahead of Android/iOS. Admin should show per-platform release/flag scopes, not assume features are 1:1.
- Product scope excludes check-in features and **email notifications** unless Founder separately changes product requirements.

## 6. Phase-by-phase implementation contracts

**Phase 1 — Workspaces and trustworthy inventory** (PR #1053, current draft):
Authenticated landing page, existing Social/Food/Merchant tools regrouped without duplicating routes, shared audit access, pending Maps and Account cards explicitly noninteractive, responsive role-based menu, login/preflight and CI. Add full coverage inventory/backlog in this document. **No new privileges or money movement.**

**Phase 2 — Core Operations:**
Action Center, enhanced Audit Log, scoped Global Search, live read-only Health and Analytics, staff notifications preview; then review/action APIs for missing Social/Food/Merchant operations with reason/confirmation/audit and reversible moderation. Compose **individual reviewed PRs**, not QA branch #1062.

**Phase 3 — Maps and Account:**
Verified Places moderation with RLS, provenance, duplicate resolution and reversible edits; central user identity evidence; service-level entitlements; separately design/test real single sign-on and account privacy lifecycle. Read-only evidence first, write actions later.

**Phase 4 — Finance, Settlement, Merchant:**
Webhook/idempotency and order/payment reconciliation, ledger/fees, case-based refunds with approvals and Stripe test-mode validations, merchant store/team/menu oversight. New finance/rider/pricing feature flags OFF by default until separately approved.

**Phase 5 — Platform & Security Operations:**
Staff permissions/MFA, protected configuration changes, push delivery management, observability/incident center, maintenance controls and granular platform releases. Limit operational blast radius, instrument audit + rollback.

**Phase 6 — Whole-platform acceptance:**
For each capability, mark exact state `planned -> backend ready -> UI ready -> isolated QA -> approved -> production verified`, link code owner/PR, API, role matrix, tests, feature flag, deployment and incident/runbook. Do not consider "every detail" complete while a route merely renders.

## 7. Acceptance gates

- [ ] All major services have an owner, source of truth, audited capability backlog and honest UI status.
- [ ] No staff/anonymous user can access a protected action directly without the relevant permission.
- [ ] No privileged customer/merchant/payment fields leak through read RPCs, exports, errors or logs.
- [ ] Each high-impact mutation is server-authorized, reasoned, idempotent and auditable.
- [ ] Payments/refunds have provider reconciliation and approval gates; negative/duplicate/replayed tests pass.
- [ ] Flagged or unavailable services show truthful "not enabled" state—not fake success.
- [ ] Authenticated Admin, Moderator, regular user and revoked-role browser flows tested on isolated staging.
- [ ] Mobile UI at 320/390/768/1440px, Thai/English and accessibility reviewed.
- [ ] `admin.wynos.online` domain is attached, protected and production smoke-tested independently.
- [ ] Launch, audit, alerting and rollback are documented with exact Production deployment artifacts.

**Change control:** this specification authorizes planning/development of separate draft branches only; it does not approve applying production migrations, enabling promotions/payments, editing domains, granting staff roles, or releasing drafts.
