# Real Flutter Merchant home — 2026-10-24

Founder requested an implemented home screen using the supplied structure: selected store, status, sales, four shortcuts, readiness checklist and store-quality card. Implemented in the existing Flutter Merchant frontend, retaining the official ZOKY artwork and pink palette. Gray canvas/white cards; four shortcuts stay in one row on normal phone widths and wrap for narrow/large-text layouts. Existing Orders/Menu/More destinations remain available.

## Data and actions

- Store status uses existing business schedule/temporary closure helpers, with unpublished/suspended status taking precedence. Manual `is_open` stays separate. The status sheet reuses the existing permission-controlled store update and readback. No synthetic closing time.
- Sales and completed count reuse the existing server report, show waiting/error states, and open the existing Flutter report page. Long values scroll horizontally so 200% text is preserved.
- Finance/ads/campaigns open the corresponding existing Merchant tool, passing the currently selected store as a preference. A pure allowlist parser rejects invalid/duplicate queries and gives order notifications/payment returns precedence. The existing RLS-scoped snapshot resolves store access/fallback; URLs confer no permissions. Promotions use the implemented Flutter page.
- Four readiness checks mirror the existing Merchant checklist: store contact/hours/delivery area, receipt configuration, available menu, published state. These are presentation checks; the existing server publish validation remains authoritative. Rows navigate to the relevant existing settings/menu.
- Quality uses store-wide aggregates from the existing `merchant_store_reviews` RPC (only one review requested; individual review/customer details do not cross the bridge). Display all-time customer rating and unanswered reviews, not invented weekly acceptance percentages. Missing RPC, zero reviews, errors and invalid aggregates have separate outcomes. Quality errors clear stale values; store/access changes clear summaries.
- Clickable cards have explicit action semantics; readiness progress and horizontally scrollable sales retain their own accessible information.

## Verification

`npm run check` passed: 372 Node tests, Flutter analysis/26 tests, release Flutter and Next builds, font policy, lint and TypeScript. Final accessibility adjustments were reverified with Flutter analysis/26 tests/release compilation and dedicated Chromium browser QA 10/10 on mobile/desktop. The browser exercises manual/slip payment through delivery proof, reloads a fresh synthetic document for clean home captures and navigates the remaining pages. Focused Node suite55 includes bridge27 and tool-link15; tool-link regressions confirm inaccessible UUID preferences fall back to authorized stores and no-access snapshots do not query tables.

All queries/tests use mocks or synthetic fixtures, never customer data or live database writes. Preview uses the existing shared authenticated host; production routing/cutover and production schema remain unchanged. Open `/merchant/flutter` to use the new Flutter view; the auth gate remembers this return path. The legacy `/merchant` remains available.

Synthetic screenshots: [mobile home](real-home/mobile-dashboard.png), [mobile quality](real-home/mobile-quality.png), [desktop home](real-home/desktop-dashboard.png), [desktop quality](real-home/desktop-quality.png). These illustrate UI behavior; displayed test figures are not production metrics.
