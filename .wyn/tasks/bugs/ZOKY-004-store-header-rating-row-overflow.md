# Bug Report — ZOKY-004 (StoreScreen header rating row)

Status: bugs — **discovered by AI QA & Security during SELLER-004 round 2 verification (2026-08-15), not blocking SELLER-004's approval** (see rationale below); needs its own Debug round when scheduled.
Owner: AI Debug Engineer (not yet assigned/started)
Found by: AI QA & Security, while independently re-measuring `StoreScreen`'s device matrix for SELLER-004's BUG-1 round 2 verification.

Bug: `StoreScreen`'s `_buildHeader` rating row (`app/lib/features/zoky/presentation/store_screen.dart`, inside the `FutureBuilder<(double, int)>` that reads `_ratingFuture`) renders `Row(children: [StarRatingDisplay(...), SizedBox(width: 4), Text('${rating} · 0 ผู้ติดตาม · ${productCount} สินค้า')])` with **no `Expanded`/`Flexible` around the `Text`**. At any real phone width (360–430px logical), the available width for this Row (screen width minus the 16px side padding ×2 minus the 32px+16px logo circle) is only ~278px, which is narrower than the star icons + text combined whenever the store has **at least 1 review** (i.e. `rating.$2 != 0`, the branch that actually shows stars). This produces a `RenderFlex overflowed ... on the right` error.

This is **not caused by SELLER-004** — confirmed via `git log`/`git show` that this exact unwrapped `Row` has existed unchanged since ZOKY-004 introduced the rating display (commit `135af7a`). SELLER-004 (commits `0bf5253`, `f7035c8`) never touched this Row. It was never caught by any prior QA round (ZOKY-004 round 1/2, SELLER-004 round 1/2) because every `StoreScreen` test that exercises a rated store ran at `flutter_test`'s default 800×600 viewport, which is wide enough (688px available) that the overflow never triggers — the exact same blind spot documented in `.wyn/tasks/bugs/SELLER-004-store-screen-header-overflow.md` (BUG-1), just in a different Row of the same header.

Reproduction (widget test, `tester.view.physicalSize` set to a real phone size, `FlutterError.onError` captured directly — not `tester.takeException()`):

1. Build a `Store` with any name/productCount and a `RecordingZokyRepository` whose `storeRating` is any non-zero-count tuple, e.g. `(4.5, 1)`.
2. `pumpWidget(MaterialApp(home: StoreScreen(...)))`, `pumpAndSettle()`.
3. Observe a `FlutterError` containing `overflowed ... on the right` from `RenderFlex#... store_screen.dart:286` (the rating `Row`).

Measured overflow amount across the standard SELLER-004 device matrix (all with a plain, non-rated-by-default store, `storeRating: (4.5, 1)`, no banner/info fields at all — this is the *minimum* trigger, not an edge case):

| Viewport | Overflow |
|---|---|
| 360×640 | 235 px |
| 375×667 | 220 px |
| 390×844 | 205 px |
| 430×932 | 165 px |

The overflow shrinks as the screen widens but does not disappear at any phone size tested. It is independent of `productCount`/description length — the *minimum* rated-store text ("4.5 · 0 ผู้ติดตาม · 1 สินค้า" + 5 star icons) already overflows.

Expected: Any store with reviews shows its aggregate rating on `StoreScreen` without a layout overflow, on any real phone width.

Actual: `RenderFlex` overflow of 165–235px on every phone width tested, for literally any store with ≥1 review. In a debug/profile build this renders the yellow-black overflow stripe over the header; in a release build the affected Text/Row silently clips, likely hiding part of the "X ผู้ติดตาม · Y สินค้า" text from the user.

Root Cause (preliminary, from reading the code — Debug Engineer should confirm independently per project convention): the `Text` sibling of `StarRatingDisplay` inside the `Row` has no `Expanded`/`Flexible` wrapper, so it sizes to its own natural (unwrapped) width instead of being constrained to the remaining space in the Row. The `rating == null || rating.$2 == 0` branch just above it returns a bare `Text` with no `Row` at all, which is why *unrated* stores never hit this (a lone `Text` inside a `Column` wraps normally instead of overflowing).

Suggested Fix direction (not yet implemented — for the assigned Debug Engineer to verify/adjust): wrap the `Text` in `Expanded` (matching how `_buildStoreInfoSection`'s address/business-hours rows already wrap their `Text` in `Expanded`) and add `overflow: TextOverflow.ellipsis` so the text wraps/truncates instead of pushing past the Row's bounds. Re-run the full SELLER-004 BUG-1 device matrix (360×640, 375×667, 390×844+1.3, 430×932+1.3, landscape) with `storeRating` set on every case, since none of BUG-1's own regression tests set a non-zero rating — that's precisely why this second Row's bug slipped through the same fix.

Files likely affected: `app/lib/features/zoky/presentation/store_screen.dart` (`_buildHeader`'s rating `Row`, ~line 286). Possibly `app/test/store_screen_test.dart` (add a device-matrix case with `storeRating` set, mirroring BUG-1's own matrix additions).

Regression Risk: Low — the fix is a single `Expanded` wrap, same shape as the existing (already-correct) `_buildStoreInfoSection` rows right below it in the same file. Should not affect any other behaviour.

Why this does not block SELLER-004's round 2 approval: SELLER-004's own Acceptance Criteria, Requirements, and the specific BUG-1 fix under test (banner + "ข้อมูลร้านค้า" section causing the header to collapse `TabBarView` to 0 height) are all independently verified working correctly (see SELLER-004's QA round 2 output). This finding is in an unrelated, unmodified-by-SELLER-004 code path that predates SELLER-004 by two features (ZOKY-004). Per standard triage, a newly-discovered pre-existing defect outside a task's scope and Acceptance Criteria does not block that task's approval, but must be filed and reported for prompt follow-up given its severity (affects essentially any rated store on any real phone).

Handoff to QA: once fixed, re-verify with the full SELLER-004 BUG-1 device matrix but with `storeRating` set to a non-zero-count value on every case (this is the exact gap that let this bug ship unnoticed through both SELLER-004 QA rounds).
