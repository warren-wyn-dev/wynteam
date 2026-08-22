import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../drop/presentation/drop_detail_screen.dart' show dropShareLink;
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/home_feed_item.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/hashtag_text.dart';
import '../../../report/data/report_repository.dart';
import '../../../report/data/report_target_type.dart';
import '../../../report/presentation/report_sheet.dart';

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
  });

  final HomeFeedItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenProfile;

  bool get _isOwnDrop =>
      item.authorId == Supabase.instance.client.auth.currentUser!.id;

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: dropShareLink(item.id)),
    );
  }

  Future<void> _openMoreMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
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
          ],
        ),
      ),
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
                            AvatarCircle(
                              imageUrl: item.authorAvatarUrl,
                              fallbackText: item.authorUsername,
                              radius: 16,
                            ),
                            const SizedBox(width: WynSpacing.space2),
                            Text(
                              item.authorNameOrUsername,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_isOwnDrop)
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'เพิ่มเติม',
                        onPressed: () => _openMoreMenu(context),
                      ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 1,
                child: Image.network(item.imageUrl!, fit: BoxFit.cover),
              ),
              if (item.caption != null && item.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: HashtagText(item.caption!),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space1),
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
                          color: item.likedByMe ? Colors.red : null,
                        ),
                        onPressed: onToggleLike,
                      ),
                    ),
                    Text('${item.likeCount}'),
                    const SizedBox(width: WynSpacing.space2),
                    Semantics(
                      label: 'ดูคอมเมนต์',
                      excludeSemantics: true,
                      child: IconButton(
                        icon: const Icon(Icons.mode_comment_outlined, size: 20),
                        onPressed: onTap,
                      ),
                    ),
                    Text('${item.commentCount}'),
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
                      label: item.savedByMe
                          ? 'บันทึกแล้ว กดเพื่อเอาออกจาก Saved'
                          : 'กดเพื่อบันทึก',
                      excludeSemantics: true,
                      child: IconButton(
                        icon: Icon(
                          item.savedByMe ? Icons.bookmark : Icons.bookmark_border,
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
      ),
    );
  }
}
