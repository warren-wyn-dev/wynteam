import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/text_utils.dart';
import '../../../home/presentation/widgets/home_card_metrics.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/club_member.dart';
import '../../data/club_post.dart';
import '../club_post_detail_screen.dart' show clubPostShareLink;
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/action_metric.dart';
import '../../../../core/widgets/action_sheet_row.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../../../../core/widgets/hashtag_text.dart';
import '../../../report/data/report_repository.dart';
import '../../../report/data/report_target_type.dart';
import '../../../report/presentation/report_sheet.dart';
import '../../../../core/widgets/post_media.dart';
import '../../../../core/widgets/wyn_heart_icon.dart';

/// A Club post card for the Posts tab list. Restyled onto the exact same
/// two-column geometry ([homeCardEdgeInset]/[homeCardAvatarGap]/
/// [homeCardAvatarDiameter]) and Like/Comment [ActionMetric] row
/// HomeDropCard/HomePopCard use, so a Club's feed reads as one family
/// with Home rather than a visually distinct list -- Founder request:
/// "ในคลับ ฟีดโพสต์ ควรหน้าตาแบบหน้า Home". Share/Save moved into the
/// "..." menu, same simplification WYNOSHomeSpec.md 4.6 made for Home's
/// own action bar. Not a byte-for-byte port: a Club post has no
/// verified-author badge, ReDrop, Poll, view count, or liked-by list in
/// its data model ([ClubPost] has none of those fields), so this card
/// only carries over the parts Home and Club posts actually share.
class ClubPostCard extends StatelessWidget {
  const ClubPostCard({
    super.key,
    required this.post,
    required this.myRole,
    required this.onTap,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onTogglePin,
    required this.onDelete,
  });

  final ClubPost post;
  final ClubMemberRole? myRole;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  bool get _isOwnPost =>
      post.authorId == Supabase.instance.client.auth.currentUser!.id;

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(text: clubPostShareLink(post.id)));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบโพสต์นี้?'),
        content: const Text('ลบแล้วไม่สามารถกู้คืนได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }

  Future<void> _report(BuildContext context) {
    return showReportSheet(
      context,
      reportRepository: ReportRepository(Supabase.instance.client),
      targetType: ReportTargetType.clubPost,
      targetId: post.id,
      targetLabel: 'รายงานโพสต์ของ ${post.authorNameOrUsername}',
      associatedUserId: post.authorId,
    );
  }

  Future<void> _openMoreMenu(BuildContext context) async {
    final canModerate = myRole?.canModeratePosts ?? false;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        // Same "Share/Save live in the menu" simplification Home's own
        // action bar made (WYNOSHomeSpec.md 4.6) -- always offered first,
        // regardless of authorship/role, ahead of the Club-specific rows
        // below.
        ActionSheetRow(
          icon: Icons.share_outlined,
          label: 'แชร์',
          onTap: () {
            Navigator.of(sheetContext).pop();
            _share();
          },
        ),
        ActionSheetRow(
          icon: post.savedByMe ? Icons.bookmark : Icons.bookmark_border,
          label: post.savedByMe ? 'เอาออกจากบันทึก' : 'บันทึก',
          onTap: () {
            Navigator.of(sheetContext).pop();
            onToggleSave();
          },
        ),
        if (_isOwnPost || canModerate)
          ActionSheetRow(
            icon: Icons.delete_outline,
            label: 'ลบโพสต์',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _confirmDelete(context);
            },
          ),
        if (!_isOwnPost && canModerate)
          ActionSheetRow(
            icon: post.pinned ? Icons.push_pin_outlined : Icons.push_pin,
            label: post.pinned ? 'เลิกปักหมุด' : 'ปักหมุด',
            onTap: () {
              Navigator.of(sheetContext).pop();
              onTogglePin();
            },
          ),
        // Report is always the last item and only ever shown for
        // someone else's post (see wyn-026-report-system.md, Screen
        // 6) -- everyone who isn't the author can report a post,
        // regardless of whether they also have moderation rights.
        if (!_isOwnPost)
          ActionSheetRow(
            icon: Icons.flag_outlined,
            label: 'รายงานโพสต์',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _report(context);
            },
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = post.imageUrls != null && post.imageUrls!.isNotEmpty;

    return Semantics(
      label: 'โพสต์ของ ${post.authorNameOrUsername}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // Same vertical rhythm as HomeDropCard/HomePopCard (WYN-107).
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: homeCardEdgeInset),
                child: AvatarCircle(
                  imageUrl: post.authorAvatarUrl,
                  fallbackText: post.authorUsername,
                  radius: homeCardAvatarDiameter / 2,
                ),
              ),
              const SizedBox(width: homeCardAvatarGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: homeCardEdgeInset),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Text(
                                    post.authorNameOrUsername,
                                    style: Theme.of(context).textTheme.titleSmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  relativeTimeLabel(post.createdAt, now: DateTime.now()),
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          // Same 44x44 tap-target-only box HomeDropCard uses --
                          // see its own comment for why this stays smaller
                          // than IconButton's default 48.
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
                    if (post.content != null && post.content!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          0,
                          WynSpacing.space2,
                          homeCardEdgeInset,
                          WynSpacing.space2,
                        ),
                        child: !hasImages
                            ? DoubleTapLike(
                                onLike: onToggleLike,
                                alreadyLiked: post.likedByMe,
                                child: HashtagText(post.content!),
                              )
                            : HashtagText(post.content!),
                      ),
                    if (hasImages)
                      Padding(
                        padding: const EdgeInsets.only(right: homeCardEdgeInset),
                        child: DoubleTapLike(
                          onLike: onToggleLike,
                          alreadyLiked: post.likedByMe,
                          child: ClubPostImages(imageUrls: post.imageUrls!),
                        ),
                      ),
                    if (post.linkUrl != null && post.linkUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          0, WynSpacing.space2, homeCardEdgeInset, 0,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  post.linkUrl!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(
                        right: homeCardEdgeInset, top: WynSpacing.space2,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            ActionMetric(
                              icon: WynHeartIcon(
                                filled: post.likedByMe,
                                size: 17,
                                color: post.likedByMe
                                    ? WynColors.iconLikeActive
                                    : WynColors.iconIdle,
                              ),
                              iconState: post.likedByMe,
                              count: post.likeCount,
                              color: post.likedByMe
                                  ? WynColors.iconLikeActive
                                  : WynColors.iconIdle,
                              semanticsLabel: post.likedByMe
                                  ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ'
                                  : 'กดเพื่อถูกใจ',
                              onTap: onToggleLike,
                            ),
                            const SizedBox(width: WynSpacing.space5),
                            ActionMetric(
                              icon: const Icon(Icons.mode_comment_outlined,
                                  size: 17, color: WynColors.graphite),
                              iconState: Icons.mode_comment_outlined,
                              count: post.commentCount,
                              color: WynColors.graphite,
                              semanticsLabel: 'ดูคอมเมนต์',
                              onTap: onTap,
                            ),
                          ],
                        ),
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

