/// Bridge used by full-screen pushed routes that need to return to the
/// already-mounted RootShell and select one of its bottom destinations.
///
/// WYNOS currently uses one app Navigator rather than a nested Navigator per
/// tab, so a pushed route paints above RootShell's own bottom navigation. The
/// controller keeps RootShell as the single owner of destination behavior
/// (guest gates, badges, create-post action, tab refresh semantics) instead of
/// duplicating that logic in pushed screens.
class RootNavigationController {
  RootNavigationController._();

  static Object? _owner;
  static Future<void> Function(int)? _handler;

  static bool get isAttached => _handler != null;

  static void attach(Object owner, Future<void> Function(int) handler) {
    _owner = owner;
    _handler = handler;
  }

  static void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _handler = null;
  }

  static Future<void> selectDestination(int navIndex) async {
    final handler = _handler;
    if (handler == null) return;
    await handler(navIndex);
  }
}
