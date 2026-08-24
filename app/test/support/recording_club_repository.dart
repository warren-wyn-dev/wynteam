import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_member.dart';
import 'package:wyn/features/club/data/club_repository.dart';

/// A ClubRepository whose network-touching methods are overridden to just
/// record what they were called with / return canned data, instead of
/// making a real Supabase call. Mirrors RecordingFollowRepository -- see
/// .wyn/learning/PATTERNS.md.
class RecordingClubRepository extends ClubRepository {
  RecordingClubRepository({
    List<Club>? myClubs,
    this.club,
    this.myMembership,
    List<ClubMember>? approvedMembers,
    List<ClubMember>? pendingMembers,
    this.memberCount = 1,
    List<Club>? discoverableClubs,
    List<Club>? searchResults,
    Set<String>? pendingClubIds,
  })  : myClubs = myClubs ?? [],
        approvedMembers = approvedMembers ?? [],
        pendingMembers = pendingMembers ?? [],
        discoverableClubs = discoverableClubs ?? [],
        searchResults = searchResults ?? [],
        pendingClubIds = pendingClubIds ?? {},
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchMyClubs].
  final List<Club> myClubs;

  /// Backing list for both [fetchPopularClubs] and [fetchNewClubs] --
  /// each just sorts/caps this differently, same as the real
  /// implementation's shared `_fetchDiscoverableClubs`.
  final List<Club> discoverableClubs;

  /// Returned by [searchClubs] for page 0 only (page 1+ returns empty).
  final List<Club> searchResults;

  /// Returned by [fetchPendingClubIds] -- WYN-056's Explore Club cards
  /// use this to show "รออนุมัติ" instead of "เข้าร่วม".
  final Set<String> pendingClubIds;

  /// Returned by [fetchClub], regardless of clubId.
  final Club? club;

  /// Returned by [fetchMyMembership], regardless of clubId.
  final ClubMember? myMembership;

  /// Returned by [fetchApprovedMembers].
  final List<ClubMember> approvedMembers;

  /// Returned by [fetchPendingMembers].
  final List<ClubMember> pendingMembers;

  final int memberCount;

  int joinClubCalls = 0;
  int leaveClubCalls = 0;
  int createClubCalls = 0;
  int updateClubInfoCalls = 0;
  int updatePrivacyCalls = 0;
  final List<ClubPrivacy> updatePrivacyArgs = [];
  final List<String> approveMemberUserIdArgs = [];
  final List<String> rejectMemberUserIdArgs = [];
  final List<String> removeMemberUserIdArgs = [];
  final List<String> banMemberUserIdArgs = [];
  final List<ClubMemberRole> setMemberRoleArgs = [];
  final List<String> setMemberRoleUserIdArgs = [];

  @override
  Future<int> countMembers(String clubId) async => memberCount;

  @override
  Future<Club?> fetchClub(String clubId) async => club;

  @override
  Future<List<Club>> fetchMyClubs() async => myClubs;

  @override
  Future<ClubMember?> fetchMyMembership(String clubId) async => myMembership;

  @override
  Future<List<ClubMember>> fetchApprovedMembers(String clubId) async => approvedMembers;

  @override
  Future<List<ClubMember>> fetchPendingMembers(String clubId) async => pendingMembers;

  @override
  Future<List<Club>> fetchPopularClubs({String? category, int limit = 10}) async {
    final filtered = category == null
        ? discoverableClubs
        : discoverableClubs.where((c) => c.category == category).toList();
    final sorted = [...filtered]..sort((a, b) => b.memberCount.compareTo(a.memberCount));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<Club>> fetchNewClubs({String? category, int limit = 10}) async {
    final filtered = category == null
        ? discoverableClubs
        : discoverableClubs.where((c) => c.category == category).toList();
    final sorted = [...filtered]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<Club>> searchClubs({required String query, required int page}) async {
    return page == 0 ? searchResults : <Club>[];
  }

  @override
  Future<Set<String>> fetchPendingClubIds() async => pendingClubIds;

  @override
  Future<void> joinClub(Club club) async {
    joinClubCalls++;
  }

  @override
  Future<void> leaveClub(String clubId) async {
    leaveClubCalls++;
  }

  @override
  Future<void> approveMember({required String clubId, required String userId}) async {
    approveMemberUserIdArgs.add(userId);
  }

  @override
  Future<void> rejectMember({required String clubId, required String userId}) async {
    rejectMemberUserIdArgs.add(userId);
  }

  @override
  Future<void> removeMember({required String clubId, required String userId}) async {
    removeMemberUserIdArgs.add(userId);
  }

  @override
  Future<void> banMember({required String clubId, required String userId}) async {
    banMemberUserIdArgs.add(userId);
  }

  @override
  Future<void> setMemberRole({
    required String clubId,
    required String userId,
    required ClubMemberRole role,
  }) async {
    setMemberRoleUserIdArgs.add(userId);
    setMemberRoleArgs.add(role);
  }

  @override
  Future<void> updateClubInfo({
    required String clubId,
    required String name,
    required String description,
    String? category,
  }) async {
    updateClubInfoCalls++;
  }

  @override
  Future<void> updatePrivacy({required String clubId, required ClubPrivacy privacy}) async {
    updatePrivacyCalls++;
    updatePrivacyArgs.add(privacy);
  }

  @override
  Future<void> updateRules({required String clubId, required String rules}) async {}

  @override
  Future<String> uploadClubCover({
    required String clubId,
    required Uint8List bytes,
    required String fileExtension,
  }) async =>
      'https://example.supabase.co/club-media/$clubId/cover.$fileExtension';

  @override
  Future<String> uploadClubIcon({
    required String clubId,
    required Uint8List bytes,
    required String fileExtension,
  }) async =>
      'https://example.supabase.co/club-media/$clubId/icon.$fileExtension';

  @override
  Future<Club> createClub({
    required String name,
    required String description,
    String? category,
    required ClubPrivacy privacy,
    Uint8List? coverBytes,
    String? coverExtension,
    Uint8List? iconBytes,
    String? iconExtension,
  }) async {
    createClubCalls++;
    return club ??
        Club(
          id: 'new-club',
          name: name,
          category: category,
          privacy: privacy,
          ownerId: 'me',
          createdAt: DateTime.now(),
          memberCount: 1,
        );
  }
}
