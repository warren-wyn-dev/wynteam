# Bug Report — ZOKY-126 (Home slice: LOW-severity findings, batch)

Status: bugs
Severity: **LOW** (each item; none blocks the Home slice)
Owner: AI Debug Engineer (items 1–5), AI DevOps (item 6), AI Design/PM (item 7)
Found by: AI QA & Security — Home slice QA round, 2026-10-17, branch `docs/zoky-foundation` @ 895367c

Bug / Reproduction / Fix direction (one per item):

1. **Web preview font fallback goes to Google's CDN.** CanvasKit is bundled (`useLocalCanvasKit: true` with `--no-web-resources-cdn`), but the engine's font fallback still defaults to `https://fonts.gstatic.com/s/` (string present in `build/web/main.dart.js`). `StoreScreen` renders a text "★" (U+2605), which is **not** in Anuphan (checked the font's cmap), so opening a store in the preview should fetch a Noto symbols font from Google; typing emoji in search would too. Found by code/font inspection, **not verified in a browser** (no browser in the QA sandbox). Fix: use the `Zoky3DIcon` star (as Home does) and/or set `fontFallbackBaseUrl` to a local path in the bootstrap config.
2. **Cover URL handling is inconsistent.** `ZokyStoreCover` sends anything that does not start with lowercase `http://`/`https://` to `Image.asset` — safe (asset bundle only; `javascript:`, `file:`, `data:`, `content:`, `../` all fall back to the drawn art, covered by tests), but `HTTPS://…` or a leading space silently lose a real photo. `ZokyStoreCard` and `ZokyMenuItemCard` pass any string to `Image.network` (non-http schemes fail on mobile; on web, `data:` would render). Cleartext `http://` is accepted. No `cacheWidth`/`cacheHeight` on network images (full-size decode). Fix (with ZOKY-105/106 mapping): accept only `https` public-bucket URLs at the repository boundary; add decode sizes.
3. **"FOOD DELIVERY" pill is truncated at 200% text** on 320pt ("FOOD D…"); design §10.2 says no truncation on the main flow up to 200%. The screen reader still gets the full text.
4. **Orphan divider in the recommended card meta row.** When the ETA wraps to its own line (e.g. 375pt × 1.3), the 1px divider stays at the end of the rating line ("★ 4.8 |").
5. **Web preview `?top=` / `?bottom=` accept `NaN`, negative or huge values** (`double.tryParse`) and feed them to `MediaQuery` padding (`tool/web_preview_main.dart`). Preview-only; clamp to 0–100.
6. **Android release manifest has no `INTERNET` permission** (only debug/profile). Fine for demo mode, but real cover photos (`Image.network`) and Supabase (ZOKY-105) will fail only in release builds. Add it when the backend lands.
7. **Docs drift / dead code:** design system §9.8 still marks the floating capsule nav "PROPOSED — รอ Founder review" although DECISIONS.md records Phase 5 approval; `HomeScreen` keeps the whole legacy body (`kShowLegacyHomeBody = false`, search field, filters, grid) as dead code in production builds.

Expected / Actual: see each item.

Root Cause: see each item (all from reading the code plus the QA tests listed below).

Files Changed: (for Debug) `store_screen.dart`, `zoky_store_cover.dart`, `zoky_store_card.dart`, `zoky_menu_item_card.dart`, `zoky_food_hero_card.dart`, `zoky_recommended_store_card.dart`, `tool/web_preview_main.dart`, `android/app/src/main/AndroidManifest.xml` (when the backend lands), `.wyn/docs/design/zoky-design-system.md`.

Tests: cover-URL scheme tests and the "no network in demo mode" test in `zoky_app/test/qa/home_slice_qa_test.dart` (passing).

Regression Risk: Low.

Handoff to QA: re-check each item when fixed; item 1 needs a real browser network log.
