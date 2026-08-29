import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../drop/presentation/drop_detail_screen.dart' show dropShareLink;
import '../../data/home_feed_item.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wynos_home_tokens.dart';
import '../../../../core/text_utils.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../../../../core/widgets/hashtag_text.dart';
import '../../../../core/widgets/wynos_ringed_avatar.dart';
import '../../../report/data/report_repository.dart';
import '../../../report/data/report_target_type.dart';
import '../../../report/presentation/report_sheet.dart';
import '../../../drop/presentation/widgets/poll_card.dart';

/// A Drop card in the Home feed. Same visual structure as
/// HomePopCard so the two read as one family, per
/// .wyn/docs/design/wyn-007-home.md ("ทิศทางภาพรวม").
///
/// WYN-072 (WYNOS Design Reference Rollout, Screen 01): restyled to
/// match `/SPEC.md` Section 4.6-4.9 -- sapphire-ringed avatar, Fraunces/
/// Inter tokens (see WynosHomeTokens), Share/Bookmark moved out of the
/// action bar into the "⋯" more-options menu (SPEC 4.6 point 4), the
/// action bar trimmed to exactly Heart/Comment/Repost/Eye (SPEC 4.9),
/// and the single available image rendered as a peek-card carousel
/// (SPEC 4.7). Every existing callback/business-logic wire-up (like,
/// save, ReDrop, poll vote, hide, report) is unchanged -- only styling
/// and where Share/Save live moved.
///
/// Two SPEC.md sub-components are deliberately NOT implemented this
/// round, real-data gaps rather than mocked placeholders (see
/// .wyn/tasks/active/WYN-072-wynos-design-reference-home-feed.md,
/// Known Issues):
/// - SPEC 4.8 (liked-by row, stacked avatars of who liked a post) --
///   `HomeFeedItem`/`home_feed` only ever carry an aggregate
///   `likeCount`, never a list of liker profiles, for any Home feed
///   query. Nothing here fakes a placeholder "liked by X and N others"
///   string.
/// - SPEC 4.10 (top reply preview, the highest-engagement reply) -- no
///   repository/RPC anywhere in this codebase returns "the top reply"
///   for a Drop/Pop; `commentCount` is the only comment-related field
///   `HomeFeedItem` carries.
/// - The verified badge (SPEC 4.6 point 3) also has no backing field
///   anywhere in `Profile`/`HomeFeedItem` yet, so it's never rendered.
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

  /// WYN-072 (SPEC.md Section 4.6 point 4): Share and Save now live
  /// here, at the top, above the pre-existing Hide/Report/Delete-ReDrop
  /// entries -- one shared "⋯" menu rather than a second more-options
  /// button next to the pre-existing one (SPEC.md Section 0 forbids
  /// adding components not named in the spec, and the reference itself
  /// has no Hide/Report concept to give a separate menu to). Kept as a
  /// bottom sheet (this codebase's existing more-options idiom) rather
  /// than switching to a literal `top-6 right-0` anchored dropdown --
  /// SPEC.md Section 6 explicitly allows falling back to "existing
  /// styling" for anything the reference doesn't give a Flutter
  /// equivalent for.
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
            // A divider between the Share/Save pair above and whatever
            // Hide/Report/Delete-ReDrop entries follow -- only when at
            // least one of those actually renders below (matches
            // whichever of the two guards immediately below resolves
            // true).
            if (!_isOwnDrop || _isOwnRedrop) const Divider(height: 1),
            // Reporting your own Drop makes no sense -- same guard
            // _isOwnDrop already applied to this button's own
            // visibility before WYN-034, kept here now that the
            // button can also show for a reason unrelated to
            // authorship (_isOwnRedrop).
            if (!_isOwnDrop && onHide != null)
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('ไม่สนใจโพสต์นี้'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onHide?.call();
                },
              ),
            if (!_isOwnDrop)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('รายงานโพสต์'),
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
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('ลบ ReDrop'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onDeleteRedrop?.call();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// SPEC.md Section 4.7 (peek-card image carousel). Only one real
  /// image is available per Drop from the Home feed's own data source
  /// today (`HomeFeedItem.imageUrl`, always just the cover/first image)
  /// -- WYN-071's full multi-image list (`drop_images`) exists in the
  /// schema and is already used by DropDetailScreen's own gallery, but
  /// wiring every Home feed card to lazily fetch it too would add an
  /// extra query per card in a paginated list (a real N+1 concern, not
  /// this task's to solve). See this file's class doc comment / this
  /// task's Known Issues -- the scaffold below already renders however
  /// many cards it's given, so it's ready for that data the moment it
  /// exists.
  Widget _buildImageCarousel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth * 0.82;
        final cardHeight = cardWidth * 5 / 4;
        return SizedBox(
          height: cardHeight,
          child: DoubleTapLike(
            onLike: onToggleLike,
            alreadyLiked: item.likedByMe,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: WynSpacing.space6),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: cardWidth,
                    child: Image.network(item.imageUrl!, fit: BoxFit.cover),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                        const Icon(
                          Icons.repeat,
                          size: 12,
                          color: WynosHomeTokens.graphite,
                        ),
                        const SizedBox(width: WynSpacing.space1),
                        Text(
                          'ReDrop โดย @${item.redropperUsername}',
                          style: WynosHomeTokens.redropAttribution,
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
                  child: _wrapSapphireLinks(
                    context,
                    HashtagText(item.quoteText!, style: WynosHomeTokens.postBody),
                  ),
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
                            WynosRingedAvatar(
                              imageUrl: item.authorAvatarUrl,
                              fallbackText: item.authorUsername,
                              radius: 16,
                            ),
                            const SizedBox(width: WynSpacing.space2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.authorNameOrUsername,
                                    style: WynosHomeTokens.postAuthorName,
                                  ),
                                  Text(
                                    relativeTimeLabel(item.createdAt, now: DateTime.now()),
                                    style: WynosHomeTokens.caption(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // WYN-034: also shown for the viewer's own ReDrop of
                    // someone else's Drop -- _openMoreMenu itself decides
                    // which entries actually appear.
                    if (!_isOwnDrop || _isOwnRedrop)
                      IconButton(
                        icon: const Icon(Icons.more_horiz,
                            size: 16, color: WynosHomeTokens.faint),
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
                _buildImageCarousel(),
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
                          child: _wrapSapphireLinks(
                            context,
                            HashtagText(item.caption!, style: WynosHomeTokens.postBody),
                          ),
                        )
                      : _wrapSapphireLinks(
                          context,
                          HashtagText(item.caption!, style: WynosHomeTokens.postBody),
                        ),
                ),
              // SPEC.md Section 4.8 (liked-by row) is deliberately not
              // rendered here -- see this file's class doc comment.
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
                        onPressed: onTap,
                      ),
                    ),
                    Text('${item.commentCount}', style: WynosHomeTokens.caption()),
                    const SizedBox(width: WynSpacing.space5),
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
                              ? WynosHomeTokens.sapphire
                              : WynosHomeTokens.graphite,
                        ),
                        onPressed: () => _openRedropSheet(context),
                      ),
                    ),
                    Text('${item.redropCount}', style: WynosHomeTokens.caption()),
                    const SizedBox(width: WynSpacing.space5),
                    // SPEC.md Section 4.9: view count is display-only,
                    // never tappable, `faint` (one shade lighter than
                    // the 3 tappable icons before it).
                    Semantics(
                      label: 'เข้าชมแล้ว ${item.viewCount} ครั้ง',
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: WynosHomeTokens.faint,
                          ),
                          const SizedBox(width: WynSpacing.space1),
                          Text('${item.viewCount}',
                              style: WynosHomeTokens.caption(
                                  color: WynosHomeTokens.faint)),
                        ],
                      ),
                    ),
                    // WYN-072 (SPEC.md Section 4.9): Share and Save are
                    // no longer in this row -- see [_openMoreMenu].
                  ],
                ),
              ),
              // SPEC.md Section 4.10 (top reply preview) is deliberately
              // not rendered here -- see this file's class doc comment.
            ],
          ),
        ),
      ),
    );
  }

  /// Recolors [HashtagText]'s hashtag/mention link color to `sapphire`
  /// (this screen's one accent, SPEC.md Section 1) without touching
  /// [HashtagText] itself (which reads `Theme.of(context).colorScheme.
  /// primary`, still Cyan/DS-001 everywhere else this widget is reused
  /// -- Chat, DropDetailScreen, ClubPostCard, ...). Scoped to just this
  /// subtree, same "local Theme override" approach used for any other
  /// third-party-styled widget this task reuses as-is.
  Widget _wrapSapphireLinks(BuildContext context, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: scheme.copyWith(primary: WynosHomeTokens.sapphire),
      ),
      child: child,
    );
  }
}
