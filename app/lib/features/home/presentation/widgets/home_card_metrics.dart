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
const double homeCardEdgeInset = WynSpacing.space4;

/// The avatar's diameter, and so the width of the card's left column.
/// 44px keeps the feed compact while matching the slightly larger
/// profile treatment requested for the X/Threads-like visual weight.
const double homeCardAvatarDiameter = 44;

/// Founder-marked vertical position: the avatar's top edge starts on the
/// visual text line instead of at the top edge of the whole post row.
const double homeCardAvatarTopInset = WynSpacing.space4;

/// Gap between the avatar column and the content column.
/// The avatar grew by 4px, so this gap tightens by the same amount to keep
/// the already-approved content column at x=68 instead of pushing the
/// name, caption and media to the right.
const double homeCardAvatarGap = WynSpacing.space2;

/// Where the content column starts, measured from the screen edge:
/// 16 + 44 + 8 = 68 on any width. The avatar gets more visual weight
/// without moving the name/caption/photo alignment the Founder already
/// approved.
const double homeCardContentInset =
    homeCardEdgeInset + homeCardAvatarDiameter + homeCardAvatarGap;

/// Founder-approved vertical rhythm around Home feed post boundaries.
/// Divider -> post header, content/media -> action row, and action row ->
/// divider all use this same 6px target.
const double homePostVerticalRhythm = 6;

/// Caption text is intentionally lifted 3px toward the author row. Transform
/// does not affect layout, so the trailing layout gap is reduced by the same
/// amount to keep the visible caption/hashtag -> action/media gap at 6px.
const double homePostCaptionLift = 3;
const double homePostCaptionTrailingLayoutGap =
    homePostVerticalRhythm - homePostCaptionLift;
