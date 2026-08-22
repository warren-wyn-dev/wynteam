import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/block/data/block_relationship.dart';
import 'package:wyn/features/block/data/block_repository.dart';
import 'package:wyn/features/profile/data/profile.dart';

/// A BlockRepository whose network-touching methods are overridden to
/// just record what they were called with, instead of making a real
/// Supabase call. Mirrors RecordingReportRepository (WYN-026) -- see
/// .wyn/learning/PATTERNS.md.
class RecordingBlockRepository extends BlockRepository {
  RecordingBlockRepository({
    this.blockRelationshipResult = BlockRelationship.none,
    this.blockRelationshipError,
    this.blockUserError,
    this.unblockUserError,
    this.blockedUsersPages = const [],
    this.fetchBlockedUsersError,
  }) : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [blockRelationship] unless [blockRelationshipError] is set.
  BlockRelationship blockRelationshipResult;
  Object? blockRelationshipError;

  Object? blockUserError;
  Object? unblockUserError;

  /// One entry per page index -- fetchBlockedUsers(page: n) returns
  /// blockedUsersPages[n], or an empty list once past the end.
  List<List<Profile>> blockedUsersPages;

  /// If set, [fetchBlockedUsers] throws this instead of returning a page.
  Object? fetchBlockedUsersError;

  int blockRelationshipCalls = 0;
  int blockUserCalls = 0;
  int unblockUserCalls = 0;
  String? lastBlockedUserId;
  String? lastUnblockedUserId;

  @override
  Future<BlockRelationship> blockRelationship(String userId) async {
    blockRelationshipCalls++;
    final error = blockRelationshipError;
    if (error != null) throw error;
    return blockRelationshipResult;
  }

  @override
  Future<void> blockUser(String userId) async {
    blockUserCalls++;
    lastBlockedUserId = userId;
    final error = blockUserError;
    if (error != null) throw error;
  }

  @override
  Future<void> unblockUser(String userId) async {
    unblockUserCalls++;
    lastUnblockedUserId = userId;
    final error = unblockUserError;
    if (error != null) throw error;
  }

  @override
  Future<List<Profile>> fetchBlockedUsers({required int page}) async {
    final error = fetchBlockedUsersError;
    if (error != null) throw error;
    if (page < 0 || page >= blockedUsersPages.length) return [];
    return blockedUsersPages[page];
  }
}
