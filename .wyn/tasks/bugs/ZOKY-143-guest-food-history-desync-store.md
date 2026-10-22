# Bug Report — ZOKY-143

Status: fixed — waiting QA re-test
Severity: MEDIUM (same history desync as ZOKY-140, signed-out visitors; no data loss, no security impact)
Owner: AI Debug Engineer
Found by: AI QA & Security re-test of ZOKY-140, branch `feat/zoky-web-app-design` @ 9d0d41f4, 2026-10-22

Bug:
Signed out: `/food` → hero → Food (`?view=food`) → tap a store → browser back / swipe-back. The URL becomes `/food` but
the store stays on screen; the next back leaves the site, and "ดูร้านทั้งหมด" afterwards shows Home instead of Food.

Root Cause: `web/components/food/food-guest-browse.tsx` — `popstate` only did `setView(...)`; it ignored `selectedId` and
`showBasket`, and `pickStore` kept `?view=food` (same pattern as ZOKY-140 on the signed-in screen).

Fix (2026-10-22): same approach as ZOKY-140. Leaving Food for a store or the basket pushes one entry without
`?view=food` (state `zkScreen` + `zkStore`); later moves replace that entry; `popstate` restores store/basket from it
(none = the list). The store's in-app back "ดูร้านทั้งหมด" uses `history.back()` on such an entry so entries do not stack.
Files Changed: `web/components/food/food-guest-browse.tsx`, `web/tests/browser/wynos-food-developer-preview.spec.ts`
Tests: guest Food→store→back = Food, forward = store, in-app back = Food then back = Home on site, reload on the
store entry ≠ Food then back = Food (mocked browser suite, 390/430/820).
Regression Risk: low–medium; `?store=` shared links for guests unchanged (no `?view=food` in the URL → no entry pushed).
Handoff to QA: rerun guest + signed-in Home/Food history matrix.
