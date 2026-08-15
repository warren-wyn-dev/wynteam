import 'package:flutter/material.dart';

/// Interactive 5-star picker for ReviewFormSheet (ZOKY-004) -- tapping
/// star N selects a rating of N, filling stars 1..N and leaving the
/// rest outlined. [rating] is 0 (no stars filled) until the user taps
/// one; there's no default selection, since submitting a review
/// requires an explicit choice (see .wyn/docs/design/zoky-004-review.md,
/// ReviewFormSheet).
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
  });

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Semantics(
            label: 'ให้ $star ดาว',
            excludeSemantics: true,
            child: IconButton(
              iconSize: 32,
              icon: Icon(
                star <= rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              onPressed: () => onChanged(star),
            ),
          ),
      ],
    );
  }
}

/// Read-only star rating display for review tiles/rating summaries
/// (ZOKY-004) -- rounds [rating] to the nearest whole star rather than
/// rendering a partial (half) star, to keep the widget simple.
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final filled = rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            star <= filled ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
      ],
    );
  }
}
