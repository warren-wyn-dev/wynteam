# Bug Report — WYN-024 / DS-009 (QA round 3 finding — broader than round 2's report)

Status: **partially fixed — 2 of 4 segments now fully legible, 2 remain truncated at every real phone width (including the default "สำหรับคุณ") — see Debug Engineer Report below for why this needs AI Design, not another Debug attempt**
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

---

## Debug Engineer Report (2026-08-22, round 3)

**Bug**: as filed by QA round 3 above — every active `SegmentedButton` segment (not just "จาก Club ของคุณ") is compressed to ~1-3 visible characters at real phone widths, including "สำหรับคุณ" (default, active from first launch, no tap needed).

**Reproduction (confirmed independently before fixing)**: same technique QA round 3 used — `RenderParagraph` size of the active label + a `TextPainter` laid out unconstrained with the same style to estimate visible character count. At 360px, before any fix: all 4 segments measured `box=Size(30.0, 20.0)` regardless of label length — "สำหรับคุณ" showed ~1/9 chars visible, "ติดตาม"/"ล่าสุด" ~2/6, "จาก Club ของคุณ" ~2/15. Matches QA's numbers exactly.

**Root Cause**: confirmed by inspecting Flutter's own `segmented_button.dart` source (`/home/user/flutter_sdk/flutter/packages/flutter/lib/src/material/segmented_button.dart`) rather than guessing. Two compounding causes:
1. `SegmentedButton` divides its total width equally across all segments (4-way here), independent of each label's content length.
2. Every segment defaults to `showSelectedIcon: true`, so whichever segment is currently selected gets an `Icons.check` icon (line 1284: `Widget? get selectedIcon => const Icon(Icons.check);`) inserted before its label, consuming a further fixed chunk of that segment's already-equal width share — a chunk *no other* (non-selected) segment has to pay, which is why only the *active* segment was ever the one QA found illegible, not the other three at rest.

**Fix applied** (`_buildFeedModeToggle` in `home_feed_screen.dart`):
1. `showSelectedIcon: false` on the `SegmentedButton` — the checkmark is redundant anyway since Material's default styling already shows selection via each segment's own fill/outline color change; removing it reclaims that segment's fixed icon-width budget for its label instead.
2. `style: ButtonStyle(padding: EdgeInsets.symmetric(horizontal: 2), visualDensity: VisualDensity.compact)` — tightens the default `EdgeInsets.all(8)` per-segment padding, reclaiming further width.

**Measured result** (same technique, all 4 segments, 360-430px):
- "ติดตาม" / "ล่าสุด" (6 chars each): **fully legible from ~390px up** (`didExceedMaxLines: false`), still slightly truncated at 360-375px but visibly better (~5/6 chars vs. ~2/6 before).
- "สำหรับคุณ" (9 chars, **the default active segment**) and "จาก Club ของคุณ" (15 chars): **still ellipsis-truncated at every width tested, 360-430px** — box width roughly doubled to tripled (30px → 80-97px) but still well short of their unconstrained natural width (141px and 211.5px respectively).

**This fix is real and safe, but it does not close the bug.** Doubling/tripling the checkmark+padding budget was the smallest, purely-technical lever available to Debug Engineer without changing the control's structure or visual design — and it measurably helped 2 of 4 segments. But the remaining gap for "สำหรับคุณ" and "จาก Club ของคุณ" is not a padding/icon problem anymore: their full label text (141px / 211.5px) simply cannot fit in a ~80-100px budget that a 4-way equal split of a 360-430px screen allows, no matter how tight the padding gets. Squeezing padding further would start harming tap-target size and visual balance for no meaningful legibility gain. Closing this fully requires one of:
- Shortening "สำหรับคุณ"/"จาก Club ของคุณ" specifically (a copy decision), or
- Restructuring the control itself (e.g. a scrollable segment row, 2x2 layout, or dropdown/menu instead of a fixed 4-way `SegmentedButton`) — a UX/visual decision.

Both are AI Design calls, not something Debug Engineer should pick unilaterally — consistent with QA round 3's own recommendation. Applying a bigger structural change here myself would repeat exactly the mistake logged in `.wyn/learning/MISTAKES.md`'s WYN-024/DS-009 QA round 2→3 entry: acting on an assumption about the right UI shape without design input.

**Files Changed**: `app/lib/features/home/presentation/home_feed_screen.dart` (`_buildFeedModeToggle` — `showSelectedIcon`/`style` added), `app/test/home_feed_screen_test.dart` (2 new regression tests).

**Tests**: `flutter analyze` — 0 issues. `flutter test` — **360/360 pass** (358 + 2 new). Red→green proof: `git stash` on `home_feed_screen.dart` only → both new tests fail (checkmark icon present; "ติดตาม"/"ล่าสุด" still ellipsis-truncated at 390px) → `git stash pop` restores the fix → both pass again. The two new tests deliberately do **not** assert legibility for "สำหรับคุณ"/"จาก Club ของคุณ" since that would be asserting a false invariant — they cover only what this fix actually closes.

**Regression Risk**: Low. `showSelectedIcon: false` and tighter padding are additive style changes to one widget; full 360-test suite (unrelated to this screen) re-run clean.

**Handoff to QA**: round 4. Expect this to still be a **FAIL** for "สำหรับคุณ" (default state) and "จาก Club ของคุณ" specifically — that's expected and reported honestly above, not something round 4 needs to rediscover. Please independently re-verify the 2 segments that did improve ("ติดตาม"/"ล่าสุด" legible from ~390px) and confirm the 2 that didn't, then route the remaining structural question to AI Design/Founder (a design comparison + popup decision, same pattern as DS-009's own indicator-placement question) rather than back to Debug for a third layout-only attempt — two consecutive Debug rounds on the same underlying constraint (round 2's dot relocation, round 3's icon/padding trim) without a design-level decision is the signal to escalate now, per this bug's own original recommendation.
