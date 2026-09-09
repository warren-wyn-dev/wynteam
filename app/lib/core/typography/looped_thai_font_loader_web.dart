import 'package:flutter/services.dart';

const _family = 'WYNThaiLooped';
const _fontBaseUrl =
    'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansthailooped/';
const _fontFile = 'NotoSansThaiLooped%5Bwdth,wght%5D.ttf';

Future<void> loadLoopedThaiFontForWeb() async {
  final loader = FontLoader(_family)
    ..addFont(NetworkAssetBundle(Uri.parse(_fontBaseUrl)).load(_fontFile));

  // Typography must never block app startup indefinitely. If the font CDN is
  // unavailable, Flutter falls back to its existing web font behaviour.
  try {
    await loader.load().timeout(const Duration(seconds: 4));
  } catch (_) {
    // Intentionally silent: this is a visual fallback, not a boot dependency.
  }
}
