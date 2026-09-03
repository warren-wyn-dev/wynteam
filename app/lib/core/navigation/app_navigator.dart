import 'package:flutter/material.dart';

/// App-wide navigator key, attached to `MaterialApp.navigatorKey` in
/// main.dart. WYN-016's push-notification tap handler needs this because
/// `FirebaseMessaging.onMessageOpenedApp`/`getInitialMessage` fire at the
/// app root (a background/terminated tap re-launches or resumes the
/// whole app), not from inside any particular screen's `BuildContext` --
/// there's no widget-local context available to call
/// `Navigator.of(context)` from at that point.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide `ScaffoldMessenger` key, attached to
/// `MaterialApp.scaffoldMessengerKey` in main.dart -- same rationale as
/// [appNavigatorKey] above (no widget-local `BuildContext` at the app
/// root), needed by WYN-102's push-notification `_openPop` so it can show
/// a "content not available" SnackBar instead of navigating to a hidden
/// Pop, without a `BuildContext` of its own to call
/// `ScaffoldMessenger.of(context)` from.
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
