import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/text_utils.dart';
import '../../../../core/widgets/hashtag_text.dart';
import '../../../home/data/home_feed_item.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../../../core/widgets/network_thumbnail.dart';

/// One row of the Bookmarks list (15-bookmarks.tsx's `SavedRow`) --
/// avatar, name, relative time, caption, like/comment/repost counts, and
/// a filled bookmark button that unsaves this item.
///
/// Deliberately its own widget rather than a reuse/trim of
/// HomeDropCard/HomePopCard: those carry image-as-hero, video, poll,
/// ReDrop, and "..." more-menu weight the mockup's plain text-first row
/// doesn't have, and this pass is scoped to just the Bookmarks screen --
/// ProfileSavedTab's own 3-column grid (used on a profile's own Saved
/// tab) is untouched. Unlike the mockup, this always renders a small
/// trailing thumbnail when the saved item has one (Drop's `imageUrl` or
/// Pop's `thumbnailUrl`) -- every real Drop/Pop has one, so a text-only
/// row would silently hide real content the mockup's own two-item mock
/// data just never happened to show.
class SavedPostRow extends StatelessWidget {
  const SavedPostRow({
    super.key,
    required this.item,
    required this.isLast,
    required this.onTap,
    required this.onOpenProfile,
    required this.onUnsave,
  });

  final HomeFeedItem item;

  /// Whether this is the last row in the list -- suppresses the
  /// bottom hairline divider the reference draws between rows.
  final bool isLast;

  final VoidCallback onTap;
  final VoidCallback onOpenProfile;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = item.contentType == HomeContentType.drop
        ? item.imageUrl
        : item.thumbnailUrl;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space6,
          vertical: WynSpacing.space4,
        ),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: WynColors.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpenProfile,
              borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
              child: AvatarCircle(
                imageUrl: item.authorAvatarUrl,
                fallbackText: item.authorUsername,
                radius: 20,
                ring: true,
              ),
            ),
            const SizedBox(width: WynSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onOpenProfile,
                    borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.authorNameOrUsername,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(width: WynSpacing.space2),
                        Text(
                          relativeTimeLabel(item.createdAt, now: DateTime.now()),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: WynColors.mutedNeutral,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (item.caption != null && item.caption!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: WynSpacing.space1 + 2),
                      child: HashtagText(
                        item.caption!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: WynSpacing.space3),
                    child: Row(
                      children: [
                        _Metric(icon: Icons.favorite_border, count: item.likeCount),
                        const SizedBox(width: WynSpacing.space5),
                        _Metric(icon: Icons.mode_comment_outlined, count: item.commentCount),
                        const SizedBox(width: WynSpacing.space5),
                        _Metric(icon: Icons.repeat, count: item.redropCount),
                        const Spacer(),
                        Semantics(
                          label: 'เอาออกจากบันทึกไว้',
                          button: true,
                          excludeSemantics: true,
                          child: InkWell(
                            onTap: onUnsave,
                            borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                            child: const Padding(
                              padding: EdgeInsets.all(WynSpacing.space1),
                              child: Icon(
                                Icons.bookmark,
                                size: 18,
                                color: WynColors.sapphire,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (thumbnailUrl != null) ...[
              const SizedBox(width: WynSpacing.space3),
              ClipRRect(
                borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                // The SizedBox is load-bearing, not decoration: this row
                // is the one place a fixed-size thumbnail sits beside an
                // Expanded sibling in a Row, so an unbounded failure
                // state would overflow the row rather than just the
                // image (the reason this call site grew an errorBuilder
                // of its own before NetworkThumbnail existed). Bounding
                // it also gives NetworkThumbnail a finite width to
                // decode against, so a 56px thumbnail stops decoding a
                // full-size upload.
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: NetworkThumbnail(imageUrl: thumbnailUrl),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: WynColors.graphite),
        const SizedBox(width: WynSpacing.space1),
        Text(
          '$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: WynColors.graphite,
              ),
        ),
      ],
    );
  }
}
