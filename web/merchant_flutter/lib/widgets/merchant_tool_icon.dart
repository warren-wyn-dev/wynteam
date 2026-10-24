import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A cell from the shared four-column, two-row merchant tool atlas.
class MerchantToolIcon extends StatefulWidget {
  const MerchantToolIcon({
    super.key,
    required this.index,
    this.size = 48,
    this.fallback,
  }) : assert(index >= 0 && index < 8),
       assert(size > 0 && size < double.infinity);

  final int index;
  final double size;
  final IconData? fallback;

  @override
  State<MerchantToolIcon> createState() => _MerchantToolIconState();
}

class _MerchantToolIconState extends State<MerchantToolIcon> {
  static const _asset = AssetImage('assets/brand/merchant-tools-3d.png');
  ImageStream? _stream;
  ui.Image? _image;
  late final ImageStreamListener _listener = ImageStreamListener(
    _onImage,
    onError: _onError,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _asset.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == next.key) return;
    _stream?.removeListener(_listener);
    _stream = next;
    next.addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    if (!mounted) {
      info.dispose();
      return;
    }
    final previous = _image;
    setState(() => _image = info.image.clone());
    info.dispose();
    previous?.dispose();
  }

  void _onError(Object error, StackTrace? stackTrace) {
    if (!mounted) return;
    final previous = _image;
    setState(() => _image = null);
    previous?.dispose();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: image == null
            ? Icon(widget.fallback ?? Icons.apps_rounded, size: widget.size)
            : CustomPaint(painter: _MerchantToolPainter(image, widget.index)),
      ),
    );
  }
}

class _MerchantToolPainter extends CustomPainter {
  const _MerchantToolPainter(this.image, this.index);

  final ui.Image image;
  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = Size(image.width / 4, image.height / 2);
    final source = Rect.fromLTWH(
      (index % 4) * cell.width,
      (index ~/ 4) * cell.height,
      cell.width,
      cell.height,
    );
    final fitted = applyBoxFit(BoxFit.contain, cell, size);
    final target = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      source,
      target,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_MerchantToolPainter oldDelegate) =>
      image != oldDelegate.image || index != oldDelegate.index;
}
