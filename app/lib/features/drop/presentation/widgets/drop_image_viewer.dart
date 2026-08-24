import 'package:flutter/material.dart';

/// Full-screen, swipeable, pinch-to-zoom image viewer -- WYN-064 Design,
/// Screen 4. Opened by tapping a multi-image Drop's gallery in
/// DropDetailScreen (see DropImageGallery). Always a black background
/// regardless of the app's light theme -- a media viewer sitting
/// directly on photos, not a themed surface, same posture the
/// image-scrim tokens in WynColors already document for this exact
/// kind of "always black, unrelated to light/dark theme" case.
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) => InteractiveViewer(
                child: Center(
                  child: Image.network(widget.imageUrls[index]),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Semantics(
                label: 'ปิด',
                button: true,
                excludeSemantics: true,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            if (widget.imageUrls.length > 1)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Semantics(
                  label:
                      'รูปที่ ${_currentIndex + 1} จาก ${widget.imageUrls.length}',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.imageUrls.length; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 6,
                          height: 6,
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
