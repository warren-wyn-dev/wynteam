import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a post's media area (image/video) with Instagram-style
/// double-tap-to-like -- WYNOS V1.0.0 Beta requirement 4. Two quick taps
/// call [onLike] and show a large heart that pops in and fades out over
/// the media; a third+ tap in the same spot repeats the animation but
/// never calls [onLike] again once [alreadyLiked] is true, so a rapid
/// double-tap on an already-liked post can't double-count the Like.
///
/// Deliberately never *unlikes* on double-tap (unlike the small heart
/// IconButton elsewhere on the card, which does toggle) -- every social
/// platform this pattern is modeled on treats double-tap as "Like",
/// full stop, not a toggle, so a stray extra tap can never accidentally
/// undo a Like the user meant to keep.
class DoubleTapLike extends StatefulWidget {
  const DoubleTapLike({
    super.key,
    required this.child,
    required this.onLike,
    required this.alreadyLiked,
  });

  final Widget child;

  /// Called at most once per already-unliked post, the moment a double
  /// tap is detected -- the caller owns the actual optimistic-update/
  /// API-call shape (same [onLike] callback the small heart button
  /// already uses elsewhere on the card).
  final VoidCallback onLike;

  final bool alreadyLiked;

  @override
  State<DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<DoubleTapLike>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  // Pops past full size then settles, rather than a flat fade-in --
  // reads as a "stamp" the way the real apps this is modeled on do.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35),
    TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
  ]).animate(_controller);

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50),
  ]).animate(_controller);

  void _handleDoubleTap() {
    // WYN-064: haptic only on the tap that actually likes -- a repeat
    // double-tap on an already-liked post still replays the heart (see
    // class doc) but shouldn't buzz again since nothing changed.
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // Hides the heart entirely once it's at rest: either its
                // initial pre-animation state (isDismissed, value 0) or
                // having just finished fading out (isCompleted -- a
                // forward(from: 0) animation settles at status
                // `completed`, not `dismissed`, once it reaches the end;
                // its opacity is already 0 there by construction, so
                // this only removes an already-invisible widget from
                // the tree rather than changing what's visible).
                if (_controller.isDismissed || _controller.isCompleted) {
                  return const SizedBox.shrink();
                }
                return Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: const Icon(
                      Icons.favorite,
                      key: Key('double_tap_heart'),
                      color: Colors.white,
                      size: 100,
                      shadows: [
                        Shadow(color: Colors.black38, blurRadius: 16),
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
