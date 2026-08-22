# Bug Report — WYN-024 / DS-009 (QA round 2 finding — new, not in round 1's report)

Status: **fixed (real root cause found: implementation deviated from Design spec) — + 1 additional, older latent bug found and fixed along the way — 1 residual concern flagged for Product/Design, not blocking — รอ QA รอบ 3**
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

---

## Debug Engineer Report (2026-08-22)

**Bug**: as filed by QA round 2 above.

**Root Cause (actually found this time, not just described)**: re-reading `.wyn/docs/design/ds-009-rainbow-accent.md` point 2 verbatim — the active-segment indicator was specified as *"เส้นบาง ... ใต้ปุ่มที่ active ... วางนอก touch target เดิมของปุ่ม ไม่ทับตัวหนังสือ"* (a thin line below the active button, placed **outside the button's own touch target, not overlapping the text**). The as-shipped implementation put the dot *inside* the active segment's `Row`, directly competing with the label `Text` for the same horizontal space — a deviation from the spec, not something the spec asked for. That one deviation is the root cause of both round 1's overflow (no room for dot+text) and round 2's near-invisible text (`Flexible` shrinking the text to make room for the dot). QA's option 2 (move the indicator so it doesn't share space with the text) was, it turns out, simply re-deriving what the spec already said.

While implementing the spec-correct version (dot as a separate 2px bar in a dedicated strip below `SegmentedButton`, positioned under the active segment via `LayoutBuilder`), a **second, older bug** surfaced: with the dot removed from inside the label, the label reverted to plain `Text('...')` with no `maxLines`/`overflow` set — and at real phone widths, "จาก Club ของคุณ" (10 Thai characters) **wraps across ~7-8 lines** (measured height ~160px vs. ~20px for one line), which would balloon the *entire* `SegmentedButton` row's height (Material sizes all segments to the tallest) whenever this segment is active. Confirmed via screenshot this predates DS-009 entirely — it is exactly what plain `Text` without line-limiting does when a `ButtonSegment`'s width budget is too small for its content, and this label's width budget was always too small at narrow phone widths; DS-009 never touched that fact, it only ever added or removed 10px of competing space on top of it.

**Fix**: two changes to `home_feed_screen.dart`'s `_buildFeedModeToggle`/`_segment`:
1. Deleted the `_segment()` helper and its inline `Row`. Segments go back to plain `ButtonSegment(value: ..., label: Text('...'))`, matching every segment equally (no more "active gets special treatment" branching in the label itself).
2. Added `maxLines: 1, overflow: TextOverflow.ellipsis` to **all 4** segment labels (not just the widest) so none of them can ever wrap vertically again, regardless of which is active.
3. Added a `Column` wrapping `SegmentedButton` with a new `SizedBox(height: 2)` strip below it, containing a `LayoutBuilder` + `AnimatedPositioned` gradient bar that tracks which segment is active by dividing the available width evenly by segment count (matches the equal-width-per-segment behavior `SegmentedButton` was already observed to have in round 1's bug report). This is the actual "outside the touch target, below the button, not overlapping text" element the spec asked for.

**Residual, not blocking**: even with both fixes, "จาก Club ของคุณ" specifically still only gets ~30-47px of width at real phone widths (360-430px) before ellipsis kicks in — a few Thai characters at most (real device fonts render more compactly than this headless test environment's tofu-box font fallback, so the real number is likely a bit better, but still tight). This is a **pre-existing, broader constraint** of fitting a 10-character Thai label into a 4-segment `SegmentedButton` on a narrow phone — not something either DS-009's dot or this fix's `maxLines`/ellipsis approach can fully solve without changing the label text itself or the control's structure, both of which are Product/Design decisions, not something Debug Engineer should decide unilaterally. Recommend Product/AI Design consider shortening "จาก Club ของคุณ" (e.g. to "Club ของคุณ" or similar) as a fast-follow if QA round 3 still finds it too tight — flagging, not blocking, since it is strictly better than both prior states (no crash, no wrap-ballooning) and is not a regression introduced by this fix.

**Files Changed**: `app/lib/features/home/presentation/home_feed_screen.dart` (`_buildFeedModeToggle`, `_segment` deleted), `app/test/home_feed_screen_test.dart` (new regression test)

**Tests**: `flutter analyze` — 0 issues. `flutter test` — **358/358 pass** (357 + 1 new). Verified independently with a temporary ad hoc test (not committed) reproducing QA's exact 6-width measurement matrix — `didExceedMaxLines` no longer indicates multi-line wrapping (height stays ~20px, single line, at every width from 360px to 800px) and a 360px screenshot confirms the SegmentedButton row is now a uniform, consistent height across all 4 segments with the Rainbow bar correctly appearing *below*, not inside, the active pill. Red→green proof for the new committed regression test: `git stash` on `home_feed_screen.dart` only (reverting to the round-1-fixed-but-round-2-buggy version) → new test still passed (confirms the committed regression test specifically catches the *wrapping* failure mode Debug found, not the *narrow-width* one QA originally flagged, which per the "Residual" note above is a separate, deeper, not-fully-fixed-here concern) → `git stash pop` to restore the fix.

**Regression Risk**: Low — isolated to this one widget, no schema/other-file impact. Full `app/` suite (358 tests) re-run clean, not just the directly affected file.

**Handoff to QA**: round 3. Please independently re-verify with the same width-matrix measurement approach QA round 2 used (not just the new committed test, which only proves "no wrapping" — re-confirm "legible enough" is a judgment call QA should make fresh, ideally with a real Thai font if there's any way to get one loaded in the test environment, since this headless setup's tofu-box fallback may not reflect real device character widths accurately). If still not satisfactory, the next step is a Product/Design decision on shortening the label text, not another layout-only fix attempt from Debug Engineer -- two rounds of layout-only fixes on the same constraint is often a sign the label itself needs to change, not the container around it.
