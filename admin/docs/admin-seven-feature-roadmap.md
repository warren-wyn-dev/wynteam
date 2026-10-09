# WYNOS Admin — 7-Feature Phased Roadmap (planning only)

**Date:** 2026-10-09  
**Status:** Proposed for Founder / Product / CTO / Security review — **not approved for implementation or release**.  
**Scope:** WYNOS Admin only. This document is an independent planning artifact, based on current source and PR #1053. It introduces **no implementation, schema migration, deployment, secrets, feature flags, live actions or infrastructure spending**.

## 1. Why / product outcome

Transform WYNOS Admin into a simple, trustworthy multi-service control center that helps authorized staff find work, investigate events, discover records, detect service failures, secure their sessions and understand product trends.

UX baseline: premium, minimalist, responsive and mobile-friendly. Keep one Workspace selector at the top; the sidebar and mobile bottom navigation show **only the selected Workspace's items**. Cross-workspace utilities belong to the Overview or a clearly separated Central workspace, not an ever-growing combined sidebar.

**Non-goals:** replacing Social/Food/Merchant front ends, live order or payment mutations, new checkout logic, user-facing search changes, emails, automatic marketing, enabling Cron, changing role privileges, spending money, adding external monitoring vendors by default, or moving production databases. Existing behavior must be preserved.

## 2. Verified foundation and open dependencies

- PR #1053 (Workspace/navigation) is separate and not merged at time of planning. Its Admin role model is admin / moderator; it has service-scoped navigation, server-side Admin layout access control, and Admin-only Food orders and ads access.
- Existing reusable Admin sources include: user directory/search and profile methods, moderation queue / reports, merchant applications, Food overview/store/order RPCs, Social dashboard metrics, announcement history and the staff audit log.
- The existing staff audit log query reads the admin_audit_log view with an upper limit of 200 items; richer filtering and cursor pagination are a **proposal**, not functionality already present.
- PR #1051 concerns additional Admin security/database QA and a Food promotion scheduler safety change. It remains separate. Do not combine its migrations with new features.
- Supabase staging is inactive; Preview had pointed to the Stripe Sandbox with an incompatible profiles schema. Admin Browser QA with authenticated Admin/Moderator/User fixtures is still pending. Never repurpose Production or Stripe Sandbox as Admin staging.
- Build CI is useful but does not prove signed-in UI behavior. Feature development can start with deterministic offline fixtures, but a real release needs isolated staging and browser/security QA.

**Branch / PR policy:** This document lives in a docs-only draft PR based on main, **not** PR #1053. After approval, create a separate implementation branch and PR **per feature**, rebased on the then-current reviewed baseline. Keep all new user-visible features **disabled by default** until approved release gates. Do not modify or merge PR #1053 as part of this plan.

## 3. Delivery plan

| Phase | Feature(s) | Priority | First usable slice | Approx. complexity | Dependency |
| --- | --- | --- | --- | --- | --- |
| 0 — readiness | Shared contracts and security gates (no new UI feature) | P0 prerequisite | Source inventory, permissions, event definitions, accessibility patterns, staging strategy | Medium | Product / CTO / Security review, isolated QA |
| 1 — operations | **1. Action Center**, **6. Audit Log Plus** | P0 | Read-only pending-work links and real staff activity filters | Medium | PR #1053 workspaces, existing audited sources |
| 2 — discovery + reliability | **2. Global Search**, **3. System Health** | P1 | Role-scoped results; real observed health with timestamp and unknown state | Medium–High | Approved search contracts and trusted observability |
| 3 — staff safety + attention | **5. Admin Security Center**, **4. Admin Notifications** | P1 (security gating may escalate to P0) | Session/MFA enrollment plan and in-app alerts for permitted work | High | Auth/security approval, event origin and delivery guarantees |
| 4 — analysis | **7. Analytics Center** | P2 | Trustworthy per-service trend panels with metric definitions | Medium–High | Verified aggregations, metric governance |

