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

## Pre-release account-exit follow-up — 2026-10-25

GitHub review found that removing header actions also hid the only sign-out action when no store was accessible. Source fix `9a53e008` (candidate cherry-pick `57f63d91`) keeps a sign-out button outside store-dependent content. It reuses the existing shared-auth sign-out, pending-operation guard and failure recovery. The approved normal-store design is unchanged.

Flutter analysis, all 30 widget/controller/repository tests, the release compilation and system-font guard passed. Three added widget regressions exercise empty stores, failed store loading and final-store access revocation, and verify that the actual sign-out callback remains callable. The compiled mobile/desktop suite passed 16/16: the original ten core cases plus six account-exit cases, including refresh-triggered revocation and the actual Dart-to-host `signOut` request. Independent review found no CRITICAL/HIGH issue.

Only synthetic fixtures were used. Existing JavaScript/backend source is unchanged by this follow-up; the previously recorded full web checks remain baseline evidence and the protected release workflow reruns the full candidate checks before staging. The earlier release run `40097479381` was cancelled before staging or production action. Live metadata was rechecked on 2026-10-25 and still identified the original `e6f577dc` / `dpl_HhzmnfVpb9qyHd7yeiAiiUmkbPV9` deployment.

The next protected run, `40169014948`, stopped at TypeScript verification before staging: the new browser fixture asserted required custom properties on `Window`. Source fix `32e8da4b` (candidate `ba81ce4a`) makes those asserted fields optional, without changing emitted JavaScript or the strict sign-out assertions. Independent review found no blocker. The complete `npm run check` then passed on this actual production-based candidate: ESLint, TypeScript, all 390 Node executions, Flutter analysis and 30 tests, release compilation, font guard and Next.js production build. The already-passing 16 compiled browser cases remain applicable because this correction only changes erased TypeScript annotations. No staging artifact or production change is claimed by this record.
