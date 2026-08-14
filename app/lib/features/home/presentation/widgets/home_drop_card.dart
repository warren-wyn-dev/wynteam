import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../drop/presentation/drop_detail_screen.dart' show dropShareLink;
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/home_feed_item.dart';

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

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: dropShareLink(item.id)),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: InkWell(
                  onTap: onOpenProfile,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarCircle(
                        imageUrl: item.authorAvatarUrl,
                        fallbackText: item.authorUsername,
                        radius: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.authorNameOrUsername,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
              AspectRatio(
                aspectRatio: 1,
                child: Image.network(item.imageUrl!, fit: BoxFit.cover),
              ),
              if (item.caption != null && item.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text(item.caption!),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
                    const SizedBox(width: 8),
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
