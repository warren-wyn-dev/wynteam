import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../data/home_feed_item.dart';

/// One square tile in Home's "กำลังนิยม" (Trending) row -- WYN-017.
/// Visually modeled on DropGridTile (image + like-count scrim), but
/// accepts a [HomeFeedItem] so one tile handles both Drop and Pop
/// content, since neither DropGridTile nor PopGridTile is content-type
/// agnostic. See .wyn/docs/design/wyn-017-home-trending-recommended-clubs.md.
class TrendingTile extends StatelessWidget {
  const TrendingTile({super.key, required this.item, required this.onTap});

  final HomeFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPop = item.contentType == HomeContentType.pop;
    final imageUrl = isPop ? item.thumbnailUrl : item.imageUrl;

    return Semantics(
      label: isPop
          ? 'วิดีโอของ ${item.authorNameOrUsername}, ถูกใจ ${item.likeCount} ครั้ง'
          : 'รูปของ ${item.authorNameOrUsername}, ถูกใจ ${item.likeCount} ครั้ง',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                Image.network(imageUrl, fit: BoxFit.cover)
              else
                Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              if (isPop)
                const Center(
                  child: ExcludeSemantics(
                    child: Icon(Icons.play_circle, color: Colors.white, size: 28),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, WynColors.imageScrim],
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite, size: 13, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          '${item.likeCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
