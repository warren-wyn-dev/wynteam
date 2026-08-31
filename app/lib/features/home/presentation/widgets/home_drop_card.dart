import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../drop/presentation/drop_detail_screen.dart' show dropShareLink;
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/home_feed_item.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/text_utils.dart';
import '../../../../core/widgets/action_metric.dart';
import '../../../../core/widgets/action_sheet_row.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../../../../core/widgets/hashtag_text.dart';
import 'liked_by_row.dart';
import 'top_reply_preview.dart';
import 'verified_badge.dart';
import '../../../report/data/report_repository.dart';
import '../../../report/data/report_target_type.dart';
import '../../../report/presentation/report_sheet.dart';
import '../../../drop/presentation/widgets/poll_card.dart';

/// A Drop card in the Home feed. Same visual structure as
/// HomePopCard so the two read as one family, per
/// .wyn/docs/design/wyn-007-home.md ("ทิศทางภาพรวม").
class HomeDropCard extends StatelessWidget {
  const HomeDropCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onOpenProfile,
    required this.onToggleRedrop,
    required this.onQuoteRedrop,
    this.onOpenRedropperProfile,
    this.onDeleteRedrop,
    this.onVotePoll,
    this.onHide,
  });

  final HomeFeedItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenProfile;

  /// WYN-034: Standard ReDrop toggle -- called by the action sheet's
  /// "🔄 ReDrop"/"ยกเลิก ReDrop" entry, never directly by tapping the 🔄
  /// icon itself (see [_openRedropSheet]'s doc comment for why).
  final VoidCallback onToggleRedrop;

  /// WYN-034: opens QuoteRedropScreen -- called by the action sheet's
  /// "💬 Quote ReDrop" entry.
  final VoidCallback onQuoteRedrop;

  /// WYN-034: opens the *redropper's* profile (not the original Drop's
  /// author) when [item.redropId] is set -- null (never called) for a
  /// plain, non-ReDrop-sourced card, which is why this is optional
  /// unlike [onOpenProfile].
  final VoidCallback? onOpenRedropperProfile;

  /// WYN-034: deletes *this specific ReDrop* (Standard or Quote) --
  /// only ever wired up (and only ever offered in the More menu, see
  /// [_openMoreMenu]) when [_isOwnRedrop] is true. Distinct from
  /// [onToggleRedrop]/`deleteDrop` -- this never touches the
  /// underlying Drop itself, only the viewer's own ReDrop entry of it.
  final VoidCallback? onDeleteRedrop;

  /// WYN-035: called with the tapped option's index when [item.isPoll]
  /// -- null (never called) for a plain image card.
  final ValueChanged<int>? onVotePoll;

  /// WYNOS Unified Home Feed Algorithm V1.0 -- records the "Hide" User
  /// Signal and removes this card from the feed immediately. Only
  /// offered for someone else's Drop (see [_isOwnDrop]'s use in
  /// [_openMoreMenu]), same gating as "รายงานโพสต์" -- hiding your own
  /// post from your own feed isn't a meaningful action.
  final VoidCallback? onHide;

  bool get _isOwnDrop =>
      item.authorId == Supabase.instance.client.auth.currentUser!.id;

  /// Whether *this card* is the viewer's own ReDrop (Standard or
  /// Quote) of someone's Drop -- independent of [_isOwnDrop], which is
  /// about the underlying Drop's authorship. A card can be neither,
  /// either, or (redropping your own Drop) both at once.
  bool get _isOwnRedrop =>
      item.redropId != null &&
      item.redropperId == Supabase.instance.client.auth.currentUser!.id;

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: dropShareLink(item.id)),
    );
  }

  /// WYN-034: the 🔄 icon opens a small action sheet rather than
  /// toggling directly on tap -- ReDrop broadcasts to the redropper's
  /// own followers, a bigger-consequence action than a Like, so it
  /// gets the same 2-step "tap icon → pick an action" shape as most
  /// platforms' own Repost/Quote entry point, not a single-tap toggle.
  Future<void> _openRedropSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(item.redroppedByMe ? 'ยกเลิก ReDrop' : '🔄 ReDrop'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onToggleRedrop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('💬 Quote ReDrop'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onQuoteRedrop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMoreMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        // WYNOSHomeSpec.md 4.6: Share/Save deliberately live here now,
        // not in the action bar (see that section's own "deliberate
        // simplification" note) -- always offered first, ahead of the
        // existing Hide/Report/Delete-ReDrop rows below, which the
        // spec's own simplified 2-row mockup doesn't have to account
        // for but this app already does.
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
        // Reporting your own Drop makes no sense -- same guard
        // _isOwnDrop already applied to this button's own
        // visibility before WYN-034, kept here now that the
        // button can also show for a reason unrelated to
        // authorship (_isOwnRedrop).
        if (!_isOwnDrop && onHide != null)
          ActionSheetRow(
            icon: Icons.visibility_off_outlined,
            label: 'ไม่สนใจโพสต์นี้',
            onTap: () {
              Navigator.of(sheetContext).pop();
              onHide?.call();
            },
          ),
        if (!_isOwnDrop)
          ActionSheetRow(
            icon: Icons.flag_outlined,
            label: 'รายงานโพสต์',
            onTap: () {
              Navigator.of(sheetContext).pop();
              showReportSheet(
                context,
                reportRepository: ReportRepository(Supabase.instance.client),
                targetType: ReportTargetType.drop,
                targetId: item.id,
                targetLabel: 'รายงานโพสต์ของ ${item.authorNameOrUsername}',
                associatedUserId: item.authorId,
              );
            },
          ),
        // WYN-034: removes *this ReDrop entry* only -- the original
        // Drop (and any other ReDrops of it) are untouched.
        if (_isOwnRedrop)
          ActionSheetRow(
            icon: Icons.delete_outline,
            label: 'ลบ ReDrop',
            onTap: () {
              Navigator.of(sheetContext).pop();
              onDeleteRedrop?.call();
            },
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'รูปของ ${item.authorNameOrUsername}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WYN-034, Screen 3 -- shown only when this card came from
              // someone's ReDrop rather than directly from `drops`. The
              // avatar/username/image/caption/stats row below this stays
              // completely unchanged either way -- it always describes
              // the *original* Drop, credit preserved.
              if (item.redropId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    WynSpacing.space3, 0, WynSpacing.space3, WynSpacing.space1,
                  ),
                  child: InkWell(
                    onTap: onOpenRedropperProfile,
                    borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.repeat,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: WynSpacing.space1),
                        Text(
                          'ReDrop โดย @${item.redropperUsername}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (item.quoteText != null && item.quoteText!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    WynSpacing.space3, 0, WynSpacing.space3, WynSpacing.space2,
                  ),
                  child: HashtagText(item.quoteText!),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space1),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onOpenProfile,
                        borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                        child: Row(
                          children: [
                            AvatarCircle(
                              imageUrl: item.authorAvatarUrl,
                              fallbackText: item.authorUsername,
                              radius: 16,
                            ),
                            const SizedBox(width: WynSpacing.space2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.authorNameOrUsername,
                                          style: Theme.of(context).textTheme.titleSmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (item.authorIsVerified) ...[
                                        const SizedBox(width: WynSpacing.space1),
                                        const VerifiedBadge(),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    relativeTimeLabel(item.createdAt, now: DateTime.now()),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // WYNOSHomeSpec.md 4.6: always shown now, even on the
                    // viewer's own plain (non-ReDrop) Drop -- Share/Save
                    // moved in here from the action bar apply regardless
                    // of authorship. _openMoreMenu itself still decides
                    // which of the authorship-gated rows (Hide/Report/
                    // Delete ReDrop) actually appear underneath those two.
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'เพิ่มเติม',
                      onPressed: () => _openMoreMenu(context),
                    ),
                  ],
                ),
              ),
              if (item.isPoll)
                PollCard(
                  options: item.pollOptions!,
                  expiresAt: item.pollExpiresAt!,
                  myVoteIndex: item.pollMyVoteIndex,
                  totalVotes: item.pollTotalVotes,
                  optionCounts: item.pollOptionCounts,
                  isOwnPoll: _isOwnDrop,
                  onVote: (index) => onVotePoll?.call(index),
                )
              else if (item.imageUrl != null)
                DoubleTapLike(
                  onLike: onToggleLike,
                  alreadyLiked: item.likedByMe,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(item.imageUrl!, fit: BoxFit.cover),
                  ),
                ),
              // WYNOS V1.0.0 Beta requirement 2: a Drop can now be
              // caption-only (no image, not a Poll) -- _canShare in
              // CreateDropScreen already guarantees a non-empty caption
              // whenever that's the case, so this is never reached with
              // a null/empty caption for a plain (non-poll) card.
              if (item.caption != null && item.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: !item.isPoll && item.imageUrl == null
                      ? DoubleTapLike(
                          onLike: onToggleLike,
                          alreadyLiked: item.likedByMe,
                          child: HashtagText(item.caption!),
                        )
                      : HashtagText(item.caption!),
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
                    // Heart/comment/repost/eye sizing+color match
                    // WYNOSHomeSpec.md 4.9's table exactly -- exactly
                    // these 4 elements now that Share/Bookmark moved
                    // into the "..." menu (see _openMoreMenu, spec 4.6).
                    ActionMetric(
                      icon: item.likedByMe ? Icons.favorite : Icons.favorite_border,
                      iconSize: 17,
                      count: item.likeCount,
                      color: item.likedByMe ? WynColors.sapphire : WynColors.graphite,
                      semanticsLabel: item.likedByMe
                          ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ'
                          : 'กดเพื่อถูกใจ',
                      onTap: onToggleLike,
                    ),
                    const SizedBox(width: WynSpacing.space5),
                    ActionMetric(
                      icon: Icons.mode_comment_outlined,
                      iconSize: 17,
                      count: item.commentCount,
                      color: WynColors.graphite,
                      semanticsLabel: 'ดูคอมเมนต์',
                      onTap: onTap,
                    ),
                    const SizedBox(width: WynSpacing.space5),
                    ActionMetric(
                      icon: Icons.repeat,
                      iconSize: 17,
                      count: item.redropCount,
                      color: WynColors.graphite,
                      semanticsLabel: item.redroppedByMe
                          ? 'ReDrop แล้ว กดเพื่อเลือกดำเนินการ'
                          : 'กดเพื่อ ReDrop',
                      onTap: () => _openRedropSheet(context),
                    ),
                    const SizedBox(width: WynSpacing.space5),
                    ActionMetric(
                      icon: Icons.visibility_outlined,
                      iconSize: 16,
                      count: item.viewCount,
                      color: WynColors.faint,
                      semanticsLabel: 'เข้าชมแล้ว ${item.viewCount} ครั้ง',
                      onTap: null,
                    ),
                  ],
                ),
              ),
              if (item.topReply != null)
                TopReplyPreview(reply: item.topReply!, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}
