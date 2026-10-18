# Bug Report — ZOKY-131 (Food page: low-severity findings)

Status: **bugs**
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
