import 'package:flutter/material.dart';

import '../../../../core/text_utils.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/review.dart';
import 'star_rating.dart';

/// A single review row -- mirrors PopCommentSheet's comment tile
/// structure (avatar + author name + content), with a star rating and
/// [Review.productName] (shown only when non-null, i.e. on
/// StoreScreen's combined Reviews tab) added. See
/// .wyn/docs/design/zoky-004-review.md.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarCircle(
            imageUrl: review.authorAvatarUrl,
            fallbackText: review.authorUsername,
            radius: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review.authorNameOrUsername, style: Theme.of(context).textTheme.titleSmall),
                if (review.productName != null)
                  Text(
                    review.productName!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    StarRatingDisplay(rating: review.rating.toDouble()),
                    const SizedBox(width: 8),
                    Text(
                      relativeTimeLabel(review.createdAt, now: DateTime.now()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
                if (review.textContent != null && review.textContent!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(review.textContent!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
