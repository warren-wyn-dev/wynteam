import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/widgets/double_tap_like.dart';
import '../../data/drop.dart';
import '../../data/drop_repository.dart';
import 'drop_image_viewer.dart';

/// DropDetailScreen's image area -- WYN-071 Design, Screens 3-4. A
/// single-image Drop renders exactly as it always has (this widget
/// changes nothing about that case); a multi-image Drop additionally
/// fetches the full ordered list on demand ([DropRepository.
/// fetchDropImages], only ever called for this case -- see that
/// method's own doc comment) and shows a swipeable PageView with a
/// position counter, tapping into [DropImageViewer] for the full-screen
/// pinch-to-zoom experience.
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
  // Null until the multi-image case's fetch resolves. Never touched at
  // all for a single-image Drop.
  List<String>? _imageUrls;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.drop.hasMultipleImages) _load();
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
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.network(url, fit: BoxFit.cover),
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
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: imageUrls.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) =>
                  Image.network(imageUrls[index], fit: BoxFit.cover),
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
    );
  }
}
