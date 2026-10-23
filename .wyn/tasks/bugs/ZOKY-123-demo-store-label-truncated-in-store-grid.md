# Bug Report — ZOKY-123 ("(ร้านตัวอย่าง)" demo label cut off on store grid cards)

Status: verified — QA re-test PASS (2026-10-17)
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

Root Cause (confirmed by Debug, 2026-10-17):
Reproduced with the un-skipped `ZOKY-123:` test (Anuphan loaded, 320pt × 1.3): the three listed names exceed `maxLines: 2` and the " (ร้านตัวอย่าง)" suffix is the ellipsized part. `ZokyStoreCard` had no demo marking other than the suffix inside the truncatable name `Text`.

Fix:
Same approach as the Home recommended card: for `store.isDemo` the grid card shows `nameWithoutDemoSuffix` and puts the existing `ZokyDemoBadge` ("ตัวอย่าง", no new copy) at the top-left of the photo, one line, scaled down (`FittedBox`) only if needed so it is never cut. Width limit: full photo width minus gaps, or half the photo when the top-right "ปิดอยู่" overlay is present. When the store is also an ad, the "โฆษณา" overlay stacks under the badge in the same top-left column (no overlap). The screen-reader label still reads the full name including "(ร้านตัวอย่าง)" (unchanged).

Files Changed:
- `zoky_app/lib/core/widgets/zoky_store_card.dart`
- `zoky_app/test/qa/home_slice_qa_test.dart` (removed `skip:`; assertion unchanged — it now passes because no ellipsizable suffix text exists on the grid card)
- `zoky_app/test/store_card_demo_badge_test.dart` (new, real font: 320/360/390/430 × 1.0/1.3/2.0 — every demo card has exactly one badge inside the card, badge text not clipped, no overlap with "ปิดอยู่"/"โฆษณา", no suffix in the visible name; non-demo store has no badge)

Tests: QA repro + new tests + `widgets_layout_test.dart`, `shell_navigation_test.dart`, `home_hero_card_test.dart` pass.

Regression Risk: Low. Visible name on the grid no longer contains "(ร้านตัวอย่าง)" (the badge replaces it, as on Home). StoreScreen title/body still show the full name with the suffix.

Debug Engineer: reproduced with the QA test; reused `ZokyDemoBadge`; combined with ZOKY-125 (1:1 photo) the top-left column has more room.

Handoff to QA: re-run at 320/360/375/390/414/430 × 1.0/1.3/1.6/2.0 with the real font.

QA Re-test (AI QA & Security, 2026-10-17): **Verified**
- Environment: branch `docs/zoky-foundation` @ 41ddc95, Flutter widget tests (devicePixelRatio 1, FakeViewPadding, real Anuphan font where noted), suite `zoky_app/test/qa/home_slice_retest_qa_test.dart`, real Anuphan font.
- Entries "ค้นหาของอร่อย" (hero), Home "ดูทั้งหมด" → "ร้านอาหารทั้งหมด" and the legacy body × widths 320/360/375/390/414/430/932 × text 1.0/1.15/1.3/1.45/1.6/2.0 (126 cases, all 9 demo stores each, scrolled into view): exactly one `ZokyDemoBadge` per demo card, inside the photo, text not clipped, never scaled below 85% of its natural size, no visible "(ร้านตัวอย่าง)" suffix, no overlap with any other overlay, no FlutterError. 126/126 pass.
- New related finding (pre-existing, not caused by this fix): the other photo overlays ("โฆษณา", promo, "ปิดอยู่", ETA) are still ellipsized because of their half-width cap → filed as **ZOKY-127 (MEDIUM)**.
