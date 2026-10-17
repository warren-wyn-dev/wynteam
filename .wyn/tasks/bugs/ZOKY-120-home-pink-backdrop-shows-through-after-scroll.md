# Bug Report — ZOKY-120 (Home: pink overscroll backdrop shows through content after scrolling)

Status: fixed — awaiting QA re-test
Severity: **HIGH** (Founder-approved Home design breaks in a default state; text becomes illegible)
Owner: AI Debug Engineer
Found by: AI QA & Security — Home slice QA round (Phases 1–5), 2026-10-17, branch `docs/zoky-foundation` @ 895367c

Bug:
`HomeScreen._phase1()` (`zoky_app/lib/features/home/home_screen.dart`) paints a fixed pink `ColoredBox(ZokyColors.headerTop)` at the top of the screen (height = `padding.top + ZokySpacing.s24`) *behind* the `CustomScrollView`, so an iOS overscroll bounce shows pink. The comment says it is "always covered by the header otherwise" — that is false: the box does not scroll, while the header does. Once the header scrolls away, every transparent part of the content that passes the top 44–107pt sits on hot pink: the hero card gutters, the "ดีลเด็ดวันนี้" / "ร้านอาหารแนะนำ" headings, the "ดูทั้งหมด" links and the demo note "ข้อมูลตัวอย่าง ยังไม่ใช่โปรโมชันจริง" (sections have no background of their own).

Measured contrast on `#F93384`: `brandDeep #D61256` ("ดูทั้งหมด") **1.43:1**, `textSecondary #6B6B76` (demo note) **1.46:1**, ink headings 5.01:1. The demo-data note (Founder rule) becomes unreadable.

Reproduction:
1. `cd zoky_app && flutter test test/qa/home_slice_qa_test.dart` with `skip: true` removed from the test `ZOKY-120: once the header scrolls away, no pink band remains ...` → fails (pixel at (4,30) is `#F93384`).
2. Visual: run the app / web preview at 320×568 (text scale 1.0), or any phone in landscape (932×430, 1.0), or 375×667 / 390×844 at text scale ≥ 1.3; scroll Home to the end. The section heading row sits on a pink band at the top of the screen (screenshots taken during QA: 320×568@2.0, 375×667@1.3, 932×430@1.0).
3. On 390×844 / 430×932 at 1.0 the max scroll is short, so only pink bars beside the hero card are visible (cosmetic), but the same defect.

Expected: After the header scrolls away, content keeps its white background; pink appears only during the top overscroll bounce.

Actual: A fixed pink band (44–107pt tall depending on the top inset) stays under the status bar behind scrolled content.

Root Cause (confirmed by Debug, 2026-10-17):
Reproduced with the un-skipped QA test (pixel (4,30) = `#F93384` at 320×568 top 20, scrolled to the end) and in the web preview at 430×932 (top 59): at text 1.0/1.3 pink bars beside the hero card, at text 2.0 the "ดีลเด็ดวันนี้" heading and the demo note sit on pink under the status bar. Cause as reported: the backdrop `Positioned(top: 0, height: paddingTop + s24)` is a fixed sibling under the `CustomScrollView` in the `Stack`; it does not move with the scroll, and the slivers after the header are transparent, so once the header has scrolled more than `paddingTop + 24` the band is exposed.

Fix:
`HomeScreen._phase1()` now listens to the feed's own vertical scroll (`NotificationListener<Notification>`, depth 0 only — `ScrollNotification` plus `ScrollMetricsNotification` for layout-driven offset changes such as rotation/restored offsets) and sizes the backdrop as `max(0, (paddingTop + 24) - pixels)` via a `ValueNotifier` + `ValueListenableBuilder`. At offset 0 the backdrop is exactly the old size (hidden under the header) → Phase 1 header pixel-identical at rest; while overscrolling (negative pixels) it grows with the bounce so iOS still shows pink; scrolling down it shrinks in step with the header and is gone before any content reaches the top. No header/hero/section widget changed.

Files Changed:
- `zoky_app/lib/features/home/home_screen.dart`
- `zoky_app/test/qa/home_slice_qa_test.dart` (removed `skip:` of the ZOKY-120 repro; assertion unchanged)
- `zoky_app/test/home_overscroll_backdrop_test.dart` (new regression tests: iOS overscroll still pink at the top; no pink under the status bar when scrolled at 430×932@2.0 top 59, 375×667@1.3 top 20, 932×430@1.0; scrolled then the top inset grows)

Tests: QA repro passes; new regression tests fail on the old code (4 of 5; the overscroll test passes on both by design) and pass with the fix; home/shell/nav suites pass.

Regression Risk: Low. A per-frame rebuild of one `Positioned`/`ColoredBox` while scrolling (negligible). Nested horizontal rows are ignored (depth > 0). Re-tap scroll-to-top and the nav matrix still pass.

Debug Engineer:
- Reproduced in test and in the web preview (before/after screenshots: `scratchpad/fixes/zoky120-*.png` in the session scratchpad).
- Status bar after the fix: once the header leaves the status bar, the app-level default region gives dark icons (verified by test `status bar icons: light over the header at rest, dark over white content once scrolled`). The web preview's simulated status bar (`tool/web_preview_main.dart`) always draws white text, so in preview screenshots the clock is white-on-white after scrolling — preview artifact only, not changed (preview tool out of scope).
- At-rest preview screenshots before/after are byte-identical at 430×932 text 1.0/1.3/2.0 (Phase 1 look unchanged).
- Not verified on a real iOS device (no device in sandbox); the bounce colour is covered by a widget test with `TargetPlatform.iOS` drag.

Handoff to QA: re-run the device matrix (320/360/375/390/414/430 × 568–932, landscape, text 1.0–2.0), sample pixels under the status bar after scrolling, and verify the top bounce still shows pink on iOS.
