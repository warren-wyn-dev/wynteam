// WYNOS Interaction Feedback System -- the one place that vibrates.
//
// Before this, four widgets called `HapticFeedback.lightImpact()`
// directly (ActionMetric, DoubleTapLike, FollowActionButton,
// ViewProfileScreen). That was fine at four. It is not fine at forty:
// there is nowhere to put a device check, nowhere to stop a rebuild
// storm from buzzing twice, and nothing stopping the fifth call site
// from picking `mediumImpact` for a Like because whoever wrote it
// didn't know the other four had settled on light.
//
// So: features call [WynFeedback] (semantic actions), WynFeedback calls
// this (intents), and this is the only file in `lib/` allowed to touch
// `HapticFeedback`. `test/interaction_guard_test.dart` enforces that
// last sentence the same way `design_system_guard_test.dart` enforces
// the colour tokens -- a rule that reads the real source stays true
// after the next feature; a rule written in a doc does not.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'wyn_haptic_type.dart';

/// Central haptic driver. Never construct one -- everything is static,
/// because a haptic has no state worth owning and every call site would
/// otherwise have to be handed an instance.
class WynHaptics {
  WynHaptics._();

  /// Two haptics of the same kind closer together than this are almost
  /// certainly one action reported twice (a rebuild that re-ran a
  /// callback, a gesture recognised by two overlapping detectors), not
  /// a human tapping twice -- the fastest deliberate double-tap people
  /// actually produce is ~150ms apart, and WYNOS's own double-tap-like
  /// window is Flutter's 300ms default.
  ///
  /// Deliberately compared against a timestamp rather than enforced
  /// with a `Timer`: a pending timer at the end of a widget test fails
  /// that test ("A Timer is still pending"), and this app has 151 test
  /// files that must keep passing. Nothing here ever schedules.
  static const Duration _repeatWindow = Duration(milliseconds: 80);

  static WynHapticType? _lastType;
  static int _lastAtMs = 0;

  /// Whether this device can actually produce a haptic.
  ///
  /// Android and iOS only. On web the browser exposes at most
  /// `navigator.vibrate` (which Flutter's `HapticFeedback` does not
  /// drive, and which Safari on iOS does not implement at all), and on
  /// desktop there is no vibration motor to drive -- WYNOS ships a web
  /// build (`.github/workflows/deploy-web.yml`), so this is a real code
  /// path, not a hypothetical one. Everywhere else the whole system
  /// degrades to "visual feedback only", silently, which is the correct
  /// fallback: a haptic is an enhancement on top of a UI that already
  /// tells the user what happened.
  static bool get isSupported {
    final override = debugSupportedOverride;
    if (override != null) return override;
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Fire [type], or do nothing at all if this device can't.
  ///
  /// Never throws. A haptic failing is not a reason for a Like to fail,
  /// so every platform-channel error is swallowed here rather than
  /// bubbling into a feature's `try`/`catch` and being mistaken for the
  /// action itself having gone wrong.
  static void fire(WynHapticType type) {
    if (_isRepeat(type)) return;
    if (debugRecording) debugFired.add(type);
    if (!isSupported) return;
    try {
      switch (type) {
        case WynHapticType.light:
          HapticFeedback.lightImpact();
        case WynHapticType.medium:
          HapticFeedback.mediumImpact();
        case WynHapticType.heavy:
          HapticFeedback.heavyImpact();
        case WynHapticType.selection:
          HapticFeedback.selectionClick();
        // Flutter exposes no notification-style haptic (iOS's
        // UINotificationFeedbackGenerator has no Framework binding), and
        // hand-rolling one out of two delayed impacts would mean
        // scheduling a Timer on every success -- see [_repeatWindow] for
        // why this file schedules nothing. Intensity carries the meaning
        // instead: a completed action lands softer than a failed one,
        // and both are paired with visual feedback that says which it
        // was. The enum keeps them distinct so this mapping can improve
        // later without touching a single call site.
        case WynHapticType.success:
          HapticFeedback.lightImpact();
        case WynHapticType.warning:
          HapticFeedback.mediumImpact();
        case WynHapticType.error:
          HapticFeedback.heavyImpact();
      }
    } catch (_) {
      // Silent by design -- see the doc comment above.
    }
  }

  /// True when the same intent already fired inside [_repeatWindow].
  ///
  /// Records the timestamp even when [isSupported] is false so the
  /// de-duplication is identical on every platform (and so the debug
  /// recorder below sees exactly what a phone would).
  static bool _isRepeat(WynHapticType type) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isRepeat =
        type == _lastType && nowMs - _lastAtMs < _repeatWindow.inMilliseconds;
    _lastType = type;
    _lastAtMs = nowMs;
    return isRepeat;
  }

  // -------------------------------------------------------------------
  // Test seams
  // -------------------------------------------------------------------

  /// Forces [isSupported] regardless of platform. Tests only.
  @visibleForTesting
  static bool? debugSupportedOverride;

  /// When true, every intent that survives de-duplication is appended to
  /// [debugFired]. Off by default: an always-on list would grow without
  /// bound in a real session.
  @visibleForTesting
  static bool debugRecording = false;

  @visibleForTesting
  static final List<WynHapticType> debugFired = <WynHapticType>[];

  /// Clears the recorder *and* the de-duplication state -- without the
  /// second half, a test firing the same intent as the previous test
  /// would silently record nothing.
  @visibleForTesting
  static void debugReset() {
    debugFired.clear();
    _lastType = null;
    _lastAtMs = 0;
  }
}
