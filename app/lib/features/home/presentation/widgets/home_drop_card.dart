import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart' show dropShareLink;
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/home_feed_item.dart';
import '../../../../core/text_utils.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../design/wynos_home_tokens.dart';
import 'wynos_avatar_ring.dart';
import 'wynos_double_tap_like.dart';
import 'wynos_image_carousel.dart';
import 'wynos_liked_by_row.dart';
import 'wynos_more_menu.dart';
import 'wynos_top_reply.dart';
import 'wynos_verified_badge.dart';
import '../../../../core/widgets/hashtag_text.dart';
import '../../../report/data/report_repository.dart';
import '../../../report/data/report_target_type.dart';
import '../../../report/presentation/report_sheet.dart';
import '../../../drop/presentation/widgets/poll_card.dart';

/// A Drop card in the Home feed. Same visual structure as
/// HomePopCard so the two read as one family, per
/// .wyn/docs/design/wyn-007-home.md ("ทิศทางภาพรวม") and the WYNOS
/// Home reference spec, section 4.6.
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
    required this.dropRepository,
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

  /// WYNOS Home reference spec 4.7 -- only ever used to lazily fetch the
  /// full image list ([DropRepository.fetchDropImages]) for a Drop with
  /// [HomeFeedItem.hasMultipleImages], the same on-demand fetch
  /// DropDetailScreen's own full-screen viewer already uses (WYN-071) --
  /// never eagerly loaded for every card in the feed.
  final DropRepository dropRepository;

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
  /// [_menuActions]) when [_isOwnRedrop] is true. Distinct from
  /// [onToggleRedrop]/`deleteDrop` -- this never touches the
  /// underlying Drop itself, only the viewer's own ReDrop entry of it.
  final VoidCallback? onDeleteRedrop;

  /// WYN-035: called with the tapped option's index when [item.isPoll]
  /// -- null (never called) for a plain image card.
  final ValueChanged<int>? onVotePoll;

  /// WYNOS Unified Home Feed Algorithm V1.0 -- records the "Hide" User
  /// Signal and removes this card from the feed immediately. Only
  /// offered for someone else's Drop (see [_isOwnDrop]'s use in
  /// [_menuActions]), same gating as "รายงานโพสต์" -- hiding your own
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

  /// WYNOS Home reference spec 4.6: the `⋯` button is now always
  /// visible -- Share and Save moved in here from the action bar apply
  /// to your own post too, so the menu can never be empty the way the
  /// old bottom sheet's Hide/Report-only content could be for a
  /// non-ReDrop post of your own.
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
        // Hiding/reporting your own Drop makes no sense -- same guard
        // this app has always applied to these two entries.
        if (!_isOwnDrop && onHide != null)
          WynosMenuAction(
            icon: Icons.visibility_off_outlined,
            label: 'ไม่สนใจโพสต์นี้',
            onTap: () => onHide!(),
          ),
        if (!_isOwnDrop)
          WynosMenuAction(
            icon: Icons.flag_outlined,
            label: 'รายงานโพสต์',
            onTap: () => showReportSheet(
              context,
              reportRepository: ReportRepository(Supabase.instance.client),
              targetType: ReportTargetType.drop,
              targetId: item.id,
              targetLabel: 'รายงานโพสต์ของ ${item.authorNameOrUsername}',
              associatedUserId: item.authorId,
            ),
          ),
        // WYN-034: removes *this ReDrop entry* only -- the original
        // Drop (and any other ReDrops of it) are untouched.
        if (_isOwnRedrop)
          WynosMenuAction(
            icon: Icons.delete_outline,
            label: 'ลบ ReDrop',
            onTap: () => onDeleteRedrop?.call(),
          ),
      ];

  /// WYNOS Home reference spec 4.6 -- each line of the caption is its
  /// own paragraph (space-y-2 between them), not one flowing block, so
  /// a caption with line breaks reads the same as the reference's own
  /// multi-`<p>` markup.
  ///
  /// A caption-only Drop (no image, not a Poll -- WYNOS V1.0.0 Beta
  /// requirement 2) keeps its pre-existing double-tap-to-like: with no
  /// image to overlay the heart-burst on, this still uses the plain
  /// [DoubleTapLike] the app already had rather than
  /// [WynosDoubleTapLike]'s image-sized visual.
  Widget _captionColumn(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in item.caption!.split('\n'))
          Padding(
            padding: const EdgeInsets.only(
              bottom: WynosHomeSpacing.postLineGap,
            ),
            child: HashtagText(line, style: WynosHomeText.postBody),
          ),
      ],
    );
    if (item.isPoll || item.hasMultipleImages || item.imageUrl != null) {
      return column;
    }
    return DoubleTapLike(
      onLike: onToggleLike,
      alreadyLiked: item.likedByMe,
      onTap: onTap,
      child: column,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The tap-to-open InkWell sits *behind* the actual content in a
    // Stack rather than wrapping it -- an ancestor GestureDetector/
    // InkWell with a plain onTap (no onDoubleTap of its own) always
    // wins the gesture arena over a descendant's double-tap recognizer
    // (see WynosDoubleTapLike/DoubleTapLike's onTap doc comments): it
    // has no reason to wait out the double-tap disambiguation window,
    // so it resolves and steals the first tap before a second one can
    // ever arrive. Stacking it underneath means Flutter's hit test
    // never even reaches it for a point the media widget's own
    // GestureDetector already claims, while blank areas the content
    // doesn't paint anything hit-testable over still fall through to
    // it exactly as before.
    return Semantics(
      label: 'รูปของ ${item.authorNameOrUsername}',
      button: true,
      child: Stack(
        children: [
          Positioned.fill(child: InkWell(onTap: onTap)),
          Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WynosHomeSpacing.pagePadding,
            vertical: WynosHomeSpacing.postVertical,
          ),
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
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: onOpenRedropperProfile,
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.repeat,
                          size: 13,
                          color: WynosHomeColors.onInkSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ReDrop โดย @${item.redropperUsername}',
                          style: WynosHomeText.redropAttribution,
                        ),
                      ],
                    ),
                  ),
                ),
              if (item.quoteText != null && item.quoteText!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: HashtagText(
                    item.quoteText!,
                    style: WynosHomeText.postBody,
                  ),
                ),
              Row(
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
                        // timestamp), not the old two-line name-then-
                        // timestamp stack.
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
                                    const SizedBox(width: 6),
                                    Text(
                                      relativeTimeLabel(
                                        item.createdAt,
                                        now: DateTime.now(),
                                      ),
                                      style: WynosHomeText.timestamp,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // WYN-034: also shown for the viewer's own
                            // ReDrop of someone else's Drop -- always
                            // visible now (see [_menuActions]'s doc
                            // comment for why).
                            WynosMoreMenuButton(actions: _menuActions(context)),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                        else if (item.hasMultipleImages)
                          // WYNOS Home reference spec 4.7 -- the
                          // peek-card carousel. fetchDropImages is
                          // on-demand (WYN-071), so this fetches once
                          // per build of a visible multi-image card,
                          // not eagerly for the whole feed.
                          FutureBuilder<List<String>>(
                            future: dropRepository.fetchDropImages(item.id),
                            builder: (context, snapshot) {
                              final urls = snapshot.data;
                              if (urls == null || urls.length < 2) {
                                // Still loading, or a (should-never-
                                // happen) fetch that came back with
                                // fewer than the imageCount this card
                                // was built for -- show the known
                                // first image as a static placeholder
                                // rather than an empty gap or a
                                // spinner that would jump the layout
                                // once real content arrives.
                                return WynosImageCarouselPlaceholder(
                                  imageUrl: item.imageUrl!,
                                );
                              }
                              return WynosImageCarousel(
                                imageUrls: urls,
                                onLike: onToggleLike,
                                alreadyLiked: item.likedByMe,
                                onTap: onTap,
                              );
                            },
                          )
                        else if (item.imageUrl != null)
                          // WYNOS Home reference spec 4.7 -- the
                          // spec's own heart-burst visual (72px paper
                          // heart, exact keyframe timing), scoped to
                          // Home only; see that widget's doc comment
                          // for why this isn't just DoubleTapLike with
                          // new numbers.
                          WynosDoubleTapLike(
                            onLike: onToggleLike,
                            alreadyLiked: item.likedByMe,
                            onTap: onTap,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Image.network(
                                item.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        // WYNOS V1.0.0 Beta requirement 2: a Drop can
                        // now be caption-only (no image, not a Poll)
                        // -- _canShare in CreateDropScreen already
                        // guarantees a non-empty caption whenever
                        // that's the case, so this is never reached
                        // with a null/empty caption for a plain
                        // (non-poll) card.
                        //
                        // WYNOS Home reference spec 4.6 -- each line
                        // of the caption is its own paragraph
                        // (space-y-2 between them), not one flowing
                        // block, so a caption with line breaks reads
                        // the same as the reference's own multi-<p>
                        // markup.
                        if (item.caption != null && item.caption!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              top: item.isPoll ||
                                      item.hasMultipleImages ||
                                      item.imageUrl != null
                                  ? 10
                                  : 0,
                            ),
                            child: _captionColumn(context),
                          ),
                        // WYNOS Home reference spec 4.8 -- own top
                        // margin, so it sits correctly whether the
                        // card above it was an image, a carousel, a
                        // caption, or (for a Poll) the PollCard.
                        WynosLikedByRow(
                          likedBy: item.likedBy,
                          likeCount: item.likeCount,
                        ),
                        // WYNOS Home reference spec 4.6 -- exactly
                        // four action-bar icons (Heart/Comment/
                        // Repost/Eye); Share and Save moved into the
                        // `⋯` menu above. Own top gap (mirrors
                        // WynosLikedByRow's mt-2.5) so the bar sits
                        // correctly even when likeCount is 0 and that
                        // row renders nothing.
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
                                icon: const Icon(
                                  Icons.mode_comment_outlined,
                                  size: 17,
                                  color: WynosHomeColors.graphite,
                                ),
                                onPressed: onTap,
                              ),
                            ),
                            const SizedBox(width: WynosHomeSpacing.actionIconLabelGap),
                            Text('${item.commentCount}', style: WynosHomeText.actionCount),
                            const SizedBox(width: WynosHomeSpacing.actionBarGap),
                            Semantics(
                              label: item.redroppedByMe
                                  ? 'ReDrop แล้ว กดเพื่อเลือกดำเนินการ'
                                  : 'กดเพื่อ ReDrop',
                              excludeSemantics: true,
                              child: IconButton(
                                icon: Icon(
                                  Icons.repeat,
                                  size: 17,
                                  color: item.redroppedByMe
                                      ? WynosHomeColors.sapphire
                                      : WynosHomeColors.graphite,
                                ),
                                onPressed: () => _openRedropSheet(context),
                              ),
                            ),
                            const SizedBox(width: WynosHomeSpacing.actionIconLabelGap),
                            Text('${item.redropCount}', style: WynosHomeText.actionCount),
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
                        WynosTopReply(reply: item.topReply, onTap: onTap),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        ],
      ),
    );
  }
}
