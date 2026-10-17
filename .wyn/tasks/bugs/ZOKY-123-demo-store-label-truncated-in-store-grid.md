# Bug Report — ZOKY-123 ("(ร้านตัวอย่าง)" demo label cut off on store grid cards)

Status: bugs
Severity: **MEDIUM** (Founder rule: every demo store must carry the sample label in every state)
Owner: AI Debug Engineer
Found by: AI QA & Security — Home slice QA round, 2026-10-17, branch `docs/zoky-foundation` @ 895367c

Bug:
On the store grid (`ZokyStoreCard`, used by "ค้นหาของอร่อย" and Home recommended "ดูทั้งหมด" → "ร้านอาหารทั้งหมด") the only sample label is the name suffix " (ร้านตัวอย่าง)", rendered with `maxLines: 2, overflow: ellipsis`. When the name needs a third line the suffix is the part that gets cut. The grid shows sample ratings with review counts ("4.3 (88)"), promo overlays ("ลด 20%", "ส่งฟรี") and an "โฆษณา" overlay, so a card without its label looks like a real store/promotion. The screen has no other demo note.

Measured with the bundled Anuphan font (FontLoader), 2-column grid: at **320pt × text 1.3** three names are ellipsized: "ก๋วยเตี๋ยวเรือหน้ามอ (ร้านตัวอย่าง)", "ข้าวผัดกะเพราเจ้าเก่า (ร้านตัวอย่าง)", "เบอร์เกอร์บ้านสวน (ร้านตัวอย่าง)". 320/360/390/414 × 1.0/1.15/1.6 and 360+ × 1.3 were fine (≥ 1.5 switches to 1 column). The semantics label still reads the full name.

Reproduction:
1. Remove `skip: true` from `ZOKY-123: demo suffix is never ellipsized ...` in `zoky_app/test/qa/home_slice_qa_test.dart` → fails listing the three names.
2. Manual: 320pt wide device, text 130%, Home → "ค้นหาของอร่อย".

Expected: The sample marking is always visible, whatever the name length (e.g. the same `ZokyDemoBadge` on the photo used by the Home recommended card, or a label outside the ellipsized text).

Actual: Label truncated away on narrow screens with enlarged text.

Root Cause (preliminary): the demo label lives inside the truncatable name text instead of a separate, non-truncatable element.

Fix (direction): reuse `ZokyDemoBadge` on the grid photo (as Phase 4 did), or render the suffix as its own widget. Do not invent new copy.

Files Changed: (for Debug) `zoky_app/lib/core/widgets/zoky_store_card.dart`; un-skip the repro.

Tests: `ZOKY-123:` test in `zoky_app/test/qa/home_slice_qa_test.dart` (skipped). Note: tests must load the Anuphan font — with the default test font every name looks truncated.

Regression Risk: Low.

Handoff to QA: re-run at 320/360/375/390/414/430 × 1.0/1.3/1.6/2.0 with the real font.
