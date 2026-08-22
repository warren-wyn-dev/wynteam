import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/mute/data/mute_repository.dart';
import 'package:wyn/features/profile/data/profile.dart';

/// A MuteRepository whose network-touching methods are overridden to
/// just record what they were called with, instead of making a real
/// Supabase call. Mirrors RecordingBlockRepository (WYN-027) -- see
/// .wyn/learning/PATTERNS.md.
class RecordingMuteRepository extends MuteRepository {
  RecordingMuteRepository({
    this.isMutedResult = false,
    this.isMutedError,
    this.muteUserError,
    this.unmuteUserError,
    this.mutedUsersPages = const [],
    this.fetchMutedUsersError,
  }) : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  bool isMutedResult;
  Object? isMutedError;

  Object? muteUserError;
  Object? unmuteUserError;

  /// One entry per page index -- fetchMutedUsers(page: n) returns
  /// mutedUsersPages[n], or an empty list once past the end.
  List<List<Profile>> mutedUsersPages;

  /// If set, [fetchMutedUsers] throws this instead of returning a page.
  Object? fetchMutedUsersError;

  int isMutedCalls = 0;
  int muteUserCalls = 0;
  int unmuteUserCalls = 0;
  String? lastMutedUserId;
  String? lastUnmutedUserId;

  @override
  Future<bool> isMuted(String userId) async {
    isMutedCalls++;
    final error = isMutedError;
    if (error != null) throw error;
    return isMutedResult;
  }

  @override
  Future<void> muteUser(String userId) async {
    muteUserCalls++;
    lastMutedUserId = userId;
    final error = muteUserError;
    if (error != null) throw error;
  }

  @override
  Future<void> unmuteUser(String userId) async {
    unmuteUserCalls++;
    lastUnmutedUserId = userId;
    final error = unmuteUserError;
    if (error != null) throw error;
  }

  @override
  Future<List<Profile>> fetchMutedUsers({required int page}) async {
    final error = fetchMutedUsersError;
    if (error != null) throw error;
    if (page < 0 || page >= mutedUsersPages.length) return [];
    return mutedUsersPages[page];
  }
}
