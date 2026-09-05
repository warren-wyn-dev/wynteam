import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/core/interaction/wyn_feedback.dart';
import 'package:wyn/core/interaction/wyn_haptic_type.dart';
import 'package:wyn/core/interaction/wyn_haptics.dart';
import 'package:wyn/core/interaction/wyn_motion.dart';
import 'package:wyn/core/interaction/wyn_press_scale.dart';
import 'package:wyn/core/interaction/wyn_state_pop.dart';
import 'package:wyn/core/widgets/action_metric.dart';

/// The WYNOS Interaction Feedback System's own tests.
///
/// Two things are being protected here, and they are different:
///
///  1. That a haptic reaches the platform when it should -- asserted
///     against the *real* `SystemChannels.platform` message, not against
///     an internal counter, so this stays true if the mapping inside
///     [WynHaptics.fire] is ever rewritten.
///  2. That nothing crashes and nothing fires when it shouldn't -- the
///     unsupported-device path, and the repeat suppression that keeps a
///     rebuild from buzzing twice for one action.
void main() {
  /// Every `HapticFeedback.*` call the framework made during a test,
  /// as the argument the platform channel actually received (e.g.
  /// 'HapticFeedbackType.lightImpact').
  late List<String> platformHaptics;

  setUp(() {
    platformHaptics = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        platformHaptics.add(call.arguments as String);
      }
      return null;
    });
    WynHaptics.debugRecording = true;
    WynHaptics.debugReset();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    WynHaptics.debugRecording = false;
    WynHaptics.debugSupportedOverride = null;
    WynHaptics.debugReset();
  });

  group('WynHaptics', () {
    test('each intent maps to a distinct platform impact', () {
      WynHaptics.debugSupportedOverride = true;

      // Fired in this order deliberately: no two adjacent entries are
      // the same intent, so the repeat suppression (its own test below)
      // can't hide a missing call here.
      for (final type in WynHapticType.values) {
        WynHaptics.fire(type);
      }

      expect(platformHaptics, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
        'HapticFeedbackType.selectionClick',
        // success/warning/error carry their meaning through intensity --
        // Flutter exposes no notification-style haptic. See
        // WynHaptics.fire.
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    test('an unsupported device silently does nothing, and does not throw',
        () {
      WynHaptics.debugSupportedOverride = false;

      for (final type in WynHapticType.values) {
        expect(() => WynHaptics.fire(type), returnsNormally);
      }

      expect(platformHaptics, isEmpty,
          reason: 'no vibration should ever reach a device that has none');
    });

    test('the same intent twice in a row fires once', () {
      WynHaptics.debugSupportedOverride = true;

      // The rebuild-storm case: one user action, several frames, the
      // same callback reached more than once.
      WynHaptics.fire(WynHapticType.light);
      WynHaptics.fire(WynHapticType.light);
      WynHaptics.fire(WynHapticType.light);

      expect(platformHaptics, ['HapticFeedbackType.lightImpact']);
    });

    test('two different intents in a row both fire', () {
      WynHaptics.debugSupportedOverride = true;

      // Suppression must be per-intent, not a blanket rate limit: a
      // failed action right after a tap has to be able to say so.
      WynHaptics.fire(WynHapticType.light);
      WynHaptics.fire(WynHapticType.error);

      expect(platformHaptics, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    test('isSupported is false on the web build', () {
      // Not asserting kIsWeb itself (always false under flutter_test) --
      // asserting that the override seam the web path relies on exists
      // and is honoured, which is what keeps the fallback reachable.
      WynHaptics.debugSupportedOverride = false;
      expect(WynHaptics.isSupported, isFalse);
      WynHaptics.debugSupportedOverride = true;
      expect(WynHaptics.isSupported, isTrue);
    });
  });

  group('WynFeedback', () {
    test('maps every product action to the weight the rules call for', () {
      WynHaptics.debugSupportedOverride = false; // recorder only

      final cases = <String, (void Function(), WynHapticType)>{
        'like': (WynFeedback.like, WynHapticType.light),
        'save': (WynFeedback.save, WynHapticType.light),
        'follow': (WynFeedback.follow, WynHapticType.light),
        'commentSent': (WynFeedback.commentSent, WynHapticType.light),
        'toggle': (WynFeedback.toggle, WynHapticType.light),
        'selectionChanged':
            (WynFeedback.selectionChanged, WynHapticType.selection),
        'deleted': (WynFeedback.deleted, WynHapticType.medium),
        'confirmed': (WynFeedback.confirmed, WynHapticType.medium),
        'completed': (WynFeedback.completed, WynHapticType.success),
        'failed': (WynFeedback.failed, WynHapticType.error),
      };

      for (final entry in cases.entries) {
        WynHaptics.debugReset();
        entry.value.$1();
        expect(WynHaptics.debugFired, [entry.value.$2],
            reason: 'WynFeedback.${entry.key}');
      }
    });
  });

  group('WynMotion', () {
    testWidgets('animates normally when the user has no stated preference',
        (tester) async {
      late Duration resolved;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(),
        child: Builder(builder: (context) {
          resolved = WynMotion.duration(context, WynMotion.standard);
          return const SizedBox();
        }),
      ));
      expect(resolved, WynMotion.standard);
    });

    testWidgets('collapses to zero when the OS asks for less motion',
        (tester) async {
      late Duration resolved;
      late bool reduced;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (context) {
          reduced = WynMotion.isReduced(context);
          resolved = WynMotion.duration(context, WynMotion.standard);
          return const SizedBox();
        }),
      ));
      expect(reduced, isTrue);
      // Zero, not "skipped": the widget still lands on its new value, so
      // the state change itself is never lost -- only the travel is.
      expect(resolved, Duration.zero);
    });
  });

  group('WynPressScale', () {
    testWidgets('shrinks while held and returns to full size', (tester) async {
      Widget build(bool pressed) => MaterialApp(
            home: WynPressScale(pressed: pressed, child: const Text('tap me')),
          );

      await tester.pumpWidget(build(false));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          1.0);

      await tester.pumpWidget(build(true));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          WynMotion.pressedScale);

      await tester.pumpWidget(build(false));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          1.0);
    });

    testWidgets('keeps the pressed size but drops the travel under reduced '
        'motion', (tester) async {
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: WynPressScale(pressed: true, child: Text('tap me')),
        ),
      ));

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, WynMotion.pressedScale);
      expect(scale.duration, Duration.zero);
    });
  });

  group('WynPressable', () {
    testWidgets('fires its haptic on touch-down, not on the async result',
        (tester) async {
      WynHaptics.debugSupportedOverride = true;
      var taps = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WynPressable(
            haptic: WynHapticType.light,
            semanticsLabel: 'ทดสอบ',
            onTap: () => taps++,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('tap me'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('tap me'));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(platformHaptics, ['HapticFeedbackType.lightImpact']);
    });

    testWidgets('a disabled pressable neither buzzes nor scales',
        (tester) async {
      WynHaptics.debugSupportedOverride = true;

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: WynPressable(
            haptic: WynHapticType.light,
            onTap: null,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('tap me'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('tap me'));
      await tester.pumpAndSettle();

      expect(platformHaptics, isEmpty);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          1.0);
    });
  });

  group('ActionMetric (the system, wired into the most-tapped control)', () {
    Widget metric({
      required bool liked,
      required VoidCallback onTap,
      bool reduceMotion = false,
    }) =>
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: ActionMetric(
                  icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                  iconState: liked,
                  count: liked ? 1 : 0,
                  color: const Color(0xFF000000),
                  semanticsLabel: liked ? 'ถูกใจแล้ว' : 'กดเพื่อถูกใจ',
                  onTap: onTap,
                ),
              ),
            ),
          ),
        );

    testWidgets('one tap is one haptic and one callback', (tester) async {
      WynHaptics.debugSupportedOverride = true;
      var taps = 0;

      await tester.pumpWidget(metric(liked: false, onTap: () => taps++));
      await tester.tap(find.byType(Icon));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(platformHaptics, ['HapticFeedbackType.lightImpact']);
    });

    testWidgets('rebuilding the card does not fire a haptic', (tester) async {
      WynHaptics.debugSupportedOverride = true;

      // What a scrolling feed does constantly. The pop is driven off
      // iconState changing, and the haptic off the tap -- neither is
      // driven off build(), and this is the guard for that.
      await tester.pumpWidget(metric(liked: false, onTap: () {}));
      await tester.pumpWidget(metric(liked: true, onTap: () {}));
      await tester.pumpWidget(metric(liked: true, onTap: () {}));
      await tester.pumpAndSettle();

      expect(platformHaptics, isEmpty);
    });

    testWidgets('reduced motion lands on the new state without animating it',
        (tester) async {
      double popScale() => tester
          .widget<ScaleTransition>(find.descendant(
            of: find.byType(WynStatePop),
            matching: find.byType(ScaleTransition),
          ))
          .scale
          .value;

      await tester.pumpWidget(
          metric(liked: false, onTap: () {}, reduceMotion: true));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
          metric(liked: true, onTap: () {}, reduceMotion: true));
      await tester.pump(const Duration(milliseconds: 20));

      // Full size the whole way through -- no travel. The icon itself
      // has still swapped to the filled heart, which is what actually
      // carries the meaning.
      expect(popScale(), 1.0);
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        Icons.favorite,
      );
    });
  });
}
