# Bug Report — ZOKY-132 (Home + Food: buttons expose no tap action to assistive tech)

Status: **fixed — awaiting QA re-test**
Severity: **HIGH** (accessibility; WCAG 2.1.1 Keyboard / 4.1.2 Name, Role, Value). The core flow (search, open a store, choose address, collect a coupon, open the cart) is announced as "button" but has no semantics action. Assistive tech that activates through actions (Android Switch Access / Voice Access, TalkBack's click action, Flutter web semantics) cannot operate these controls. VoiceOver may still work through UIKit's simulated touch at the element centre; not verified on a device. Pre-existing (Home v1 and the Food page), **not** a regression of ZOKY-128..131. CTO may downgrade to MEDIUM if a device check shows TalkBack and VoiceOver both activate every control.
Owner: AI Debug Engineer
Found by: AI QA & Security — Food page re-test, 2026-10-18, branch `docs/zoky-foundation` @ 5775c10 (same at 0170d10)

Bug:
Custom buttons wrap their `InkWell`/`GestureDetector` in `Semantics(button: true, label: …, excludeSemantics: true)` without `onTap`. `excludeSemantics` also drops the InkWell's tap action, so the one semantics node has `isButton` and a label but **no `SemanticsAction.tap`**.

Semantics dump, Food page at 390×844: 28 buttons with no tap action, including the address button "จัดส่งที่ บ้าน (ตัวอย่าง)", "ร้านโปรด", "คูปองส่วนลด", "จัดส่ง"/"รับเองที่ร้าน", the search field, all 7 category circles, "ดูทั้งหมด", the 3 "เก็บโค้ด" buttons, "ตัวกรอง", every store row and "ตะกร้า". Home: hero "ค้นหาของอร่อย", "ร้านโปรด", both "ดูทั้งหมด", the 5 recommended store cards and the 4 deal cards. Only the back button, the quick filter chips (`ZokyChip`) and the bottom-nav tabs have a tap action. The bottom nav already uses the correct pattern (`zoky_bottom_nav.dart:267`: `Semantics(onTap: onTap, excludeSemantics: true, …)`).

Reproduction:
1. `flutter test test/qa/food_page_retest_qa_test.dart --run-skipped --plain-name "ZOKY-132"`:
   - "every button on Home + Food exposes a tap action" → fails, prints `QA-NO-TAP-ACTION 28: …`.
   - "screen-reader activation (semantics tap) on the search field opens search" → `performAction(tap)` on the search node does nothing (FoodHomeScreen stays).
2. Manual: Android, Voice Access → "show numbers" on the Food page: the numbers skip the search field, the rows and the address. Or TalkBack: focus the search field and double tap.

Expected: every node that says "button" has a tap action that does the same as a finger tap (and toggles report their state), on Home, Food and their sheets.

Actual: no tap action on 28 Food and 13 Home buttons (list above).

Root Cause (QA, preliminary): `excludeSemantics: true` without `onTap` on the wrapping `Semantics`. Files with this pattern (check each one): `lib/features/food/widgets/{zoky_food_address_button,zoky_food_cart_button,zoky_food_category_row,zoky_food_coupon_section,zoky_food_mode_toggle,zoky_food_search_field,zoky_food_store_row}.dart`, `lib/features/food/food_home_screen.dart` (ตัวกรอง, `_storesHeading`), `lib/features/home/widgets/{zoky_food_hero_card,zoky_home_section_header,zoky_recommended_store_card}.dart`, `lib/core/widgets/{zoky_glossy_heart_button,zoky_store_card,zoky_cart_bar,zoky_menu_item_card,zoky_3d_icon}.dart`, `lib/features/deals/widgets/zoky_deal_card.dart`, `lib/features/address/address_sheet.dart`.

Fix (direction): pass the same callback as `Semantics(onTap: …)`, as the bottom nav does (null when disabled), so labels and visuals do not change. Add a regression test that walks the semantics tree of Home and Food and asserts `isButton ⇒ hasAction(tap)`.

Files Changed:
Tests: `zoky_app/test/qa/food_page_retest_qa_test.dart` — two `ZOKY-132 repro` tests (`skip: true`).
Regression Risk: Low (semantics only, no visual change). Re-run the reading-order tests (ZOKY-130), because adding actions must not change the order.
Handoff to QA: un-skip both repros; also check Home and the address/favorites/coupon sheets; VoiceOver + TalkBack spot check on a device.

## Debug Engineer — 2026-10-18

Reproduction: `flutter test test/qa/food_page_retest_qa_test.dart --run-skipped --plain-name "ZOKY-132"` failed both repros before the fix: `QA-NO-TAP-ACTION 28` (same list as above) and the semantics tap on the search field left FoodHomeScreen open.

Root Cause (confirmed): `Semantics(excludeSemantics: true)` drops the semantics of its subtree, including the `SemanticsAction.tap` the child `InkWell`/`GestureDetector` would contribute. The wrapping `Semantics` had `button: true` and a label but no `onTap`, so the single node had no action. All callbacks are non-nullable and none of these buttons has a disabled state or a long-press handler.

Fix: `onTap:` on each of those `Semantics` wrappers, wired to the same callback as the `InkWell`/`GestureDetector` below (the bottom-nav pattern). 15 one-line additions. No labels, hints, flags, widget tree or layout changed, so the reading order (ZOKY-130) and the pixels stay the same.
- Home: hero "ค้นหาของอร่อย" (`zoky_food_hero_card.dart`), "ดูทั้งหมด" (`zoky_home_section_header.dart`), recommended store cards (`zoky_recommended_store_card.dart`), deal cards (`deals/widgets/zoky_deal_card.dart`), "ร้านโปรด" (`core/widgets/zoky_glossy_heart_button.dart`, also used for "ร้านโปรด"/"คูปองส่วนลด" on Food).
- Food: address (`zoky_food_address_button.dart`), จัดส่ง/รับเองที่ร้าน (`zoky_food_mode_toggle.dart`), search (`zoky_food_search_field.dart`), category circles (`zoky_food_category_row.dart`), "เก็บโค้ด" (`zoky_food_coupon_section.dart`), store rows (`zoky_food_store_row.dart`), ตะกร้า (`zoky_food_cart_button.dart`), ตัวกรอง and the filter-sheet options (`food_home_screen.dart`), address-sheet rows (`address/address_sheet.dart`).
- No new abstraction: each site is one line and the callbacks differ.

Same pattern outside Home/Food (not changed, report for CTO/QA): `core/widgets/zoky_cart_bar.dart` (store page "ดูตะกร้า" bar), `core/widgets/zoky_menu_item_card.dart` (store page "เพิ่ม … ลงตะกร้า"), `core/widgets/zoky_store_card.dart` (store search results grid). `ZokyButton` sets `excludeSemantics` only while loading, when it is also disabled, which is correct. The other `excludeSemantics` uses are non-interactive (headers, images, coupon text, "เพิ่มที่อยู่ใหม่ เร็ว ๆ นี้").

Verification:
- Pixel diff: Home and Food rendered with Anuphan at 390×844 and 390×2400, before (stash) vs after: raw RGBA byte-identical for all 4 images.
- `flutter analyze`: no issues. Full `flutter test`: 1011 passed, 12 skipped, 0 failed (incl. ZOKY-130 reading-order tests).
- New regression test fails on the old code (15/15) and passes after the fix.

Files Changed: the 14 `lib/` files listed above.

Tests:
- `zoky_app/test/qa/food_page_retest_qa_test.dart`: both ZOKY-132 repros un-skipped and passing.
- `zoky_app/test/semantics_tap_action_test.dart` (new): walks the whole semantics tree on Home, Food (delivery and pickup), the address sheet and the filter sheet. Every enabled button must have `SemanticsAction.tap`, and no disabled button may have one. Home, Food and the sheets are opened through semantics taps. Each fixed widget is also tested on its own: a semantics tap fires its callback exactly once (the mode toggle switches the mode).

Regression Risk: Low. Semantics only. Not checked on a real device.

Handoff to QA: re-run both repros and the new test. Spot check with VoiceOver, TalkBack and Switch/Voice Access on a device. Decide whether to file the 3 remaining sites (store page, search) as a follow-up.
