# Bug Report — ZOKY-127 (Store grid: photo overlay labels truncated — "โฆษณา" ad disclosure, promo, closed, ETA)

Status: bugs
Severity: **MEDIUM** (the "โฆษณา" paid-placement disclosure and the "ลด 20%" promo value become unreadable; ETA is cut at default text size on 375pt phones; design §10.2 says no truncation on the main flow). Not HIGH today because only demo data is affected (no real ads/promos yet) and the screen reader still reads the full text. **Must be fixed before real ads/promotions from the backend (ZOKY-105/106) go live.** Founder/PM may raise it if the ad disclosure counts as a legal requirement.
Owner: AI Debug Engineer
Found by: AI QA & Security — Home slice re-test round, 2026-10-17, branch `docs/zoky-foundation` @ 41ddc95 (first raised as a note by AI Debug Engineer while fixing ZOKY-123). Pre-existing: same output at a63d90e (before the ZOKY-123/125 fixes); missed in the first QA round.

Bug:
`ZokyStoreCard._Photo` (`zoky_app/lib/core/widgets/zoky_store_card.dart`) caps every overlay (`_Overlay`: ad, closed, promo, ETA) at `half = photoWidth / 2 - 6` and renders the label with `maxLines: 1, overflow: ellipsis`. On 2-column grids the photo is only ~138–180pt wide, so labels are ellipsized. The cap applies even when nothing sits on the other side of the photo (e.g. the ad label at top-left of an open store has the whole top row free; the demo badge above it already uses the full width).

Measured with the bundled Anuphan font (`didExceedMaxLines` of each overlay `RenderParagraph`, all 9 demo stores, entries "ค้นหาของอร่อย", Home "ดูทั้งหมด" → "ร้านอาหารทั้งหมด" and the legacy body — identical results):

| Label | Truncated at |
|---|---|
| "โฆษณา" (ad disclosure) → "โฆษ…" | 320pt × text 1.3, 1.45 |
| "ลด 20%" / "ลด ฿30" (promo) → "ลด 2…" | 320 × 1.15–1.45 ("ลด 20%"), 360 × 1.3–1.45; "ลด ฿30" 320 × 1.3–1.45 |
| "ปิดอยู่" (closed) → "ปิ…" | 320 × 1.15–1.45 |
| ETA "20–30 นาที" → "20–30 น…" / "20–…" | **every card** at 320/360/375 × 1.0–1.45, 390 × 1.15–1.45, 414/430 × 1.3–1.45 |

At text ≥ 1.5 the grid switches to 1 column and nothing is truncated; overlays clamp text to 1.3, so 1.3–1.49 is the worst case. Screenshots (session scratchpad): `shots/new/grid_320_1.3.png` ("โฆษ…", "20–…"), `shots/new/grid_375_1.0.png` ("20–30 น…").

Why the ad label matters: it is the only visible marker that a listing is paid placement; "โฆษ…" is not a readable disclosure. A truncated promo value ("ลด 2…") is ambiguous price information. A truncated "ปิ…" hides that the store is closed (no other visible closed marker on the card).

Reproduction:
1. Remove `skip: true` from the four `ZOKY-127:` tests in `zoky_app/test/qa/home_slice_retest_qa_test.dart` and run `flutter test test/qa/home_slice_retest_qa_test.dart --plain-name ZOKY-127` → all fail (e.g. `{'demo-store-1': {'โฆษณา', '20–30 นาที'}}` at 320 × 1.3).
2. Manual: 320pt device (or 375pt for ETA), text 130% (ETA: 100%), Home → "ค้นหาของอร่อย".

Expected: Overlay labels are fully readable at every supported width and text scale (design §10.2); at minimum the ad disclosure, promo value and closed state are never ellipsized.

Actual: Labels are ellipsized as in the table above.

Root Cause (preliminary, QA): the fixed half-width cap per overlay plus `TextOverflow.ellipsis`; ETA ("xx–yy นาที", ~80–90pt at caption bold + 16pt padding) never fits in ~77pt at 375pt.

Fix (direction, for Debug/Design — QA does not decide): give an overlay the full photo width when the opposite corner is empty (ad at top-left of an open store, as the demo badge already does; promo vs ETA at the bottom), and/or stack/scale down (`FittedBox`, as for the demo badge) instead of ellipsizing, or move ETA out of the photo into the meta row (as on the Home recommended card). Keep the "no overlap" guarantee (covered by `store_card_demo_badge_test.dart`, `widgets_layout_test.dart` and the re-test grid matrix).

Files Changed: (for Debug) `zoky_app/lib/core/widgets/zoky_store_card.dart`; un-skip the four repros.

Tests: `ZOKY-127:` tests in `zoky_app/test/qa/home_slice_retest_qa_test.dart` (skipped); the grid matrix in the same file prints every truncation as `QA-TRUNCATED ...`.

Regression Risk: Low–Medium (overlay layout; re-run the overlap checks at 320–430 × 1.0–1.45 and 932 landscape).

Handoff to QA: re-run the ZOKY-127 repros and the grid matrix (search / ดูทั้งหมด / legacy × 320–430, 932 × 1.0–2.0).
