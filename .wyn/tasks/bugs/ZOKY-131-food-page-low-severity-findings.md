# Bug Report — ZOKY-131 (Food page: low-severity findings)

Status: **fixed — awaiting QA re-test**
Severity: **LOW** (each item; none blocks the demo)
Owner: AI Debug Engineer
Found by: AI QA & Security — Food page round, 2026-10-18, branch `docs/zoky-foundation` @ 46a8f0c

Bug / Reproduction / Expected / Actual:
1. **Retry gives no loading feedback.** `ZokyStateView.error(onAction: _loadAll)` calls `_loadAll()` with `showSkeletons: false` (the doc comment says retry shows skeletons). On a slow network the error stays unchanged after tapping "ลองอีกครั้ง" until the call ends; repeated taps start parallel loads with no request id (an older response can overwrite a newer one). Repro: `food_page_qa_test.dart --run-skipped --plain-name "retry from the error state"`. Expected: skeletons (or spinner) while retrying. `lib/features/food/food_home_screen.dart:185,543`.
2. **Failed pull-to-refresh wipes the loaded list.** `_loadStores` sets `_stores = null` + error on any failure, so a refresh while offline replaces content (and coupons) with the full-page error. Repro: `--plain-name "pull to refresh that fails"`. Expected (suggestion; PM/Design decide): keep content and show a SnackBar.
3. **Odd distance values render literally.** `distanceKm` `Infinity`/`NaN`/negative → "ระยะ Infinity กม." / "-1.0 กม." in the row text and screen-reader label. Repro: `--plain-name "distance renders sanely"`. Expected: hide distance unless finite and >= 0 (validate at the repository boundary when ZOKY-105 lands).
4. **Cart FAB covers "เก็บโค้ด".** 320×568, text 1.3 (delivery and pickup), page just opened: the floating cart sits over the first coupon's collect button (scratchpad `shots/food_320x568_t1.3_s0_pickup.png`: "เก็บโ…" under the FAB); taps on the covered part open the cart snackbar. Scrolling reveals it.
5. **Category labels break inside a word.** 320 × 1.3 and 375 × 2.0: "ก๋วยเตี๋ยว" wraps as "ก๋วยเตี๋ย / ว" (`shots/food_320x568_t1.3_s0.png`). Suggest scaleDown/smaller label or wider item.
6. **Pickup → store page shows delivery info.** Store rows in pickup mode open `StoreScreen`, which still shows "ค่าส่ง ฿…" and no pickup context. Pickup is demo-only per DECISIONS 2026-10-18; note for the planned pickup task.
7. **Stale comment.** `store_search_screen.dart:19` and `test/support/pump_zoky.dart` mention the placeholder "สั่งอะไรดี?"; the approved field says "ค้นหาร้านอาหารหรือเมนู".

Root Cause / Fix: per item above (directions only; Debug/PM decide).
Files Changed:
Tests: `zoky_app/test/qa/food_page_qa_test.dart` — items 1–3 as skipped repros (ZOKY-131).
Regression Risk: Low.
Handoff to QA: un-skip the three repros; visual check of 4–5 at 320×568.

## Debug Engineer — 2026-10-18 (commit 684558e)

Reproduction: the three repros (`retry from the error state`, `pull to refresh that fails`, `distance renders sanely`) failed as described; items 4–5 seen in the QA screenshots and re-rendered with Anuphan.

Root Cause / Fix per item:
1. Retry called `_loadAll()` with `showSkeletons: false`, and responses had no request id. → Retry now calls `_loadAll(showSkeletons: true)`. Stores and categories each carry a request counter, and stale responses are dropped (regression test: pull to refresh during a retry, then the older response lands last; the newer list is kept).
2. `_loadStores` always set `_stores = null` + error on failure. → When content is already loaded, a failed refresh keeps it and shows a SnackBar using the existing "เชื่อมต่อไม่ได้" copy. Categories also keep their circles. (Keeping content + SnackBar was QA's suggestion; PM/Design can change the copy.)
3. Distance formatted any double. → `ZokyFoodStoreRow.shownDistanceKm` shows distance only if it is finite and >= 0, in the row text, the screen-reader label and the "ใกล้ฉัน" filter.
4. In the compact coupon layout, "เก็บโค้ด" sat at the end (bottom-right), under the floating cart. → It is now aligned to the start side. Bottom padding cannot help here because the coupon is near the top of the content. Only compact cards change (320pt, or large text); the default 390pt layout is unchanged. Test: no overlap at 320×568, text 1.0/1.3, delivery and pickup.
5. Category label (`maxLines: 2`) broke the unbreakable word. → One line that shrinks to fit, with a 4pt side inset so labels keep a gap. This is a no-op when the label fits (all widths at text 1.0). At 375 × 2.0, labels shrink by different amounts (e.g. "ก๋วยเตี๋ยว" is smaller than "ตามสั่ง"). Design may prefer another treatment.
6. Store page from a pickup-mode row hides "ค่าส่ง" (new optional `StoreScreen.fulfillmentMode`, passed by the food page). Store pages from Home/search are unchanged. No other pickup context was added (planned pickup task).
7. Stale "สั่งอะไรดี?" comments updated (`store_search_screen.dart`, `test/support/pump_zoky.dart`).

Files Changed: `lib/features/food/food_home_screen.dart`, `lib/features/food/widgets/{zoky_food_store_row,zoky_food_coupon_section,zoky_food_category_row}.dart`, `lib/features/store/store_screen.dart`, `lib/features/search/store_search_screen.dart`, tests.

Tests: three QA repros un-skipped and passing. New `food_home_screen_test.dart` group "ZOKY-131 low-severity fixes" (race, pickup fee, FAB × 4, category labels × 2). The FAB (1.0 pickup) and category tests fail without the fix. The QA icon audit now gets its error state from a failed first load, because a failed refresh no longer shows it.

Regression Risk: Low.

Handoff to QA: visual check of items 4–5 at 320×568 and 375×667 × 2.0; offline refresh on device.
