# Bug Report — ZOKY-124 (Home ignores the left/right safe area in landscape)

Status: bugs
Severity: **MEDIUM** (iPhone landscape is enabled in `ios/Runner/Info.plist`; logo/heart/content can sit under the notch / Dynamic Island)
Owner: AI Debug Engineer
Found by: AI QA & Security — Home slice QA round, 2026-10-17, branch `docs/zoky-foundation` @ 895367c

Bug:
`UISupportedInterfaceOrientations` (iPhone) allows LandscapeLeft/Right. In landscape, notched iPhones report ~47–59pt left/right insets. `ZokyBottomNav` respects `padding.left/right`, but `ZokyHomeHeader` (wordmark at x≈20, heart at the right edge), `ZokyFoodHeroCard` (x=16) and the deals/recommended rows use fixed gutters only. With insets 59/59 at 932×430 the wordmark starts at x≈20 and the heart ends at x≈912 — inside the cut-out area.

Reproduction:
1. Remove `skip: true` from `ZOKY-124: landscape with a notch keeps the logo inside the safe area` in `zoky_app/test/qa/home_slice_qa_test.dart` → fails (`logo.left` ≈ 20 < 59).
2. Manual (needs a device): iPhone 14/15 Pro, rotate to landscape on Home.

Expected: Either content honors the horizontal safe area (pink header still bleeds edge to edge), or phones are locked to portrait — the latter is a product decision for Founder/PM, not for QA.

Actual: Logo, heart, hero card and section rows can be covered by the notch.

Root Cause (preliminary): horizontal insets not applied outside the nav.

Fix (direction): apply `MediaQuery.paddingOf(context).left/right` to the header row padding and the content gutters (or a `SafeArea(top: false, bottom: false)` around non-bleeding content), or get a decision to lock phone orientation to portrait.

Files Changed: (for Debug) `zoky_home_header.dart`, `home_screen.dart`, possibly section widgets; un-skip the repro.

Tests: `ZOKY-124:` test in `zoky_app/test/qa/home_slice_qa_test.dart` (skipped).

Regression Risk: Low in portrait (insets are 0).

Handoff to QA: re-check landscape with insets 0/47/59 on both sides and portrait regression.

QA Re-test (AI QA & Security, 2026-10-17, @ 41ddc95): **Still open — awaiting Founder decision** (portrait lock vs. landscape support). Repro un-skipped temporarily: still fails (logo.left ≈ 20 < 59). Not changed by the ZOKY-120..125 fixes.
