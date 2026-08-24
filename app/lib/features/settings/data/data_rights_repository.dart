import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps the two WYN-047 (Data Rights) RPCs -- `export_my_data()` and
/// `delete_my_account()`. Both are argument-less on the DB side and
/// always scoped to `auth.uid()` server-side (see supabase/schema.sql,
/// WYN-047 section) -- neither method here takes a `userId` parameter
/// either, same "someone else's data isn't a concept the client can
/// even express" reasoning as SavedRepository/
/// NotificationSettingsRepository. A separate small repository (not
/// folded into AuthRepository) since neither RPC is an auth-flow
/// concern -- export reads content the app already owns other
/// repositories for (Drop/Pop/Comment/...), and account deletion is a
/// data-lifecycle action that merely *ends with* a sign-out, not an
/// auth primitive itself.
class DataRightsRepository {
  DataRightsRepository(this._client);

  final SupabaseClient _client;

  /// Returns the caller's own data (Profile/Drop/Pop/Comment/Follow/
  /// Saved/Club membership/Settings/sent Chat messages -- see
  /// `export_my_data()`'s own comment in supabase/schema.sql for the
  /// full list and what's deliberately excluded) as a JSON string,
  /// ready to hand to share_plus as a file's bytes.
  Future<String> exportMyData() async {
    final result = await _client.rpc('export_my_data');
    return jsonEncode(result);
  }

  /// Deletes the caller's `auth.users` row -- irreversible and
  /// immediate, no grace period (see the RPC's own comment in
  /// supabase/schema.sql). The 88 `on delete cascade` FKs already in
  /// this schema remove every other row belonging to the caller.
  /// Signing the client out afterward is the caller's job (the DB
  /// layer has no way to invalidate an already-issued JWT), not this
  /// method's.
  Future<void> deleteMyAccount() async {
    await _client.rpc('delete_my_account');
  }
}
