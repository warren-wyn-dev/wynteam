import 'startup_events_stub.dart'
    if (dart.library.js_interop) 'startup_events_web.dart'
    as platform;

void reportMerchantContentReady({
  required int viewId,
  required int elapsedMilliseconds,
  required int fontWarmupMilliseconds,
  required bool fontWarmupTimedOut,
}) => platform.reportMerchantContentReady(
  viewId: viewId,
  elapsedMilliseconds: elapsedMilliseconds,
  fontWarmupMilliseconds: fontWarmupMilliseconds,
  fontWarmupTimedOut: fontWarmupTimedOut,
);
