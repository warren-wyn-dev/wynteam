import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../drop/data/drop.dart' show AudienceOption;
import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart' show dropShareLink;
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/home_feed_item.dart';
import 'home_card_metrics.dart';
import 'home_feed_image_peek_carousel.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/text_utils.dart';
import '../../../../core/widgets/action_metric.dart';
import '../../../../core/widgets/action_sheet_row.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../../../../core/widgets/hashtag_text.dart';
import '../../../../core/widgets/post_media.dart';
import 'liked_by_row.dart';
import 'top_reply_preview.dart';
import 'verified_badge.dart';
import '../../../report/data/report_repository.dart';
import '../../../report/data/report_target_type.dart';
import '../../../report/presentation/report_sheet.dart';
import '../../../drop/presentation/widgets/poll_card.dart';
import '../../../drop/presentation/widgets/redrop_action_sheet.dart';

/// A Drop card in the Home feed. Same visual structure as
/// HomePopCard so the two read as one family, per
/// .wyn/docs/design/wyn-007-home.md ("ทิศทางภาพรวม").
class HomeDropCard extends StatelessWidget {
  const HomeDropCard({
    super.key,
    required this.item,
    required this.dropRepository,
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

  /// WYN-092: only used to fetch the full image list for a
  /// multi-image Drop's peek carousel (`fetchDropImages`, reused
  /// as-is from WYN-071) -- untouched for every other Drop shape
  /// this card renders (text-only, Poll, single-image).
  final DropRepository dropRepository;

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

  /// WYN-034: the ReDrop icon opens a small action sheet rather than
  /// toggling directly on tap -- ReDrop broadcasts to the redropper's
  /// own followers, a bigger-consequence action than a Like, so it
  /// gets the same 2-step "tap icon → pick an action" shape as most
  /// platforms' own Repost/Quote entry point, not a single-tap toggle.
  ///
  /// Beta4 §6: built from [ActionSheetBody]/[ActionSheetRow], the same
  /// two widgets every other "..." sheet in the app is built from --
  /// this was the last sheet still hand-rolling a bare `Wrap` of
  /// `ListTile`s, and the only place in the product where an emoji
  /// ('🔄'/'💬') stood in for an icon. An emoji is not part of the
  /// icon system: it renders in the platform's own colour, at the
  /// font's own metrics, on its own baseline, and has no pressed,
  /// active, or disabled state to give -- so the two most consequential
  /// rows in the feed were also the two that could not follow the icon
  /// system's rules. [showRedropSheet] is now shared with Drop Detail
  /// so both entry points to the same two actions cannot drift apart
  /// again.
  Future<void> _openRedropSheet(BuildContext context) {
    return showRedropSheet(
      context,
      isRedropped: item.redroppedByMe,
      onToggleRedrop: onToggleRedrop,
      onQuoteRedrop: onQuoteRedrop,
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
          // WYN-107: 16 top and bottom, matching design-reference/
          // 01-home.tsx's own `pt-4 pb-4` per post -- the card is
          // wider-set now, and the old 8 left it looking cramped
          // against the extra horizontal room.
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WYN-034, Screen 3 -- shown only when this card came from
              // someone's ReDrop rather than directly from `drops`. The
              // avatar/username/image/caption/stats row below this stays
              // completely unchanged either way -- it always describes
              // the *original* Drop, credit preserved.
              //
              // WYN-107: this row and the quote text below it are the
              // two things on the card that are *not* about the original
              // Drop -- they are the redropper speaking. They stay above
              // the two columns, spanning the card, exactly as
              // design-reference/01-home.tsx puts its own `post.redropBy`
              // line above the `flex gap-3.5` row.
              if (item.redropId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    homeCardEdgeInset,
                    0,
                    homeCardEdgeInset,
                    WynSpacing.space1,
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
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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
                    homeCardEdgeInset,
                    0,
                    homeCardEdgeInset,
                    WynSpacing.space2,
                  ),
                  child: HashtagText(item.quoteText!),
                ),
              // WYN-107: the card's two columns. The avatar is the left
              // column of the card itself now -- not a cell inside the
              // header row -- so everything else (name, caption, photos,
              // liked-by, action bar, top reply) lines up in one right
              // column that starts at the name.
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
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
                                      Text(
                                        // WYN-098, Design spec Screen 4:
                                        // appended to the same line (not a
                                        // 3rd row) when this Drop has a
                                        // check-in -- plain text, no Icon
                                        // widget (matches Product spec's
                                        // literal "📍 {ชื่อสถานที่}" copy),
                                        // and deliberately not wrapped in
                                        // any tap handler (not tappable,
                                        // per that spec's Out of Scope).
                                        item.location != null
                                            ? '${relativeTimeLabel(item.createdAt, now: DateTime.now())} · 📍 ${item.location}'
                                            : relativeTimeLabel(item.createdAt,
                                                now: DateTime.now()),
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // WYNOSHomeSpec.md 4.6: always shown now,
                              // even on the viewer's own plain
                              // (non-ReDrop) Drop -- Share/Save moved in
                              // here from the action bar apply
                              // regardless of authorship. _openMoreMenu
                              // itself still decides which of the
                              // authorship-gated rows (Hide/Report/
                              // Delete ReDrop) actually appear
                              // underneath those two.
                              //
                              // WYN-107: pinned to a 44x44 box so the
                              // header row is the height of the name
                              // block plus its own tap target, rather
                              // than IconButton's default 48 -- which,
                              // now that the avatar is a column of its
                              // own beside this row, would push the
                              // name off the avatar's own top line.
                              // Still >= the 44 minimum DS-001 6 sets.
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
                            // WYN-107: no left inset -- the content column already
                            // starts at the name. Only the right edge is held off
                            // the screen.
                            padding: const EdgeInsets.fromLTRB(
                              0,
                              WynSpacing.space2,
                              homeCardEdgeInset,
                              WynSpacing.space2,
                            ),
                            child: !item.isPoll && item.imageUrl == null
                                ? DoubleTapLike(
                                    onLike: onToggleLike,
                                    alreadyLiked: item.likedByMe,
                                    child: HashtagText(item.caption!),
                                  )
                                : HashtagText(item.caption!),
                          ),
                        if (item.isPoll)
                          Padding(
                            padding:
                                const EdgeInsets.only(right: homeCardEdgeInset),
                            child: PollCard(
                              options: item.pollOptions!,
                              expiresAt: item.pollExpiresAt!,
                              myVoteIndex: item.pollMyVoteIndex,
                              totalVotes: item.pollTotalVotes,
                              optionCounts: item.pollOptionCounts,
                              isOwnPoll: _isOwnDrop,
                              onVote: (index) => onVotePoll?.call(index),
                            ),
                          )
                        // WYN-092 (Wynos V1.0.0 Beta2 Phase 2, item 14): a
                        // multi-image Drop gets the new peek carousel instead --
                        // everything below (single-image DoubleTapLike +
                        // ConstrainedBox + AspectRatio + Image.network) is
                        // completely untouched for the single-image case, which
                        // is still the overwhelming majority of Drops in the
                        // feed.
                        else if (item.imageUrl != null &&
                            item.hasMultipleImages)
                          HomeFeedImagePeekCarousel(
                            item: item,
                            dropRepository: dropRepository,
                            onLike: onToggleLike,
                          )
                        else if (item.imageUrl != null)
                          Padding(
                            // WYN-107: a lone photo stops at the card's right
                            // inset rather than bleeding like the carousel does --
                            // there is no next card for it to hint at, so running
                            // it to the screen edge would only break the column.
                            padding:
                                const EdgeInsets.only(right: homeCardEdgeInset),
                            child: DoubleTapLike(
                              onLike: onToggleLike,
                              alreadyLiked: item.likedByMe,
                              // Beta3: the aspect-ratio clamp (WYN-093), the
                              // 0.75-of-viewport height cap, and the placeholder/
                              // error pair all moved into PostImageFrame, which
                              // Drop Detail's gallery now shares -- so a photo is
                              // the same shape in the feed and in the post, which
                              // it was not before (Detail hard-cropped every photo
                              // into a square). Same widget also bounds the decode
                              // size, which a bare Image.network here never did.
                              child: PostImageFrame(
                                imageUrl: item.imageUrl!,
                                imageWidth: item.imageWidth,
                                imageHeight: item.imageHeight,
                                // WYN-107: rounded now that it sits inside the
                                // column instead of spanning the screen -- a
                                // square corner floating on white reads as
                                // unfinished. Drop Detail keeps the default (no
                                // radius): its photo is still full-bleed.
                                borderRadius: WynSpacing.radiusLg,
                              ),
                            ),
                          ),
                        if (item.likedBy.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              0,
                              WynSpacing.space2 + 2,
                              homeCardEdgeInset,
                              0,
                            ),
                            child: LikedByRow(
                              likedBy: item.likedBy,
                              totalLikeCount: item.likeCount,
                            ),
                          ),
                        Padding(
                          // WYN-096 aligned this row with the rest of the card;
                          // WYN-107 moved the whole card into a content column, so
                          // "the rest of the card" is now the column's own left
                          // edge -- which is exactly what the Founder asked for
                          // when they circled this row: "ปุ่มควรขยับ ให้ตรงชื่อ".
                          // ActionMetric's own internal spacing stays untouched.
                          padding:
                              const EdgeInsets.only(right: homeCardEdgeInset),
                          child: Row(
                            children: [
                              // Heart/comment/repost/eye sizing+color match
                              // WYNOSHomeSpec.md 4.9's table exactly -- exactly
                              // these 4 elements now that Share/Bookmark moved
                              // into the "..." menu (see _openMoreMenu, spec 4.6).
                              ActionMetric(
                                icon: item.likedByMe
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                iconSize: 17,
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
                                reply: item.topReply!, onTap: onTap),
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
