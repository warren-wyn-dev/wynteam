import 'package:flutter/material.dart';

import 'wynos_double_tap_like.dart';

/// WYNOS Home reference spec 4.7 -- the "peek card" multi-image
/// carousel: each card 82% of the available width, 4:5 aspect ratio,
/// 16px corner radius, an 8px gap between cards, snapping, with the
/// next card always peeking in from the right edge. Double-tap
/// anywhere in the carousel likes the post (see [WynosDoubleTapLike],
/// wrapping the whole scroll area the same way the reference puts its
/// onClick handler on the outer scroll container, not per-image).
///
/// [imageUrls] must have at least 2 entries -- HomeDropCard only ever
/// builds this once [HomeFeedItem.hasMultipleImages] is true; a
/// single-image Drop keeps using the plain static image display.
class WynosImageCarousel extends StatelessWidget {
  const WynosImageCarousel({
    super.key,
    required this.imageUrls,
    required this.onLike,
    required this.alreadyLiked,
  });

  final List<String> imageUrls;
  final VoidCallback onLike;
  final bool alreadyLiked;

  static const double _cardWidthFraction = 0.82;
  static const double _cardAspectRatio = 4 / 5;
  static const double _cardGap = 8;
  static const double _cardRadius = 16;

  @override
  Widget build(BuildContext context) {
    return WynosDoubleTapLike(
      onLike: onLike,
      alreadyLiked: alreadyLiked,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth * _cardWidthFraction;
          final cardHeight = cardWidth / _cardAspectRatio;

          return SizedBox(
            height: cardHeight,
            // padEnds: false -- the first card starts flush with the
            // carousel's own left edge; every card after it peeks in
            // from the right by construction of a sub-1.0
            // viewportFraction, matching the reference's "next card
            // peeking" effect without needing a literal negative-
            // margin trick (a CSS-specific technique with no direct
            // Flutter equivalent).
            child: PageView.builder(
              padEnds: false,
              controller: PageController(viewportFraction: _cardWidthFraction),
              physics: const PageScrollPhysics(),
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                final isLast = index == imageUrls.length - 1;
                return Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : _cardGap),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_cardRadius),
                    child: Image.network(
                      imageUrls[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Shown in place of [WynosImageCarousel] while the full image list is
/// still loading (DropRepository.fetchDropImages is on-demand, not
/// eager -- see that method's own doc comment) -- a single static card
/// using the Drop's already-known first image ([HomeFeedItem.imageUrl]
/// doubles as images[0], the invariant WYN-071's drop_images migration
/// in supabase/schema.sql establishes), sized and shaped like a
/// carousel card so there's no layout jump once the real carousel
/// replaces it.
class WynosImageCarouselPlaceholder extends StatelessWidget {
  const WynosImageCarouselPlaceholder({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            constraints.maxWidth * WynosImageCarousel._cardWidthFraction;
        final cardHeight = cardWidth / WynosImageCarousel._cardAspectRatio;
        return SizedBox(
          height: cardHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(WynosImageCarousel._cardRadius),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: cardWidth,
                height: cardHeight,
              ),
            ),
          ),
        );
      },
    );
  }
}
