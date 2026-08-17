import 'package:flutter/material.dart';

/// Generic single-image fullscreen/zoom viewer -- deliberately not tied to
/// Drop (see .wyn/docs/design/wyn-025-drop-composer-polish.md, R3): future
/// features (Club post image, ZOKY product image) can reuse this
/// unchanged, the same way confirm_delete_dialog.dart is shared today.
///
/// Uses only Flutter's built-in InteractiveViewer -- no external zoom
/// package. Deliberately does NOT support multi-image swipe or Hero
/// animation in this round (see design doc's Design Rules).
class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer>
    with SingleTickerProviderStateMixin {
  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;
  static const double _doubleTapScale = 3.0;

  final _transformationController = TransformationController();
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        final animation = _animation;
        if (animation == null) return;
        _transformationController.value = animation.value;
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _onDoubleTap() {
    final isZoomedIn = _transformationController.value != Matrix4.identity();
    final endMatrix = isZoomedIn ? Matrix4.identity() : _zoomedMatrix();

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(
      CurveTween(curve: Curves.easeOut).animate(_animationController),
    );
    _animationController.forward(from: 0);
  }

  Matrix4 _zoomedMatrix() {
    final tapPosition = _doubleTapDetails?.localPosition ?? Offset.zero;
    return Matrix4.identity()
      ..translateByDouble(-tapPosition.dx * (_doubleTapScale - 1),
          -tapPosition.dy * (_doubleTapScale - 1), 0.0, 1.0)
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, _doubleTapScale, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onDoubleTapDown: _onDoubleTapDown,
            onDoubleTap: _onDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: _minScale,
              maxScale: _maxScale,
              child: Center(
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: Colors.white, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'โหลดรูปไม่สำเร็จ',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'ย้อนกลับ',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
