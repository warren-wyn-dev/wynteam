import 'package:web/web.dart' as web;

/// The standard way a browser tells a page it is currently running
/// launched-from-home-screen rather than in an ordinary browser tab --
/// both Chrome/Android and modern Safari/iOS update this media query
/// once a visitor opens the installed PWA (not something WYNOS sets
/// itself). Wrapped defensively: an older/unusual browser that throws
/// on an unrecognized media feature should read as "not installed",
/// same fail-open posture as every other best-effort platform check in
/// this app, not crash the one banner that would otherwise tell them
/// how to install it.
bool isStandaloneDisplayMode() {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}
