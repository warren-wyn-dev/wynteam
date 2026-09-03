import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../../../../core/widgets/post_media.dart';
import '../../../drop/data/drop_repository.dart';
import '../../data/home_feed_item.dart';

/// Home feed's "peek" carousel for a multi-image Drop -- WYN-092
/// (Wynos V1.0.0 Beta2 Phase 2, item 14). Only ever built by
/// [HomeDropCard] when `item.hasMultipleImages` is true; a
/// single-image (or text-only/Poll) Drop never reaches this widget at
/// all and keeps rendering exactly as it always has (a bare
/// `Image.network` in a full-width `AspectRatio`, unchanged).
///
/// Deliberately a *different* shape from DropDetailScreen's own
/// `DropImageGallery` (full-bleed 1:1 `PageView` + "1/3" counter badge
/// + dot indicator) -- that widget is Detail screen's "look at this
/// one post" pattern; this one is Home feed's "scroll past quickly,
/// peek that there's more" pattern: each image renders at 82% of the
/// row's width with a 4:5 aspect ratio and 16px rounded corners, and
/// the next image visibly peeks in at the right edge. Both patterns
/// are correct in their own context -- see
/// .wyn/docs/design/wyn-092-home-feed-multi-image-peek-carousel.md.
///
/// Row/card width here is already the full device width by the time
/// this widget is built -- [HomeDropCard]'s image slot has never had
/// any horizontal padding around it (same "let the image be the hero"
/// posture `WynSpacing.radiusNone`'s own doc comment describes for the
/// single-image case). That's *why* this widget doesn't need the
/// "negative right margin" trick `design-reference/01-home.tsx`'s CSS
/// prototype uses (there, the *page* itself has horizontal padding the
/// scroll container has to bleed past) -- an 82%-wide item inside a
/// horizontal `ListView` that already spans the full row naturally
/// leaves the next item's leading edge visible without any extra
/// margin math. The 82%/4:5/16px/8px-gap visual result is identical
/// either way; only the technique differs because the ambient layout
/// differs.
class HomeFeedImagePeekCarousel extends StatefulWidget {
  const HomeFeedImagePeekCarousel({
    super.key,
    required this.item,
    required this.dropRepository,
    required this.onLike,
  });

  /// Must have `item.hasMultipleImages == true` -- the caller
  /// ([HomeDropCard]) is the one that checks this before building this
  /// widget at all.
  final HomeFeedItem item;
  final DropRepository dropRepository;
  final VoidCallback onLike;

  @override
  State<HomeFeedImagePeekCarousel> createState() =>
      _HomeFeedImagePeekCarouselState();
}

