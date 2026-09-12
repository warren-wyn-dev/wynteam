import 'package:flutter/services.dart';

// The approved Home mockup uses traditional headed/looped Thai glyphs.
// Keep the registered family stable, but load Google's OFL-licensed
// Noto Sans Thai Looped variable font rather than the loopless face.
const _family = 'WYNThaiLooped';
const _fontBaseUrl =
    'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansthailooped/';
const _fontFile = 'NotoSansThaiLooped%5Bwdth%2Cwght%5D.ttf';

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
