import 'package:flutter/material.dart';

/// Square grid-tile fallback for a caption-only Drop (WYNOS V1.0.0 Beta
/// requirement 2: a Drop no longer needs a photo) -- mirrors
/// [PollPlaceholderTile]'s "not every Drop has an image" role, but shows
/// a caption snippet instead of a fixed "โพล" label since there's real
/// text worth previewing here.
class TextDropPlaceholderTile extends StatelessWidget {
  const TextDropPlaceholderTile({super.key, required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Text(
        caption,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
