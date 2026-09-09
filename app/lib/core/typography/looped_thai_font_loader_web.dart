import 'package:flutter/services.dart';

const _family = 'WYNThaiLooped';
const _fontBaseUrl =
    'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansthailooped/';
const _fontFile = 'NotoSansThaiLooped%5Bwdth,wght%5D.ttf';

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
