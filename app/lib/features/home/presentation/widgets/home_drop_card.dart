import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../drop/data/drop.dart' show AudienceOption;
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
    this.showViewCount = true,
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

  /// WYN-088 (Wynos V1.0.0 Beta2, item 27): the eye/view-count
  /// ActionMetric is hidden on the Home feed (every tab) now, but this
  /// same [HomeDropCard] is also reused on the viewer's own Profile
  /// (drop grid/ReDrops/Likes tabs), where Founder wants it kept --
  /// "จะได้รู้ว่ามีใครเห็นโพสต์นี้กี่คนดู". Defaults to true (shown) so
  /// every other call site (Profile's 3 tabs, hashtag feed) is
  /// unaffected -- only home_feed_screen.dart passes false.
  final bool showViewCount;

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
              title: Text(item.redroppedByMe ? 'ยกเลิกรีโพสต์' : '🔄 รีโพสต์'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onToggleRedrop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('💬 Quote รีโพสต์'),
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
            label: 'ลบรีโพสต์',
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
                        Flexible(
                          child: Text(
                            // WYN-087 (Wynos V1.0.0 Beta2, item 26):
                            // relative time appended, same as a plain
                            // post's own author row -- Founder: "ตรง
                            // รีโพสต์ 'รีโพสต์ โดย @sky_blue' ระบุเวลา
                            // เหมือนโพสต์ด้วย". item.createdAt is
                            // already the *ReDrop's* own created_at here
                            // (not the original Drop's), straight from
                            // home_feed's `r.created_at` for this row --
                            // no schema change needed, this is exactly
                            // the "time the redropper pressed ReDrop"
                            // Founder asked for.
                            'รีโพสต์โดย @${item.redropperUsername} · '
                            '${relativeTimeLabel(item.createdAt, now: DateTime.now())}',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
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
              // WYN-086 (Wynos V1.0.0 Beta2, item 25): caption goes above
              // the image/poll now, not below -- Founder: "อยากให้ข้อความ
              // ที่โพสต์อยู่ด้านบน ส่วนรูปอยู่ด้านล่าง". A caption-only
              // Drop still just shows caption with nothing under it, same
              // as before. WYNOS V1.0.0 Beta requirement 2: a Drop can be
              // caption-only (no image, not a Poll) -- _canShare in
              // CreateDropScreen already guarantees a non-empty caption
              // whenever that's the case, so this is never reached with
              // a null/empty caption for a plain (non-poll) card.
              if (item.caption != null && item.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: !item.isPoll && item.imageUrl == null
                      ? DoubleTapLike(
                          onLike: onToggleLike,
                          alreadyLiked: item.likedByMe,
                          child: HashtagText(item.caption!),
                        )
                      : HashtagText(item.caption!),
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
                  // WYN-093 (Wynos V1.0.0 Beta2, item 19): the extra
                  // ConstrainedBox is the "maxHeight = 0.75 * screen
                  // height" ceiling from the Design spec -- a second,
                  // independent cap on top of the aspect-ratio clamp
                  // below, so even a Drop right at the 0.8 (4:5)
                  // portrait bound can't fill almost the whole screen
                  // on a very tall viewport (e.g. a tablet held
                  // upright).
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 0.75 * MediaQuery.of(context).size.height,
                    ),
                    child: AspectRatio(
                      aspectRatio: _feedImageAspectRatio(item),
                      // WYN-074: a bare Image.network showed nothing while
                      // loading, so fast scrolling flashed a blank white
                      // gap. Went through CachedNetworkImage first, but on
                      // Flutter Web every image failed to render at all
                      // (worse than the flash it fixed) -- reverted to
                      // Image.network's own loadingBuilder/errorBuilder,
                      // which are proven-working on this exact web build.
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
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
                      color: item.likedByMe ? Colors.red : WynColors.graphite,
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
                    // WYN-097, Design spec Screen 6: hidden entirely
                    // (not disabled/greyed) once this post's audience
                    // isn't "ทุกคน" -- prevents "รีโพสต์ได้แต่คนอื่นเห็น
                    // แค่บางคน" confusion, same "ซ่อนเองอัตโนมัติ"
                    // posture the 9-image toolbar limit (WYN-071)
                    // already established.
                    if (item.audience == AudienceOption.everyone) ...[
                      const SizedBox(width: WynSpacing.space5),
                      ActionMetric(
                        icon: Icons.repeat,
                        iconSize: 17,
                        count: item.redropCount,
                        // WYN-089: same active-state color the Focused Action
                        // Bar (DropDetailScreen._buildFocusedActionBar) has
                        // used for this all along -- only the icon changes
                        // color, the count stays graphite (same convention
                        // as Like: the number is a total, not a status
                        // indicator).
                        color: item.redroppedByMe
                            ? WynColors.sapphire
                            : WynColors.graphite,
                        semanticsLabel: item.redroppedByMe
                            ? 'รีโพสต์แล้ว กดเพื่อเลือกดำเนินการ'
                            : 'กดเพื่อรีโพสต์',
                        onTap: () => _openRedropSheet(context),
                      ),
                    ],
                    // WYN-088: hidden on the Home feed (showViewCount:
                    // false there) -- still shown everywhere else this
                    // card is reused (Profile's 3 tabs, hashtag feed).
                    if (showViewCount) ...[
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

/// WYN-093 (Wynos V1.0.0 Beta2, item 19): the aspect ratio to render
/// [item]'s image at -- its true width/height when known, clamped to
/// [_minFeedImageAspectRatio] (4:5, the most-portrait shape allowed
/// without cropping) .. [_maxFeedImageAspectRatio] (1.91:1, the most-
/// landscape shape allowed without cropping). Outside that range the
/// image still renders (via BoxFit.cover, unchanged), just cropped at
/// whichever edge it overshoots -- same as every image did
/// unconditionally before this task. Falls back to the old fixed 1:1
/// square when [HomeFeedItem.imageWidth]/[HomeFeedItem.imageHeight]
/// aren't known yet (any Drop uploaded before this metadata existed,
/// or an invalid non-positive height) -- see
/// .wyn/docs/design/wyn-093-dynamic-height-images.md.
double _feedImageAspectRatio(HomeFeedItem item) {
  final width = item.imageWidth;
  final height = item.imageHeight;
  if (width == null || height == null || height <= 0) return 1;
  return (width / height).clamp(
    _minFeedImageAspectRatio,
    _maxFeedImageAspectRatio,
  );
}

const double _minFeedImageAspectRatio = 0.8;
const double _maxFeedImageAspectRatio = 1.91;
