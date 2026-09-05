// WYNOS Interaction Feedback System -- press feedback.
//
// One standard for "this control noticed my finger", so the answer to
// "how much should it shrink, and how fast" is a token instead of a
// judgement call per widget.
//
// Scale, deliberately, and nothing else: `Transform.scale` (which is
// what AnimatedScale drives) paints at a different size without
// changing the widget's layout size, so a pressed control never nudges
// its neighbours. Animating padding or width to get the same look would
// mark the whole subtree dirty for layout on every frame of every tap,
// on cards the user is also scrolling.
import 'package:flutter/material.dart';

import 'wyn_haptic_type.dart';
import 'wyn_haptics.dart';
import 'wyn_motion.dart';

/// Shrinks [child] while [pressed] is true.
///
/// Stateless on purpose -- the owner already knows whether it is being
/// pressed (an InkWell's onTapDown/onTapUp/onTapCancel, a GestureDetector's
/// equivalents), and duplicating that into a second recogniser inside
/// this widget is how you end up with two gesture arenas fighting over
/// the same taps.
class WynPressScale extends StatelessWidget {
  const WynPressScale({
    super.key,
    required this.pressed,
    required this.child,
    this.scale = WynMotion.pressedScale,
  });

  final bool pressed;
  final Widget child;

  /// Override only for a control large enough that 6% reads as a lurch
  /// (a full-bleed card, say).
  final double scale;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed ? scale : 1.0,
      // Reduced motion drops the travel, not the state: the control
      // still shows its pressed size, it just gets there instantly.
      duration: WynMotion.duration(context, WynMotion.press),
      curve: WynMotion.enter,
      child: child,
    );
  }
}

/// A tappable region with WYNOS's standard press feedback and, if asked,
/// a haptic -- for new call sites that would otherwise hand-roll the
/// InkWell + press-state + haptic trio.
///
/// Existing widgets that already own their own gesture handling
/// (ActionMetric, the feed cards) use [WynPressScale] directly instead;
/// rewriting them to route through this would be a refactor for its own
/// sake and would put a second InkWell inside ones that already have one.
class WynPressable extends StatefulWidget {
  const WynPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.haptic,
    this.borderRadius,
    this.semanticsLabel,
  });

  final Widget child;

  /// Null disables the control -- no press feedback, no haptic, and
  /// (via [Semantics.enabled]) announced as disabled rather than just
  /// silently inert.
  final VoidCallback? onTap;

  /// Fired on tap-down, before [onTap] runs: the buzz is confirming the
  /// *touch*, and a buzz that waits for an async result arrives long
  /// after the finger has left. Outcome feedback is a separate call the
  /// action itself makes when it knows ([WynFeedback.completed] /
  /// [WynFeedback.failed]).
  final WynHapticType? haptic;

  final BorderRadius? borderRadius;
  final String? semanticsLabel;

  @override
  State<WynPressable> createState() => _WynPressableState();
}

class _WynPressableState extends State<WynPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final label = widget.semanticsLabel;

    Widget result = WynPressScale(
      pressed: _pressed,
      child: InkWell(
        onTap: onTap,
        onTapDown: onTap == null
            ? null
            : (_) {
                _setPressed(true);
                final haptic = widget.haptic;
                if (haptic != null) WynHaptics.fire(haptic);
              },
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        borderRadius: widget.borderRadius,
        child: widget.child,
      ),
    );

    if (label != null) {
      result = Semantics(
        label: label,
        button: true,
        enabled: onTap != null,
        excludeSemantics: true,
        child: result,
      );
    }
    return result;
  }
}
