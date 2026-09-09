import 'package:flutter/services.dart';

// Keep the registered family name stable so existing ThemeData/tests do not
// need a migration, but use the cleaner OFL Noto Sans Thai face. On iPhone
// Safari this is visually closer to modern iOS Thai than the traditional
// looped face while still giving Flutter Web a reliable Thai glyph fallback.
const _family = 'WYNThaiLooped';
const _fontBaseUrl =
    'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansthai/';
const _fontFile = 'NotoSansThai%5Bwdth,wght%5D.ttf';

Future<void> loadLoopedThaiFontForWeb() async {
  // This font is only a visual enhancement. Keep every part of the network
  // setup inside the try/catch so a browser-specific exception can never
  // escape into app startup when this future is intentionally not awaited.
  try {
    final loader = FontLoader(_family)
      ..addFont(NetworkAssetBundle(Uri.parse(_fontBaseUrl)).load(_fontFile));

    await loader.load().timeout(const Duration(seconds: 4));
  } catch (_) {
    // Intentionally silent: Flutter keeps using its existing web fallback.
  }
}