These are relative phases, **not committed dates**. PR #1053 can be released independently once its own QA and approval gates pass. No need to wait for all seven features before releasing the Workspace refactor.

### Phase 0 — prerequisite design / gating

Deliverables: product requirements + acceptance cases, exact Admin/Moderator permission matrix (per record/field/action), existing query/RPC inventory, data retention and event contracts, accessibility and performance targets, rollout and rollback design, a test-data-only staging plan.

- Require genuine server-side permissions per search result, count, export, notifications and drill-down, not merely hidden menus.
- No service_role keys in a client bundle, no production data dumps into test environments, and no new permission grants as a side effect of UI work.
- If a new migration, integration, mandatory MFA policy or provider cost is required, stop at a design/approval gate before applying it.
- Clearly distinguish “not deployed”, “no data”, “cannot verify”, “loading” and “system unhealthy” everywhere.
- Base critical Admin authentication protections and access checks are release gates **now**; do not delay a necessary security fix until Phase 3.

**Exit:** approved scope and permissions, source-contract mapping, sample synthetic fixtures, high-risk tests, independent feature PRs agreed.

## 4. Feature definitions and acceptance

### 1. Action Center — Phase 1

**Goal:** Give staff one prioritized, read-only starting point for pending work across allowed WYNOS services.

**MVP:** Cards/rows linking to pending Social reports/moderation, Merchant applications, and Admin-only Food order/payment review. Show source, category, timestamp, status and appropriate deep link. Reuse audited Admin functions; counts must be real and permission-filtered. Server-fetch each source separately so a failed source does not erase healthy data.

**Permissions:** Admin sees authorized cross-service tasks. Moderator must not see order contacts, payment details or hidden Admin-only items, even in badge counts/HTML/RSC payloads. Never route unauthorized tasks to a view that leaks details.

**Explicitly out:** auto-approving merchants, settling payouts, refunding orders, triggering marketing, unreviewed bulk actions.

**Acceptance:** guest/user denied; Admin/Moderator queues differ correctly; no task duplicates by stable source ID; partial source failure shows “ตรวจสอบไม่ได้” plus last checked time, not zero; every link goes to an existing authorized route; empty/loading/error states work at 320px/390px/iPad/desktop.

**Candidate implementation PR:** Action Center read-only UI + source adapters + tests.

### 6. Audit Log Plus — Phase 1

**Goal:** Make existing staff history useful for investigating actions.

**MVP:** Filter by actor, event type, date range and service, searchable target ID and next-page cursor; clear/export functions are **not** included. Reuse admin_audit_log and existing server-side role restriction. Add indices or RPCs only after query-plan and approval review.

**Security:** Server-verified filters, bounded page size, explicit ordering, privacy redaction, no secrets, tokens, private notes or full PII in URLs/log output; “who did what/when” sourced from actual audited events. Define event-to-Workspace mapping instead of guessing from UI routes.

**Acceptance:** stable ordering across pagination with equal timestamps; filters compose, can be cleared and survive navigation; no events leak through direct URL/API to unauthorized roles; no new writes or changes to existing audit events.

**Candidate implementation PR:** Audit Log Plus read/query UI + filtering tests; any required backend migration split into separate reviewed PR.

### 2. Global Search — Phase 2

**Goal:** Search users, merchant applications/stores and orders from Admin, without exposing private data across roles.

**MVP:** Search palette available from Admin top header with separate categorized results, keyboard navigation and authorized deep links. Start with existing searchUsers, Admin merchant application data, Food stores/orders RPCs where approved. Request only bounded results from each category; implement debouncing, minimum query length and abuse/rate limits at trusted boundaries.

**Security:** Role/record/field checks at the server and database, not client filters. Moderator never receives order contacts/payment data or counts. Prevent enumeration, substring probing of sensitive phone/email by unprivileged staff, unsafe highlighting, HTML injection, cross-user privacy leaks and logs of raw sensitive queries. Never add a global service_role search endpoint.

**Acceptance:** correctly isolates categories, handles “no results/forbidden/partial failure”; safe keyboard focus and escape key; no sensitive fields in browser payload or server logs; bounded latency and query volume verified against realistic synthetic fixtures.

