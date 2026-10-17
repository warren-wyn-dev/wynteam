# Bug Report — ZOKY-121 (Rating shown without reviews on StoreScreen and the store grid card)

Status: bugs
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

Root Cause (preliminary): two call sites use `isNew`/`ratingAverage` instead of the `rating` getter added for Phase 4.

Fix (direction): use `store.rating` in `StoreScreen._info`, `ZokyStoreCard` (text, star icon, semantics). Keep the "ร้านใหม่" copy decision with PM/Design (web parity) — only the score must disappear.

Files Changed: (for Debug) `store_screen.dart`, `zoky_store_card.dart`; un-skip the repro tests.

Tests: `ZOKY-121:` tests in `zoky_app/test/qa/home_slice_qa_test.dart` (skipped).

Regression Risk: Low. Check the legacy-body filter "เรตติ้ง 4.5+" (`StoreFilter.rating` uses `ratingAverage`) for the same rule.

Handoff to QA: re-run the repro tests plus the search/see-all/store flows with rated, unrated and avg-without-count stores.
