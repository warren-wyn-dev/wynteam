import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

/// Web PKCE storage backed directly by the browser's origin-scoped
/// localStorage.
///
/// Supabase Flutter 2.17.2 otherwise routes PKCE verifier persistence through
/// the legacy SharedPreferences API on web. WYNOS' OAuth callback is a full
/// page navigation, so the verifier must survive that navigation reliably.
GotrueAsyncStorage? createWebPkceStorage() => _WebPkceStorage();

class _WebPkceStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async {
    return web.window.localStorage.getItem(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    web.window.localStorage.setItem(key, value);
  }

  @override
  Future<void> removeItem({required String key}) async {
    web.window.localStorage.removeItem(key);
  }
}