/// Single image: 1:1 like Drop. Multiple images: a horizontal carousel
/// with a dot indicator -- Club's first Multiple Images pattern in the
/// app (Drop only ever has one image).
/// A Club post's photos.
///
/// Beta4 §7 ("Different contexts, same WYNOS visual language"): this is
/// a post, so it uses the same [PostImageFrame]/[PostImageCarousel] a
/// WYNOS Drop uses on the feed and on Post Detail -- a row of cards
/// with the next one peeking in at the edge, not the full-bleed
/// `PageView` slab this used to be. Before Beta4 the same person's
/// photos were a card row in one part of the app and a one-at-a-time
/// slab in another, for no reason a reader could see.
///
/// §7 also says explicitly not to force every surface onto one layout,
/// and this is not that: the aspect ratio still differs from a Drop's,
/// because it has to. `club_posts` carries no image dimensions at all
/// (unlike `drops`, which gained `image_width`/`image_height` in
/// WYN-093), so there is nothing here to lay a true aspect ratio out
/// from -- [PostImageFrame] falls back to 1:1 when dimensions are
/// absent, which is exactly the shape this widget hardcoded before.
/// The shape is unchanged; the arrangement, the snapping, the decode
/// bound and the loading/error states are now the shared ones.
class ClubPostImages extends StatelessWidget {
  const ClubPostImages({super.key, required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 1) {
      // Null dimensions on purpose: `club_posts` has no width/height
      // columns, and PostImageFrame's documented fallback for unknown
      // dimensions is 1:1 -- the exact shape this widget used before.
      return PostImageFrame(
        imageUrl: imageUrls.first,
        imageWidth: null,
        imageHeight: null,
      );
    }
    return PostImageCarousel(
      imageUrls: imageUrls,
      semanticLabelBuilder: (index, total) => 'รูปที่ ${index + 1} จาก $total',
    );
  }
}
