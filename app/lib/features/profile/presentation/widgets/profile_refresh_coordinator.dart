/// Coordinates one pull-to-refresh gesture across the Profile header and
/// whichever profile-tab bodies are currently mounted.
///
/// ViewProfileScreen owns the single visible RefreshIndicator. Individual
/// tabs register their data reload callback here instead of exposing a second
/// RefreshIndicator, so one gesture has one spinner and one completion point.
class ProfileRefreshCoordinator {
  final Map<Object, Future<void> Function()> _callbacks = {};

  void attach(Object owner, Future<void> Function() callback) {
    _callbacks[owner] = callback;
  }

  void detach(Object owner) {
    _callbacks.remove(owner);
  }

  Future<void> refreshAll() async {
    final callbacks = List<Future<void> Function()>.of(_callbacks.values);
    if (callbacks.isEmpty) return;
    await Future.wait(callbacks.map((callback) => callback()));
  }
}
