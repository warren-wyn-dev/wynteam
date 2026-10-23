# Hosted Merchant preview — 2026-10-23

Preview: https://wynteam-gesb-oyjszxvg5-warren14.vercel.app/merchant/flutter

- Existing team/project: `warren14` / `wynteam-gesb` (`prj_oLd50Avnp17cc7PjaUEG3OqLy2Mi`).
- Deployment: `dpl_DVDSnnkGu4U73JFdqaKBTDBcsvtD`, READY, Preview (`target: null`).
- Application commit: `e2ea20d1e58e1ad3b0ced23f0e5e58e31c62229f`, redeployed server-side from the existing Git deployment. No local source deployment or production promotion.

## Authorized configuration repair

After reconnecting Vercel, the Founder explicitly approved copying only the existing sandbox preview Supabase URL and publishable key into the Merchant preview. `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` were copied from `sandbox/stripe-testmode-20261008` to `feat/zoky-merchant-flutter`, scoped to Preview only, stored encrypted. Values were not displayed, logged, written to local files or committed. Original sandbox variables and production configuration were preserved. No other credentials, sandbox flags or database configuration were copied.

## Verification

- Protected HTTP checks: Merchant page, install manifest, Flutter bootstrap and FontManifest return 200.
- The `missing-config` state is gone. A fresh browser visiting `/merchant/flutter` reaches the existing `/merchant/login` and its login form.
- Hosted Chromium mobile/desktop QA: **10/10 PASS** (1.3 minutes) against the deployed build. The existing source test cases were run with an additional fixture that acquires protected-preview access separately for every case, blocks WebSockets and denies external/backend requests except explicitly mocked API fixtures and required font resources.
- Coverage includes signed-out routing, disposable shared-auth host/bridge, load-failure recovery, and actual compiled Flutter order flows for both slip and explicit no-slip payment through preparation ETA and mandatory-photo completion.
- The first hosted run encountered a Vercel protection session problem between cases. Per-case protected access resolved it; Deployment Protection was not disabled. Browser auth state/access URLs were private temporary files, and traces/video were disabled. No authentication artifacts or share tokens are published here.

Screenshots contain synthetic fixtures only:

- [Hosted login](hosted/login.png)
- [Mobile completed order](hosted/mobile-order-completed.png)
- [Desktop completed order](hosted/desktop-order-completed.png)

## Limits and release state

This is hosted frontend/synthetic-contract evidence. Real merchant credentials, live database/customer records, actual payments, push delivery and physical-phone camera selection were not exercised. The existing immutable private-evidence limitation after an abandoned failed final RPC remains documented in the main QA report and the P2 review thread.

Production has not changed. The Merchant root cutover flag remains off. The production-based candidate (`37c050b7`, separate from main) remains available for review; this preview's application source is the feature branch. Do not promote this main-based preview as the production artifact while the coordinated release freeze is active. Required review and the existing scoped release/environment gates still apply.