class _HomeFeedImagePeekCarouselState
    extends State<HomeFeedImagePeekCarousel> {
  // Null until the images are known -- which, since Beta3, is almost
  // always immediately: HomeRepository batch-loads every multi-image
  // Drop of a page in one query and hands the list down on the item
  // itself, so this widget usually builds its carousel on the very
  // first frame with no request of its own. [_load] is the fallback
  // for the paths that don't carry the list (Profile's tabs and the
  // hashtag feed build their cards from a plain Drop), and for a
  // batch that failed. In every "not known yet" case the build method
  // shows just the first image ([HomeFeedItem.imageUrl]) rather than a
  // spinner, same "show what we already have while more loads" posture
  // as DropImageGallery's identical field.
  List<String>? _imageUrls;

  @override
  void initState() {
    super.initState();
    _imageUrls = widget.item.imageUrls;
    if (_imageUrls == null) _load();
  }

  @override
  void didUpdateWidget(HomeFeedImagePeekCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A row refreshed in place (a Like from this card, a single-row
    // resync after Detail) rebuilds this widget with a new item that
    // carries its own freshly batch-loaded list -- take it rather than
    // holding the one captured at mount, which may now be stale.
    final incoming = widget.item.imageUrls;
    if (incoming != null && incoming != _imageUrls) {
      _imageUrls = incoming;
    }
  }

  Future<void> _load() async {
    try {
      final urls =
          await widget.dropRepository.fetchDropImages(widget.item.id);
      if (!mounted) return;
      setState(() => _imageUrls = urls);
    } catch (_) {
      // Falls back to just the first image below -- a failed fetch
      // here shouldn't block viewing the Drop at all, same posture as
      // DropImageGallery._DropImageGalleryState._load's identical
      // catch clause.
    }
  }

  /// The shared [PostImageFrame] treatment HomeDropCard's own
  /// single-image path uses -- shown while
  /// [_imageUrls] hasn't resolved yet (no loading spinner, "show what
  /// we already have") and as the silent fallback if the fetch fails
  /// outright or somehow comes back with 1 or 0 images.
  Widget _singleImageFallback(BuildContext context) {
    final url = widget.item.imageUrl;
    if (url == null) return const SizedBox.shrink();
    return PostImageFrame(
      imageUrl: url,
      imageWidth: widget.item.imageWidth,
      imageHeight: widget.item.imageHeight,
    );
  }

  Widget _peekCarousel(BuildContext context, List<String> imageUrls) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth * _peekWidthFraction;
        final itemHeight = itemWidth / _peekAspectRatio;
        return SizedBox(
          height: itemHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              final isLast = index == imageUrls.length - 1;
              return Padding(
                padding: EdgeInsets.only(
                  right: isLast ? 0 : WynSpacing.space2,
                ),
                child: Semantics(
                  label: 'รูปที่ ${index + 1} จาก ${imageUrls.length} ของ '
                      '${widget.item.authorNameOrUsername}',
                  image: true,
                  excludeSemantics: true,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
                    child: SizedBox(
                      width: itemWidth,
                      height: itemHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PostImage(imageUrl: imageUrls[index]),
                          // WYN-092: shown on the first card only, same
                          // "small icon in the corner, no count" the
                          // Founder's reference image shows -- unlike
                          // DropImageGallery's "1/3" text badge (a
                          // Detail-screen-only convention, out of
                          // scope here per this widget's own doc
                          // comment).
                          if (index == 0)
                            const Positioned(
                              right: 8,
                              bottom: 8,
                              child: ExcludeSemantics(
                                child: _PeekMultiImageBadge(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = _imageUrls;
    return DoubleTapLike(
      onLike: widget.onLike,
      alreadyLiked: widget.item.likedByMe,
      // No `onTap` passed here -- same as HomeDropCard's own
      // single-image DoubleTapLike usage right above this widget's
      // call site. HomeDropCard already wraps its *entire* card
      // (avatar row through action bar) in one outer InkWell.onTap
      // that opens Detail; a lone single tap that isn't followed by a
      // second tap resolves up to that ancestor exactly as it already
      // does for the single-image case today, so this widget doesn't
      // need (and mustn't add) a second, competing tap handler. A real
      // horizontal drag on the ListView below is a distinct gesture
      // (Scrollable's own drag recognizer) that never conflicts with
      // either tap recognizer -- Flutter's gesture arena resolves
      // "moved past touch slop" as a scroll, not a tap, on its own.
      child: imageUrls == null || imageUrls.length <= 1
          ? _singleImageFallback(context)
          : _peekCarousel(context, imageUrls),
    );
  }
}

/// Small circular "multiple photos" indicator, bottom-right of the
/// first card -- reuses the same `WynColors.imageScrim` dark-circle
/// treatment `HomePopCard`'s duration badge already uses elsewhere in
/// this same feed, rather than inventing a new badge style.
class _PeekMultiImageBadge extends StatelessWidget {
  const _PeekMultiImageBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: WynColors.imageScrim,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.photo_library_outlined,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}

// 82% of the row's width, 4:5 (portrait) aspect ratio -- both taken
// directly from design-reference/SPEC.md 4.7 ("Image carousel
// (peek-card style)") and the Founder's own reference image
// (f91d7b63-image.jpg, Beta2 Phase 2 PDF item 14).
const double _peekWidthFraction = 0.82;
const double _peekAspectRatio = 4 / 5;
