import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../../../../core/widgets/post_media.dart';
import '../../../drop/data/drop_repository.dart';
import '../../data/home_feed_item.dart';
import 'home_card_metrics.dart';

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

class _HomeFeedImagePeekCarouselState extends State<HomeFeedImagePeekCarousel> {
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
      final urls = await widget.dropRepository.fetchDropImages(widget.item.id);
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
      // Same rounding HomeDropCard's own single-photo path uses -- this
      // is that path's stand-in while the list resolves, so it has to
      // look like it (WYN-107).
      borderRadius: WynSpacing.radiusLg,
    );
  }

  Widget _peekCarousel(BuildContext context, List<String> imageUrls) {
    // Beta3: the row itself is [PostImageCarousel] now -- the same
    // widget Drop Detail builds, so a post's photos are one card row
    // with the same geometry wherever you meet them. Nothing about how
    // this looks in the feed changed: same 82% card, same 4:5, same
    // 16px corners, same 8px gap, same free scroll.
    return PostImageCarousel(
      imageUrls: imageUrls,
      // WYN-107: the row is laid out past the card's right inset so the
      // next card peeks towards the screen edge, but a card is still 82%
      // of the *column* the post is written in -- the Flutter equivalent
      // of the reference prototype's `-mr-6 pr-6` on this same row.
      trailingBleed: homeCardEdgeInset,
      semanticLabelBuilder: (index, total) =>
          'รูปที่ ${index + 1} จาก $total ของ '
          '${widget.item.authorNameOrUsername}',
      // WYN-092: shown on the first card only, same "small icon in the
      // corner, no count" the Founder's reference image shows --
      // unlike Drop Detail's "1/3" counter, which belongs to a screen
      // where you are looking at one post rather than scrolling past
      // it.
      cardOverlayBuilder: (context, index) => index == 0
          ? const Positioned(
              right: 8,
              bottom: 8,
              child: ExcludeSemantics(child: _PeekMultiImageBadge()),
            )
          : null,
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
