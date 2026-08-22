# Design — WYN-024 follow-up: Home feed-mode selector becomes horizontally scrollable

Owner: AI Design → AI Coding
Ref: `.wyn/docs/design/wyn-024-bottom-nav-v1-restructure.md` (Screen 2, superseded Responsive Behavior section), `.wyn/tasks/bugs/WYN-024-segmented-button-active-label-illegible-all-segments.md` (QA round 3 finding + Debug round 3 partial fix + QA round 4 verification)

## Context — why this exists

The original Screen 2 spec anticipated overflow risk on narrow phones and delegated a fallback to Coding ("ถ้าคับให้ยุบ label เหลือไอคอน+tooltip", threshold "< 360px"). That assumption turned out to be wrong on two counts, both confirmed with real `RenderParagraph` measurements across 4 rounds of QA/Debug:

1. The failure zone is not an edge case below 360px — it's **every real phone width tested, 360-430px** — for "สำหรับคุณ" (the default active segment on every app launch) and "จาก Club ของคุณ".
2. The root cause was never really about label length. `SegmentedButton` divides its row width equally across all 4 segments regardless of content, and the auto-added selected-checkmark icon eats further fixed width from whichever segment happens to be active. Debug Engineer's round 3 fix (`showSelectedIcon: false` + tighter padding) fully resolved 2 of 4 segments ("ติดตาม"/"ล่าสุด") but structurally cannot resolve the other 2 — their full text (141px/211.5px) needs more room than any amount of padding-trimming inside a 4-way equal split of a 360-430px screen can offer.

This is an AI Design decision, made under `.wyn/company/RULES.md`'s "สิ่งที่ AI Team ทำได้โดยไม่ต้องขออนุมัติล่วงหน้า: ออกแบบ" — a single component's interaction pattern is not on the Founder-authority list (Core Vision/Business Model/Major Architecture/Security/Auth/destructive DB/production infra/AI governance/approval rules). Unlike DS-009's Design System color question, this doesn't need a Founder popup.

## Options considered

