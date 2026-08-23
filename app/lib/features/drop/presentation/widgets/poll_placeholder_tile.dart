import 'package:flutter/material.dart';

/// Square fallback for the spots that used to assume a Drop always
/// has an image -- grid tiles and the Quote ReDrop preview (WYN-035,
/// Design Screen 3). Deliberately doesn't render options/percentages:
/// every place this is used is a thumbnail that opens the full
/// `DropDetailScreen` (or, for the Quote ReDrop preview, is read-only
/// already) -- not somewhere a vote can happen directly.
class PollPlaceholderTile extends StatelessWidget {
  const PollPlaceholderTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.poll_outlined,
              size: 28,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              'โพล',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
