/// The two-column geometry every card in the Home feed is laid out on
/// -- WYN-107, `.wyn/docs/design/wyn-107-home-feed-two-column-layout.md`.
///
/// The avatar is the card's own left column; the author's name, the
/// caption, the photos, the liked-by row, the action bar and the top
/// reply all live in one right column that starts at the name. Before
/// this, a card was a full-width stack: the avatar sat on the header
/// row only and everything under it ran back to the screen edge, so the
/// action bar was in a different vertical line from the name it belongs
/// to -- Founder, 2026-09-03, circling that row: "ปุ่มควรขยับ ให้ตรงชื่อ".
///
/// Shared by [HomeDropCard] and [HomePopCard] (and by the image row
/// between them) rather than written out in each: the two cards sit in
/// the same feed, one after the other, so a value that drifts in one of
/// them is immediately visible as two card styles in one scroll --
/// which is the reason the Founder asked for the Pop card to be changed
/// alongside the Drop card at all ("ให้ทั้งฟีดหน้าตาเหมือนกัน").
library;

import '../../../../core/design/wyn_spacing.dart';

/// The card's inset from the screen edge, left and right. Every section
/// of the card respects it -- except the photo row, which deliberately
/// bleeds past the right one (Design Rule 2: overflow the right edge
/// only, never the left, which is the whole alignment this task is
/// about).
const double homeCardEdgeInset = WynSpacing.space6;

/// The avatar's diameter, and so the width of the card's left column.
const double homeCardAvatarDiameter = 40;

/// Gap between the avatar column and the content column.
///
/// Deliberately not a [WynSpacing] token: `design-reference/01-home.tsx`
/// sets `gap-3.5` (14px) on this exact row, and the 4px grid has no 14
/// (it has 12 and 16). A micro-spacing exception of the same kind
/// DS-008 §2 already accepted -- copied from the reference the Founder
/// approved, not a number invented here.
const double homeCardAvatarGap = 14;

/// Where the content column starts, measured from the screen edge:
/// 24 + 40 + 14 = 78 on any width. Every section of a card lines up
/// here, including the photo row's left edge.
const double homeCardContentInset =
    homeCardEdgeInset + homeCardAvatarDiameter + homeCardAvatarGap;
