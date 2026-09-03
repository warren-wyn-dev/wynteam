import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../data/profile_photo_crop.dart';

/// Screen — Crop รูปโปรไฟล์ (WYN-104, Wynos V1.0.0 Beta2 item 18).
/// Pushed by `EditProfileScreen._pickImage()` right after `ImagePicker`
/// returns a picked image, *before* it's ever set as that screen's own
/// preview -- see .wyn/docs/design/wyn-104-profile-photo-crop.md, Screen
/// 1. Pops `null` on "ยกเลิก" (caller's existing/previous avatar stays
/// unchanged, exactly as if no new image had been picked at all) or the
/// cropped PNG bytes on "เสร็จสิ้น".
///
/// **Package choice** (Design spec asked this be verified before
/// installing anything): hand-rolled pan/zoom via
/// `GestureDetector.onScale*`, not a new pub dependency
/// (`crop_your_image`, the Product/Design spec's tentative pick pending
/// this exact check). The app already has a working, tested pinch-to-
/// zoom precedent with zero extra dependencies --
/// DropImageViewer/EvidenceImageViewer's `InteractiveViewer` (WYN-071) --
/// and the crop math this screen actually needs (pan/zoom state -> a
/// source `Rect` -> a cropped square) is the exact same dart:ui-only
/// shape as square_crop.dart's existing `centerCropToSquare`. Taking on a
/// new third-party dependency (with its own platform-support/maintenance
/// risk -- Product spec Risk R1 -- and, concretely, no way to verify it
/// installs/builds against this project's pinned Flutter SDK from inside
/// this sandbox) isn't justified when the built-in gesture primitives
/// already cover pinch+drag+bounded-pan exactly as specced. This is the
/// smaller, safer change.
///
/// See profile_photo_crop.dart for the actual pan/zoom/crop math (kept
/// separate and independently unit-tested with plain `test()` -- see that
/// file's own doc comment for why, re: this sandbox's real-image-decode-
/// through-the-widget-tree hang, .wyn/company/DECISIONS.md 2026-09-02).
///
/// **EXIF orientation** (Product spec Edge Case 3): not handled with any
/// extra manual EXIF-parsing step here. `dart:ui`'s image codec (Skia)
/// already applies embedded JPEG EXIF orientation automatically during
/// decode -- the same decoder every `Image`/`ui.instantiateImageCodec`
/// call in this codebase already goes through -- so a photo that's
/// right-side-up in, say, the OS's own photo gallery should already
/// decode right-side-up here with no extra code. This is *unverified on
/// a real device* in this sandbox (no camera, no simulator) -- flagged
/// explicitly for AI QA & Security per Product spec Risk R2, rather than
/// adding unverified manual EXIF-correction code on top of an already-
/// automatic pipeline.
class ProfilePhotoCropScreen extends StatefulWidget {
  const ProfilePhotoCropScreen({
    super.key,
    required this.imageBytes,
    @visibleForTesting this.debugInitialDimensions,
  });

  final Uint8List imageBytes;

  /// Test-only seam: skips the real `decodeImageDimensions` call (which
  /// needs genuinely decodable bytes -- decoding real image bytes
  /// *through the widget tree* hangs in this sandbox, see the class doc
  /// comment above) so widget tests can drive this screen's gesture/
  /// button wiring with throwaway bytes instead. See
  /// profile_photo_crop_screen_test.dart.
  @visibleForTesting
  final (int, int)? debugInitialDimensions;

  @override
  State<ProfilePhotoCropScreen> createState() =>
      _ProfilePhotoCropScreenState();
}

class _ProfilePhotoCropScreenState extends State<ProfilePhotoCropScreen> {
  static const double _viewportSize = 260;
  static const double _minScale = 1.0;
  static const double _maxScale = 3.0;
  static const double _zoomButtonStep = 0.25;

  int? _originalWidth;
  int? _originalHeight;
  double _scale = _minScale;
  Offset _offset = Offset.zero;

