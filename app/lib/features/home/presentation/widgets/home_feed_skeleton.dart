import 'package:flutter/material.dart';

import '../../../../core/design/wyn_spacing.dart';

/// Loading state for the Home feed's initial fetch -- placeholder cards
/// shaped like the real ones (avatar + name row, image block, action
/// row) rather than a lone spinner in an empty viewport.
///
/// Home is the screen a Wynos account opens most often, and it was the
/// one with the weakest loading state: Profile has had a full
/// [ProfileSkeleton] since WYN-013, while Home showed a centered
/// CircularProgressIndicator on blank white. A skeleton also stops the
/// layout jumping when content lands, because the space is already the
/// right shape.
///
/// Static blocks, not an animated shimmer -- same reasoning as
/// ProfileSkeleton: an indeterminate animation makes `pumpAndSettle`
/// never settle, a trap this codebase has hit and documented before.
class HomeFeedSkeleton extends StatelessWidget {
  const HomeFeedSkeleton({super.key, this.cardCount = 3});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    Widget bar({required double width, double height = 12}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
          ),
        );

    Widget card() => Padding(
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: WynSpacing.space4),
                child: Row(
                  children: [
                    CircleAvatar(radius: 18, backgroundColor: color),
                    const SizedBox(width: WynSpacing.space3),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(width: 120, height: 13),
                        const SizedBox(height: WynSpacing.space2),
                        bar(width: 70, height: 10),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: WynSpacing.space3),
              AspectRatio(aspectRatio: 1, child: ColoredBox(color: color)),
              const SizedBox(height: WynSpacing.space3),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: WynSpacing.space4),
                child: Row(
                  children: [
                    bar(width: 44),
                    const SizedBox(width: WynSpacing.space5),
                    bar(width: 44),
                    const SizedBox(width: WynSpacing.space5),
                    bar(width: 44),
                  ],
                ),
              ),
            ],
          ),
        );

    return ExcludeSemantics(
      child: Column(
        children: [for (var i = 0; i < cardCount; i++) card()],
      ),
    );
  }
}
