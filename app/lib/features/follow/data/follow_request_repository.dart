import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/data/profile.dart';

/// Wraps the `follow_requests` reads/writes needed for WYN-039 (Private
/// Account + Follow Request). A separate table/repository from `follows`
/// (WYN-008)/[FollowRepository] entirely -- see
/// .wyn/docs/design/wyn-039-private-account-follow-request.md, decision
/// 1, for why the pending state was kept out of `follows` itself.
class FollowRequestRepository {
  FollowRequestRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 30;

  /// Sends a Follow Request to a Private account. Throws (RLS denial) if
  /// [userId] isn't actually Private, is blocked either-way with the
  /// caller, or the caller already follows them -- callers only reach
  /// this method after already checking `profile.isPrivate` client-side,
  /// so those are defense-in-depth failures, not expected UI paths.
  Future<void> sendRequest({required String userId}) {
    final currentUserId = _client.auth.currentUser!.id;
    return _client.from('follow_requests').insert({
      'requester_id': currentUserId,
      'target_id': userId,
    });
  }

  /// Cancels a request the caller themself sent (before it's been
  /// decided).
  Future<void> cancelRequest({required String userId}) {
    final currentUserId = _client.auth.currentUser!.id;
    return _client
        .from('follow_requests')
        .delete()
        .eq('requester_id', currentUserId)
        .eq('target_id', userId);
  }

  /// Rejects a request someone sent to the caller -- a plain delete,
  /// same RLS-allowed path as [cancelRequest], just the other party.
  /// Sends no notification to the requester (see schema.sql).
  Future<void> rejectRequest({required String requesterId}) {
    final currentUserId = _client.auth.currentUser!.id;
    return _client
        .from('follow_requests')
        .delete()
        .eq('requester_id', requesterId)
        .eq('target_id', currentUserId);
  }

  /// Accepts a request someone sent to the caller -- must go through the
  /// RPC (not a raw follows insert), see schema.sql's
  /// accept_follow_request().
  Future<void> acceptRequest({required String requesterId}) {
    return _client.rpc(
      'accept_follow_request',
      params: {'p_requester_id': requesterId},
    );
  }

  /// True if the caller has a pending, undecided request against
  /// [userId] -- drives the Follow button's "ขอติดตามแล้ว" state on
  /// ViewProfileScreen.
  Future<bool> hasPendingRequest({required String userId}) async {
    final currentUserId = _client.auth.currentUser!.id;
    final row = await _client
        .from('follow_requests')
        .select()
        .eq('requester_id', currentUserId)
        .eq('target_id', userId)
        .maybeSingle();
    return row != null;
  }

  /// Requests waiting on the caller's own decision, newest first -- for
  /// [FollowRequestListScreen] (Design Screen 3).
  Future<List<Profile>> fetchPendingRequests({required int page}) async {
    final currentUserId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('follow_requests')
        .select(
            'created_at, requester:profiles!follow_requests_requester_id_fkey(*)')
        .eq('target_id', currentUserId)
        .order('created_at', ascending: false)
        .range(from, to);

    return rows
        .map((row) => Profile.fromMap(row['requester'] as Map<String, dynamic>))
        .toList();
  }

  /// Badge count on ViewProfileScreen's own-profile header (Design
  /// Screen 3's entry point) -- a plain count is fine here (unlike
  /// follower_count()/following_count()) since the caller is always
  /// counting their *own* incoming requests, which the RLS SELECT
  /// policy already lets them see in full.
  Future<int> countPendingRequests() async {
    final currentUserId = _client.auth.currentUser!.id;
    final response = await _client
        .from('follow_requests')
        .count(CountOption.exact)
        .eq('target_id', currentUserId);
    return response;
  }
}
