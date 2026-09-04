/// The one place that decides how a post's photos are *shaped*,
/// *arranged* and *decoded*, for every surface that shows a post as a
/// post -- Home feed and Drop Detail, single image and multi-image
/// alike.
///
/// Beta3 exists because those surfaces had each grown their own answer:
/// HomeDropCard clamped a Drop's true aspect ratio to 4:5..1.91:1
/// (WYN-093), HomeFeedImagePeekCarousel duplicated that same clamp in a
/// private copy of the function "rather than exporting it just for this
/// one reuse", and DropImageGallery ignored dimensions entirely and
/// rendered every photo into a hard `AspectRatio(1)` with
/// `BoxFit.cover`. The visible result was the Founder's own Beta3
/// report: a portrait photo that reads correctly in the feed is cropped
/// top-and-bottom the moment you open the post -- the same picture,
/// half of it gone, on the one screen dedicated to looking at it.
///
/// A post with several photos is a *row of cards* with the next one
/// peeking in at the edge -- Founder, 2026-09-03: "รูปต้องเรียงกันเป็น
/// การ์ดนะ แล้วก็รูปที่ 2 ก็โผล่นิดเดียว". The Home feed already read
/// that way (WYN-092); Drop Detail did not -- it showed one full-bleed
/// photo at a time in a `PageView`, so the same post was a card row in
/// the feed and a single slab the moment you opened it. [PostImage-
/// Carousel] is now the one implementation both screens build, so
/// there is no second answer to drift from the first.
///
/// Profile's grid is deliberately NOT a caller here: a grid is a
/// content *overview* and square tiles are the right shape for it (see
/// [NetworkThumbnail], which grid tiles already use). This file is
/// about the post-shaped surfaces only.
library;

import 'package:flutter/material.dart';

import '../design/wyn_spacing.dart';
import 'network_thumbnail.dart';

/// The most-portrait shape a post photo is shown at without cropping
/// (4:5) and the most-landscape (1.91:1). Outside that range the photo
/// still renders, cropped at whichever edge it overshoots -- the same
/// bounds WYN-093 established for the feed, now applied everywhere a
/// post is shown post-shaped.
const double minPostImageAspectRatio = 0.8;
const double maxPostImageAspectRatio = 1.91;

/// The aspect ratio to render a post photo at, given its true pixel
/// dimensions. Falls back to a 1:1 square when the dimensions aren't
/// known -- every Drop uploaded before WYN-093 added the columns, and
/// any row with a non-positive height.
double postImageAspectRatio(int? width, int? height) {
  if (width == null || height == null || height <= 0 || width <= 0) return 1;
  return (width / height)
      .clamp(minPostImageAspectRatio, maxPostImageAspectRatio);
}

/// A post's photo: decoded at the size it is actually painted at, with
/// the neutral placeholder/broken-image pair every surface was
/// repeating by hand.
///
/// The decode bound is the reason this is a widget rather than a bare
/// `Image.network` call. Wynos compresses uploads to 1600x1600
/// (WYN-103); a plain `Image.network` decodes all of that regardless of
/// the box it lands in -- ~10MB of bitmap per photo. A feed row on a
/// 390pt-wide phone paints roughly 1170 physical pixels of width at
/// DPR 3, and only 780 at DPR 2, so the same photo costs ~5.5MB and
/// ~2.4MB respectively once decoded to fit. With images from several
/// rows alive at once that difference is the difference between a feed
/// that scrolls and one the OS starts evicting.
///
/// Deliberately still `Image.network` under the hood, not
/// `CachedNetworkImage`: WYN-074 tried that and every image failed to
/// render on this project's Flutter Web build. That constraint has not
/// changed, so neither has this.
class PostImage extends StatelessWidget {
  const PostImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final String imageUrl;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Image.network(
          imageUrl,
          fit: fit,
          semanticLabel: semanticLabel,
          cacheWidth: decodeWidthFor(
            constraints.maxWidth,
            devicePixelRatio: devicePixelRatio,
          ),
          // A neutral block, never a spinner: a post photo resolves in
          // well under a second on any usable connection, and a
          // spinner appearing and vanishing on every row of a scroll
          // is more visual noise than the wait it reports. Matches the
          // placeholder NetworkThumbnail already uses for grid tiles,
          // so a photo looks the same while loading wherever it is.
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
          errorBuilder: networkImageErrorBuilder,
        );
      },
    );
  }
}

/// A post's photo laid out the way every post-shaped surface lays one
/// out: the clamped aspect ratio from [postImageAspectRatio], capped so
/// a tall photo can never eat a whole viewport, decoded to fit.
///
/// The height cap (WYN-093) is a second, independent ceiling on top of
/// the ratio clamp -- without it a photo right at the 4:5 bound fills
/// almost the entire screen on a tall viewport (a tablet held upright),
/// leaving no visible sign that a caption, an action bar, or a next
/// post exists below it.
class PostImageFrame extends StatelessWidget {
  const PostImageFrame({
    super.key,
    required this.imageUrl,
    required this.imageWidth,
    required this.imageHeight,
    this.maxHeightFraction = 0.75,
    this.borderRadius = WynSpacing.radiusNone,
    this.semanticLabel,
  });

