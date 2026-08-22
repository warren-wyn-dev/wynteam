import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/data/profile.dart';

/// Wraps the `mutes` table for WYN-028 (Mute). Unlike BlockRepository,
/// there's no RPC here -- mute has no atomic side effect to coordinate
/// (no Follow teardown, no interaction restriction), so plain
/// insert/delete through RLS is enough, the same shape FollowRepository
/// already uses for `follows`. See supabase/schema.sql for the RLS
/// policies and for the `home_feed` view, which is the only place mute
/// is actually enforced.
class MuteRepository {
  MuteRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 30;

  Future<bool> isMuted(String userId) async {
    final userIdSelf = _client.auth.currentUser!.id;
    final rows = await _client
        .from('mutes')
        .select('muter_id')
        .eq('muter_id', userIdSelf)
        .eq('muted_id', userId)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> muteUser(String userId) {
    final userIdSelf = _client.auth.currentUser!.id;
    return _client.from('mutes').insert({
      'muter_id': userIdSelf,
      'muted_id': userId,
    });
  }

  Future<void> unmuteUser(String userId) {
    final userIdSelf = _client.auth.currentUser!.id;
    return _client
        .from('mutes')
        .delete()
        .eq('muter_id', userIdSelf)
        .eq('muted_id', userId);
  }

  /// The current user's own Muted List (Settings → Safety), newest mute
  /// first. RLS on `mutes` already restricts this to rows the caller
  /// themselves created as muter_id, so no extra filter needed here.
  Future<List<Profile>> fetchMutedUsers({required int page}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('mutes')
        .select('created_at, muted:profiles!mutes_muted_id_fkey(*)')
        .order('created_at', ascending: false)
        .range(from, to);

    return rows
        .map((row) => Profile.fromMap(row['muted'] as Map<String, dynamic>))
        .toList();
  }
}
