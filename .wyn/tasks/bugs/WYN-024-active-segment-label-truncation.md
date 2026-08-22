# Bug Report — WYN-024 / DS-009 (QA round 2 finding — new, not in round 1's report)

Status: bugs
Owner: AI Debug Engineer
Bug: The fix for QA round 1's Bug 2 (Rainbow accent dot overflowing the active feed-mode segment) stops the `RenderFlex` overflow assertion, but at every realistic phone width the active **"จาก Club ของคุณ"** segment's label is now compressed to near-nothing — not a cosmetically-tight ellipsis, but the text rendering box shrinking to 20–38px wide (2-3 Thai characters at most, likely less with the ellipsis glyph itself), while the rest of the 10-character label is invisible. Confirmed at every width this codebase's own `.wyn/learning/LESSONS_LEARNED.md` (SELLER-004 entries) established as the required "real phone" baseline test matrix, not just one edge case.

Reproduction: widget test, `HomeFeedScreen` in a `MaterialApp`, tap `find.text('จาก Club ของคุณ')` to make it the active segment, then inspect the `RenderParagraph` behind that `Text` (found via `tester.renderObject(find.text('จาก Club ของคุณ')) as RenderParagraph`):

| Viewport width | Label render box | `didExceedMaxLines` |
|---|---|---|
| 360px (SE/small Android) | `Size(20.0, 20.0)` | `true` |
| 375px (iPhone SE 2/3) | `Size(23.8, 20.0)` | `true` |
| 390px (iPhone 14/15) | `Size(27.5, 20.0)` | `true` |
| 414px (iPhone Plus) | `Size(33.5, 20.0)` | `true` |
| 430px (iPhone Pro Max, largest common phone) | `Size(37.5, 20.0)` | `true` |
| 800px (`flutter test`'s own default viewport — wider than any phone) | `Size(130.0, 20.0)` | `true` |

No `flutter test` viewport width produces a fully-visible label — `didExceedMaxLines` is `true` at every single one, including the 800px default the existing automated suite runs at (which is why `home_feed_screen_test.dart`'s own tests didn't catch this: none of them assert on the *rendered size* of the active segment's text, only that the text/dot widgets exist in the tree and that no layout exception fires — see the codebase's own SELLER-004 lesson: *"widget test ที่ผ่าน 100% ไม่ได้แปลว่า layout ไม่พังบนมือถือจริง"*). A screenshot at 360px (via `RenderRepaintBoundary.toImage`, Thai/icon fonts render as tofu boxes in this headless environment, but box *sizes* are accurate) shows the active segment containing only Material's own auto-generated selected-checkmark icon and the Rainbow dot — no visible label text at all.

Root Cause: QA round 1's / Debug's fix (`Flexible(child: Text(label, overflow: TextOverflow.ellipsis))`) correctly stops the overflow *assertion*, but `Flexible` has no lower bound — it will happily shrink the `Text` to whatever sliver of space is left after `SegmentedButton`'s own internal padding, the Material checkmark icon it auto-adds for the selected segment, the 6px accent dot, and the 4px `SizedBox` spacing, even if that's only 20px. The fix solved "does it crash/warn" but not "is it still legible" — those are two different bars, and only the first was checked (by both QA round 1 and Debug) before signing off.

Fix (not applied by QA — reported for Debug Engineer): several options, pick with AI Design's input since this is a visual/UX call, not purely technical:
1. Drop the dot+spacing from the label `Row` entirely when the *combined* label+dot would need more width than some safe minimum, falling back to plain `Text` with normal ellipsis (i.e. same behavior as the 3 inactive segments) — accepting that the Rainbow accent simply doesn't render on the widest segment on narrow screens, rather than sacrificing the text.
2. Move the accent indicator to not compete with the label's horizontal space at all (e.g. a small dot/bar *below* or *above* the segment instead of inline before the text) — this was actually DS-009's own design doc's *other* option (an underline indicator) before this round's implementation chose the inline-dot approach as a "safer to implement" simplification; revisiting that alternative may resolve this for good.
3. Give the dot+text `Row` a `mainAxisSize: MainAxisSize.min` *and* wrap the whole `SegmentedButton` (or just this segment) with a minimum-width guarantee so `Flexible` has a floor it won't shrink below, then let `SegmentedButton` itself scroll/wrap if it truly doesn't fit — more invasive, likely overkill for a decorative element.

Recommendation: **not for QA to decide** — flag to AI Design for a quick read on which of the above (or another option) preserves DS-009's intent best, since all three change what a user actually sees, not just plumbing.

Files likely affected: `app/lib/features/home/presentation/home_feed_screen.dart` (`_segment` method only, same as round 1's Bug 2).

Regression Risk: same as before — isolated to this one decorative element, no schema/other-screen impact.

Handoff to QA: round 3, once fixed — re-run this exact width matrix (or an equivalent regression test committed to the suite) and confirm the active "จาก Club ของคุณ" segment's label is legible (not just non-crashing) at 360-430px specifically, not only that `flutter test`'s default 800px viewport looks fine.
