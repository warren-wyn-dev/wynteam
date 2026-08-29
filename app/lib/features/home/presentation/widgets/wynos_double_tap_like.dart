import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/wynos_home_tokens.dart';

/// WYNOS Home reference spec 4.7 -- double-tap-to-like + heart-burst
/// animation, drawn to this spec's exact visual constants (72px,
/// paper-filled, no stroke, its own drop-shadow and keyframe timing).
///
/// Deliberately a separate widget from core/widgets/double_tap_like.dart
/// rather than a shared one with new parameters -- that widget is also
/// used outside Home (drop_image_gallery.dart, WYN-071), so changing its
/// numbers to match this spec would silently reskin an unrelated screen
/// nobody asked to redesign. The gesture/state shape mirrors it closely
/// (double-tap only ever *likes*, never toggles back off, on the same
/// reasoning as that widget's own doc comment: every platform this
/// pattern is modeled on treats double-tap as "Like", full stop) --
/// only the visual output differs.
class WynosDoubleTapLike extends StatefulWidget {
  const WynosDoubleTapLike({
    super.key,
    required this.child,
    required this.onLike,
    required this.alreadyLiked,
    this.onTap,
  });

  final Widget child;

  /// Called at most once per already-unliked post, the moment a double
  /// tap is detected.
  final VoidCallback onLike;

  final bool alreadyLiked;

  /// Optional single-tap handler on the same GestureDetector as the
  /// double-tap recognizer -- see core/widgets/double_tap_like.dart's
  /// identical [onTap] doc comment for why this belongs on one
  /// recognizer rather than a nested second GestureDetector.
  final VoidCallback? onTap;

  @override
  State<WynosDoubleTapLike> createState() => _WynosDoubleTapLikeState();
}

class _WynosDoubleTapLikeState extends State<WynosDoubleTapLike>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  // Spec 4.7 keyframes, converted to TweenSequence weights (each
  // segment's % span of the 700ms total):
  //   0%   scale 0.4, opacity 0
  //   25%  scale 1.15, opacity 1
  //   40%  scale 1.0, opacity 1
  //   100% scale 1.0, opacity 0
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.4, end: 1.15).chain(CurveTween(curve: Curves.easeOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 15,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
  ]).animate(_controller);

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 15),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 60,
    ),
  ]).animate(_controller);

  void _handleDoubleTap() {
    // Haptic only on the tap that actually likes -- a repeat double-tap
    // on an already-liked post still replays the heart (see class doc)
    // but shouldn't buzz again since nothing changed.
    if (!widget.alreadyLiked) {
      widget.onLike();
      HapticFeedback.lightImpact();
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          // pointer-events: none in the reference -- IgnorePointer so
          // the burst never blocks the carousel's own scroll/tap
          // handling underneath it.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // Removed from the tree at rest (initial pre-animation
                // state, or having just finished fading out) rather than
                // left invisible-but-present on top of the carousel.
                if (_controller.isDismissed || _controller.isCompleted) {
                  return const SizedBox.shrink();
                }
                return Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: const Icon(
                      Icons.favorite,
                      key: Key('wynos_double_tap_heart'),
                      color: WynosHomeColors.paper,
                      size: 72,
                      shadows: [
                        // drop-shadow(0 4px 16px rgba(0,0,0,0.3))
                        Shadow(
                          color: Color(0x4D000000),
                          offset: Offset(0, 4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
