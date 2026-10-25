# Final ZOKY Merchant home — 2026-10-24

The Founder approved publishing the final pink Merchant design. Implementation: `82b18ee9`; compiled browser assertion correction: `c6786dda`. Production authorization is recorded in `.wyn/company/APPROVALS.md`.

The authenticated home contains the selected shop name and same-row notification bell, actual status/hours in an editable pill, pink sales with grouped digits and a smaller fractional amount on the same baseline, eight pink 3D tool shortcuts, and actual readiness progress. No lower shop-quality card or decorative sales dash remains. Quality opens a separate page with existing all-review aggregates and the real feedback destination; no weekly metric is invented. Finance, ads and campaigns retain role checks. Help and notification settings reuse their existing legacy pages through the strict store/tool link parser. Existing order, payment and notification deep-link precedence is preserved.

The eight generated decorative icons share a single transparent 4×2 PNG atlas. Flutter crops its cells without modifying the original image; accessible button labels remain text. The official ZOKY logo stays on login, with no company logo in the authenticated header.

## Verification

- `npm run check`: PASS — 374 Node test executions, 27 Flutter tests, analysis, ESLint, TypeScript, Flutter release build, system-font guard and Next production build.
- Following the independent review's removal of a noninteractive quality-card chevron, the Flutter analysis/tests/release build and font guard passed again.
- Compiled Flutter plus shared-auth wrapper browser suite: 10/10 PASS on Chromium mobile and desktop. Includes signed-out return, removable/token-free bridge, bundle recovery, slip/manual receipt checks, preparation ETA, mandatory delivery photo and complete status readback, all-review quality navigation, menu and More.
- Existing 320px/200% text and large-sales widget regressions passed. Release-freeze guard passed. Independent UI review found no remaining blocker.

The first compiled run exposed exact-text assertions incompatible with Flutter's grouped text semantics on the quality page. Only test matchers changed; the complete rerun passed. No live customers, database, payment service or production credentials were used in these tests.

## Compiled screenshots (synthetic fixtures)

- [Mobile home](final-home/mobile-dashboard.png), [mobile quality](final-home/mobile-quality.png)
- [Desktop home](final-home/desktop-dashboard.png), [desktop quality](final-home/desktop-quality.png)

These are actual Flutter captures, not mockups. The source branch is not the production artifact: release preparation isolates Merchant changes onto the live `web` project base `e6f577dcccb86b51c68d91e754b19fe4cfa27222`, preserving later Food fixes. Production staging, protected review and promotion are recorded separately; passing local tests does not claim a live rollout.
