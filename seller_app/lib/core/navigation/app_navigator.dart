import 'package:flutter/material.dart';

/// App-wide navigator key, attached to `MaterialApp.navigatorKey` in
/// main.dart. Duplicated from `app/`'s identical file -- see that file's
/// doc comment for why WYN-016's push-notification tap handler needs
/// this instead of a widget-local `BuildContext`.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
