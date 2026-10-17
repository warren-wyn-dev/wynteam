# Bug Report — ZOKY-122 ("ร้านโปรด" sheet overflows in landscape and at large text)

Status: bugs
Severity: **MEDIUM** (overflow at text ≥ 1.6 on small phones = accessibility; also in landscape at 1.0)
Owner: AI Debug Engineer
Found by: AI QA & Security — Home slice QA round, 2026-10-17, branch `docs/zoky-foundation` @ 895367c

Bug:
`HomeScreen._openFavorites()` (`zoky_app/lib/features/home/home_screen.dart`) opens `showModalBottomSheet` (not scroll-controlled → max 9/16 of the screen height) with a non-scrollable `ZokyStateView.empty` (108pt circle + 32pt vertical padding ×2 + title + message). When that does not fit, the Column overflows.

Measured (FlutterError.onError, full app, tap the header heart):

| Viewport | Text 1.0 | 1.3 | 1.6 | 2.0 |
|---|---|---|---|---|
| 320×568 | ok | ok | 45 px | 117 px |
| 375×667 | ok | ok | ok | 19 px |
| 390×844 / 430×932 | ok | ok | ok | ok |
| 932×430 (landscape) | 49 px | 63 px | 78 px | 97 px |
| 667×375 (landscape) | 80 px | 94 px | 109 px | 128 px |

Secondary (LOW, same code): this sheet is always a Material sheet, also on iOS, unlike the deal sheet which uses the adaptive `showZokySheet` (Founder decision 2026-10-17 #5: sheets follow iOS/Android).

Reproduction:
1. Remove `skip: true` from the four `ZOKY-122:` tests in `zoky_app/test/qa/home_slice_qa_test.dart` → all fail with "A RenderFlex overflowed by N pixels on the bottom".
2. Manual: 320×568 at 200% text (or any phone in landscape) → tap the heart on the pink header.

Expected: The placeholder sheet fits or scrolls at every supported size and text scale up to 200% (design system §10.2), with no overflow stripe/clipped text.

Actual: Bottom overflow; in release the message is clipped.

Root Cause (preliminary): fixed-height state view inside a height-capped, non-scrollable sheet.

Fix (direction): wrap the content in a `SingleChildScrollView` (or use `showZokySheet`, which already handles height/safe area and platform style). Do not change the copy.

Files Changed: (for Debug) `home_screen.dart`; un-skip the repro tests.

Tests: `ZOKY-122:` tests in `zoky_app/test/qa/home_slice_qa_test.dart` (skipped); passing baseline `header heart opens the "ร้านโปรด" placeholder only (390x844, text 2.0)`.

Regression Risk: Low.

Handoff to QA: re-run the table above on iOS and Android platform themes.
