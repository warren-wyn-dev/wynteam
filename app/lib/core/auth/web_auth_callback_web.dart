import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

const _authQueryKeys = <String>{
  'code',
  'error',
  'error_code',
  'error_description',
};

/// Handles the single initial OAuth/PKCE callback on Flutter Web without
/// relying on app_links to reconstruct the browser URL.
///
/// Critically, auth query parameters are removed even when exchange fails.
/// Supabase Flutter 2.17.2 only clears them after a successful exchange; a
/// failed/expired verifier therefore leaves `?code=...` behind and Safari can
/// replay the same one-time code when the tab is restored or reloaded.
Future<void> handleInitialWebAuthCallback(
  SupabaseClient client,
  Uri initialUri,
) async {
  if (!_containsAuthCallback(initialUri)) return;

  try {
    await client.auth.getSessionFromUrl(initialUri);
  } catch (error, stackTrace) {
    debugPrint('WYNOS web auth callback exchange failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  } finally {
    _clearAuthQueryParameters(initialUri);
  }
}

bool _containsAuthCallback(Uri uri) {
  return _authQueryKeys.any(uri.queryParameters.containsKey);
}

void _clearAuthQueryParameters(Uri uri) {
  final query = Map<String, String>.from(uri.queryParameters);
  for (final key in _authQueryKeys) {
    query.remove(key);
  }

  final cleaned = uri.replace(
    queryParameters: query.isEmpty ? null : query,
  );
  web.window.history.replaceState(null, '', cleaned.toString());
}