  // Gesture-start snapshot -- GestureDetector.onScaleUpdate reports
  // scale/focalPoint relative to onScaleStart, not incrementally frame to
  // frame, so these are needed to turn that into an update against the
  // screen's own running _scale/_offset state.
  double _gestureStartScale = _minScale;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocalPoint = Offset.zero;

  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDimensions();
  }

  Future<void> _loadDimensions() async {
    try {
      final debugDimensions = widget.debugInitialDimensions;
      final (width, height) = debugDimensions ??
          await decodeCropImageDimensions(widget.imageBytes);
      if (!mounted) return;
      setState(() {
        _originalWidth = width;
        _originalHeight = height;
        _offset = centeredCropOffset(
          originalWidth: width,
          originalHeight: height,
          viewportSize: _viewportSize,
          scale: _scale,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'เปิดรูปไม่สำเร็จ ลองเลือกรูปใหม่อีกครั้ง');
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _scale;
    _gestureStartOffset = _offset;
    _gestureStartFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final width = _originalWidth;
    final height = _originalHeight;
    if (width == null || height == null) return;

    // A single-finger drag reports scale == 1.0 throughout (pure pan);
    // a two-finger pinch reports both scale and focalPoint changing at
    // once -- both are handled by this one callback, matching the
    // Design spec's "Drag (1 นิ้ว).../Pinch-to-zoom (2 นิ้ว)..." as two
    // facets of the same gesture rather than two separate handlers.
    final newScale =
        (_gestureStartScale * details.scale).clamp(_minScale, _maxScale);
    final focalDelta = details.focalPoint - _gestureStartFocalPoint;
    final newOffset = clampCropOffset(
      offset: _gestureStartOffset + focalDelta,
      originalWidth: width,
      originalHeight: height,
      viewportSize: _viewportSize,
      scale: newScale,
    );
    setState(() {
      _scale = newScale;
      _offset = newOffset;
    });
  }

  // Shared by the +/- buttons and the fallback Slider (Product spec Edge
  // Case 5 -- accessibility, screen readers can't pinch).
  void _setScale(double newScale) {
    final width = _originalWidth;
    final height = _originalHeight;
    if (width == null || height == null) return;
    final clampedScale = newScale.clamp(_minScale, _maxScale);
    setState(() {
      _scale = clampedScale;
      _offset = clampCropOffset(
        offset: _offset,
        originalWidth: width,
        originalHeight: height,
        viewportSize: _viewportSize,
        scale: clampedScale,
      );
    });
  }

  Future<void> _finish() async {
    final width = _originalWidth;
    final height = _originalHeight;
    if (width == null || height == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      final sourceRect = computeCropSourceRect(
        originalWidth: width,
        originalHeight: height,
        viewportSize: _viewportSize,
        scale: _scale,
        offset: _offset,
      );
      final cropped = await cropToCircleSquare(
        bytes: widget.imageBytes,
        sourceRect: sourceRect,
      );
      if (!mounted) return;
      Navigator.of(context).pop(cropped);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'ครอปรูปไม่สำเร็จ ลองใหม่อีกครั้ง';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = _originalWidth;
    final height = _originalHeight;
    final ready = width != null && height != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leadingWidth: 88,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก', style: TextStyle(color: Colors.white)),
        ),
        centerTitle: true,
        title: const Text(
          'ปรับตำแหน่งรูป',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: ready && !_isProcessing ? _finish : null,
            child: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'เสร็จสิ้น',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: !ready
                    ? (_errorMessage != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const CircularProgressIndicator(color: Colors.white))
                    : _buildCropViewport(width, height),
              ),
            ),
            // Only a "เสร็จสิ้น" (crop) failure once the image is already
            // ready reaches here -- a load failure (image never became
            // ready) shows its own message above instead.
            if (ready && _errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage!,
                  // Beta4 §10: was an ad-hoc `Colors.redAccent`, the one
                  // error colour in the app that came from Material
                  // rather than the design system. This screen's surface
                  // is black (see the Scaffold above), so the system's
                  // on-dark error token is the correct one of the two --
                  // errorLight (#DC2626) is tuned for paper.
                  style: const TextStyle(color: WynColors.errorDark),
                  textAlign: TextAlign.center,
                ),
              ),
            _buildZoomBar(ready),
          ],
        ),
      ),
    );
  }

  Widget _buildCropViewport(int width, int height) {
    final (displayWidth, displayHeight) = cropDisplaySize(
      originalWidth: width,
      originalHeight: height,
      viewportSize: _viewportSize,
      scale: _scale,
    );
    return GestureDetector(
      key: const Key('crop_gesture_detector'),
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      // The mask overlay (dark square around a bright circle) makes the
      // circular frame stand out against the picked image -- standard
      // image-cropper convention (IG/FB), see Design spec's "มิเรอร์
      // mask overlay มาตรฐาน".
      child: SizedBox(
        width: _viewportSize,
        height: _viewportSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipOval(
              child: ColoredBox(
                color: Colors.grey.shade900,
                child: Stack(
                  children: [
                    Positioned(
                      left: _offset.dx,
                      top: _offset.dy,
                      child: Image.memory(
                        widget.imageBytes,
                        width: displayWidth,
                        height: displayHeight,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomBar(bool ready) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          WynSpacing.space6, 8, WynSpacing.space6, WynSpacing.space6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'ลดการซูม',
            icon: const Icon(Icons.remove, color: Colors.white),
            onPressed: ready ? () => _setScale(_scale - _zoomButtonStep) : null,
          ),
          Expanded(
            child: Semantics(
              label: 'ระดับการซูม',
              value: '${(_scale * 100).round()}%',
              child: Slider(
                key: const Key('crop_zoom_slider'),
                value: _scale,
                min: _minScale,
                max: _maxScale,
                activeColor: Colors.white,
                inactiveColor: Colors.white38,
                onChanged: ready ? _setScale : null,
              ),
            ),
          ),
          IconButton(
            tooltip: 'เพิ่มการซูม',
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: ready ? () => _setScale(_scale + _zoomButtonStep) : null,
          ),
        ],
      ),
    );
  }
}
