import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/widgets.dart';

bool get shouldUseBrowserNativeEmoji => false;

Widget browserNativeEmoji(String emoji, {required double fontSize}) =>
    BrowserSystemText(emoji, style: TextStyle(fontSize: fontSize));
