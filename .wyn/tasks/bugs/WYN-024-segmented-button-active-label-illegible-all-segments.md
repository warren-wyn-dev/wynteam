# Bug Report — WYN-024 / DS-009 (QA round 3 finding — broader than round 2's report)

Status: bugs
Owner: AI Debug Engineer
Bug: Round 2's fix (`maxLines: 1` + ellipsis on all 4 segment labels, Rainbow indicator moved to a separate strip below the button) correctly stops both the overflow crash and the vertical-wrap ballooning. But it does **not** fix legibility — and the problem is not confined to "จาก Club ของคุณ" as round 2 scoped it. At every real phone width (360–430px), **whichever segment is active** gets compressed to roughly 1–3 of its label's characters visible before the ellipsis, because `SegmentedButton` divides the row's width equally across all 4 segments regardless of label length, and the auto-added selected-checkmark icon eats a fixed chunk of whichever segment is currently active. This includes **"สำหรับคุณ" — the default active segment on first load, before the user taps anything.**

Reproduction: widget test, `HomeFeedScreen` in a `MaterialApp` at `tester.view.physicalSize = Size(360, 800)` (no other viewport tested differently — same at 375/390/414/430). For each segment, tap it to make it active (or, for "สำหรับคุณ", just pump — it's active by default) and inspect the `RenderParagraph` behind its label `Text`, plus a `TextPainter` laid out unconstrained with the same style to estimate the label's natural width and back out how many of its characters actually fit in the truncated box:

| Segment (chars) | Active-state box width | Est. visible chars |
|---|---|---|
| "สำหรับคุณ" (9) — **default, no tap needed** | 30.0px | ~1 of 9 |
| "ติดตาม" (6) | 30.0px | ~2 of 6 |
| "ล่าสุด" (6) | 30.0px | ~2 of 6 |
| "จาก Club ของคุณ" (15) — round 2's original finding | 30.0–47.5px (360–430px) | ~2–3 of 15 |

All four converge on the same ~30px active-segment width regardless of label length, because that width comes from equal 4-way division of the row plus the checkmark icon's fixed footprint — not from the label's own content. `didExceedMaxLines` is `true` for every one of them at every width tested, confirming ellipsis is truncating real content, not just leaving safety margin.

Root Cause: the round 2 fix treated this as a problem specific to the widest label ("จาก Club ของคุณ"), because that was the only segment QA round 2 happened to test. The actual constraint is structural: a 4-segment `SegmentedButton` combined with Material's auto-added selected-checkmark icon does not leave enough width per segment for a legible Thai label at any real phone width, for *any* segment that happens to be active — the label text itself was never the variable that mattered most. Shortening only "จาก Club ของคุณ" (the fix QA round 2's report suggested as a fast-follow) would not fix "สำหรับคุณ" or "ติดตาม" also being squeezed to 1–2 visible characters when they're the active one.

This also means the bug is not new in behavior terms — it was already true the moment `maxLines: 1` + ellipsis was applied uniformly to all 4 segments in round 2's fix — but its *severity* is: this affects the **default** state of Home's mode toggle on every single app launch, on every phone in the 360–430px range (i.e., effectively all phones), not an edge case reached only by tapping into one specific segment.

Fix (not applied by QA — reported for Debug Engineer, likely needs AI Design input since this is a structural UI decision, not a plumbing fix):
1. Remove the auto-added selected checkmark (`SegmentedButton` has a `showSelectedIcon: false` parameter) to reclaim its fixed width footprint for text — may be enough on its own, should be measured, not assumed.
2. If (1) isn't enough alone, reconsider whether 4 segments is viable on narrow phones — a horizontally scrollable segment row, a dropdown/menu control, or 2 rows of 2, are all real Material alternatives to a fixed-width 4-way `SegmentedButton`.
3. Whatever is chosen, re-measure with the same `RenderParagraph`/character-visibility technique used in this report at 360–430px for **all four** segments, in both default and tapped-active states, before calling it fixed — round 2's mistake was checking only one segment.

Recommendation: this is a structural control choice, not a copy-length issue as round 2 assumed — flag to AI Design for a decision on `showSelectedIcon: false` vs. a different control entirely, same as the DS-009 indicator-placement question was routed to Design rather than guessed at by Coding/Debug.

Files likely affected: `app/lib/features/home/presentation/home_feed_screen.dart` (`_buildFeedModeToggle`).

Regression Risk: same as before — isolated to this one control, no schema/other-screen impact. However this is higher *user-facing* severity than round 2's framing suggested, since it's visible on Home's default state for every user, every launch.

Handoff to QA: round 4, once fixed. Re-run the exact 4-segment × width-matrix measurement above (not just the widest segment) and confirm every segment shows a legible majority of its label, in both default and tapped states, before passing.
