import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/data/profile.dart';
import 'block_relationship.dart';

/// Wraps the `blocks` table read and `block_user()`/`unblock_user()`/
/// `block_relationship()` RPCs needed for WYN-027 (Block). See
/// supabase/schema.sql for the RLS policies and RPC functions this
/// relies on -- enforcement of what a block actually *does* (hiding
/// content, blocking Follow/Like/Comment/mentions) lives entirely at
/// the data layer there, not in this repository.
class BlockRepository {
  BlockRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 30;

  Future<BlockRelationship> blockRelationship(String userId) async {
    final result = await _client.rpc('block_relationship', params: {
      'p_other_user_id': userId,
    });
    return BlockRelationship.fromWire(result as String);
  }

  Future<void> blockUser(String userId) {
    return _client.rpc('block_user', params: {'p_target_user_id': userId});
  }

  Future<void> unblockUser(String userId) {
    return _client.rpc('unblock_user', params: {'p_target_user_id': userId});
  }

  /// The current user's own Blocked List (Settings → Safety), newest
  /// block first. RLS on `blocks` already restricts this to rows the
  /// caller themselves created as blocker_id, so no extra filter needed
  /// here.
  Future<List<Profile>> fetchBlockedUsers({required int page}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('blocks')
        .select('created_at, blocked:profiles!blocks_blocked_id_fkey(*)')
        .order('created_at', ascending: false)
        .range(from, to);

    return rows
        .map((row) => Profile.fromMap(row['blocked'] as Map<String, dynamic>))
        .toList();
  }
}
