import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/design/zoky_colors.dart';

/// Pink behind the top edge of a page whose pink header scrolls with the
/// content ([child], a vertical scroll view), so an iOS overscroll bounce
/// reveals the header color instead of a white gap (ZOKY-120).
///
/// The backdrop is [height] tall at scroll offset 0 (keep it smaller than
/// the header, which hides it at rest) and shrinks by the scroll offset,
/// so it stays inside the area the header still covers and is gone once
/// the header scrolls away; content below the header never sits on pink.
///
/// Shared by Home and the food landing page.
class ZokyOverscrollBackdrop extends StatefulWidget {
  const ZokyOverscrollBackdrop({
    super.key,
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  State<ZokyOverscrollBackdrop> createState() => _ZokyOverscrollBackdropState();
}

class _ZokyOverscrollBackdropState extends State<ZokyOverscrollBackdrop> {
  /// Vertical offset of the page (negative while overscrolling).
  final ValueNotifier<double> _scrollPixels = ValueNotifier<double>(0);

  bool _onScroll(Notification notification) {
    final ScrollMetrics metrics;
    final int depth;
    if (notification is ScrollNotification) {
      metrics = notification.metrics;
      depth = notification.depth;
    } else if (notification is ScrollMetricsNotification) {
      // Offset changes from layout (rotation, restored offset) send no
      // ScrollNotification.
      metrics = notification.metrics;
      depth = notification.depth;
    } else {
      return false;
    }
    // Only the page itself, not the horizontal rows inside it.
    if (depth == 0 && metrics.axis == Axis.vertical) {
      _scrollPixels.value = metrics.pixels;
    }
    return false;
  }

  @override
  void dispose() {
    _scrollPixels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _scrollPixels,
          builder: (context, pixels, _) => Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: math.max(0, widget.height - pixels),
            child: const ColoredBox(color: ZokyColors.headerTop),
          ),
        ),
        NotificationListener<Notification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
      ],
    );
  }
}
