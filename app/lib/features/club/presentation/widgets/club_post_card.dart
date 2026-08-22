import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/text_utils.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/club_member.dart';
import '../../data/club_post.dart';
import '../club_post_detail_screen.dart' show clubPostShareLink;
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/hashtag_text.dart';
import '../../../report/data/report_repository.dart';
import '../../../report/data/report_target_type.dart';
import '../../../report/presentation/report_sheet.dart';

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
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (_isOwnPost || canModerate)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('ลบโพสต์'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDelete(context);
                },
              ),
            if (!_isOwnPost && canModerate)
              ListTile(
                leading: Icon(post.pinned ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(post.pinned ? 'เลิกปักหมุด' : 'ปักหมุด'),
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
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('รายงานโพสต์'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _report(context);
                },
              ),
          ],
        ),
      ),
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
                    radius: 16,
                  ),
                  const SizedBox(width: WynSpacing.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorNameOrUsername,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          relativeTimeLabel(post.createdAt, now: DateTime.now()),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (showMoreButton)
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _openMoreMenu(context),
                    ),
                ],
              ),
            ),
            if (post.content != null && post.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: HashtagText(post.content!),
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
                        color: post.likedByMe ? Colors.red : null,
                      ),
                      onPressed: onToggleLike,
                    ),
                  ),
                  Text('${post.likeCount}'),
                  const SizedBox(width: WynSpacing.space2),
                  Semantics(
                    label: 'ดูคอมเมนต์',
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.mode_comment_outlined, size: 20),
                      onPressed: onTap,
                    ),
                  ),
                  Text('${post.commentCount}'),
                  Semantics(
                    label: 'แชร์',
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      onPressed: _share,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: post.savedByMe ? 'บันทึกแล้ว กดเพื่อเอาออกจาก Saved' : 'กดเพื่อบันทึก',
                    excludeSemantics: true,
                    child: IconButton(
                      icon: Icon(post.savedByMe ? Icons.bookmark : Icons.bookmark_border),
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
class ClubPostImages extends StatefulWidget {
  const ClubPostImages({super.key, required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<ClubPostImages> createState() => _ClubPostImagesState();
}

class _ClubPostImagesState extends State<ClubPostImages> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.length == 1) {
      return AspectRatio(
        aspectRatio: 1,
        child: Image.network(widget.imageUrls.first, fit: BoxFit.cover),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) =>
                Image.network(widget.imageUrls[index], fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.imageUrls.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == _page
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
