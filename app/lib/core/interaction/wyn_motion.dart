// WYNOS Interaction Feedback System -- motion tokens.
//
// The durations already in the app were each chosen on their own day:
// 220ms for the ActionMetric pop, 180ms for the Follow label cross-fade,
// 700ms for the double-tap heart. None of them is wrong, but nothing
// says what a *new* animation should use, so the next one is another
// number picked in isolation. These are that answer -- named by the job
// they do, not by their value, the same way `WynSpacing` names 4/8/12.
//
// Nothing here is a new dependency. WYNOS animates with the Flutter
// framework's own AnimationController/AnimatedFoo widgets and will keep
// doing so: a motion library would be a large, permanent cost for
// interactions this small.
import 'package:flutter/widgets.dart';

/// Duration/curve tokens and the reduced-motion gate.
class WynMotion {
  WynMotion._();

  // -------------------------------------------------------------------
  // Duration
  // -------------------------------------------------------------------

  /// A control acknowledging your finger -- press-down scale, ripple
  /// tint. Anything slower than this reads as lag rather than feedback.
  static const Duration press = Duration(milliseconds: 90);

  /// A small state swap the user is already looking at: an icon
  /// filling, a label cross-fading.
  static const Duration quick = Duration(milliseconds: 160);

  /// The default for a visible element changing size, position or
  /// opacity. Matches the 220ms the ActionMetric pop already used.
  static const Duration standard = Duration(milliseconds: 220);

  /// Something entering or leaving the screen on its own (a row
  /// collapsing away after a delete).
  static const Duration emphasized = Duration(milliseconds: 300);

  // -------------------------------------------------------------------
  // Curve
  // -------------------------------------------------------------------

  /// Arriving/settling -- fast at the start, eased at the end, which is
  /// what makes a UI feel like it responded *immediately* even when the
  /// animation itself takes 200ms.
  static const Curve enter = Curves.easeOutCubic;

  /// Leaving.
  static const Curve exit = Curves.easeInCubic;

  /// The one overshoot WYNOS allows, and only on a state change the user
  /// deliberately caused (the Like heart). Curves.easeOutBack overshoots
  /// by ~10% -- a "pop", not a bounce. Anything springier than this on a
  /// feed the user is scrolling reads as noise.
  static const Curve pop = Curves.easeOutBack;

  // -------------------------------------------------------------------
  // Scale
  // -------------------------------------------------------------------

  /// How far a control shrinks while held. Small on purpose: 4% is
  /// clearly felt at a glance and still leaves a 17px icon legible.
  static const double pressedScale = 0.94;

  /// Where a state-change pop starts before settling at 1.0.
  static const double popFromScale = 0.75;

  // -------------------------------------------------------------------
  // Reduced motion
  // -------------------------------------------------------------------

  /// True when the OS accessibility setting for reduced/removed
  /// animations is on (iOS "Reduce Motion", Android "Remove animations",
  /// and the browser's `prefers-reduced-motion` on the web build --
  /// Flutter maps all three onto the same MediaQuery flag).
  ///
  /// `maybe...` because this is called from widgets that are also built
  /// in tests without a MediaQuery ancestor; no MediaQuery means no
  /// stated preference, which is the same as "animate normally".
  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero if the user asked for less motion.
  ///
  /// Zero rather than "skip the widget": an AnimatedFoo with a zero
  /// duration still lands on the new value instantly, so the *state
  /// change itself* is never lost -- only the travel between states is.
  /// That distinction is the accessibility requirement: motion may
  /// never be the only thing carrying meaning.
  static Duration duration(BuildContext context, Duration duration) =>
      isReduced(context) ? Duration.zero : duration;
}
