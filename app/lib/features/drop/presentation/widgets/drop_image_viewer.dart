import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Full-screen, swipeable, pinch-to-zoom image viewer -- WYN-071 Design,
/// Screen 4. Opened by tapping a multi-image Drop's gallery in
/// DropDetailScreen (see DropImageGallery). Always an ink background
/// regardless of the app's light theme -- 20-image-viewer.tsx's own doc
/// comment: "the one screen in the app that intentionally breaks from
/// the light palette, the way a lightbox does in most apps."
///
/// The reference also shows a like/share/bookmark action row under the
/// dots -- deliberately not added here: this widget only ever receives
/// [imageUrls]/[initialIndex], no [Drop] or repositories, so real
/// like/save state would mean threading those through and duplicating
/// DropDetailScreen's own interaction logic in a second place, a real
/// scope expansion rather than a restyle. Left as a flagged gap, not
/// guessed at, same posture as Bookmarks' own unimplemented per-row
/// unsave affordance.
class DropImageViewer extends StatefulWidget {
  const DropImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<DropImageViewer> createState() => _DropImageViewerState();
}

class _DropImageViewerState extends State<DropImageViewer> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Semantics(
                    label: 'ปิด',
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 22, color: WynColors.paper),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: WynColors.paper.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) => InteractiveViewer(
                  child: Center(
                    child: Image.network(widget.imageUrls[index]),
                  ),
                ),
              ),
            ),
            if (widget.imageUrls.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
                child: Semantics(
                  label:
                      'รูปที่ ${_currentIndex + 1} จาก ${widget.imageUrls.length}',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.imageUrls.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _currentIndex ? 14 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2.5),
                            color: i == _currentIndex
                                ? WynColors.paper
                                : WynColors.paper.withValues(alpha: 0.33),
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
