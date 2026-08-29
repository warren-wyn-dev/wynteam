import 'package:flutter/material.dart';

import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wynos_home_tokens.dart';
import '../../../../core/text_utils.dart';
import '../../../../core/widgets/hashtag_text.dart';

/// A single full-width post row for WYN-073's own-profile view (Screen
/// 05 of the WYNOS design reference, `/05-profile.tsx`'s `PostRow` +
/// `ActionBar`) -- timestamp, full caption text (hashtags rendered
/// inline in sapphire via [HashtagText], not stripped into a separate
/// line below like the static `.tsx` mockup, so the existing tap-to-
/// hashtag-feed/tap-to-mentioned-profile behavior everywhere else in the
/// app keeps working here too), then a 4-icon action bar (Heart/
/// Comment/Repost/Eye) styled to match WYN-072's `HomeDropCard` action
/// bar exactly (icon sizes, `WynosHomeTokens.caption()` count labels,
/// `WynSpacing.space5` gaps, sapphire-when-active icon color) --
/// SPEC.md Section 4.9, reused for visual consistency between the two
/// screens' post rows even though this file predates a shared
/// post-row/action-bar widget existing.
///
/// Deliberately its own widget rather than a restyle of `HomeDropCard`
/// (app/lib/features/home/presentation/widgets/home_drop_card.dart):
/// that card's own layout (avatar + author name/handle header, image
/// carousel) doesn't fit `/05-profile.tsx`'s row shape (no author
/// identity per row -- it's always the profile owner's own post, and
/// the reference explicitly says posts render as full-width *text* rows
/// "instead of a 3-column image-grid ... WYNOS posts are text-first").
/// Once there's a genuinely shared post-row primitive both screens can
/// use as-is, this and `HomeDropCard`'s action-bar block should be
/// consolidated into one widget -- see WYN-073's task file, Known
/// Issues.
class WynosPostRow extends StatelessWidget {
  const WynosPostRow({
    super.key,
    required this.createdAt,
    required this.caption,
    required this.likeCount,
    required this.likedByMe,
    required this.commentCount,
    required this.redropCount,
    required this.viewCount,
    required this.onTap,
    required this.onToggleLike,
    this.onTapComment,
    this.onTapRedrop,
    this.redroppedByMe = false,
    this.trailing,
    this.attributionLabel,
    this.onTapAttribution,
    this.quoteText,
    this.showBottomDivider = true,
  });

  final DateTime createdAt;
  final String caption;
  final int likeCount;
  final bool likedByMe;
  final int commentCount;
  final int redropCount;
  final int viewCount;

  /// Opens the post's detail screen -- the whole row is tappable (same
  /// posture as HomeDropCard's own outer InkWell), independent of the
  /// action bar's own per-icon tap targets below.
  final VoidCallback onTap;

  final VoidCallback onToggleLike;

  /// Defaults to [onTap] when null -- tapping the comment icon/count
  /// opens the same detail screen the rest of the row does, same as
  /// HomeDropCard's comment icon.
  final VoidCallback? onTapComment;

  /// Null means the Repost icon/count is display-only (no action sheet)
  /// -- this is the case for own-profile's "โพสต์"/"ถูกใจ" tabs, which
  /// never offered a ReDrop action even before this row style existed
  /// (the 3-column grid they replaced had none either); non-null on the
  /// "ReDrop" tab, which already had this action via `HomeDropCard`.
  final VoidCallback? onTapRedrop;
  final bool redroppedByMe;

  /// Extra content between the caption and the action bar -- used to
  /// carry an existing `PollCard` through unchanged when the underlying
  /// Drop is a Poll, without this file needing to know anything about
  /// Poll rendering itself.
  final Widget? trailing;

  /// "ReDrop โดย @username" line, shown above the timestamp -- only
  /// non-null on the "ReDrop" tab.
  final String? attributionLabel;
  final VoidCallback? onTapAttribution;

  /// A Quote ReDrop's own commentary -- shown above [caption] (which
  /// still always describes the *original* Drop), same "quote text,
  /// then the original post" order HomeDropCard already uses. Only
  /// non-null on the "ReDrop" tab, and only for a Quote (not Standard)
  /// ReDrop.
  final String? quoteText;

