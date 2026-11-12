# Merchant Flutter performance implementation

Status: implementation complete; final browser/build and staged release verification in progress. No production alias has moved.

## Scope and authority

The Founder authorized all diagnosed fixes and production release in the 2026-10-27/28 session, retaining Flutter. See `.wyn/company/APPROVALS.md`, Merchant Flutter performance improvements. Work starts from the exact live release `93e6954563b2dcd1108e4157772231262b201b63`, not all of current main.

Acceptance criteria:

1. Authorized menu/orders/store controls become usable without waiting for sales/quality/campaign summaries. Background order invalidations do not refetch every menu/report or disable all writes.
2. User store/status changes supersede old reads; no stale response, previous account/store cache, or revoked permission can publish into a new scope.
3. Expensive visited panels preserve their authorized data and local selections while switching tabs; refresh when stale or explicitly invalidated. Hidden tabs do not poll.
4. Large menu lists create visible rows lazily. Small menu photos use the existing scoped public optimizer, preserve original stored paths and fall back to originals on image errors.
5. Guests render the login form promptly and do not download authenticated bridge functionality. Login redirects retain valid remembered destinations.
6. Flutter remains embedded with one engine and scoped add/remove views. Content-addressed app/engine/assets receive immutable caching; stable bootstrap/HTML and fixed compatibility paths revalidate.
7. Auth/session ownership, server RPC/RLS checks, private image handling, payment/order behavior and recovery route remain covered by regression tests.

## Implementation

- Controller publishes critical reads first, parallelizes secondary summaries, separates loading/refresh/mutation state, coalesces invalidations and scopes polling to orders/access. Initial store listing is no longer duplicated.
- UI retains only visited expensive panels in the current account/store/role scope, and lazily renders menu groups/rows. Loading summaries are represented as pending, not invented zero values.
- Bridge shares only concurrent in-flight read access checks; every later read rechecks, writes always obtain a fresh grant, and final active-session validation remains. Public menu thumbnails are restricted to this project's `food-public` object URLs; private/signed/external URLs never enter the public optimizer.
- Login uses an optimized small logo and renders while checking the existing session. Heavy authenticated bridge code is dynamically imported after the existing gate.
- Build output is content-addressed after compilation, including engine and assets. No fixed-name app or bootstrap URL is cached as immutable. Known fixed asset URLs rewrite to the current payload for older open wrappers.
- Flutter builds dual WebAssembly/JavaScript output. The pinned SDK selects Skwasm on supported Chromium and retains CanvasKit/JavaScript fallback on unsupported browsers. Single-thread Skwasm avoids changing shared-origin isolation/auth behavior.
- The tool atlas is encoded as lossless WebP: 1,017,506 → 652,796 bytes. Dimensions, alpha and composited pixels on white/black are identical; the PNG source remains tracked but is not bundled.

## Verification and limitations

Original production baseline in an isolated worktree: Flutter analyze, 55 Flutter tests, TypeScript and 77 Merchant Node tests passed. Final integrated Flutter analyze/build and 83 tests passed. Merchant Node 95 tests, other required Node scripts 335 tests, TypeScript and ESLint passed (17 existing warnings, no errors). Final compiled Flutter payload: `5ae1c3707eb1885592ed`. Final browser QA passed 26/26 in a clean 1.9-minute run on both mobile and desktop Chromium: actual Skwasm and forced CanvasKit fallback, order/payment/delivery/pickup, pending-summary responsiveness, panel reuse, store/access eviction and account exit. Next production build passed using the same generated Flutter payload and synthetic public configuration. Staged release verification remains pending.

A controlled synthetic baseline experiment used the same source, Brotli settings, 4× CPU throttling, 1.6 Mbps and 150 ms latency: Wasm 16.45 s vs CanvasKit 22.17 s to usable content in one sample; compressed app+engine was about 11% smaller. This is experiment evidence for renderer choice, not a real-user production speed guarantee.

All authenticated regression data are synthetic fixtures. No real customer transaction, bank transfer, live private image or database mutation is used. API/SQL latency for a real signed-in store and physical-device behavior remain unmeasured; do not claim a guaranteed speedup percentage.

## Scoped release and recovery

Project `web` (`prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`), team `warren14` (`team_Kamt1PUT5XKn9MWrF404re1w`). A normal project promotion would also move other domains. The dedicated workflow stages production with `--skip-domain` and never assigns aliases. After verified staging, assign only `merchant.wynos.online`; snapshot non-Merchant mappings before/after.

Previous Merchant deployment: `dpl_2muRGSzQwa7qxcHjYAApkbxBbJuJ`, `web-3w118rjcs-warren14.vercel.app`. Keep this mapping available for an explicitly directed recovery. Do not automatically roll back or alter unrelated aliases.

Release SHA, staged URL, browser results, cache/header checks, production smoke and error scan: pending.