**A. Icon + tooltip fallback (the original spec's own idea)** — rejected. The 4 feed modes are abstract states (For You / Following / Latest / From your Clubs), not concrete objects. There's no icon set a first-time user would reliably map to these 4 concepts without memorizing them first, especially "สำหรับคุณ" vs "ล่าสุด" (For You vs. Latest — both plausibly a clock or star icon). Trading full readability for icon guesswork is a worse UX regression than the bug it's meant to fix.

**B. Shorten the label text** (raised as a fast-follow suggestion in the round-2 Debug report) — rejected as insufficient on its own, confirmed by measurement: even "สำหรับคุณ" — already among the shortest natural phrasings — needs 141px, more than a 4-way equal split of any real phone width offers. Shortening text alone doesn't change the width-allocation model that's the actual root cause.

**C. Replace with a dropdown/menu control showing only the current mode** — rejected. This solves legibility trivially (only one label needs to fit at a time, easily within any phone width) but changes the core interaction paradigm from "see all 4 options and the current selection at a glance" to "tap to reveal a hidden list" — a bigger UX paradigm shift than this bug requires. `SegmentedButton`'s whole value (an Instagram/TikTok-adjacent, immediately-scannable mode switcher) would be lost.

**D. Horizontally scrollable segmented row, each segment sized to its own natural (intrinsic) content width — chosen.** Every label keeps its full, unabbreviated text — no copy changes, no icon substitution. `SegmentedButton` stops being forced to fill/equally-divide the row width; instead it's wrapped so each segment gets exactly the width its own label needs, and the whole row scrolls horizontally when the combined width exceeds the screen. This is a standard, well-understood Material/iOS pattern (scrollable tab/chip rows) that needs no new Design System component and preserves the original "see everything at a glance" intent — on any screen wide enough to fit all 4 without scrolling (most tablets, desktop web), it behaves identically to today with zero visible change.

## Design Decision

Keep all 4 existing labels exactly as-is: "สำหรับคุณ" / "ติดตาม" / "ล่าสุด" / "จาก Club ของคุณ" (**Option D**). No copy changes, no icon changes, no change to which modes exist or their order (still: สำหรับคุณ → ติดตาม → ล่าสุด → จาก Club ของคุณ, per the original WYN-024 spec).

Components:
- The `SegmentedButton<_HomeFeedMode>` itself stays the same widget with the same 4 segments, `showSelectedIcon: false`, and the tightened padding from Debug round 3 (both still correct and worth keeping — they're a net improvement even after this change, since they make the "ติดตาม"/"ล่าสุด" segments narrower and leave more scroll room for the other two).
- Wrap it so it is no longer forced to stretch to the full row width — each segment should size to its own label's natural width instead of an equal 4-way split.
- Make the row horizontally scrollable when the segments' combined natural width exceeds the available width. On a screen wide enough to fit all 4 without scrolling, there must be no visible difference from today (no unnecessary empty scroll space, no forced full-width stretch).

Interactions: identical to today — tapping a segment selects it exactly as before. Additionally: if the newly-active segment isn't fully within the visible scroll viewport (e.g. user scrolled right to tap "จาก Club ของคุณ", then somehow another segment becomes active another way), the row should scroll to bring the active segment fully into view — this matters less here since selection only ever happens via direct tap on a visible segment, but keep it in mind if a future feature ever changes selection programmatically.

States: no new state. Scroll position is not persisted — resets naturally each time `HomeFeedScreen` remounts, consistent with the existing "feed mode always resets to สำหรับคุณ on fresh mount" behavior already established in this screen.

Responsive Behavior: this *is* the responsive behavior fix — supersedes the original spec's icon+tooltip idea entirely (see the updated note in `wyn-024-bottom-nav-v1-restructure.md`'s Screen 2). No breakpoint/threshold logic needed: the scroll either activates naturally (content wider than viewport) or doesn't (content fits) — same mechanism handles every screen size from the narrowest supported phone up through tablet/desktop-web without a hardcoded px cutoff.

Accessibility:
- Semantics: each segment's accessible label must stay the full, untruncated text (already true today, keep as-is) — a screen reader must read "จาก Club ของคุณ", not a truncated form, regardless of what's visible on-screen.
- The scrollable row must be reachable via standard scroll semantics (swipe/scroll gestures for screen reader users) — Flutter's default horizontal scroll semantics handle this without extra work, just don't suppress/override them.
- Existing focus/traversal order across the 4 segments is unaffected by this change.

Design Rules: no Design System token changes — same `SegmentedButton`, same colors, same DS-009 Rainbow accent strip below it (Cyan/rainbow tokens untouched, per DS-001–009).

**Note to Coding on DS-009's Rainbow indicator strip**: the indicator strip added in Debug round 2 (`.wyn/docs/design/ds-009-rainbow-accent.md`) currently positions itself by dividing the available width evenly by segment count (`constraints.maxWidth / modes.length`) — that assumption breaks once segments are no longer equal width. The indicator must be repositioned to track each segment's *actual* rendered x-offset and width (whatever layout mechanism ends up computing per-segment geometry), not an assumed equal split — this is an implementation detail left to Coding's judgment on the exact technique, but the requirement is: **the indicator must always sit directly under whichever segment is currently active, regardless of that segment's real on-screen width or position**, exactly as DS-009's original spec already required ("นอก touch target เดิมของปุ่ม ไม่ทับตัวหนังสือ").

Handoff: ส่ง AI Coding — ไฟล์ที่แก้: `app/lib/features/home/presentation/home_feed_screen.dart` (`_buildFeedModeToggle` — เปลี่ยนโครง `SegmentedButton` ให้ scroll แนวนอนได้ตามข้างต้น + แก้ indicator strip ให้ track ตำแหน่งจริงของ segment ที่ active แทนการหารเท่ากัน) — ทดสอบด้วย widget test ที่ความกว้างจริง 360-430px (ใช้เทคนิคเดิมที่ QA/Debug ใช้ตลอด 4 รอบที่ผ่านมา: `RenderParagraph`/`didExceedMaxLines`) ยืนยันว่าทั้ง 4 segment ไม่มีตัวไหนถูกตัดข้อความอีกเลย ไม่ใช่แค่ 2 ตัวที่เคยแก้ได้ก่อนหน้า
