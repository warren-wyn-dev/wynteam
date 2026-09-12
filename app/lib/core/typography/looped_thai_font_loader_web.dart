import 'package:flutter/services.dart';

const _family = 'WYNThaiLooped';
const _fontBaseUrl =
    'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansthailooped/';
const _fontFile = 'NotoSansThaiLooped%5Bwdth%2Cwght%5D.ttf';

Future<void> loadLoopedThaiFontForWeb() async {
  // Ordinary Flutter Text still renders through Flutter's web canvas rather
  // than the DOM and cannot read the visitor's installed Thai system font.
  // Keep this enhancement non-blocking and fail-safe: DOM system-text surfaces
  // do not depend on it, and startup must never fail if the remote font cannot
  // be reached.
  try {
    final loader = FontLoader(_family)
      ..addFont(NetworkAssetBundle(Uri.parse(_fontBaseUrl)).load(_fontFile));
    await loader.load().timeout(const Duration(seconds: 4));
  } catch (_) {
    // Leave Flutter's built-in fallback behavior in place on network failure.
  }
}
