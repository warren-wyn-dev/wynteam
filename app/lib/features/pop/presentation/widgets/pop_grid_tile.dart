import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../data/pop.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/network_thumbnail.dart';

/// Formats a duration in seconds as "m:ss" (e.g. 45 -> "0:45").
String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// One square tile in a profile's Pop grid tab (WYN-013). Media area
/// only -- mirrors HomePopCard's thumbnail/play-icon/duration-badge
/// (WYN-007) with the header/interaction row stripped out, matching
/// DropGridTile's own "minimal, tap in for detail" precedent (WYN-005).
class PopGridTile extends StatelessWidget {
  const PopGridTile({super.key, required this.pop, required this.onTap});

  final Pop pop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'วิดีโอของ ${pop.authorNameOrUsername} ความยาว ${pop.durationSeconds} วินาที',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pop.thumbnailUrl != null)
                NetworkThumbnail(imageUrl: pop.thumbnailUrl!)
              else
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              const Center(
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space1, vertical: 1),
                    decoration: BoxDecoration(
                      color: WynColors.imageScrim,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      _formatDuration(pop.durationSeconds),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
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
