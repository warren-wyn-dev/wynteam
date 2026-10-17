# Bug Report — ZOKY-121 (Rating shown without reviews on StoreScreen and the store grid card)

Status: verified — QA re-test PASS (2026-10-17)
Severity: **MEDIUM** (Founder rule "show rating only with real reviews"; not triggered by current demo data)
Owner: AI Debug Engineer
Found by: AI QA & Security — Home slice QA round, 2026-10-17, branch `docs/zoky-foundation` @ 895367c

Bug:
The Home recommended card correctly uses `ZokyStoreSummary.rating` (null unless `ratingCount > 0 && ratingAverage > 0`). The screens reached from Home do not:
- `zoky_app/lib/features/store/store_screen.dart` `_info()` shows `'★ ${store.ratingAverage}'` whenever `!store.isNew` (`isNew` = `ratingAverage <= 0`), ignoring `ratingCount`.
- `zoky_app/lib/core/widgets/zoky_store_card.dart` (grid on "ค้นหาของอร่อย" and Home "ดูทั้งหมด" → "ร้านอาหารทั้งหมด") does the same in the visible text and in the semantics label ("คะแนน 4.5"). It also always draws a star icon, even next to "ร้านใหม่".
So a store with `ratingAverage 4.5, ratingCount 0` shows "4.5" on the grid and "★ 4.5" on the store page while Home hides it — the same store looks rated on one screen and unrated on another.

Reproduction:
1. Remove `skip: true` from the two `ZOKY-121:` tests in `zoky_app/test/qa/home_slice_qa_test.dart` and run `flutter test test/qa/home_slice_qa_test.dart` → both fail (rating text found).
2. Manual: build a `ZokyStoreSummary(ratingAverage: 4.5, ratingCount: 0, ...)` and open it in `StoreScreen` / render `ZokyStoreCard`.

Expected: Every surface uses the same rule as Home (`store.rating != null`); without reviews no score (and no star suggesting one) is shown or announced.

Actual: Score shown/announced from `ratingAverage` alone.

Root Cause (confirmed by Debug, 2026-10-17):
Reproduced with both un-skipped `ZOKY-121:` tests ("4.5" found on `StoreScreen` and on `ZokyStoreCard` for `ratingAverage 4.5, ratingCount 0`). `StoreScreen._info()` and `ZokyStoreCard` (text, star icon, semantics) decide on `isNew` (`ratingAverage <= 0`) and print `ratingAverage`, ignoring `ratingCount`; only the Home card uses the `rating` getter. The legacy-body filter `StoreFilter.rating` also used `ratingAverage`.

Fix:
- `ZokyStoreCard`: star icon + score + `(count)` and the "คะแนน x" semantics only when `store.rating != null`; otherwise "ร้านใหม่" (unchanged copy) when `isNew`, and nothing for an average without reviews. The star is no longer drawn next to "ร้านใหม่".
- `StoreScreen._info()`: `'★ x'` only when `store.rating != null`, else "ร้านใหม่" when `isNew` (unchanged copy), else nothing.
- `HomeScreen._filtered` (legacy body, behind `kShowLegacyHomeBody = false`): "เรตติ้ง 4.5+" filters on `store.rating` (same rule).
"ร้านใหม่" copy/when-to-show is unchanged (PM/Design decision kept); only the score without reviews disappears.

Files Changed:
- `zoky_app/lib/core/widgets/zoky_store_card.dart`
- `zoky_app/lib/features/store/store_screen.dart`
- `zoky_app/lib/features/home/home_screen.dart` (legacy filter line only)
- `zoky_app/test/qa/home_slice_qa_test.dart` (removed the two `skip:`; assertions unchanged)
- `zoky_app/test/store_rating_rule_test.dart` (new: no score/star/announcement without reviews; rated store shows star, score, count and "คะแนน 4.5"; new store keeps "ร้านใหม่" without star; StoreScreen rated/new)

Tests: both QA repros pass; new tests + `widgets_layout_test.dart` + `home_recommended_test.dart` pass.

Regression Risk: Low. Demo stores all have `ratingCount > 0`, so the demo UI is unchanged. The text "★" on StoreScreen is kept (ZOKY-126 item 1 not addressed here).

Debug Engineer: reproduced with the QA tests; fix limited to the three call sites; no copy changes.

Handoff to QA: re-run the repro tests plus the search/see-all/store flows with rated, unrated and avg-without-count stores.

QA Re-test (AI QA & Security, 2026-10-17): **Verified**
- Environment: branch `docs/zoky-foundation` @ 41ddc95, Flutter widget tests (devicePixelRatio 1, FakeViewPadding, real Anuphan font where noted), suite `zoky_app/test/qa/home_slice_retest_qa_test.dart`.
- `ZokyStoreCard`, `StoreScreen` and `ZokyRecommendedStoreCard` with (avg, count) = (4.5, 12), (4.56, 3), (0, 0), (4.5, 0), (0, 7), (−1, 5), (NaN, 5), (4.5, −3): score + star + "(count)" + "คะแนน x" announced only for the two rated cases (4.56 → "4.6"); no score, no rating-coloured star, no "NaN" otherwise; "ร้านใหม่" only when avg ≤ 0 (unchanged PM copy); semantics label contains the store name in every case (not vacuous). 24/24 pass.
- Demo flow: the same rated store shows "4.8" on the Home card, the grid card and "★ 4.8" on StoreScreen.
- Observation (LOW, data boundary, logged in ZOKY-126 item 8): avg 0 + count 7 shows "ร้านใหม่" for a store that has reviews, and an average > 5 would be shown as-is; impossible with the server aggregate but should be validated in the ZOKY-106 mapping.
