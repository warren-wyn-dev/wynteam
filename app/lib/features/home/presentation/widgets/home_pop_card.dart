import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../pop/presentation/widgets/pop_clip_view.dart' show popShareLink;
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/home_feed_item.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/action_sheet_row.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../../../../core/widgets/hashtag_text.dart';
import 'liked_by_row.dart';

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
/// .wyn/docs/design/wyn-007-home.md, Design Rules.
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

  Future<void> _openMoreMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        ActionSheetRow(
          icon: Icons.visibility_off_outlined,
          label: 'ไม่สนใจโพสต์นี้',
          onTap: () {
            Navigator.of(sheetContext).pop();
            onHide?.call();
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'วิดีโอของ ${item.authorNameOrUsername} ความยาว ${item.durationSeconds} วินาที',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space1),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onOpenProfile,
                        borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AvatarCircle(
                              imageUrl: item.authorAvatarUrl,
                              fallbackText: item.authorUsername,
                              radius: 16,
                            ),
                            const SizedBox(width: WynSpacing.space2),
                            Text(
                              item.authorNameOrUsername,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_isOwnPop && onHide != null)
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'เพิ่มเติม',
                        onPressed: () => _openMoreMenu(context),
                      ),
                  ],
                ),
              ),
              DoubleTapLike(
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
                        Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
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
              if (item.caption != null && item.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: HashtagText(item.caption!),
                ),
              if (item.likedBy.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: LikedByRow(
                    likedBy: item.likedBy,
                    totalLikeCount: item.likeCount,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space1),
                child: Row(
                  children: [
                    Semantics(
                      label: item.likedByMe
                          ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ'
                          : 'กดเพื่อถูกใจ',
                      excludeSemantics: true,
                      child: IconButton(
                        icon: Icon(
                          item.likedByMe ? Icons.favorite : Icons.favorite_border,
                          color: item.likedByMe ? Colors.red : null,
                        ),
                        onPressed: onToggleLike,
                      ),
                    ),
                    Text('${item.likeCount}'),
                    const SizedBox(width: WynSpacing.space2),
                    Semantics(
                      label: 'ดูคอมเมนต์',
                      excludeSemantics: true,
                      child: IconButton(
                        icon: const Icon(Icons.mode_comment_outlined, size: 20),
                        onPressed: onTapComment ?? onTap,
                      ),
                    ),
                    Text('${item.commentCount}'),
                    Semantics(
                      label: 'แชร์',
                      excludeSemantics: true,
                      child: IconButton(
                        icon: const Icon(Icons.share_outlined, size: 20),
                        onPressed: _share,
                      ),
                    ),
                    const Icon(Icons.visibility_outlined, size: 18),
                    const SizedBox(width: WynSpacing.space1),
                    Text('${item.viewCount}'),
                    const Spacer(),
                    Semantics(
                      label: item.savedByMe
                          ? 'บันทึกแล้ว กดเพื่อเอาออกจาก Saved'
                          : 'กดเพื่อบันทึก',
                      excludeSemantics: true,
                      child: IconButton(
                        icon: Icon(
                          item.savedByMe ? Icons.bookmark : Icons.bookmark_border,
                        ),
                        onPressed: onToggleSave,
                      ),
                    ),
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
