import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/text_utils.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/club_member.dart';
import '../../data/club_post.dart';
import '../club_post_detail_screen.dart' show clubPostShareLink;
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/action_sheet_row.dart';
import '../../../../core/widgets/hashtag_text.dart';
import '../../../report/data/report_repository.dart';
import '../../../report/data/report_target_type.dart';
import '../../../report/presentation/report_sheet.dart';
import '../../../../core/widgets/post_media.dart';

/// A Club post card for the Posts tab list. Same interaction-row family
/// as HomeDropCard/HomePopCard (Like/Comment/Share/Bookmark), plus a
/// role-gated More menu per the Design spec, Screen 5.
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
    // Everyone can open the More menu now that a non-moderator, non-
    // author viewer still has "รายงานโพสต์" to see there (WYN-026).
    const showMoreButton = true;

    return InkWell(
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
                  AvatarCircle(
                    imageUrl: post.authorAvatarUrl,
                    fallbackText: post.authorUsername,
                    radius: 17,
                    ring: true,
                  ),
                  const SizedBox(width: WynSpacing.space2),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            post.authorNameOrUsername,
                            overflow: TextOverflow.ellipsis,
                            style: _textStyle(
                                fontSize: 15, fontWeight: FontWeight.w600, color: WynColors.ink),
                          ),
                        ),
                        const SizedBox(width: WynSpacing.space2),
                        Text(
                          relativeTimeLabel(post.createdAt, now: DateTime.now()),
                          style: _textStyle(fontSize: 13, color: WynColors.mutedNeutral),
                        ),
                      ],
                    ),
                  ),
                  if (showMoreButton)
                    IconButton(
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: WynColors.faint),
                      onPressed: () => _openMoreMenu(context),
                    ),
                ],
              ),
            ),
            if (post.content != null && post.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: HashtagText(
                  post.content!,
                  style: _textStyle(fontSize: 16, color: WynColors.ink, height: 1.5),
                ),
              ),
            if (post.imageUrls != null && post.imageUrls!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: WynSpacing.space2),
                child: ClubPostImages(imageUrls: post.imageUrls!),
              ),
            if (post.linkUrl != null && post.linkUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
              padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space1),
              child: Row(
                children: [
                  Semantics(
                    label: post.likedByMe ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ' : 'กดเพื่อถูกใจ',
                    excludeSemantics: true,
                    child: IconButton(
                      icon: Icon(
                        post.likedByMe ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: post.likedByMe
                            ? WynColors.iconLikeActive
                            : WynColors.iconIdle,
                      ),
                      onPressed: onToggleLike,
                    ),
                  ),
                  Text('${post.likeCount}',
                      style: _textStyle(fontSize: 13, color: WynColors.graphite)),
                  const SizedBox(width: WynSpacing.space2),
                  Semantics(
                    label: 'ดูคอมเมนต์',
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.mode_comment_outlined,
                          size: 18, color: WynColors.graphite),
                      onPressed: onTap,
                    ),
                  ),
                  Text('${post.commentCount}',
                      style: _textStyle(fontSize: 13, color: WynColors.graphite)),
                  // Not in 08-club.tsx's own 3-icon ClubPostRow (real,
                  // existing capability -- Founder decision, 2026-08-29).
                  Semantics(
                    label: 'แชร์',
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined,
                          size: 18, color: WynColors.graphite),
                      onPressed: _share,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: post.savedByMe ? 'บันทึกแล้ว กดเพื่อเอาออกจาก Saved' : 'กดเพื่อบันทึก',
                    excludeSemantics: true,
                    child: IconButton(
                      icon: Icon(
                        post.savedByMe ? Icons.bookmark : Icons.bookmark_border,
                        size: 17,
                        color: WynColors.faint,
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


TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? height,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
