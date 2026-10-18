# Bug Report — ZOKY-130 (Food page: VoiceOver/TalkBack read the pinned header and filter chips after the content)

Status: **fixed — awaiting QA re-test**
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

## Debug Engineer — 2026-10-18 (commit f4cdd42)

Reproduction: `--run-skipped --plain-name "reading order"` printed the QA-ORDER above (header and chips after the rows).

Root Cause (confirmed in Flutter source): `RenderSliverPinnedPersistentHeader.describeSemanticsConfiguration` tags its nodes `RenderViewport.excludeFromScrolling`. `_RenderScrollSemantics` then puts them as siblings after the inner scrolling node, so they are read after all the content. The coupon button came after the search field because of geometric sorting inside that header.

Fix: each sliver of the food page is wrapped in `SliverSemantics(container: true, explicitChildNodes: true, sortKey: OrdinalSortKey(i))`. The wrapper node is not tagged, so the headers stay inside the scroll node, and the ordinal keys fix the order: header (back, address, heart, coupons, จัดส่ง/รับเองที่ร้าน, search), categories, coupons, store heading + ตัวกรอง, quick chips, rows, then the cart (outside the scroll view).

Verified orders: page just opened (390×844) matches the expected sequence exactly. Scrolled 300/900/end: compact header (search) first, then content, chips, rows, cart. 2000pt viewport: same as just opened.

Files Changed: `lib/features/food/food_home_screen.dart`.

Tests: QA "reading order follows the visual order" un-skipped and passing.

Regression Risk: Low. Side effect: the scroll node's `scrollIndex` (row X of Y hint) is no longer derived from the rows, because they now sit one level deeper. Not verified on a real device; needs a VoiceOver/TalkBack spot check.

Handoff to QA: device spot check with VoiceOver and TalkBack, including after scrolling.