  final String imageUrl;
  final int? imageWidth;
  final int? imageHeight;

  /// Share of the viewport height this photo may occupy at most.
  final double maxHeightFraction;

  /// Corner radius the photo is clipped to.
  ///
  /// Defaults to [WynSpacing.radiusNone] -- "let the image be the hero"
  /// for the surfaces where a photo still runs into both screen edges
  /// (Drop Detail, Club), where a rounded corner would only carve a
  /// notch out of a full-bleed slab. WYN-107 gives the Home feed's own
  /// photo [WynSpacing.radiusLg] instead: once the photo sits inside
  /// the card's content column it no longer touches the left edge, and
  /// a square corner floating on white reads as unfinished. A parameter
  /// rather than a hardcoded value precisely because the two cases are
  /// both right, in their own surface.
  final double borderRadius;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final image = PostImage(imageUrl: imageUrl, semanticLabel: semanticLabel);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeightFraction * MediaQuery.sizeOf(context).height,
      ),
      child: AspectRatio(
        aspectRatio: postImageAspectRatio(imageWidth, imageHeight),
        child: borderRadius == WynSpacing.radiusNone
            ? image
            : ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: image,
              ),
      ),
    );
  }
}

// The card row's geometry, shared by every surface that shows a post's
// photos. 82% of the row's width and a 4:5 (portrait) card, both taken
// from design-reference/SPEC.md 4.7 ("Image carousel (peek-card
// style)") and the Founder's own reference image (f91d7b63-image.jpg,
// Beta2 Phase 2 PDF item 14). 82% is what makes the next card "โผล่
// นิดเดียว": the next card shows a sliver of itself past the 8pt gap --
// enough to read as "there is another photo", not enough to read as two
// photos side by side.
//
// The 82% is of the *column the post is written in*, not of whatever
// box the row happens to be painted into -- see
// [PostImageCarousel.trailingBleed], which is how a row that
// deliberately overhangs its column (WYN-107's Home feed card) still
// sizes its cards off the column.
const double postCardWidthFraction = 0.82;

/// The card shape a post's photos are laid out at when the post does not
/// say otherwise -- a Drop written before WYN-109, whose photos were
/// squares the feed already drew in a 4:5 card.
const double postCardAspectRatio = 4 / 5;

/// A post's photos as a row of rounded cards, scrolled horizontally,
/// with the next card peeking in at the right edge.
///
/// The row snaps one card at a time -- Founder, 2026-09-03: "ให้ snap
/// ทีละการ์ดเลย". It used to scroll freely (WYN-092), which left a card
/// parked half off the edge as often as not; a snap means a photo is
/// either the one you are looking at or the one peeking, never a
/// third thing in between. A decisive flick advances exactly one card
/// however hard it was thrown, so a fast scroll through a 9-photo post
/// stays a sequence of photos rather than a blur -- see
/// [_CardSnapPhysics].
///
/// [onIndexChanged] reports which card is in front, computed from the
/// scroll offset, for a caller that wants a position indicator (Drop
/// Detail's counter and dots).
class PostImageCarousel extends StatefulWidget {
  const PostImageCarousel({
    super.key,
    required this.imageUrls,
    this.onIndexChanged,
    this.semanticLabelBuilder,
    this.cardOverlayBuilder,
    this.trailingBleed = 0,
    this.aspectRatio = postCardAspectRatio,
  });

  /// Two or more URLs. A caller with one image wants [PostImageFrame].
  final List<String> imageUrls;

  /// How far this row is laid out *past* the trailing edge of the
  /// column the post is written in, so the next card can peek out
  /// towards the screen edge instead of stopping short of it.
  ///
  /// [postCardWidthFraction] is measured against the column, not the
  /// row: a card is 82% of what a paragraph of this post is wide. With
  /// the default 0 the two are the same box (Drop Detail, Club, where
  /// the row already spans the whole content width). WYN-107's Home
  /// feed card passes its own right inset here, the Flutter equivalent
  /// of the `-mr-6 pr-6` the CSS prototype in
  /// design-reference/01-home.tsx uses on this exact row.
  final double trailingBleed;

  /// The shape of each card in the row -- WYN-109, where the poster
  /// chooses it. Was a constant 4:5, which meant a photo posted as 16:9
  /// got cropped back to portrait on its way into the feed and the
  /// choice was no choice at all.
  final double aspectRatio;

  /// Called with the index of the card currently in front, whenever
  /// that changes.
  final ValueChanged<int>? onIndexChanged;

