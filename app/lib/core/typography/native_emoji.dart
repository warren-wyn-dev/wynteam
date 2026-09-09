import 'package:flutter/widgets.dart';

import 'native_emoji_stub.dart'
    if (dart.library.js_interop) 'native_emoji_web.dart' as impl;

bool get shouldUseBrowserNativeEmoji => impl.shouldUseBrowserNativeEmoji;

Widget browserNativeEmoji(String emoji, {required double fontSize}) =>
    impl.browserNativeEmoji(emoji, fontSize: fontSize);
