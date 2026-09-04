import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/web/home_screen_platform.dart';

/// WYN-107's platform-interop shim -- these run on the plain Dart VM
/// (flutter test's default target), which always resolves the
/// conditional import to `_home_screen_platform_stub.dart` (see that
/// file's own doc comment): every raw browser signal below is faked via
/// the functions' own injectable parameters rather than a real browser,
/// exactly per the design doc's Handoff §6.
void main() {
  group('isRunningStandalone', () {
    test('true when the standard display-mode media query matches', () {
      expect(
        isRunningStandalone(
          matchesStandaloneDisplayMode: true,
          iosNavigatorStandalone: false,
        ),
        isTrue,
      );
    });

    test('true when only iOS Safari\'s navigator.standalone reports it', () {
      expect(
        isRunningStandalone(
          matchesStandaloneDisplayMode: false,
          iosNavigatorStandalone: true,
        ),
        isTrue,
      );
    });

    test('false when neither signal reports standalone', () {
      expect(
        isRunningStandalone(
          matchesStandaloneDisplayMode: false,
          iosNavigatorStandalone: false,
        ),
        isFalse,
      );
    });

    test('fails closed to false when navigator.standalone is unavailable '
        '(non-iOS browsers -- null, not false)', () {
      expect(
        isRunningStandalone(
          matchesStandaloneDisplayMode: false,
          iosNavigatorStandalone: null,
        ),
        isFalse,
      );
    });

    test('fails closed to false with no overrides at all (VM stub path)', () {
      expect(isRunningStandalone(), isFalse);
    });
  });

  group('detectWebPlatformKind', () {
    const iosSafariUa =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 '
        'Safari/604.1';
    const androidChromeUa =
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36';
    const desktopChromeUa =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';
    const iosChromeUa =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/125.0.0.0 '
        'Mobile/15E148 Safari/604.1';
    const desktopSafariUa =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/17.0 Safari/605.1.15';

    test('iOS Safari UA -> iosSafari', () {
      expect(detectWebPlatformKind(userAgent: iosSafariUa), WebPlatformKind.iosSafari);
    });

    test('Android Chrome UA -> androidChrome', () {
      expect(
        detectWebPlatformKind(userAgent: androidChromeUa),
        WebPlatformKind.androidChrome,
      );
    });

    test('desktop Chrome UA -> desktopOrOther, not misread as Android Chrome '
        '(the exact Flutter Web defaultTargetPlatform pitfall the design '
        'doc warns about)', () {
      expect(
        detectWebPlatformKind(userAgent: desktopChromeUa),
        WebPlatformKind.desktopOrOther,
      );
    });

    test('desktop Safari (macOS) UA -> desktopOrOther, not iosSafari', () {
      expect(
        detectWebPlatformKind(userAgent: desktopSafariUa),
        WebPlatformKind.desktopOrOther,
      );
    });

    test('Chrome-on-iOS (CriOS) UA -> desktopOrOther, not iosSafari', () {
      expect(detectWebPlatformKind(userAgent: iosChromeUa), WebPlatformKind.desktopOrOther);
    });

    test('empty/inconclusive UA fails closed to desktopOrOther', () {
      expect(detectWebPlatformKind(userAgent: ''), WebPlatformKind.desktopOrOther);
    });

    test('fails closed to desktopOrOther with no override at all (VM stub '
        'path)', () {
      expect(detectWebPlatformKind(), WebPlatformKind.desktopOrOther);
    });
  });

  group('isAddToHomeScreenEligible', () {
    test('false when not web', () {
      expect(
        isAddToHomeScreenEligible(
          isWeb: false,
          isStandalone: () => false,
          platformKind: () => WebPlatformKind.iosSafari,
        ),
        isFalse,
      );
    });

    test('false when standalone == true', () {
      expect(
        isAddToHomeScreenEligible(
          isWeb: true,
          isStandalone: () => true,
          platformKind: () => WebPlatformKind.iosSafari,
        ),
        isFalse,
      );
    });

    test('false when the platform can\'t be identified as iOS Safari/'
        'Android Chrome', () {
      expect(
        isAddToHomeScreenEligible(
          isWeb: true,
          isStandalone: () => false,
          platformKind: () => WebPlatformKind.desktopOrOther,
        ),
        isFalse,
      );
    });

    test('true for web + not standalone + iOS Safari', () {
      expect(
        isAddToHomeScreenEligible(
          isWeb: true,
          isStandalone: () => false,
          platformKind: () => WebPlatformKind.iosSafari,
        ),
        isTrue,
      );
    });

    test('true for web + not standalone + Android Chrome', () {
      expect(
        isAddToHomeScreenEligible(
          isWeb: true,
          isStandalone: () => false,
          platformKind: () => WebPlatformKind.androidChrome,
        ),
        isTrue,
      );
    });

    test('false with no overrides at all (VM test target is never kIsWeb)', () {
      expect(isAddToHomeScreenEligible(), isFalse);
    });
  });
}
