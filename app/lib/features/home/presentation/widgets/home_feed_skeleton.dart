import 'package:flutter/material.dart';

import '../../../../core/design/wyn_spacing.dart';
import 'home_card_metrics.dart';

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
///
/// WYN-140: rebuilt on [homeCardEdgeInset]/[homeCardAvatarGap]/
/// [homeCardAvatarDiameter] -- the same two-column geometry WYN-107 gave
/// the real cards (avatar as its own left column, everything else in a
/// right column starting at the name), so a card doesn't visibly shift
/// the moment real content replaces its placeholder. Previously this
/// skeleton predated WYN-107 and still used the old single-Row layout
/// with generic 16px padding, which the real card hasn't used since.
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
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: homeCardEdgeInset),
                child: CircleAvatar(
                  radius: homeCardAvatarDiameter / 2,
                  backgroundColor: color,
                ),
              ),
              const SizedBox(width: homeCardAvatarGap),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: homeCardEdgeInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(width: 120, height: 13),
                      const SizedBox(height: WynSpacing.space1),
                      bar(width: 70, height: 10),
                      const SizedBox(height: WynSpacing.space3),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(WynSpacing.radiusLg),
                        child: AspectRatio(
                          aspectRatio: 4 / 5,
                          child: ColoredBox(color: color),
                        ),
                      ),
                      const SizedBox(height: WynSpacing.space3),
                      Row(
                        children: [
                          bar(width: 44),
                          const SizedBox(width: WynSpacing.space5),
                          bar(width: 44),
                          const SizedBox(width: WynSpacing.space5),
                          bar(width: 44),
                        ],
                      ),
                    ],
                  ),
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
