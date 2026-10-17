# Bug Report — ZOKY-127 (Store grid: photo overlay labels truncated — "โฆษณา" ad disclosure, promo, closed, ETA)

Status: **Verified** — QA re-test PASS (2026-10-17, @ 8740a16)
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

Reproduction (Debug, 2026-10-17, @ a9a3b67): un-skipped the four `ZOKY-127:` tests → 4/4 fail, e.g. 320 × 1.3 `{'demo-store-1': {'โฆษณา', '20–30 นาที'}}`, 375 × 1.0 every card's ETA, 360 × 1.3 ETA + `ลด 20%`. Web preview at 320×568 / text 130% shows "โฆษ…", "ปิ…", "ลด 2…", "20–…" (scratchpad `fixes127/before-320x568-text1.3*.png`).

Root Cause (confirmed by Debug, 2026-10-17): `_Photo` computed `half = photoWidth / 2 - 6` and passed it as `maxWidth` to every `_Overlay`, whose label was `maxLines: 1, overflow: ellipsis`. The cap was applied unconditionally (even with the opposite corner empty), and the four labels compete for two ~65–84pt halves of a 138–180pt photo. The ETA additionally does not belong on the photo: the approved Home recommended card shows it in the meta row ("★ 4.8 | 30–45 นาที").

Fix:
- ETA moved off the photo into the meta row under the name, as on the Home card: `★ 4.8 (1250) | 20–30 นาที | 1.2 กม.` (label from `ZokyRecommendedStoreCard.etaLabel`, so "30 นาที" when min == max like Home). Groups are separated by a thin rule; each group wraps as a whole and the rating group wraps inside, so nothing overflows with the square test font either. Each group carries its leading rule and the row is shifted left by the rule slot and clipped on the left edge only, so a rule never dangles at the start/end of a line (Thai marks above/below are not clipped). This also removes the old leading "·" on the distance when it wrapped.
- Top badges are one `Wrap(alignment: spaceBetween)` spanning the photo width: demo badge + "โฆษณา" (column) on the left, "ปิดอยู่" on the right when both fit, otherwise "ปิดอยู่" moves below. Every badge may use the full photo width; no half-width cap.
- `_Overlay` no longer has `maxWidth`/`maxLines`/ellipsis: the label wraps if ever wider than the photo (never ellipsized). Promo is bottom-left with the full width (no ETA opposite any more).
- Unchanged: demo badge (ZOKY-123) still one line `FittedBox(scaleDown)` inside the photo (now never squeezed to half width); 1:1 photo (ZOKY-125); rating rule via `store.rating` / "ร้านใหม่" (ZOKY-121); overlays still clamp text to 1.3; card semantics label unchanged (already contains ETA, ad, closed, promo).

Files Changed:
- `zoky_app/lib/core/widgets/zoky_store_card.dart` — photo badges layout, `_Overlay` without cap/ellipsis, ETA in meta row, `_MetaItem` + `_ClipLeftEdge`.
- `zoky_app/test/qa/home_slice_retest_qa_test.dart` — removed `skip: true` from the four `ZOKY-127:` tests (assertions untouched).
- `zoky_app/test/store_card_overlay_labels_test.dart` (new) — Debug regression: grid 320/360/375/390/414/430 × 1.0/1.15/1.3/1.45/2.0 with Anuphan: every photo badge whole (`didExceedMaxLines` false), present, inside the photo, no overlap; ETA shown once, below the photo, not cut; no card text pushed outside the card; plus a worst-case synthetic store (demo + ad + closed + long promo "ลด 20% เมื่อสั่งครบ ฿300", 120–180 min, 123456 reviews) on a 138pt card × 1.0/1.3/2.0. Fails 29+ cases on the old code.

Tests (2026-10-17): `flutter analyze` → No issues found. `flutter test` → 791 passed, 1 skipped (the ZOKY-124 repro in `test/qa/home_slice_qa_test.dart`, unrelated), 0 failed. The four `ZOKY-127:` tests pass; the re-test grid matrix (search / ดูทั้งหมด / legacy × 320–932 × 1.0–2.0) passes and prints no `QA-TRUNCATED` line. `store_card_demo_badge_test.dart`, `store_card_photo_ratio_test.dart`, `store_rating_rule_test.dart`, `widgets_layout_test.dart`, `home_recommended_test.dart` pass. Web preview after: scratchpad `fixes127/after-320x568-text1.3*.png`, `fixes127/after-430x932*.png`.

