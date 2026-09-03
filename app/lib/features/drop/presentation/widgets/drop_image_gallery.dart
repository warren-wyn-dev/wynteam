import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../../../../core/widgets/post_media.dart';
import '../../data/drop.dart';
import '../../data/drop_repository.dart';
import 'drop_image_viewer.dart';

/// DropDetailScreen's image area -- WYN-071 Design, Screens 3-4. A
/// multi-image Drop shows a swipeable PageView with a position counter
/// and dots; either shape taps into [DropImageViewer] for the
/// full-screen pinch-to-zoom experience.
///
/// Beta3 changed two things here, both about the same complaint: a
/// photo did not look like itself on the one screen dedicated to
/// looking at it.
///
/// 1. Shape. Every photo used to be forced into `AspectRatio(1)` with
///    `BoxFit.cover`, so a 4:5 portrait -- the most common phone-camera
///    shape, and one the feed renders whole -- lost its top and bottom
///    the instant the post was opened. It now uses the same
///    [postImageAspectRatio] clamp the feed does, computed from the
///    Drop's real dimensions. A gallery uses one ratio for all of its
///    images (the first image's, which is the one `drops.image_width/
///    image_height` describes) so that swiping between them doesn't
///    make the page jump; a single image simply uses its own.
/// 2. Where the list comes from. It is taken from [Drop.imageUrls] when
///    the caller already has it -- opening a multi-image post from the
///    feed now costs no image request at all -- and only fetched here
///    ([DropRepository.fetchDropImages]) when it doesn't.
class DropImageGallery extends StatefulWidget {
  const DropImageGallery({
    super.key,
    required this.drop,
    required this.dropRepository,
    required this.onLike,
    required this.onDropChanged,
  });

  final Drop drop;
  final DropRepository dropRepository;
  final VoidCallback onLike;

  /// Forwarded straight through to [DropImageViewer]'s own callback of
  /// the same name -- see that widget's doc comment.
  final ValueChanged<Drop> onDropChanged;

  @override
  State<DropImageGallery> createState() => _DropImageGalleryState();
}

class _DropImageGalleryState extends State<DropImageGallery> {
  // Null until the images are known: taken straight off the Drop when
  // whoever pushed this screen already had the list (the feed
  // batch-loads it per page), otherwise filled in by [_load]. Never
  // touched at all for a single-image Drop.
  List<String>? _imageUrls;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.drop.hasMultipleImages) return;
    _imageUrls = widget.drop.imageUrls;
    if (_imageUrls == null) _load();
  }

  Future<void> _load() async {
    try {
      final urls = await widget.dropRepository.fetchDropImages(widget.drop.id);
      if (!mounted) return;
      setState(() => _imageUrls = urls);
    } catch (_) {
      // Falls back to just the first image below (imageUrl) -- a
      // failed fetch here shouldn't block viewing the Drop at all.
    }
  }

  void _openFullScreen(List<String> imageUrls) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropImageViewer(
          drop: widget.drop,
          imageUrls: imageUrls,
          initialIndex: _currentIndex,
          dropRepository: widget.dropRepository,
          onDropChanged: widget.onDropChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = _imageUrls;

    // Single image (the overwhelmingly common case, and every Drop
    // before WYN-071 existed) -- or the multi-image fetch just hasn't
    // resolved yet, in which case the first image (drop.imageUrl) is
    // shown immediately rather than a loading spinner, same posture as
    // every other "show what we already have while more loads" pattern
    // in this app.
    if (imageUrls == null || imageUrls.length <= 1) {
      final url = widget.drop.imageUrl;
      if (url == null) return const SizedBox.shrink();
      return DoubleTapLike(
        onLike: widget.onLike,
        alreadyLiked: widget.drop.likedByMe,
        // A taller cap than the feed's 0.75: Detail is the one screen
        // where this post is the only thing on it, so a portrait photo
        // is allowed more of the viewport -- still capped, so the
        // caption above and the action bar below never scroll entirely
        // out of reach on a tall screen.
        child: PostImageFrame(
          imageUrl: url,
          imageWidth: widget.drop.imageWidth,
          imageHeight: widget.drop.imageHeight,
          maxHeightFraction: _detailMaxHeightFraction,
        ),
      );
    }

    return DoubleTapLike(
      onLike: widget.onLike,
      alreadyLiked: widget.drop.likedByMe,
      // Single tap and double tap live on the *same* GestureDetector
      // (see DoubleTapLike.onTap's own doc comment) rather than a
      // second nested one -- that's what lets both resolve reliably
      // instead of the single-tap recognizer being starved by the
      // double-tap disambiguation window.
      onTap: () => _openFullScreen(imageUrls),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              _detailMaxHeightFraction * MediaQuery.sizeOf(context).height,
        ),
        child: AspectRatio(
          aspectRatio: postImageAspectRatio(
            widget.drop.imageWidth,
            widget.drop.imageHeight,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                itemCount: imageUrls.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) =>
                    PostImage(imageUrl: imageUrls[index]),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: ExcludeSemantics(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: WynColors.imageScrim,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${imageUrls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Semantics(
                  label: 'รูปที่ ${_currentIndex + 1} จาก ${imageUrls.length}',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < imageUrls.length; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _currentIndex
                                ? Colors.white
                                : Colors.white38,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How much of the viewport a post's photo may fill on Drop Detail.
/// Higher than the feed's 0.75 (see [PostImageFrame]) because this
/// screen shows one post and nothing else -- but still a cap, so the
/// caption above and the action bar below stay within a short scroll
/// rather than being pushed off a tall screen by a portrait photo.
const double _detailMaxHeightFraction = 0.85;
