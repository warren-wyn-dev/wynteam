// WYNOS Interaction Feedback System -- the state-change pop.
//
// One shape of micro-interaction turns up everywhere in a social feed:
// an icon whose *meaning* just changed (an empty heart filled, a
// bookmark solidified) and should be seen changing, not just found
// already changed on the next frame. ActionMetric had this first, hand
// -rolled; extracting it is what lets the Pop rail's Like/Save and the
// Club card's Like/Save have exactly the same 220ms pop instead of
// three near-identical copies that drift.
//
// Driven off [state] changing rather than fired from a tap handler, and
// that difference matters twice over: the pop plays for the real state
// change (including one that arrives from somewhere else -- a refresh,
// another screen), and it does NOT play while a scrolling feed builds
// new cards with already-liked posts in them.
import 'package:flutter/material.dart';

import 'wyn_motion.dart';

/// Pops [child] whenever [state] changes.
class WynStatePop extends StatefulWidget {
  const WynStatePop({
    super.key,
    required this.state,
    required this.child,
  });

  /// Whatever "the state this thing is in" means to the caller --
  /// usually a bool (`likedByMe`, `savedByMe`).
  ///
  /// Must be a value that compares by equality: two identically
  /// configured widgets are never `==`, so passing the icon itself
  /// would make this fire on every rebuild.
  final Object state;

  final Widget child;

  @override
  State<WynStatePop> createState() => _WynStatePopState();
}

class _WynStatePopState extends State<WynStatePop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WynMotion.standard,
    // Starts settled: the first build of an already-liked post must not
    // animate, or every scroll would be a wall of popping hearts.
    value: 1,
  );

  late final Animation<double> _scale =
      Tween<double>(begin: WynMotion.popFromScale, end: 1)
          .animate(CurvedAnimation(parent: _controller, curve: WynMotion.pop));

  @override
  void didUpdateWidget(covariant WynStatePop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state == widget.state) return;
    // Reduced motion keeps the change (the child has already swapped by
    // the time this runs) and drops only the travel to it.
    if (WynMotion.isReduced(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
