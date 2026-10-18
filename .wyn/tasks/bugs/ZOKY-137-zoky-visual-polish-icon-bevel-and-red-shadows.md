# Bug Report — ZOKY-137

Status: bugs
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
