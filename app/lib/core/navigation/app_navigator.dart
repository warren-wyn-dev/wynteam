import 'package:flutter/material.dart';

/// App-wide navigator key, attached to `MaterialApp.navigatorKey` in
/// main.dart. WYN-016's push-notification tap handler needs this because
/// `FirebaseMessaging.onMessageOpenedApp`/`getInitialMessage` fire at the
/// app root (a background/terminated tap re-launches or resumes the
/// whole app), not from inside any particular screen's `BuildContext` --
/// there's no widget-local context available to call
/// `Navigator.of(context)` from at that point.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