**Candidate implementation PR:** Search UI + scoped existing-source adapters + auth abuse tests; index additions reviewed separately if needed.

### 3. System Health — Phase 2

**Goal:** Report actual service health and recent failures without false “all green” claims.

**MVP:** Admin-only statuses for Social, Food, Merchant, Admin/API/database, each with source, last-checked timestamp and separate states Healthy / Degraded / Incident / Unknown. Render a concise incident timeline from trusted observability (if available), and operator links to existing logs.

**Security/architecture:** Trusted, allowlisted health sources only. No arbitrary URL probe/SSRF, credentials, production stack traces or private customer data in the browser. Health checks must be bounded, cached and resilient so the dashboard cannot overload Production. Health reporting is read-only; no Cron toggles or deployment controls.

**Acceptance:** a source timeout/stale sample becomes Unknown, never Healthy; correct timestamps and source labels; partial service outage does not blank the page; no alert storms; no invented uptime or metrics.

**Candidate implementation PR:** Trusted health adapter + read-only screen + fake-adapter failure tests.

### 5. Admin Security Center — Phase 3

**Goal:** Improve staff-account safety without adding unrestricted role administration.

**MVP proposal:** Security settings, supported Supabase MFA/TOTP enrollment/challenge and safe recovery guidance, current session information and recent security-significant events where the provider supplies auditable signals. Required MFA policy and session revocation behavior must first pass an explicit auth/security architecture review.

**Security:** Verify MFA server-side for privileged flows if policy requires; never trust a local UI flag. Reauthentication required for sensitive changes, safe recovery preventing lockout, CSRF/session fixation/replay checks, proper account ownership. Do not expose other operators' secrets, raw tokens, OTP seeds or private IP details. Avoid promising per-device session revoke unless supported by the provider.

**Acceptance:** guest/user blocked, account owner cannot elevate role, MFA state stays correct across session refresh, recovery and lost-device flows tested on isolated accounts, throttling/lockout handling tested, no change to Production auth architecture without approval.

**Candidate implementation PR:** Security Center UX and provider integration behind default-off feature flag; policy enforcement isolated and separately authorized.

### 4. Admin Notifications — Phase 3

**Goal:** Notify staff about work and incidents in the Admin experience only.

**MVP:** In-app unread/read state with role-scoped deep links for report queue changes, merchant applications, and verified system incidents. Deduplicate by event ID and recipient; honor role changes/revocations and do not render sensitive message bodies to the wrong user. New events should come from authoritative, idempotent source contracts.

**Channels:** In-App first. Optional Admin Web Push requires additional consent and separate approval. **No Email Notifications**.

**Acceptance:** exactly-once visible item for duplicate source delivery (idempotent), unread counts update correctly, mark-read authorized for self only, read state persists across tabs, role changes remove future and existing unauthorized items, privacy-safe messages and valid deep links. Specify TTL/retention policy before schema implementation.

**Candidate implementation PR:** Admin-only notification store + recipient/role tests; add realtime/subscription only after event contract and QA.

### 7. Analytics Center — Phase 4

**Goal:** Show coherent trends across services without pretending all numbers measure the same thing.

**MVP:** Distinct Social DAU/new users, Food orders and merchant onboarding counts with verified definitions, source, refresh time, trend window and currency/unit. Reuse audited dashboard sources (Social metrics and Food overview) where semantics match. Financial fields and order/customer details remain Admin-only.

**Data quality:** Define numerator/denominator, timezone (Asia/Bangkok if approved), cutoff, cancellation/refund semantics, aggregation lag, and “unavailable” behavior. Do not sum incomparable metrics into a fake global score. Prefer read-only authorized aggregation RPCs to client-side joins. Propose export only after privacy review.

**Acceptance:** synthetic fixture totals and edge dates match definitions, no negative/impossible fabricated figures, charts work on small screens, source errors do not produce zero, Moderator view excludes private finance, aggregation does not degrade core services.

