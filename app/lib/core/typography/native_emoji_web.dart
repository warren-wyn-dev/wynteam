import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final RegExp _appleBrowserPattern =
    RegExp(r'iPhone|iPad|iPod|Macintosh', caseSensitive: false);

bool get shouldUseBrowserNativeEmoji =>
    _appleBrowserPattern.hasMatch(web.window.navigator.userAgent);

Widget browserNativeEmoji(String emoji, {required double fontSize}) {
  final boxSize = fontSize * 1.25;
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
          ..fontFamily =
              '"Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", sans-serif'
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
