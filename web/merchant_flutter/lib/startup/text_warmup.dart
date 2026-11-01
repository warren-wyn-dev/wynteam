import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Content-free startup evidence. A timeout must not hide the merchant's app.
class MerchantTextWarmupResult {
  const MerchantTextWarmupResult({
    required this.elapsedMilliseconds,
    required this.timedOut,
  });

  final int elapsedMilliseconds;
  final bool timedOut;
}

Future<MerchantTextWarmupResult>? _engineTextWarmup;

/// The app theme uses the bundled NotoSansThai family (see pubspec.yaml).
const bundledThaiFont = true;

/// Ask Flutter for its existing Thai fallback before the first visible view.
///
/// This deliberately uses the public text/layout and system-font notifications,
/// not a second text font or engine-private API. The result is shared by views
/// in this engine: removing a view never delays the next account's view again.
Future<MerchantTextWarmupResult> warmMerchantThaiText() {
  // Founder 2026-11-01: the Thai font is bundled and loaded with the engine's
  // font manifest, so there is no runtime fallback to wait for. Waiting here
  // only added up to 1.2s before the first reveal.
  if (!kIsWeb || bundledThaiFont) {
    return Future.value(
      const MerchantTextWarmupResult(elapsedMilliseconds: 0, timedOut: false),
    );
  }
  return _engineTextWarmup ??= _warmThaiText();
}

Future<MerchantTextWarmupResult> _warmThaiText() async {
  // A short real Thai paragraph selects the same script fallback as the UI.
  // It contains combining marks and the currency sign used on the dashboard.
  final painter = TextPainter(
    text: const TextSpan(
      text: 'หน้าหลัก ออเดอร์ เมนูอาหาร เพิ่มเติม ร้านของคุณ ฿๐๑๒๓๔๕๖๗๘๙',
      style: TextStyle(fontSize: 16),
    ),
    locale: const Locale('th'),
    textDirection: TextDirection.ltr,
  );
  double measure() {
    painter.markNeedsLayout();
    painter.layout();
    return painter.width;
  }

  try {
    return await waitForThaiFontMetrics(
      fontChanges: PaintingBinding.instance.systemFonts,
      measureThaiText: measure,
      maxWait: const Duration(milliseconds: 1200),
    );
  } finally {
    painter.dispose();
  }
}

/// An unrelated font notification is not proof that Thai text is ready.
///
/// The initial measurement triggers fallback acquisition on Flutter Web. Only
/// a changed Thai paragraph can finish early. Engines with already available
/// text or an unavailable fallback finish at the bound, marked as unconfirmed.
@visibleForTesting
Future<MerchantTextWarmupResult> waitForThaiFontMetrics({
  required Listenable fontChanges,
  required double Function() measureThaiText,
  required Duration maxWait,
}) {
  final elapsed = Stopwatch()..start();
  final completed = Completer<MerchantTextWarmupResult>();
  final initialWidth = measureThaiText();
  late final Timer timeout;
  late final VoidCallback changed;
  var checkScheduled = false;

  void finish({required bool timedOut}) {
    if (completed.isCompleted) return;
    timeout.cancel();
    fontChanges.removeListener(changed);
    elapsed.stop();
    completed.complete(
      MerchantTextWarmupResult(
        elapsedMilliseconds: elapsed.elapsedMilliseconds,
        timedOut: timedOut,
      ),
    );
  }

  changed = () {
    if (checkScheduled) return;
    checkScheduled = true;
    // PaintingBinding iterates its font listener set directly. Finish outside
    // that iteration, so disposing our observer cannot mutate an active loop.
    scheduleMicrotask(() {
      checkScheduled = false;
      if (completed.isCompleted) return;
      if ((measureThaiText() - initialWidth).abs() > .01) {
        finish(timedOut: false);
      }
    });
  };
  fontChanges.addListener(changed);
  timeout = Timer(maxWait, () => finish(timedOut: true));
  return completed.future;
}
