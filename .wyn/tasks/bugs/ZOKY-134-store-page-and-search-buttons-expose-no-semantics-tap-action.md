# Bug Report — ZOKY-134 (Store search grid + store page: buttons expose no tap action to assistive tech)

Status: **bugs — open (deferred: fix with the store page / search design task)**
Severity: **HIGH** (accessibility; WCAG 2.1.1 / 4.1.2), same class as ZOKY-132. Not a blocker for the Food page review: the affected screens are outside the Food page scope and are due to be redesigned. Must be resolved, or accepted by the Founder in writing, before any production release that includes the store page or store search (AGENTS.md release gates). CTO may downgrade to MEDIUM if a device check shows TalkBack and VoiceOver both activate these controls.
Owner: AI Debug Engineer / Full-Stack Engineer, inside the store page design task
Found by: AI QA & Security — ZOKY-132 re-test, 2026-10-18, branch `docs/zoky-foundation` @ d528503 (also listed by the Debug Engineer in ZOKY-132)

Bug:
Three widgets still wrap their `InkWell`/`InkResponse` in `Semantics(button: true, label: …, excludeSemantics: true)` without `onTap`, so the single semantics node says "button" but has no `SemanticsAction.tap`:
- `zoky_app/lib/core/widgets/zoky_store_card.dart` (~l.82) — store search results grid card (`store_search_screen.dart`). Reachable from the Food page now: the search field and every category circle open this screen.
- `zoky_app/lib/core/widgets/zoky_menu_item_card.dart` (~l.193) — store page "เพิ่ม … ลงตะกร้า" button.
- `zoky_app/lib/core/widgets/zoky_cart_bar.dart` (~l.44) — store page "ดูตะกร้า …" bar.

Reproduction:
1. `flutter test test/qa/zoky132_retest_qa_test.dart --run-skipped --plain-name "ZOKY-134"`:
   - "store search grid (Food search field)" fails, prints `QA-ZOKY-134 search 9: [ร้านข้าวมันไก่ป้าแดง (ร้านตัวอย่าง), …]` (all 9 store cards).
   - "store page (Food store row), add item + cart bar" fails, prints `QA-ZOKY-134 store 2: [เพิ่ม เมนูตัวอย่าง ลงตะกร้า, ดูตะกร้า 1 รายการ รวม 45 บาท]`.
2. Manual: Android Voice Access "show numbers" on the store search grid or the store page: the cards, the add button and the cart bar get no number.

Expected: every enabled button node has a tap action that does the same as a finger tap (null when disabled).
Actual: no tap action on the 9 search grid cards, the menu "เพิ่ม" button and the cart bar.

Root Cause: `excludeSemantics: true` drops the child InkWell's tap action and the wrapping `Semantics` has no `onTap`.

Fix (direction): same as ZOKY-132: `Semantics(onTap: <same callback>)` on each wrapper (bottom-nav pattern). If the redesign replaces these widgets, keep the rule: `isButton ⇒ hasAction(tap)`. Extend `zoky_app/test/semantics_tap_action_test.dart` to the store search and store page.

Tests: `zoky_app/test/qa/zoky132_retest_qa_test.dart` — two `ZOKY-134 repro` tests (`skip: true`).
Regression Risk: Low (semantics only).
Handoff to QA: un-skip both repros; run the semantics-tap vs finger-tap equivalence pattern from the ZOKY-132 re-test on the new screens; device spot check.