**Candidate implementation PR:** Metrics contract + read-only charts + formula and permission tests.

## 5. Cross-feature UX and navigation design

- Preserve the #1053 **single Workspace selector in top header**. Service-specific navigation remains scoped to the selected Workspace.
- Suggested placement (requires UI approval): Overview = Action Center preview, health summary and links; Central = Audit Log Plus / Admin Notifications / Security Center; Global Search = header command palette; Analytics Center = Overview link or Central reporting, not copied into every service sidebar.
- Desktop: prominent content title, compact controls and consistent typography. Mobile: no page-wide horizontal scroll, minimum usable touch targets, bottom safe area, focus visibility, loading/empty/error states and permission-aware menu labels.
- In early builds use fixtures clearly labeled TEST DATA, never fake Production totals or misleading “Healthy” badges.

## 6. Shared engineering rules

1. **Read-first:** Action Center, Audit Log, Search, Health and Analytics start read-only; no side effect on viewing/refreshing.
2. **Deny by default:** both Next.js server boundary and Supabase RLS/RPC permissions are authoritative; Moderator cannot read Admin-only order, payment, customer contact or financial data, including aggregates and direct APIs.
3. **Data minimization:** no service-role key in browser, no production copy to staging, log redaction and retention policies; prefer existing tables/RPCs before new schema.
4. **Stable bounded queries:** limits, cursor pagination, safe indexes, deterministic ordering and timeout/error states to avoid expensive scans.
5. **Observability with provenance:** source + timestamp + unknown if stale; never confuse absent telemetry with healthy state.
6. **Accessibility and mobile:** keyboard/screen reader states, WCAG-oriented contrast, responsive 320px–1440px and reasonable performance budgets.
7. **Safe rollout:** individually gated feature flags default OFF; independent PRs, reviewed migrations, failure/rollback documented. Do not toggle operational Cron, payments or promo controls as a convenience.

## 7. Quality gates / Done definition — each implementation PR

- Product: one user story, explicit scope/out-of-scope, UX acceptance and role matrix approved.
- Technical: source APIs, schema/index/migration needs, degraded behavior, latency and owner identified.
- Security: guest, ordinary User, Admin, Moderator; direct route + RPC abuse cases; search/privacy enumeration; cross-tenant/record isolation; sensitive field/metric redaction.
- QA: lint/types/build and unit/integration/E2E with synthetic fixtures; failure/timeout/retry, mobile/desktop, accessibility and visual QA; no unresolved critical/high findings.
- Release: staging deployment of exact reviewed SHA, authenticated role-based browser QA, reviewer approval, Founder production approval, preflight, rollback readiness and production smoke/health evidence.
- Deliverable per feature: a standalone reviewed PR with screenshots if UI changed, test results, approval record and a short runbook. Passing CI is not the same as verified live behavior.

## 8. Dependencies / blockers and decisions needed

**Known block:** Supabase Free organization currently has two active projects (Production and Stripe Sandbox), while the intended staging project is inactive. Do not stop either active system, repoint Preview at Production/Sandbox, or purchase capacity without explicit Founder approval. Vercel Hobby deployment quota and Preview protection may prevent current authenticated browser checks. These block live staging QA and release but **not** design, offline tests or data-contract review.

**Decisions before implementation:**
- Final Admin/Moderator visibility, particularly Merchant applications, Food operations and financially sensitive analytics.
- Which queues and urgency classes belong in Action Center; authorized count sources.
- Acceptable search fields and incident health data source/integrations.
- MFA requirements, recovery process and which privileged actions need step-up verification.
- Notification event list, retention, rate limits and optional Push.
- Metric definitions and reporting cutoff/timezone.
- Staging resources/budget, only if pursuing online QA.

**Suggested next action:** Approve Phase 1 detailed requirements (Action Center and Audit Log Plus) and make one implementation PR per feature, using isolated offline fixtures while PR #1053 independently advances through its own release gate. There is no authorization in this roadmap to code, merge, deploy, create new infrastructure, alter schema or perform production actions.
