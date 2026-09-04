/// WYN-107 (Add to Home Screen prompt) -- the platform-interop shim the
/// design doc's "Platform Detection" section calls a hard requirement:
/// there is no Flutter/Dart equivalent for `window.matchMedia`/
/// `navigator.standalone`/`navigator.userAgent`, and no precedent
/// anywhere in this codebase for calling raw browser JS APIs before this
/// (see .wyn/docs/design/wyn-107-add-to-home-screen-prompt.md's own
/// "โค้ด/เอกสารที่ตรวจแล้วก่อนออกแบบ" note on `app/lib/main.dart:66` being
/// the *only* existing `kIsWeb` precedent, and zero `dart:js_interop`/
/// `package:web` usage anywhere).
///
/// Conditional-imported so this file (and everything that imports it)
/// compiles cleanly on every target, not just web:
/// `_home_screen_platform_web.dart` (real `package:web`/`dart:js_interop`
/// calls) is only selected for actual web builds; every other target
/// (native iOS/Android, and critically `flutter test`'s own VM target)
/// gets `_home_screen_platform_stub.dart`'s safe no-op fallbacks instead.
/// `dart.library.js_interop` (not the legacy `dart.library.html`) is the
/// condition Dart's own migration guidance recommends for code written
/// against the newer static-interop APIs those files use.
///
/// Every public function below takes its raw browser-signal(s) as
/// optional parameters (falling back to the real
/// `impl.matchesStandaloneDisplayMode`/`impl.iosNavigatorStandalone`/
/// `impl.userAgent` when omitted) specifically so unit tests can fake
/// `matchMedia`/`navigator.standalone`/`navigator.userAgent` results
/// without a real browser -- see home_screen_platform_test.dart. And
/// every function fails closed (false / [WebPlatformKind.desktopOrOther])
/// on any error or inconclusive result, never guessing "safe to show" --
/// same posture WYN-106's AdEnv.isConfigured guard already uses ("ads
/// that aren't ready = don't exist"; here, "platform we can't identify =
/// this feature doesn't exist").
library;

import 'package:flutter/foundation.dart' show kIsWeb;

import '_home_screen_platform_stub.dart'
    if (dart.library.js_interop) '_home_screen_platform_web.dart' as impl;

/// The 3 platform buckets this whole feature cares about -- everything
/// else (desktop browsers, browsers we fail to identify) collapses into
/// [desktopOrOther], which always means "don't show anything".
enum WebPlatformKind { iosSafari, androidChrome, desktopOrOther }

/// True only once this build is actually running from an already-
/// installed home-screen icon (standalone display mode) -- the *one*
/// permanent stop-condition for the whole feature (design doc: "จุดหยุด
/// แสดงถาวรจริงมีทางเดียวเท่านั้น: ตรวจพบ standalone mode แล้ว").
///
/// Checks both signals the design doc requires: the standard
/// `(display-mode: standalone)` media query (Android Chrome + newer iOS
/// Safari) and iOS Safari's own non-standard `navigator.standalone`
/// (older iOS Safari isn't guaranteed to reflect standalone mode through
/// the media query alone) -- true if either says so.
bool isRunningStandalone({
  bool? matchesStandaloneDisplayMode,
  bool? iosNavigatorStandalone,
}) {
  try {
    if (matchesStandaloneDisplayMode ?? impl.matchesStandaloneDisplayMode()) {
      return true;
    }
    return (iosNavigatorStandalone ?? impl.iosNavigatorStandalone()) ?? false;
  } catch (_) {
    return false;
  }
}

/// iOS Safari / Android Chrome / anything else, via `navigator.userAgent`
/// sniffing -- deliberately **not** `defaultTargetPlatform` (see design
/// doc's Platform Detection §2: Flutter Web's own `defaultTargetPlatform`
/// heuristic falls back to `TargetPlatform.android` for non-iOS/macOS
/// desktop browsers, which would misidentify desktop Chrome as Android
/// Chrome and show it the wrong install instructions entirely).
///
/// Excludes the other browsers that also carry "Chrome"/"Safari" tokens
/// in their own UA strings (Chrome-on-iOS's `CriOS`, Firefox-on-iOS's
/// `FxiOS`, Edge's `Edg`, Opera's `OPR`, Samsung Internet) so those don't
/// get misclassified into either bucket -- they fall through to
/// [WebPlatformKind.desktopOrOther], same fail-closed outcome as a UA we
/// can't parse at all.
WebPlatformKind detectWebPlatformKind({String? userAgent}) {
  try {
    final ua = (userAgent ?? impl.userAgent()).toLowerCase();
    if (ua.isEmpty) return WebPlatformKind.desktopOrOther;

    final isIosDevice =
        ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
    final isSafariEngine = ua.contains('safari') &&
        !ua.contains('crios') &&
        !ua.contains('fxios') &&
        !ua.contains('edgios');
    if (isIosDevice && isSafariEngine) return WebPlatformKind.iosSafari;

    final isAndroidDevice = ua.contains('android');
    final isChromeBrowser = ua.contains('chrome') &&
        !ua.contains('edg') &&
        !ua.contains('opr') &&
        !ua.contains('samsungbrowser');
    if (isAndroidDevice && isChromeBrowser) return WebPlatformKind.androidChrome;

    return WebPlatformKind.desktopOrOther;
  } catch (_) {
    return WebPlatformKind.desktopOrOther;
  }
}

/// The single "is any Add-to-Home-Screen UI (banner, sheet, Settings row)
/// even allowed to show at all" gate -- shared by
/// `AddToHomeScreenBanner` and `SettingsScreen`'s own entry-point row so
/// the two conditions can't independently drift (design doc: the row
/// "แสดงเงื่อนไขเดียวกับ banner", just independent of the banner's own
/// snooze state, which each caller layers on top of this separately).
///
/// [isWeb]/[isStandalone]/[platformKind] are injectable (defaulting to
/// the real [kIsWeb]/[isRunningStandalone]/[detectWebPlatformKind]) for
/// the same testability reason as this file's other functions.
bool isAddToHomeScreenEligible({
  bool isWeb = kIsWeb,
  bool Function() isStandalone = isRunningStandalone,
  WebPlatformKind Function() platformKind = detectWebPlatformKind,
}) {
  if (!isWeb) return false;
  if (isStandalone()) return false;
  final kind = platformKind();
  return kind == WebPlatformKind.iosSafari ||
      kind == WebPlatformKind.androidChrome;
}
