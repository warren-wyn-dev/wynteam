import 'dart:js_interop';
import 'package:web/web.dart' as web;

void reportMerchantContentReady({
  required int viewId,
  required int elapsedMilliseconds,
  required int fontWarmupMilliseconds,
  required bool fontWarmupTimedOut,
}) {
  web.window.dispatchEvent(
    web.CustomEvent(
      'zoky-merchant-startup',
      web.CustomEventInit(
        detail: {
          'viewId': viewId,
          'phase': 'content-ready',
          'elapsedMs': elapsedMilliseconds,
          'fontWarmupMs': fontWarmupMilliseconds,
          'fontWarmupTimedOut': fontWarmupTimedOut,
        }.jsify(),
      ),
    ),
  );
}
