# Bug Report — ZOKY-133 (Food page: residual low-severity findings after ZOKY-129/131)

Status: **bugs — open**
Severity: **LOW** (each item; none blocks the demo)
Owner: AI Debug Engineer (items 1, 2); UI/UX Engineer decision (item 3)
Found by: AI QA & Security — Food page re-test, 2026-10-18, branch `docs/zoky-foundation` @ 5775c10

1. **Pickup store page still shows the delivery ETA.** ZOKY-131 item 6 hid "ค่าส่ง" on a store page opened from a pickup-mode row, but the page still shows "20–30 นาที" (`store_screen.dart` ~l.167, the ETA `Text` is not gated by `fulfillmentMode`). The food row hides ETA in pickup ("delivery-only info"), so the two pages disagree. Repro: `flutter test test/qa/food_page_retest_qa_test.dart --run-skipped --plain-name "ZOKY-133 repro"` (prints `QA-RETEST-PICKUP-STORE eta shown in pickup: true`). Expected: hide the delivery ETA in pickup (or show a pickup time if PM defines one). Pickup is demo-only (DECISIONS 2026-10-18), so this can go into the planned pickup task.
2. **Search placeholder ellipsized at large text.** "ค้นหาร้านอาหารหรือเมนู" in the food header search field is `maxLines: 1` + ellipsis. It shows as "ค้นหาร้านอาหา…" at 320 × 1.6–2.0 and "ค้นหาร้านอาหารหรื…" at 375 × 2.0 (scratchpad screenshots `food_320x568_t2.0_s0.png`, `food_375x667_t2.0_s500.png`). Pre-existing. The screen-reader label is complete, and it is a hint, not data. Suggest the same scaleDown approach as the demo address, or a shorter placeholder at large text (Design).
3. **Category labels shrink unevenly at large text.** After ZOKY-131 item 5 (one line, `FittedBox(scaleDown)`), the labels at 320 × 2.0 render at 28.6pt (อีสาน), 23.8 (ไก่ทอด), 22.7 (ตามสั่ง) and 16.6–17.7pt (ของหวาน, เครื่องดื่ม, ก๋วยเตี๋ยว, ฟาสต์ฟู้ด). They never go below the text-1.0 size (15pt), so readability is kept, but the row looks uneven. Design decision: equal size for all labels (smallest common factor), or a wider item at large text.

Tests: `zoky_app/test/qa/food_page_retest_qa_test.dart` — item 1 repro (`skip: true`). Items 2–3 are printed by the "ZOKY-129 re-test" group (`QA-RETEST-129` lines). The search placeholder is excluded from that group's ellipsis assertion until this is fixed.
Regression Risk: Low.
Handoff to QA: un-skip the item 1 repro; re-check the 320 × 2.0 header and category screenshots.
