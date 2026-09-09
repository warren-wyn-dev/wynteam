import 'package:flutter/widgets.dart';

bool get shouldUseBrowserNativeEmoji => false;

Widget browserNativeEmoji(String emoji, {required double fontSize}) =>
    Text(emoji, style: TextStyle(fontSize: fontSize));
