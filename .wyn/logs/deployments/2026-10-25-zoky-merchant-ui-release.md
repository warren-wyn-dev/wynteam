# ZOKY Merchant Flutter Web production release — 2026-10-25

## Authorization and result

The Founder requested the final Merchant design on the live website ("เอาขึ้นเว็บจริง", "ทำให้เสร็จ", "ทำต่อ") and completed both existing GitHub Production environment reviews. This is the approved Merchant frontend release within the existing Food system; no separate database or repository was created.

- Public entry: https://merchant.wynos.online/
- Workflow: https://github.com/warren-wyn-dev/wynteam/actions/runs/40205781151
- Trusted workflow/control commit: `86f414060be6d6d735611397779620c35469174e` (PR #1248).
- Released application commit: `49e34d35657771949e26472fa14f1f4744955af0`, branch `release/zoky-merchant-ui-20261024`.
- Production artifact: `dpl_AzSiNf7cK7GfS7qboogk3YtR1q73`, https://web-198ctc2ea-warren14.vercel.app, READY / production.
- Vercel target: project `web` / `prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`, team `team_Kamt1PUT5XKn9MWrF404re1w`.
- Promotion completed: **2026-10-25 17:51:44 UTC**. All four workflow jobs (`guard`, `verify`, `stage`, `promote`) succeeded; no pending deployment review remains.

The final home includes the shop-name header, same-row notification bell, editable real shop status/hours, smaller sales amount with baseline-aligned fractions, eight pink 3D tools, readiness card and four primary destinations. The separate lower weekly-quality card is removed; quality remains available through its tool. Login uses the official ZOKY logo. Account, store, menu, order and sales services reuse the existing shared session, bridge, authorization and backend.

## Release and verification evidence

The workflow validated the exact 103 approved application paths on the actual live base `e6f577dcccb86b51c68d91e754b19fe4cfa27222`, including unchanged Food/auth/database boundaries. Credential-free verification passed: full `npm run check` (lint, TypeScript, 390 Node executions, 30 Flutter tests, Flutter analysis/release build/system-font guard, Next production build), legacy Merchant browser flows and 16 compiled Flutter browser cases. The release controls separately passed 11 Python tests (including 17 workflow mutations), five Node API-fixture tests, freeze and production-secret-scoping checks, and independent review with no blocker/HIGH finding.

Stage resumed the exact already-built artifact from run `40169814667`, after correcting that run's generated-alias false failure. It checked the host, login, official logo, JavaScript, CanvasKit and 3D assets over authenticated HTTP. No rebuild or alias mutation occurred in the resume step. The final owner-approved promotion used that same immutable artifact.

Post-promotion independent Vercel metadata inspection resolved all nine customer hostnames and the generated alias to the exact released artifact, correct project/source, READY / production:

`wynos.online`, `www.wynos.online`, `geo.wynos.online`, `food.wynos.online`, `maps.wynos.online`, `zoky.wynos.online`, `tiles.wynos.online`, `routing.wynos.online`, `merchant.wynos.online`, `web-warren14.vercel.app`.

Direct public HTTP verification after promotion passed:

- GET Merchant `/`, `/merchant/login`, `/merchant/flutter`: HTTP 200; root and Flutter entry contain the Flutter manifest metadata. No Vercel Authentication page is returned.
- GET Merchant `/?payments=return` and `/?payments=refresh`: HTTP 200 with the legacy entry retained (no Flutter manifest metadata).
- GET Food, ZOKY and WYNOS roots: HTTP 200 without redirects or Merchant Flutter metadata. Food remains in its existing phase.
- HEAD official logo PNG, Flutter bootstrap, `main.dart.js`, CanvasKit WASM and 3D atlas: HTTP 200 with the expected image/JavaScript/WASM content types.

Fresh anonymous Chromium contexts verified the public root leads to `/merchant/login`, with visible email/password inputs, loaded official logo and sign-in action at 390×844 (Thai) and 1440×1000 (English). No browser page errors or failed network requests were observed. Mobile layout did not overflow; a focused desktop measurement after network idle confirmed document and viewport widths both 1440 with no out-of-bounds elements. The initial desktop measurement during hydration briefly reported two extra pixels; the settled layout did not reproduce this. No application change was needed.

These hosted checks used no authenticated customer account, database connection, customer data, credential files or environment values. Authenticated order/menu/store behavior is supported by the compiled synthetic browser and unit/integration evidence above; a real store account's final visual/functional acceptance remains for the Founder in the product. The active task is therefore retained for that acceptance rather than moved to `completed` solely because deployment succeeded. No production runtime-log contents were read.

## Recovery and boundaries

The released artifact enables the Merchant-origin Flutter root while preserving the legacy payment callbacks and other origins. No database migration, Edge Function deployment, auth-provider change, new infrastructure, Git reconnection or environment-protection change was made.

The recorded prior production artifact remains `dpl_HhzmnfVpb9qyHd7yeiAiiUmkbPV9` / `web-79yhwvs9b-warren14.vercel.app`. Recovery or rollback requires Founder direction; none was performed. The general release freeze remains active, and this release did not deploy all of `main`.

## Follow-up learning

Vercel CLI 63.1.2 `--skip-domain` disables automatic custom-domain assignment but can still assign a generated project alias. Deployment alias arrays can also retain aliases that have moved. Future scoped releases must distinguish customer hostnames from explicitly allowed generated aliases and resolve each hostname independently. Pinning the existing artifact ID and URL allowed the approved build to be resumed and promoted without rebuilding or weakening either production review.