  /// The accessibility label for card [index] of [total].
  final String Function(int index, int total)? semanticLabelBuilder;

  /// An optional widget stacked over card [index] -- the feed's
  /// "multiple photos" badge on the first card, for instance. Return
  /// null for cards that carry nothing.
  final Widget? Function(BuildContext context, int index)? cardOverlayBuilder;

  @override
  State<PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<PostImageCarousel> {
  final _controller = ScrollController();
  int _index = 0;

  // Rebuilt only when the card stride actually changes (a rotation, a
  // resize), not on every build -- handing Scrollable a fresh physics
  // object each frame is wasteful and, worse, can interrupt a
  // simulation that is mid-flight.
  double? _stride;
  ScrollPhysics? _physics;

  ScrollPhysics _physicsFor(double stride) {
    if (_physics == null || _stride != stride) {
      _stride = stride;
      _physics = _CardSnapPhysics(
        stride: stride,
        parent: const ClampingScrollPhysics(),
      );
    }
    return _physics!;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Which card is in front, from the scroll offset: each step is one
  /// card plus the gap after it. Rounding (not flooring) means the
  /// indicator flips at the halfway point, and lands exactly on a card
  /// once the snap settles -- including at the very end of the row,
  /// where the last card stops short of a whole stride because there
  /// is nothing left to scroll into.
  void _updateIndex(double stride) {
    if (!_controller.hasClients || stride <= 0) return;
    final next = (_controller.position.pixels / stride)
        .round()
        .clamp(0, widget.imageUrls.length - 1);
    if (next == _index) return;
    setState(() => _index = next);
    widget.onIndexChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The column, not the row -- see [trailingBleed].
        final columnWidth = (constraints.maxWidth - widget.trailingBleed)
            .clamp(0.0, double.infinity);
        final cardWidth = columnWidth * postCardWidthFraction;
        final cardHeight = cardWidth / widget.aspectRatio;
        final stride = cardWidth + WynSpacing.space2;

        return SizedBox(
          height: cardHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification ||
                  notification is ScrollEndNotification) {
                _updateIndex(stride);
              }
              // Never swallowed: Drop Detail wraps this row in its own
              // scroll view, which still needs to see these.
              return false;
            },
            child: ListView.builder(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: _physicsFor(stride),
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                final isLast = index == widget.imageUrls.length - 1;
                final overlay = widget.cardOverlayBuilder?.call(context, index);
                final card = ClipRRect(
                  borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
                  child: SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: overlay == null
                        ? PostImage(imageUrl: widget.imageUrls[index])
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              PostImage(imageUrl: widget.imageUrls[index]),
                              overlay,
                            ],
                          ),
                  ),
                );

                return Padding(
                  padding: EdgeInsets.only(
                    right: isLast ? 0 : WynSpacing.space2,
                  ),
                  child: widget.semanticLabelBuilder == null
                      ? card
                      : Semantics(
                          label: widget.semanticLabelBuilder!(
                            index,
                            widget.imageUrls.length,
                          ),
                          image: true,
                          excludeSemantics: true,
                          child: card,
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Snaps a [PostImageCarousel]'s row to one card at a time.
///
/// A row of 82%-wide cards can't use [PageScrollPhysics], which snaps
/// to whole viewports, and a `PageView` would have to fold the gap
/// between cards into its own `viewportFraction` -- making the card's
/// width depend on the gap and drift from the 82% the design is
/// specified in. Snapping to multiples of the card's stride keeps both
/// numbers exactly what they say they are.
class _CardSnapPhysics extends ScrollPhysics {
  const _CardSnapPhysics({required this.stride, super.parent});

  /// One card plus the gap that follows it.
  final double stride;

  @override
  _CardSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _CardSnapPhysics(stride: stride, parent: buildParent(ancestor));

  /// Where the row should come to rest.
  ///
  /// A deliberate flick moves exactly one card in the direction it was
  /// thrown, however hard -- that is what makes a 9-photo post a
  /// sequence of photos rather than a blur that ends somewhere
  /// arbitrary. A slow drag simply settles on whichever card is
  /// nearest when the finger lifts.
  double _target(ScrollMetrics position, double velocity) {
    final current = position.pixels / stride;
    final double index;
    if (velocity < -minFlingVelocity) {
      index = current.floorToDouble();
    } else if (velocity > minFlingVelocity) {
      index = current.ceilToDouble();
    } else {
      index = current.roundToDouble();
    }
    return (index * stride)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Past either end, the parent owns the behaviour (the clamped
    // stop, or a bounce on iOS) -- snapping there would fight it.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final target = _target(position, velocity);
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  /// A snapping row has no meaningful intermediate resting places, so
  /// assistive tech should not try to scroll it by arbitrary amounts.
  @override
  bool get allowImplicitScrolling => false;
}
