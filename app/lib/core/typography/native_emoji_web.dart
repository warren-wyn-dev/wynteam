import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final RegExp _appleBrowserPattern = RegExp(
  r'iPhone|iPad|iPod|Macintosh',
  caseSensitive: false,
);
final RegExp _iosWebBrowserPattern = RegExp(
  r'iPhone|iPad|iPod',
  caseSensitive: false,
);

bool get _isIosWeb {
  final navigator = web.window.navigator;
  final userAgent = navigator.userAgent;
  return _iosWebBrowserPattern.hasMatch(userAgent) ||
      (userAgent.contains('Macintosh') && navigator.maxTouchPoints > 1);
}

bool get shouldUseBrowserNativeEmoji =>
    !_isIosWeb && _appleBrowserPattern.hasMatch(web.window.navigator.userAgent);

Widget browserNativeEmoji(String emoji, {required double fontSize}) {
  // Keep the DOM emoji close to the surrounding text's visual box. The old
  // 1.25x box made Apple emoji look oversized and could open up line spacing
  // inside post captions on iPhone Safari.
  final boxSize = fontSize * 1.08;
  return SizedBox(
    width: boxSize,
    height: boxSize,
    child: HtmlElementView.fromTagName(
      tagName: 'span',
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      onElementCreated: (element) {
        final span = element as web.HTMLElement;
        span.textContent = emoji;
        span.setAttribute('aria-hidden', 'true');
        span.style
          ..fontFamily = '"Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", sans-serif'
          ..fontSize = '${fontSize}px'
          ..lineHeight = '1'
          ..width = '100%'
          ..height = '100%'
          ..display = 'flex'
          ..alignItems = 'center'
          ..justifyContent = 'center'
          ..whiteSpace = 'nowrap'
          ..pointerEvents = 'none';
      },
    ),
  );
}
