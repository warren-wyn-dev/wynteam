import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_navigator.dart';
import 'content_link.dart';

/// Turns an incoming URI -- a tapped share link (native Universal/App
/// Links, via the `app_links` package) or the browser's own address
/// (web, at startup) -- into a screen, via content_link.dart's parser
/// and opener.
///
/// One process-wide instance (see main.dart's `DeepLinkCoordinator
/// .instance.start()`), not a widget: a deep link can arrive before
/// there is anywhere in the widget tree ready to show it -- cold start,
/// before RootShell has ever mounted, with WelcomeScreen or onboarding
/// up instead (there is no session yet to fetch a Club/Drop/Profile
/// with, RLS-gated or not). Nothing is lost in the meantime: both
/// [start] and the native link stream go through [_handle], which
/// either opens the link right away (navigator already attached, e.g. a
/// link tapped while the app is already running) or leaves it as
/// [_pending] for [retryPending] to pick up once something calls it --
/// see RootShell.initState, the same "runs once per sign-in, whether
/// guest or full account" checkpoint PushNotificationService.initialize
/// already uses for the equivalent push-notification problem.
class DeepLinkCoordinator {
  DeepLinkCoordinator._();
  static final DeepLinkCoordinator instance = DeepLinkCoordinator._();

  ContentLink? _pending;

  /// Call once, from main() before runApp.
  Future<void> start() async {
    if (kIsWeb) {
      // Only meaningful with `usePathUrlStrategy()` already in effect
      // (see main.dart) -- otherwise a shared .../club/<id> link's path
      // lives in the URL fragment, not `Uri.base.path`, and never
      // matches ContentLink.parse. There is no "app already running,
      // the OS hands it a new link" event on web the way there is on
      // native (`uriLinkStream`) -- a fresh navigation is a fresh page
      // load, so nothing further to listen for.
      _handle(Uri.base);
      return;
    }

    try {
      final appLinks = AppLinks();
      final initial = await appLinks.getInitialLink();
      if (initial != null) _handle(initial);
      // Never cancelled: this coordinator is one process-wide instance
      // for the whole app lifetime (see the class doc comment), same as
      // PushNotificationService's own onMessageOpenedApp/onTokenRefresh
      // listeners never being cancelled either.
      appLinks.uriLinkStream.listen(_handle);
    } catch (_) {
      // No platform channel handler for this host/test environment --
      // deep links simply don't arrive, same fail-open posture
      // PushNotificationService takes when Firebase isn't configured.
    }
  }

  void _handle(Uri uri) {
    final link = ContentLink.parse(uri);
    if (link == null) return;
    _pending = link;
    _tryConsume();
  }

  /// Call from wherever the app just became ready to actually show
  /// content. A no-op if nothing is pending, or if the navigator still
  /// isn't attached (only possible if a native link arrives in the same
  /// frame something else is already retrying).
  void retryPending() => _tryConsume();

  void _tryConsume() {
    final link = _pending;
    if (link == null) return;
    if (appNavigatorKey.currentState == null) return;
    _pending = null;
    // Deferred a frame rather than pushed inline: [retryPending] is
    // called from RootShell.initState, and pushing a route during
    // another widget's build phase is exactly what
    // `addPostFrameCallback` exists to avoid. Harmless to defer the
    // same way when [_handle] is called from the native link stream
    // instead, which isn't itself mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(openContentLink(link));
    });
  }
}
