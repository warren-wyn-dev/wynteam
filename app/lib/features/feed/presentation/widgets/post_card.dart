import 'package:flutter/material.dart';

import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/post.dart';

/// Reused as-is by FeedScreen and PostDetailScreen so the two never draw a
/// post differently. See .wyn/docs/design/wyn-004-feed-and-post.md
/// (Screen 1 & 3).
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onTapLike,
    required this.onTapComments,
    required this.onTapDelete,
  });

  final Post post;
  final String currentUserId;
  final VoidCallback onTapLike;
  final VoidCallback onTapComments;
  final VoidCallback onTapDelete;

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    return '${diff.inDays} วันที่แล้ว';
  }

  @override
  Widget build(BuildContext context) {
    final isOwnPost = post.authorId == currentUserId;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarCircle(
                imageUrl: post.authorAvatarUrl,
                fallbackText: post.authorUsername,
                radius: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorNameOrUsername,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      _relativeTime(post.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              if (isOwnPost)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'ลบโพสต์',
                  onPressed: onTapDelete,
                ),
            ],
          ),
          if (post.textContent != null && post.textContent!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(post.textContent!),
          ],
          if (post.imageUrl != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(post.imageUrl!, fit: BoxFit.cover),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Semantics(
                label: post.likedByMe ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ' : 'กดเพื่อถูกใจ',
                excludeSemantics: true,
                child: IconButton(
                  icon: Icon(
                    post.likedByMe ? Icons.favorite : Icons.favorite_border,
                    color: post.likedByMe ? Colors.red : null,
                  ),
                  onPressed: onTapLike,
                ),
              ),
              Text('${post.likeCount}'),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined),
                tooltip: 'ความคิดเห็น',
                onPressed: onTapComments,
              ),
              Text('${post.commentCount}'),
            ],
          ),
        ],
      ),
    );
  }
}
