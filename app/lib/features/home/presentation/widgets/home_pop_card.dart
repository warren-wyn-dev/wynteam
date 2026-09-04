import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../pop/presentation/widgets/pop_clip_view.dart' show popShareLink;
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/home_feed_item.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/action_metric.dart';
import '../../../../core/widgets/wyn_heart_icon.dart';
import '../../../../core/widgets/action_sheet_row.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../../../../core/widgets/hashtag_text.dart';
import 'home_card_metrics.dart';
import 'liked_by_row.dart';
import 'top_reply_preview.dart';
import 'verified_badge.dart';
import '../../../../core/widgets/network_thumbnail.dart';

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
    this.showViewCount = true,
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

  /// WYN-088 (Wynos V1.0.0 Beta2, item 27): same eye/view-count toggle
  /// as [HomeDropCard]'s identical field -- see that doc comment.
  /// Defaults to true; only home_feed_screen.dart passes false.
  final bool showViewCount;

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
        // WYNOSHomeSpec.md 4.6: Share/Save deliberately live here now,
        // not in the action bar (see that section's own "deliberate
        // simplification" note) -- always offered first, regardless of
        // authorship, ahead of the authorship-gated Hide row below.
        ActionSheetRow(
          icon: Icons.share_outlined,
          label: 'แชร์',
          onTap: () {
            Navigator.of(sheetContext).pop();
            _share();
          },
        ),
        ActionSheetRow(
          icon: item.savedByMe ? Icons.bookmark : Icons.bookmark_border,
          label: item.savedByMe ? 'เอาออกจากบันทึก' : 'บันทึก',
          onTap: () {
            Navigator.of(sheetContext).pop();
            onToggleSave();
          },
        ),
        // WYNOS Unified Home Feed Algorithm V1.0 -- only someone else's
        // Pop can be Hidden from your own feed. Previously this whole
        // row's *visibility* was gated by never showing the "..."
        // button at all on your own Pop (the button is now always
        // shown, since Share/Save above apply regardless of
        // authorship), so the guard moves onto this row directly.
        if (!_isOwnPop && onHide != null)
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
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WYN-107: the same two columns HomeDropCard uses -- these
              // two cards sit one after the other in the same feed, so
              // they are laid out on one shared geometry
              // (home_card_metrics.dart) rather than each carrying its
              // own copy of the numbers.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: homeCardEdgeInset),
                    child: InkWell(
                      onTap: onOpenProfile,
                      borderRadius:
                          BorderRadius.circular(WynSpacing.radiusFull),
                      child: AvatarCircle(
                        imageUrl: item.authorAvatarUrl,
                        fallbackText: item.authorUsername,
                        radius: homeCardAvatarDiameter / 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: homeCardAvatarGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(right: homeCardEdgeInset),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: onOpenProfile,
                                  borderRadius: BorderRadius.circular(
                                      WynSpacing.radiusSm),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.authorNameOrUsername,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (item.authorIsVerified) ...[
                                        const SizedBox(
                                            width: WynSpacing.space1),
                                        const VerifiedBadge(),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // WYNOSHomeSpec.md 4.6: always shown now,
                              // even on the viewer's own Pop --
                              // Share/Save moved in here from the action
                              // bar apply regardless of authorship.
                              // _openMoreMenu itself still decides
                              // whether the authorship-gated Hide row
                              // appears underneath those two.
                              IconButton(
                                icon: const Icon(Icons.more_vert),
                                tooltip: 'เพิ่มเติม',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: WynSpacing.touchTargetMin,
                                  height: WynSpacing.touchTargetMin,
                                ),
                                onPressed: () => _openMoreMenu(context),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.only(right: homeCardEdgeInset),
                          child: DoubleTapLike(
                            onLike: onToggleLike,
                            alreadyLiked: item.likedByMe,
                            child: ClipRRect(
                              // Rounded for the same reason the Drop
                              // card's own photo is (WYN-107): inside
                              // the column, a square corner on white
                              // reads as unfinished.
                              borderRadius:
                                  BorderRadius.circular(WynSpacing.radiusLg),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (item.thumbnailUrl != null)
                                      Image.network(
                                        item.thumbnailUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: networkImageErrorBuilder,
                                      )
                                    else
                                      Container(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
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
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _formatDuration(
                                                item.durationSeconds!),
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
                        ),
                        if (item.caption != null && item.caption!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                0, WynSpacing.space2, homeCardEdgeInset, 0),
                            child: HashtagText(item.caption!),
                          ),
                        if (item.likedBy.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                0, WynSpacing.space2 + 2, homeCardEdgeInset, 0),
                            child: LikedByRow(
                              likedBy: item.likedBy,
                              totalLikeCount: item.likeCount,
                            ),
                          ),
                        Padding(
                          // WYN-096 aligned this row with the rest of
                          // the card; WYN-107 moved the card into a
                          // content column, so that alignment is now the
                          // column's own left edge -- same change, same
                          // reason, as HomeDropCard's identical row.
                          padding:
                              const EdgeInsets.only(right: homeCardEdgeInset),
                          child: Row(
                            children: [
                              // Same WYNOSHomeSpec.md 4.9 sizing/color as
                              // HomeDropCard's action bar (see that file) -- Pop
                              // has no ReDrop concept, so only 3 of the 4 spec'd
                              // metrics apply here. Share/Bookmark moved into
                              // the "..." menu (see _openMoreMenu, spec 4.6).
                              ActionMetric(
                                icon: WynHeartIcon(
                                  filled: item.likedByMe,
                                  size: 17,
                                  color: item.likedByMe
                                      ? WynColors.iconLikeActive
                                      : WynColors.iconIdle,
                                ),
                                iconState: item.likedByMe,
                                count: item.likeCount,
                                color: item.likedByMe
                                    ? WynColors.iconLikeActive
                                    : WynColors.iconIdle,
                                semanticsLabel: item.likedByMe
                                    ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ'
                                    : 'กดเพื่อถูกใจ',
                                onTap: onToggleLike,
                              ),
                              const SizedBox(width: WynSpacing.space5),
                              ActionMetric(
                                icon: const Icon(Icons.mode_comment_outlined,
                                    size: 17, color: WynColors.graphite),
                                iconState: Icons.mode_comment_outlined,
                                count: item.commentCount,
                                color: WynColors.graphite,
                                semanticsLabel: 'ดูคอมเมนต์',
                                onTap: onTapComment ?? onTap,
                              ),
                              // WYN-088: hidden on the Home feed (showViewCount:
                              // false there) -- HomePopCard has no other call
                              // site today, but this stays symmetric with
                              // HomeDropCard's identical toggle for whenever Pop
                              // returns to Profile (ProfilePopGridTab already
                              // exists, just unwired -- see its own doc comment).
                              if (showViewCount) ...[
                                const SizedBox(width: WynSpacing.space5),
                                ActionMetric(
                                  icon: const Icon(Icons.visibility_outlined,
                                      size: 16, color: WynColors.faint),
                                  iconState: Icons.visibility_outlined,
                                  count: item.viewCount,
                                  color: WynColors.faint,
                                  semanticsLabel:
                                      'เข้าชมแล้ว ${item.viewCount} ครั้ง',
                                  onTap: null,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (item.topReply != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(right: homeCardEdgeInset),
                            child: TopReplyPreview(
                              reply: item.topReply!,
                              onTap: onTapComment ?? onTap,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
