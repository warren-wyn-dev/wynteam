# WYNOS Admin — usability and reliability review

Date: 2026-10-13. Baseline: `42a8f9373fe900ff1de14b18cf0bc6ad8ae8b1de`.
Local branch: `fix/admin-usability-reliability`.
Status: validated candidate for authorized commit/push/PR; not merged or deployed.
Founder authorization: 2026-10-13, explicit approval to commit, push and open a PR
for this reviewed patch. Merge, migration and production release are separate gates.

## Requested outcome and scope

The Founder asked whether WYNOS Admin works across all systems, with very fast,
stable operation, a logout button and easy design/categories. This change fixes
verified reliability and navigation issues in the existing app. It does not
claim to complete the broader acceptance matrix in
`docs/engineering/WYNOS-ADMIN-COMPLETE-BEFORE-DEPLOY.md`.

## Changes

- Reuse `requireAdminRole()`'s request-scoped access in the shared layout, Team,
  Maps and store map details. Remove redundant access RPCs while preserving the
  existing server and database authorization checks.
- Bound five Dashboard read RPCs to 10 seconds using Supabase's abort signal.
  Healthy sources retain their existing results and partial failures retain
  the error notice; missing data never becomes invented zeroes.
- Preserve Supabase SSR cache-protection headers and expired-session cookie
  removals when middleware redirects to login.
- Keep global logout behavior and show pending/error/retry states on a visible
  44-pixel button. If the SDK clears the browser session but global revocation
  fails, login explicitly explains that other devices could not be confirmed.
  Local session inspection selects feedback only; it never grants access.
- Keep the email input controlled so React form-action reset after invalid
  credentials does not erase the email required for the next login attempt.
- Search only permitted menu entries by Thai aliases, English labels and
  category names. Show category descriptions, grouped results and empty states;
  clear/Escape restore existing expansion preferences. Preserve routes, system
  ownership, permissions and disabled planned entries.
- Show the existing super-admin restriction for announcement/reminder audit
  histories instead of misleading non-super staff with an empty-history claim.
- Add dependency-free Node regression tests using synthetic fixtures, wire
  `npm test` into the existing Admin CI job, and update the Admin README.

## Public deployment evidence

Anonymous HTTPS only, no credentials or live data queries:

| Path | HTTP | Result |
| --- | --- | --- |
| `/login` | 200 | Login endpoint responds; TLS verifies |
| `/` | 307 | Redirects to `/login` |
| `/food` | 307 | Redirects to `/login` |
| `/merchant/finance` | 307 | Redirects to `/login` |
| `/maps/places` | 307 | Redirects to `/login` |

These checks establish public reachability and anonymous routing only.
Single-request timings are not a performance benchmark or load test.

## Verification

| Check | Result |
| --- | --- |
| `npm test` | PASS: 27/27 across navigation, logout/session, announcement access and Dashboard reads |
| `npm run lint` | PASS: zero errors; one existing unused variable warning in `food-banner-manager.tsx:56` |
| `npx next typegen && npx tsc --noEmit` | PASS |
| `npm run build` | PASS: final Next.js 16.3.2 optimized build, all Admin routes generated, synthetic environment only; login renders the qualified logout marker server-side |
| `git diff --check` | PASS |
| Browser against final `next start` and local synthetic Supabase | PASS: 14/14 scenarios, desktop 1440px and mobile 320/375/390px; no uncaught browser errors |
| Review patch application | Forward and reverse checks against baseline/current files pass |

Auth regressions also reproduced the original failed-signout redirect and lost
expired-session cookies/cache headers using baseline source before confirming
the fixed behavior. No new dependency or test framework was added to Admin.

Browser verification caught and fixed two additional UX issues: React form
actions reset uncontrolled email after invalid credentials, and Radix's capture
handler closed the mobile drawer before the search input could clear Escape.
It also confirmed the installed Auth SDK removes the local session on a remote
global sign-out error; the qualified login notice handles that actual behavior
without restoring cleared cookies or changing logout scope.

Browser checks include invalid credentials with retained email and password-only
retry; healthy Dashboard; one access RPC per full navigation; Thai/English menu
search without additional backend calls; clear, no-result, collapsed preferences
and disabled planned links; partial and 10-second stalled Dashboard sources;
mobile focus trap, Escape and no horizontal overflow; restricted histories with
no audit requests; failed global revocation with confirmed local cleanup and a
qualified notice; successful global logout, empty browser auth cookies and
protected-route redirect; and valid non-admin credentials denied entry.

Browser artifacts are captured separately in the execution workspace. A transient
heading wait during host contention was retested with scoped assertions on the
same final build. Intentional prefetch cancellation for isolated request counts
produced expected network console entries; no uncaught application exception was
observed. These are functional checks, not production latency measurements.

## Known completeness and verification limits

- Eight sidebar entries still have no page: Account Security, Customers,
  Payments & Refunds, Customer Support, Map Reports, AI Secretary, Platform
  Marketing and System Settings. Their existing "เร็วๆ นี้" state is preserved.
- Merchant menu CRUD/images/add-ons and other business capabilities remain
  incomplete in the coordinated acceptance matrix. Page/link availability alone
  does not prove those workflows are complete.
- Tests use synthetic users and data. No production secrets, customer records,
  environment files containing secrets, authenticated production session or
  live database were used. No database/schema, infrastructure, financial or
  production changes were made.
- Dashboard request timeouts bound stalled reads, not authentication or every
  Admin request. Production speed, capacity and stability need authenticated
  staging business-flow checks and representative-volume measurements.
- Local verification does not validate deployed Supabase RLS/RPC definitions,
  actual permissions, business writes, payment/refund flows or production
  rollout. The coordinated release freeze remains in force.

## Review and next gate

Independent review found the misleading-history issue (MEDIUM) and fixed its
UI without changing security policy. Final patch review covers navigation,
logout/session handling, request deduplication and bounded Dashboard reads; no
unresolved blocker was found for this local patch. Wider release blockers in the
coordinated acceptance matrix remain.

The Founder authorized commit/push/PR for this patch on 2026-10-13 under root
`AGENTS.md` / `docs/engineering/GIT_WORKFLOW.md`. Production needs separate
approval and the coordinated release acceptance gates. This patch can be
reverted independently after review; no data rollback is needed.
