# Bug Report — ZOKY-144

Status: closed — QA re-test 3 PASS @ 136b548b, 2026-10-22
Severity: MEDIUM (same history/URL desync class as ZOKY-140/143, signed-out visitors; no data loss, no security impact)
Owner: AI Debug Engineer
Found by: AI QA & Security re-test 2 of ZOKY-143, branch `feat/zoky-web-app-design` @ f4ac83ab, 2026-10-22
Introduced by: f4ac83ab (ZOKY-143 fix). Before it, opening the basket from the list pushed nothing.

Bug:
Signed out, non-empty guest basket: Food list (`?view=food`) → floating cart button → basket → in-app "ย้อนกลับ".
The Food list is shown but the URL is `/food` (no `?view=food`). Back then shows the Food list again (dead back),
and a reload on that entry shows Home instead of Food. 390/430/820, Chromium.

Reproduction:
1. No cookie. `/food` → hero → tap store 1 → open a menu item → "เพิ่มลงตะกร้า" → "ดูร้านทั้งหมด" (back to the list).
2. Tap the floating cart button on the Food list → basket opens (URL `/food`, state `zkScreen: "basket"`, zkStore null).
3. Tap "ย้อนกลับ" in the basket header.
Expected: Food list with URL `/food?view=food`; back = Home.
Actual: Food list with URL `/food`, `history.state` null; back = Food list again (`?view=food`); reload before that back = Home.

Root Cause: `web/components/food/food-guest-browse.tsx` history effect (lines 148-161): when the pushed entry's screen
becomes null without a browser back (basket closed in-app with no store selected), it does
`replaceState(null, "", url.href)` on the pushed entry whose URL had `?view=food` removed, so a list entry without
`?view=food` stays in history. Signed-in is not affected (cart close goes to the store entry, verified).

Fix direction (Debug Engineer to decide): basket "ย้อนกลับ" should `history.back()` when the current entry is
`zkScreen: "basket"` with no store (same as "ดูร้านทั้งหมด"), or the effect must never leave a zkScreen entry as a list
without `?view=food`. Add a behavioural browser test (the current spec only does `toContain` source checks).
Fix (2026-10-22): the basket's "ย้อนกลับ" calls `history.back()` when the entry is a basket opened from the list
(`zkScreen === "basket"` and no store), like "ดูร้านทั้งหมด". Also (QA LOW note): `popstate` now closes the item sheet
on both the guest and signed-in screens, so browser back never leaves a stale item sheet over another screen.
Files Changed: `web/components/food/food-guest-browse.tsx`, `web/components/food/wynos-food-developer-app.tsx`,
`web/tests/browser/wynos-food-developer-preview.spec.ts`
Tests:
Regression Risk:
Handoff to QA: rerun /tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/e2e/qa143-guest.mjs G2 + full guest/signed-in matrix.