Regression Risk: Low–Medium. Visual change on the grid card: ETA is text in the meta row instead of a white pill on the photo, distance separator changed from "·" to the thin rule, and closed stores at narrow widths show "ปิดอยู่" under the demo badge instead of top-right. Cards can be one meta line taller on narrow phones. Long promos from the backend (ZOKY-105/106) now wrap to 2+ lines on the photo instead of being cut; extremely long promo text could cover more of the photo (still inside it). Design/PM may want a max promo length in the backend contract.

Handoff to QA: re-run the ZOKY-127 repros, the grid matrix (search / ดูทั้งหมด / legacy × 320–430, 932 × 1.0–2.0) and `test/store_card_overlay_labels_test.dart`; visually check the meta row "★ | นาที | กม." at 320 × 1.3 and 430 × 1.0, closed + demo + ad stacking, VoiceOver/TalkBack label unchanged.

QA Re-test (AI QA & Security, 2026-10-17, branch `docs/zoky-foundation` @ 8740a16): **Verified**

- Note: after the fix the badge `Text` has no `maxLines`, so `didExceedMaxLines` (used by the original repros and the Debug matrix) is always false. QA added an independent check in `zoky_app/test/qa/zoky127_retest_qa_test.dart`: every photo badge laid out on ONE line (no "โฆษ/ณา" split), inside the photo with inset, no overlap, present; meta row items whole and on one line, not cut by the left-edge clip, no visible separator without content on both sides of the same line; screen reader label equal to the pre-fix formula. Mutation check: against the pre-fix card (a9a3b67) the new test fails ("โฆษณา" ellipsized/split, "ปิดอยู่" split, ETA on photo); against HEAD it passes.
- App grids: search / "ดูทั้งหมด" / legacy × 320, 360, 375, 390, 414, 430, 932 (landscape) × text 1.0, 1.15, 1.3, 1.45, 1.6, 2.0, Anuphan, all 9 demo stores → 126/126 pass.
- Synthetic worst cases (card 120/138/160/180/220pt × text 1.0–2.0): stacked ตัวอย่าง + โฆษณา + ปิดอยู่ (+ promo "ลด ฿30"), ad + closed + promo, closed only, ร้านใหม่, no rating and not new, ETA only / min == max ("30 นาที"), km only, empty meta (no row shown), half ETA (hidden), 999999999 reviews, 1234.5 กม. → 25/25 pass (meta text may wrap inside a group on card widths/scales that no real grid produces, e.g. "20–30 / นาที" at 138pt × 2.0; never ellipsized or cut).
- Original repros: 4 `ZOKY-127:` tests pass; re-test grid matrix prints no `QA-TRUNCATED` line.
- Visual (test-rendered PNG, Anuphan): 320 × 1.3 meta rows stack as "★ 4.8 (1250)" / "20–30 นาที" / "1.2 กม." with no separator; 430 × 1.0 "★ 4.8 (1250) | 20–30 นาที" then "1.2 กม." with no leading rule; "ปิดอยู่" under "ตัวอย่าง" at 138pt, top-right at 430. Thai marks (ร้านใหม่, ปิดอยู่, กม.) not clipped.
- Screen reader: one node per card, label unchanged for all demo + synthetic stores.
- `flutter analyze` → No issues found. `flutter test` → 942 passed, 4 skipped (ZOKY-124 repro + 3 screenshot helpers that run only with `QA_SHOT_DIR`), 0 failed.
- Informational (no new bug filed): meta row reserves the 13pt rule slot at the right edge too, so it wraps ~13pt earlier than necessary (cosmetic); semantic ETA for min == max reads "30 ถึง 30 นาที" while the card shows "30 นาที" (pre-existing, same as before); backend promo length still unbounded (Debug risk note) — needs a max length in the ZOKY-105/106 contract.
