# Bug Report — ZOKY-120 (Home: pink overscroll backdrop shows through content after scrolling)

Status: bugs
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

Root Cause (preliminary — confirm independently):
The backdrop `Positioned(top: 0, height: paddingTop + s24)` is a sibling *under* the `CustomScrollView` in a `Stack`, not part of the scrolled content, and the slivers after the header are transparent.

Fix (direction, not implemented):
Show the pink only when the scroll offset is negative (e.g. size it from a `ScrollController`/`NotificationListener` with `max(0, -pixels)`, or put it inside the first sliver as an overflow above it), or give the content below the header an opaque `ZokyColors.surface` background (including the hero gutters). Do not change the approved header/hero visuals.

Files Changed: (for Debug) `zoky_app/lib/features/home/home_screen.dart`; un-skip the repro in `zoky_app/test/qa/home_slice_qa_test.dart`.

Tests: repro test `ZOKY-120: ...` in `zoky_app/test/qa/home_slice_qa_test.dart` (currently `skip: true`).

Regression Risk: Low–medium — touches the Home scroll stack; re-check the iOS bounce color, the light status-bar region, the re-tap scroll-to-top and the "nav covers no card" matrix.

Handoff to QA: re-run the device matrix (320/360/375/390/414/430 × 568–932, landscape, text 1.0–2.0), sample pixels under the status bar after scrolling, and verify the top bounce still shows pink on iOS.
