import 'package:flutter/material.dart';

import '../../data/home_feed_item.dart';
import '../design/wynos_home_tokens.dart';

/// WYNOS Home reference spec 4.8 -- the Liked-by row: up to 3
/// overlapping mini-avatars, then "ถูกใจโดย {first name}" (+ "และอีก
/// {N} คน" once there are more). Exists specifically so likes read as
/// people you might know, not an anonymous counter -- never render a
/// plain number in its place when [likedBy] data is actually available.
class WynosLikedByRow extends StatelessWidget {
  const WynosLikedByRow({
    super.key,
    required this.likedBy,
    required this.likeCount,
  });

  final List<HomeLiker> likedBy;

  /// The current (already-optimistically-updated) total -- callers
  /// pass HomeFeedItem.likeCount directly, same as ActionBar's own
  /// like count.
  final int likeCount;

  @override
  Widget build(BuildContext context) {
    // Hidden entirely if total like count is 0 -- do not render an
    // empty "liked by" row.
    if (likeCount <= 0) return const SizedBox.shrink();

    final shown = likedBy.take(3).toList();

    if (shown.isEmpty) {
      // Graceful fallback for a row that hasn't been given liked_by
      // data at all (e.g. the hashtag feed, sourced from
      // HomeFeedItem.fromDrop -- see that field's own doc comment) --
      // a plain count reads better than rendering nothing when there
      // is unambiguously at least one real like.
      return Padding(
        padding: const EdgeInsets.only(top: 10), // mt-2.5
        child: Text('ถูกใจ $likeCount คน', style: WynosHomeText.likedByText),
      );
    }

    final extra = likeCount - shown.length;
    return Padding(
      padding: const EdgeInsets.only(top: 10), // mt-2.5
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: shown.length * 12 + 10,
            height: 18,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  _MiniAvatar(liker: shown[i], offset: i * 12.0),
              ],
            ),
          ),
          const SizedBox(width: 8), // gap-2
          Flexible(
            child: Text.rich(
              TextSpan(
                style: WynosHomeText.likedByText,
                children: [
                  const TextSpan(text: 'ถูกใจโดย '),
                  TextSpan(
                    text: shown.first.nameOrUsername,
                    style: WynosHomeText.likedByName,
                  ),
                  if (extra > 0) TextSpan(text: ' และอีก $extra คน'),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.liker, required this.offset});

  final HomeLiker liker;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = liker.avatarUrl;
    final initial =
        liker.nameOrUsername.isNotEmpty ? liker.nameOrUsername[0].toUpperCase() : '?';

    return Positioned(
      left: offset,
      child: Semantics(
        label: 'รูปโปรไฟล์ของ ${liker.nameOrUsername}',
        image: true,
        excludeSemantics: true,
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: WynosHomeColors.sapphire,
            border: Border.all(color: WynosHomeColors.paper, width: 1.5),
            image: avatarUrl != null
                ? DecorationImage(
                    image: NetworkImage(avatarUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatarUrl == null
              ? Text(initial, style: WynosHomeText.miniAvatarInitial)
              : null,
        ),
      ),
    );
  }
}
