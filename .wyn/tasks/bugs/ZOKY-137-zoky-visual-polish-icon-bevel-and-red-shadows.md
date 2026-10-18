# Bug Report — ZOKY-137

Status: partially fixed (CSS) — awaiting QA re-test; icon artwork open
Severity: LOW (visual, no functional/security impact)
Owner: AI Debug Engineer / UI-UX for sign-off
Found by: AI QA & Security, branch `feat/zoky-web-rebrand` @ ffd3ac6, 2026-10-18

Bug:
1. `web/public/icons/zoky/icon-192-v1.png`, `icon-512-v1.png`, `apple-touch-icon-180-v1.png`, `icon-32-v1.png` are generated from a raster
   that already contains a rounded-square glossy bevel (lighter pink rim/corners). iOS/Android apply their own mask on top,
   so the installed icon shows a double edge (visible in the login header `wf-auth-mark` too). The maskable icon is clean.
2. Shared `web/app/food/food.css` (also imported by Merchant/Maps) still has old-red shadows/glows on Food customer
   elements: `rgb(230 0 18 / x)` at lines 1428, 1491, 1528, 1582, 1596, 2992, 3351, 3466, 4343 — faint red halos next to ZOKY pink.

Reproduction:
- Open the PNGs above; corner pixel (0,0) = (245,80,154) vs body (241,36,115): bevel rim baked in.
- `grep -n "230 0 18" web/app/food/food.css`.

Fix:
- Regenerate any/apple icons from a full-bleed source without bevel (pending master vector A1, design Q3).
- Override those shadows in the Food customer scope in food-app.css (do not edit food.css shared values for Merchant/Maps).

Tests: visual check on real iPhone/Android (staging); Playwright icon spec still passes.
Regression Risk: Low.
Handoff to QA: visual re-check on staging.

## Fix Record (AI Coding, 2026-10-18) — partial (CSS only, icon artwork skipped as instructed)

Root Cause: shared `food.css` values; most listed selectors (`wf-preview-banner`, `wf-store-cover`, `wf-category-tabs`, `wf-add`, `wf-store-cart-bar`, `wf-menu-search-add`, `wf-fulfillment-tabs`, `wf-checkout-footer`) are not rendered by any component (grep of all .ts/.tsx/.js) — dead CSS, invisible in ZOKY. The only live one in the customer app is the `.wf-form input/textarea:focus` ring (address form, line 1596).
Fix: `web/app/food/food-app.css` overrides `.fx-app .wf-form input:focus, .fx-app .wf-form textarea:focus` with `rgb(238 34 110 / 8%)`. `food.css` untouched (Merchant/Maps unchanged). Dead selectors left as is (removal = separate cleanup).
Not fixed: item 1 (icon bevel) — pending master vector A1 / design Q3.
Tests: web: lint 0 errors (17 existing warnings), typecheck pass, `node --test tests/*.test.mjs` 344/344 pass, `npm run build` pass. Deno is NOT installed in this environment: `deno check`/`deno test` not run (CI job `edge-functions` runs them); `_lib.ts` logic was executed with Node `--experimental-strip-types` and all edited .ts files parse with the TypeScript compiler (0 syntax diagnostics). Visual check on staging still needed.
Commit: 15fc1e3
