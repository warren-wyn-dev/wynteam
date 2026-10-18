# Bug Report — ZOKY-129 (Food page: ETA/distance, coupon minimum, store name and demo address label are ellipsized)

Status: **bugs**
Severity: **MEDIUM** (same class as ZOKY-127: design §10.2 "no truncation on the main flow"; the coupon minimum "เมื่อสั่งครบ ฿100" is price information; the header can hide "(ตัวอย่าง)" so a sample address reads as real — Founder rule "demo labels everywhere"). Screen readers still get the full text (row/coupon labels are complete).
Owner: AI Debug Engineer
Found by: AI QA & Security — Food page round, 2026-10-18, branch `docs/zoky-foundation` @ 46a8f0c

Bug:
Measured with the bundled Anuphan font (`RenderParagraph.didExceedMaxLines`, all demo stores, scrolling the whole page, 844pt high):

| Text (widget) | maxLines | Ellipsized at |
|---|---|---|
| Store row meta "หมวด · ★ คะแนน · 20–30 นาที · 1.9 กม." (`ZokyFoodStoreRow`) | 2 | 320 × 1.3 (1 store); 320/375 × 1.6–2.0 (all 8 stores with ETA); 430 × 2.0 — ETA and/or distance lost ("15–25 นา…") |
| Store name "ข้าวผัดกะเพราเจ้าเก่า" (`ZokyFoodStoreRow`) | 2 | 320 × 2.0 |
| Coupon condition "ชานมไข่มุกหวานใจ · เมื่อสั่งครบ ฿100" (`ZokyFoodCouponCard`) | 2 | 320 × 2.0 (all 3 coupons) |
| Header address "ที่ทำงาน (ตัวอย่าง)", "คอนโด (ตัวอย่าง)" (`ZokyFoodAddressButton`) | 1 | 320 × 1.3 (header clamps text at 1.3, so 1.3–2.0) |

Screenshot (session scratchpad): `shots/food_375x667_t2.0_s500.png` ("เครื่องดื่ม · ร้านใหม่ · 15–25 นา…").

Reproduction:
1. `flutter test test/qa/food_page_qa_test.dart --run-skipped --plain-name "no truncated"` → prints `QA-TRUNCATED` lines; 6/12 cases fail.
2. `... --run-skipped --plain-name "demo label readable"` → 320pt × 1.3 fails: `['ที่ทำงาน (ตัวอย่าง)', 'คอนโด (ตัวอย่าง)']`.
3. Manual: 320pt phone (iPhone SE 1st gen) text 130% → select "ที่ทำงาน (ตัวอย่าง)" in the header sheet; 375pt text 200% → store rows.

Expected: ETA, distance, price conditions and the demo marker are always fully readable at 320–430pt × text 1.0–2.0 (wrap, not ellipsize), as fixed for the grid in ZOKY-127.

Actual: Ellipsized as in the table.

Root Cause (preliminary, QA): `maxLines: 2/1 + TextOverflow.ellipsis` on the row meta `Text.rich`, the row name, the coupon condition and the header bold line; the row photo (up to 110pt) + gutter leave ~150pt for text on 320pt.

Fix (direction, Debug/Design decide): let the meta wrap per item (as `ZokyStoreCard` meta row after ZOKY-127) without maxLines; no maxLines on the coupon condition; for the header keep "(ตัวอย่าง)" visible (separate demo badge like ZOKY-123, or ellipsize only the name part).

Files Changed:
Tests: `zoky_app/test/qa/food_page_qa_test.dart` — "no truncated store/coupon text" (tag `qa-heavy`) and "header address keeps the demo label readable" (skipped repros, ZOKY-129).
Regression Risk: Low–Medium (rows/coupons get taller at large text; check FAB spacing and coupon card IntrinsicHeight).
Handoff to QA: un-skip both groups; re-run the layout matrix and scroll sweep in the same file.
