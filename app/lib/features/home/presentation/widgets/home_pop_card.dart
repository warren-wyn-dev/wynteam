import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../pop/presentation/widgets/pop_clip_view.dart' show popShareLink;
import '../../data/home_feed_item.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wynos_home_tokens.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../../../../core/widgets/hashtag_text.dart';
import '../../../../core/widgets/wynos_ringed_avatar.dart';

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
///
/// WYN-072 (WYNOS Design Reference Rollout, Screen 01): restyled with the
/// same WynosHomeTokens palette/type as HomeDropCard, and Share/Save
/// moved out of the action row into the "⋯" more-options menu -- see
/// HomeDropCard's class doc comment for the full reasoning (the
/// `/SPEC.md` reference has no video/Pop concept at all, so this applies
/// the same visual language to Pop's own pre-existing action set rather
/// than inventing one). No Repost/ReDrop icon here -- Pop never had one
/// (ReDrop doesn't apply to Pop content, unchanged from before this
/// task).
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

  /// WYN-072 (SPEC.md Section 4.6 point 4): Share/Save moved here from
  /// the action row (see HomeDropCard's identically-shaped
  /// `_openMoreMenu` for the full reasoning) -- one shared menu with the
  /// pre-existing Hide entry, not a second "⋯" button.
  Future<void> _openMoreMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text('แชร์',
                  style: WynosHomeTokens.bodySmall(color: WynosHomeTokens.ink)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _share();
              },
            ),
            ListTile(
              leading: Icon(
                item.savedByMe ? Icons.bookmark : Icons.bookmark_border,
              ),
              title: Text(
                item.savedByMe ? 'เอาออกจากบันทึก' : 'บันทึก',
                style: WynosHomeTokens.bodySmall(color: WynosHomeTokens.ink),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onToggleSave();
              },
            ),
            if (!_isOwnPop && onHide != null) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('ไม่สนใจโพสต์นี้'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onHide?.call();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// See HomeDropCard._wrapSapphireLinks -- identical local `Theme`
  /// override so HashtagText's hashtag/mention color is this screen's
  /// sapphire accent, without touching HashtagText itself.
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
                            WynosRingedAvatar(
                              imageUrl: item.authorAvatarUrl,
                              fallbackText: item.authorUsername,
                              radius: 16,
                            ),
                            const SizedBox(width: WynSpacing.space2),
                            Text(
                              item.authorNameOrUsername,
                              style: WynosHomeTokens.postAuthorName,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_isOwnPop && onHide != null)
                      IconButton(
                        icon: const Icon(Icons.more_horiz,
                            size: 16, color: WynosHomeTokens.faint),
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
                  child: _wrapSapphireLinks(
                    context,
                    HashtagText(item.caption!, style: WynosHomeTokens.postBody),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(
                  left: WynSpacing.space1,
                  right: WynSpacing.space1,
                  top: WynSpacing.space3,
                ),
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
                          size: 17,
                          color: item.likedByMe
                              ? WynosHomeTokens.sapphire
                              : WynosHomeTokens.graphite,
                        ),
                        onPressed: onToggleLike,
                      ),
                    ),
                    Text('${item.likeCount}', style: WynosHomeTokens.caption()),
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
                    Text('${item.commentCount}', style: WynosHomeTokens.caption()),
                    const SizedBox(width: WynSpacing.space5),
                    Icon(Icons.visibility_outlined,
                        size: 16, color: WynosHomeTokens.faint),
                    const SizedBox(width: WynSpacing.space1),
                    Text('${item.viewCount}',
                        style: WynosHomeTokens.caption(
                            color: WynosHomeTokens.faint)),
                    // WYN-072 (SPEC.md Section 4.9): Share and Save are
                    // no longer in this row -- see [_openMoreMenu].
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