  /// False for the last row in a list -- matches `/05-profile.tsx`'s own
  /// `isLast` prop (no divider after the final row).
  final bool showBottomDivider;

  /// Local-only override so [HashtagText]'s hashtag/mention spans
  /// (which read `Theme.of(context).colorScheme.primary`) render
  /// sapphire here, without touching WynTheme/WynColors globally --
  /// mirrors HomeDropCard._wrapSapphireLinks exactly (same reasoning:
  /// every other screen still needs the old Cyan-based theme until its
  /// own turn in the rollout).
  Widget _wrapSapphireLinks(BuildContext context, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: scheme.copyWith(primary: WynosHomeTokens.sapphire),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        decoration: BoxDecoration(
          border: showBottomDivider
              ? const Border(
                  bottom: BorderSide(color: WynosHomeTokens.hairline, width: 1),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attributionLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: WynSpacing.space1),
                child: InkWell(
                  onTap: onTapAttribution,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.repeat,
                          size: 14, color: WynosHomeTokens.graphite),
                      const SizedBox(width: WynSpacing.space1),
                      Text(
                        attributionLabel!,
                        style: WynosHomeTokens.redropAttribution,
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              relativeTimeLabel(createdAt, now: DateTime.now()),
              style: WynosHomeTokens.caption(),
            ),
            if (quoteText != null && quoteText!.isNotEmpty) ...[
              const SizedBox(height: WynSpacing.space2),
              _wrapSapphireLinks(
                context,
                HashtagText(quoteText!, style: WynosHomeTokens.postBody),
              ),
            ],
            if (caption.isNotEmpty) ...[
              const SizedBox(height: WynSpacing.space2),
              _wrapSapphireLinks(
                context,
                HashtagText(caption, style: WynosHomeTokens.postBody),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(height: WynSpacing.space2),
              trailing!,
            ],
            Padding(
              padding: const EdgeInsets.only(top: WynSpacing.space3),
              child: Row(
                children: [
                  Semantics(
                    label: likedByMe
                        ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ'
                        : 'กดเพื่อถูกใจ',
                    excludeSemantics: true,
                    child: IconButton(
                      icon: Icon(
                        likedByMe ? Icons.favorite : Icons.favorite_border,
                        size: 17,
                        color: likedByMe
                            ? WynosHomeTokens.sapphire
                            : WynosHomeTokens.graphite,
                      ),
                      onPressed: onToggleLike,
                    ),
                  ),
                  Text('$likeCount', style: WynosHomeTokens.caption()),
                  const SizedBox(width: WynSpacing.space5),
                  Semantics(
                    label: 'ดูคอมเมนต์',
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(
                        Icons.mode_comment_outlined,
                        size: 17,
                        color: WynosHomeTokens.graphite,
                      ),
                      onPressed: onTapComment ?? onTap,
                    ),
                  ),
                  Text('$commentCount', style: WynosHomeTokens.caption()),
                  const SizedBox(width: WynSpacing.space5),
                  Semantics(
                    label: onTapRedrop == null
                        ? 'ReDrop $redropCount ครั้ง'
                        : (redroppedByMe
                            ? 'ReDrop แล้ว กดเพื่อเลือกดำเนินการ'
                            : 'กดเพื่อ ReDrop'),
                    button: onTapRedrop != null,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: Icon(
                        Icons.repeat,
                        size: 17,
                        color: redroppedByMe
                            ? WynosHomeTokens.sapphire
                            : WynosHomeTokens.graphite,
                      ),
                      onPressed: onTapRedrop,
                    ),
                  ),
                  Text('$redropCount', style: WynosHomeTokens.caption()),
                  const SizedBox(width: WynSpacing.space5),
                  // SPEC.md Section 4.9: view count is display-only,
                  // never tappable, `faint` (one shade lighter than the
                  // 3 tappable icons before it) -- same posture as
                  // HomeDropCard's own view-count block.
                  Semantics(
                    label: 'เข้าชมแล้ว $viewCount ครั้ง',
                    excludeSemantics: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: WynosHomeTokens.faint,
                        ),
                        const SizedBox(width: WynSpacing.space1),
                        Text(
                          '$viewCount',
                          style: WynosHomeTokens.caption(
                              color: WynosHomeTokens.faint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
