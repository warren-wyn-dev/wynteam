import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../pop/presentation/widgets/pop_clip_view.dart' show popShareLink;
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/home_feed_item.dart';
import '../../../../core/widgets/hashtag_text.dart';
import '../design/wynos_home_tokens.dart';
import 'wynos_avatar_ring.dart';
import 'wynos_double_tap_like.dart';
import 'wynos_liked_by_row.dart';
import 'wynos_more_menu.dart';
import 'wynos_top_reply.dart';
import 'wynos_verified_badge.dart';

/// Formats a duration in seconds as "m:ss" (e.g. 45 -> "0:45").
String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// A Pop card in the Home feed. Deliberately a square thumbnail with a
/// play icon and duration badge -- not full 9:16 autoplaying video -- so
/// card heights stay consistent with HomeDropCard while scrolling and no
/// video plays until the user actually taps in. See
/// .wyn/docs/design/wyn-007-home.md, Design Rules, and the WYNOS Home
/// reference spec section 4.6/4.9 for this card's visual structure.
class HomePopCard extends StatelessWidget {
  const HomePopCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onOpenProfile,
    this.onTapComment,
    this.onHide,
  });

  final HomeFeedItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenProfile;

  /// WYN-023 (R2): the Comment icon's own tap target, distinct from
  /// [onTap] -- opens the clip with its comment sheet already showing
  /// instead of the plain clip [onTap] opens. Falls back to [onTap]
  /// when not provided, so any other caller of this card keeps its
  /// exact previous behavior unchanged.
  final VoidCallback? onTapComment;

  /// WYNOS Unified Home Feed Algorithm V1.0 -- records the "Hide" User
  /// Signal and removes this card from the feed immediately. Same
  /// "someone else's content only" gating as HomeDropCard's identical
  /// field -- see [_isOwnPop].
  final VoidCallback? onHide;

  bool get _isOwnPop =>
      item.authorId == Supabase.instance.client.auth.currentUser!.id;

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: popShareLink(item.id)),
    );
  }

  /// WYNOS Home reference spec 4.6: the `⋯` button is now always
  /// visible -- Share and Save moved in here from the action bar apply
  /// to your own Pop too, mirroring [HomeDropCard]'s identical change.
  List<WynosMenuAction> _menuActions(BuildContext context) => [
        WynosMenuAction(
          icon: Icons.share_outlined,
          label: 'แชร์',
          onTap: _share,
        ),
        WynosMenuAction(
          icon: item.savedByMe ? Icons.bookmark : Icons.bookmark_border,
          label: item.savedByMe ? 'เอาออกจาก Saved' : 'บันทึก',
          onTap: onToggleSave,
        ),
        if (!_isOwnPop && onHide != null)
          WynosMenuAction(
            icon: Icons.visibility_off_outlined,
            label: 'ไม่สนใจโพสต์นี้',
            onTap: () => onHide!(),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'วิดีโอของ ${item.authorNameOrUsername} ความยาว ${item.durationSeconds} วินาที',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WynosHomeSpacing.pagePadding,
            vertical: WynosHomeSpacing.postVertical,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onOpenProfile,
                child: WynosAvatarRing(
                  size: 40,
                  child: AvatarCircle(
                    imageUrl: item.authorAvatarUrl,
                    fallbackText: item.authorUsername,
                    radius: 20,
                  ),
                ),
              ),
              const SizedBox(width: WynosHomeSpacing.avatarContentGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // WYNOS Home reference spec 4.6 -- one inline
                    // header line (name + verified badge + relative
                    // timestamp).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: onOpenProfile,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.authorNameOrUsername,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: WynosHomeText.postAuthorName,
                                  ),
                                ),
                                if (item.authorIsVerified) ...[
                                  const SizedBox(width: 4),
                                  const WynosVerifiedBadge(size: 13),
                                ],
                              ],
                            ),
                          ),
                        ),
                        WynosMoreMenuButton(actions: _menuActions(context)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // WYNOS Home reference spec 4.7 -- same widget as
                    // HomeDropCard, not scoped to Drop content only.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: WynosDoubleTapLike(
                        onLike: onToggleLike,
                        alreadyLiked: item.likedByMe,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (item.thumbnailUrl != null)
                                Image.network(item.thumbnailUrl!, fit: BoxFit.cover)
                              else
                                Container(color: WynColors.imageScrim),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 56,
                                ),
                              ),
                              if (item.durationSeconds != null)
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: WynColors.imageScrim,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _formatDuration(item.durationSeconds!),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (item.caption != null && item.caption!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final line in item.caption!.split('\n'))
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: WynosHomeSpacing.postLineGap,
                                ),
                                child: HashtagText(
                                  line,
                                  style: WynosHomeText.postBody,
                                ),
                              ),
                          ],
                        ),
                      ),
                    // WYNOS Home reference spec 4.8 -- same widget as
                    // HomeDropCard, not scoped to Drop content only.
                    WynosLikedByRow(likedBy: item.likedBy, likeCount: item.likeCount),
                    // WYNOS Home reference spec 4.6 -- three action-bar
                    // icons (Heart/Comment/Eye; Pop has no ReDrop
                    // concept); Share and Save moved into the `⋯` menu
                    // above. Own top gap (mirrors WynosLikedByRow's
                    // mt-2.5) so the bar sits correctly even when
                    // likeCount is 0 and that row renders nothing.
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Semantics(
                            label: item.likedByMe
                                ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ'
                                : 'กดเพื่อถูกใจ',
                            excludeSemantics: true,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                item.likedByMe ? Icons.favorite : Icons.favorite_border,
                                size: 17,
                                color: item.likedByMe
                                    ? WynosHomeColors.sapphire
                                    : WynosHomeColors.graphite,
                              ),
                              onPressed: onToggleLike,
                            ),
                          ),
                          const SizedBox(width: WynosHomeSpacing.actionIconLabelGap),
                          Text('${item.likeCount}', style: WynosHomeText.actionCount),
                          const SizedBox(width: WynosHomeSpacing.actionBarGap),
                          Semantics(
                            label: 'ดูคอมเมนต์',
                            excludeSemantics: true,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.mode_comment_outlined,
                                size: 17,
                                color: WynosHomeColors.graphite,
                              ),
                              onPressed: onTapComment ?? onTap,
                            ),
                          ),
                          const SizedBox(width: WynosHomeSpacing.actionIconLabelGap),
                          Text('${item.commentCount}', style: WynosHomeText.actionCount),
                          const SizedBox(width: WynosHomeSpacing.actionBarGap),
                          Semantics(
                            label: 'เข้าชมแล้ว ${item.viewCount} ครั้ง',
                            excludeSemantics: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.visibility_outlined,
                                  size: 17,
                                  color: WynosHomeColors.graphite,
                                ),
                                const SizedBox(width: WynosHomeSpacing.actionIconLabelGap),
                                Text('${item.viewCount}', style: WynosHomeText.actionCount),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // WYNOS Home reference spec 4.10.
                    WynosTopReply(reply: item.topReply, onTap: onTapComment ?? onTap),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
