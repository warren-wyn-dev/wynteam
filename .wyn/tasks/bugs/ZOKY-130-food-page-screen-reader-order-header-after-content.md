# Bug Report — ZOKY-130 (Food page: VoiceOver/TalkBack read the pinned header and filter chips after the content)

Status: **bugs**
Severity: **MEDIUM** (accessibility, WCAG 1.3.2 meaningful sequence / 2.4.3 focus order): a screen-reader user swiping forward hears the categories, coupons and the first rows before the back button, address, delivery/pickup choice and search; the quick filter chips are announced before their heading "ร้านอาหารทั้งหมด". All controls remain reachable and labelled.
Owner: AI Debug Engineer
Found by: AI QA & Security — Food page round, 2026-10-18, branch `docs/zoky-foundation` @ 46a8f0c

Bug:
Semantics traversal order at 390×844 (insets 47/34), page just opened:
`สั่งอาหาร | ตามสั่ง | ก๋วยเตี๋ยว | อีสาน | เครื่องดื่ม | ฟาสต์ฟู้ด | ไก่ทอด | ของหวาน | โค้ดลดเพิ่มสำหรับคุณ | ดูทั้งหมด… | (3 coupons + เก็บโค้ด) | ร้านอาหารทั้งหมด | ตัวกรอง | (3 rows) | กลับ | จัดส่งที่ บ้าน (ตัวอย่าง) | ร้านโปรด | วิธีรับอาหาร | จัดส่ง | รับเองที่ร้าน | ค้นหาร้านอาหารหรือเมนู | คูปองส่วนลด | ทั้งหมด | ใกล้ฉัน | ส่งฟรี | มีโปรฯ | ตะกร้า`
Also the header coupon button ("คูปองส่วนลด") comes after the search field instead of after "ร้านโปรด" (also on a 2000pt-tall viewport, where the chips are still read before the categories).

Reproduction:
1. `flutter test test/qa/food_page_qa_test.dart --run-skipped --plain-name "reading order"` → prints `QA-ORDER …` and fails.
2. Manual: iPhone VoiceOver on, Home → "ค้นหาของอร่อย", swipe right from the top.

Expected: back → address → heart → coupons → จัดส่ง/รับเองที่ร้าน → search → categories → coupons section → ร้านอาหารทั้งหมด → ตัวกรอง → quick chips → rows → cart.

Actual: order above (the two pinned `SliverPersistentHeader`s are visited after the scrolling content).

Root Cause (preliminary, QA): `CustomScrollView` semantics visit pinned persistent headers after the other slivers; no `sortKey`/`OrdinalSortKey` on the header, chips and body.

Fix (direction): give the header, body and chips explicit `Semantics(sortKey: OrdinalSortKey(...))` (or a `FocusTraversalGroup`/`MergeSemantics`-free ordering) and place the coupon button next to the heart in the order. Verify on device with VoiceOver and TalkBack.

Files Changed:
Tests: `zoky_app/test/qa/food_page_qa_test.dart` — "reading order follows the visual order" (skipped repro, ZOKY-130).
Regression Risk: Low.
Handoff to QA: un-skip; VoiceOver/TalkBack spot check incl. after scrolling (header compact).
