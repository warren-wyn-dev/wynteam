import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../home/data/home_feed_item.dart';

/// Formats a duration in seconds as "m:ss" (e.g. 45 -> "0:45").
String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// One square tile in the Saved tab (WYN-013) -- Drop and Pop mixed in
/// the same grid, distinguished the same way HomePopCard/PopGridTile
/// already do (play icon + duration badge on Pop, nothing extra on
/// Drop), same "one family" reasoning as the rest of the app since
/// WYN-007.
class SavedGridTile extends StatelessWidget {
  const SavedGridTile({super.key, required this.item, required this.onTap});

  final HomeFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPop = item.contentType == HomeContentType.pop;
    return Semantics(
      label: isPop
          ? 'วิดีโอของ ${item.authorNameOrUsername} ความยาว ${item.durationSeconds} วินาที'
          : 'รูปของ ${item.authorNameOrUsername}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isPop)
                if (item.thumbnailUrl != null)
                  Image.network(item.thumbnailUrl!, fit: BoxFit.cover)
                else
                  Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  )
              else
                Image.network(item.imageUrl!, fit: BoxFit.cover),
              if (isPop) ...[
                const Center(
                  child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
                ),
                if (item.durationSeconds != null)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: ExcludeSemantics(
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: WynColors.imageScrim,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          _formatDuration(item.durationSeconds!),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
