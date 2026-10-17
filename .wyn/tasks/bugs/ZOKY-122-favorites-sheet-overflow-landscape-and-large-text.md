# Bug Report — ZOKY-122 ("ร้านโปรด" sheet overflows in landscape and at large text)

Status: fixed — awaiting QA re-test
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

Root Cause (confirmed by Debug, 2026-10-17):
Reproduced with the four un-skipped `ZOKY-122:` tests ("A RenderFlex overflowed ... on the bottom"). `_openFavorites()` used a plain `showModalBottomSheet` (not scroll-controlled → height capped at 9/16 of the screen) whose child `ZokyStateView.empty` is a fixed-height, non-scrollable Column (108pt circle + 2×32pt padding + title + message); when it is taller than the cap the Column overflows. It also bypassed the adaptive sheet, so iOS got a Material sheet.

Fix:
`_openFavorites()` now uses `showZokySheet` (same as the deal sheet: Cupertino popup with grabber on iOS, M3 scroll-controlled sheet with drag handle on Android, bottom safe area) and wraps the unchanged `ZokyStateView.empty` in a `SingleChildScrollView`, so the content fits or scrolls. Copy unchanged.

Files Changed:
- `zoky_app/lib/features/home/home_screen.dart`
- `zoky_app/test/qa/home_slice_qa_test.dart` (removed the `skip:` of the four repros; assertions unchanged)
- `zoky_app/test/home_favorites_sheet_test.dart` (new: iOS + Android × 320×568@2.0, 667×375@2.0, 932×430@1.6 — no FlutterError, Cupertino route on iOS / Material on Android, message reachable on screen; all 6 fail on the old code)

Tests: QA repros + baseline `header heart ... (390x844, text 2.0)` pass; new tests pass.

Regression Risk: Low. Android sheet now shows a drag handle (as the deal sheet). On iOS the Cupertino popup does not reserve the top status-bar inset; content only reaches it if taller than the screen, then it scrolls (same as the existing deal sheet).

Debug Engineer: reproduced with QA tests; minimal change reusing the existing adaptive helper.

Handoff to QA: re-run the table above on iOS and Android platform themes.
