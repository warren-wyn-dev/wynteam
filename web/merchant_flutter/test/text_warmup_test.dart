import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/startup/text_warmup.dart';

// PaintingBinding iterates the listeners directly; an observer must finish
// outside that loop before removing itself.
class _FontChanges implements Listenable {
  final _listeners = <VoidCallback>{};
  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void changed() {
    for (final listener in _listeners) {
      listener();
    }
  }

  bool get hasObservers => _listeners.isNotEmpty;
  void dispose() => _listeners.clear();
}

void main() {
  testWidgets(
    'font wait ignores unrelated notifications and accepts Thai layout',
    (tester) async {
      final changes = _FontChanges();
      var width = 240.0;
      MerchantTextWarmupResult? result;
      waitForThaiFontMetrics(
        fontChanges: changes,
        measureThaiText: () => width,
        maxWait: const Duration(milliseconds: 1200),
      ).then((value) => result = value);

      expect(changes.hasObservers, isTrue);
      changes.changed();
      await tester.pump();
      expect(result, isNull);

      width = 286;
      changes.changed();
      await tester.pump();
      expect(result?.timedOut, isFalse);
      expect(changes.hasObservers, isFalse);
      // Completion removes the listener/timer, so later notifications do no work.
      changes.changed();
      await tester.pump(const Duration(seconds: 2));
      expect(result?.timedOut, isFalse);
      changes.dispose();
    },
  );

  testWidgets('missing font notification is bounded and removes its observer', (
    tester,
  ) async {
    final changes = _FontChanges();
    MerchantTextWarmupResult? result;
    waitForThaiFontMetrics(
      fontChanges: changes,
      measureThaiText: () => 240,
      maxWait: const Duration(milliseconds: 1200),
    ).then((value) => result = value);

    await tester.pump(const Duration(milliseconds: 1199));
    expect(result, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(result?.timedOut, isTrue);
    expect(changes.hasObservers, isFalse);
    changes.changed();
    changes.dispose();
  });
}
