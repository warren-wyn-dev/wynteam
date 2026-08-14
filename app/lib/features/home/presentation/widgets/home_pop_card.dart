import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../pop/presentation/widgets/pop_clip_view.dart' show popShareLink;
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/home_feed_item.dart';

/// Formats a duration in seconds as "m:ss" (e.g. 45 -> "0:45").
String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// A Pop card in the Home feed. Deliberately a square thumbnail with a
/// play icon and duration badge -- not full 9:16 autoplaying video -- so
/// card heights stay consistent with HomeDropCard while scrolling and no
/// video plays until the user actually taps in. See
/// .wyn/docs/design/wyn-007-home.md, Design Rules.
class HomePopCard extends StatelessWidget {
  const HomePopCard({
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
      ShareParams(text: popShareLink(item.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'วิดีโอของ ${item.authorNameOrUsername} ความยาว ${item.durationSeconds} วินาที',
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.thumbnailUrl != null)
                      Image.network(item.thumbnailUrl!, fit: BoxFit.cover)
                    else
                      Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                    if (item.durationSeconds != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x99000000),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDuration(item.durationSeconds!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
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
                    const Icon(Icons.visibility_outlined, size: 18),
                    const SizedBox(width: 4),
                    Text('${item.viewCount}'),
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
