import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_channel.dart';
import 'package:wyn/features/club/data/club_insights.dart';
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
    this.isMutedResult = false,
    this.clubInsightsResult = const ClubInsights(
      newMembers: 0,
      newPosts: 0,
      likesAndComments: 0,
      activeMembers: 0,
    ),
    List<ClubChannel>? channels,
    List<ClubChannelCategory>? categories,
  })  : myClubs = myClubs ?? [],
        approvedMembers = approvedMembers ?? [],
        pendingMembers = pendingMembers ?? [],
        discoverableClubs = discoverableClubs ?? [],
        searchResults = searchResults ?? [],
        pendingClubIds = pendingClubIds ?? {},
        // WYN-127: defaults to a single "ทั่วไป" channel for [club], the
        // same real-world invariant `clubs_add_default_channel()`
        // guarantees server-side (every Club always has >=1 channel) --
        // so every test built before Channels existed still gets a
        // channel for ClubPostsTab to select without having to know
        // about this constructor param.
        channels = channels ??
            (club != null
                ? [
                    ClubChannel(
                      id: 'default-channel',
                      clubId: club.id,
                      name: 'ทั่วไป',
                      createdBy: club.ownerId,
                      createdAt: club.createdAt,
                    ),
                  ]
                : []),
        // WYN-133 (requirement 7): defaults to no categories -- every
        // test built before categories existed still gets the plain
        // flat-list rendering (Design's "Club ที่ไม่มีกลุ่มเลย" state)
        // without having to know about this constructor param.
        categories = categories ?? [],
        // A second, independent client just for minting fake
        // RealtimeChannel objects (see subscribeToMyMembership below) --
        // ClubRepository's own client is private to its file,
        // unreachable from this subclass. Mirrors RecordingChatRepository's
        // identical _fakeChannelClient.
        _fakeChannelClient = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  final SupabaseClient _fakeChannelClient;

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

  /// Backing list for [fetchChannels]/[createChannel]/[renameChannel]/
  /// [deleteChannel] -- WYN-127. Mutated in place by those overrides so a
  /// test can assert the round trip the same way [isMutedResult] does
  /// for mute/unmute.
  List<ClubChannel> channels;

  /// Backing list for [fetchChannelCategories]/[createChannelCategory]/
  /// [renameChannelCategory]/[deleteChannelCategory] -- WYN-133
  /// (requirement 7). Mutated in place, same pattern as [channels].
  List<ClubChannelCategory> categories;

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
  final List<String> inviteToClubUserIdArgs = [];
  Object? inviteToClubError;

  /// Set by a test to hold [inviteToClub] open until it completes the
  /// gate -- same mechanism RecordingChatRepository.sendMessageGate
  /// uses to observe the screen's sending state mid-flight.
  Completer<void>? inviteToClubGate;

  @override
  Future<int> countMembers(String clubId) async => memberCount;

  @override
  Future<Club?> fetchClub(String clubId) async => club;

  @override
  Future<List<Club>> fetchMyClubs() async => myClubs;

  @override
  Future<ClubMember?> fetchMyMembership(String clubId) async => myMembership;

  /// Every page [fetchApprovedMembers] was asked for, in order.
  final List<int> fetchApprovedMembersPageArgs = [];

  @override
  Future<List<ClubMember>> fetchApprovedMembers(
    String clubId, {
    int page = 0,
  }) async {
    fetchApprovedMembersPageArgs.add(page);
    // Page 0 returns the canned list, later pages are empty -- so a
    // screen under test settles instead of paging forever.
    return page == 0 ? approvedMembers : <ClubMember>[];
  }

  @override
  Future<List<ClubMember>> fetchPendingMembers(
    String clubId, {
    int page = 0,
  }) async =>
      page == 0 ? pendingMembers : <ClubMember>[];

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
  Future<void> inviteToClub({
    required String clubId,
    required String inviteeId,
  }) async {
    final gate = inviteToClubGate;
    if (gate != null) await gate.future;
    final error = inviteToClubError;
    if (error != null) throw error;
    inviteToClubUserIdArgs.add(inviteeId);
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

  /// Beta4 §8.1: one image per Club -- replaces the recorded
  /// `uploadClubCover`/`uploadClubIcon` pair.
  int uploadIdentityImageCalls = 0;

  @override
  Future<String> uploadClubIdentityImage({
    required String clubId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    uploadIdentityImageCalls++;
    return 'https://example.supabase.co/club-media/$clubId/icon.$fileExtension';
  }

  /// The bytes/extension the last [createClub] was given, so a test can
  /// assert a Club is created with exactly one image (Beta4 §8.1).
  Uint8List? lastCreateImageBytes;
  String? lastCreateImageExtension;

  /// WYN-116: returned by [isClubMuted], flipped by [muteClubNotifications]/
  /// [unmuteClubNotifications] so a test can assert the round trip
  /// (mute -> reload sees isClubMuted() -> true) without a real backend.
  bool isMutedResult;
  int muteClubNotificationsCalls = 0;
  int unmuteClubNotificationsCalls = 0;
  final List<String> muteClubNotificationsClubIdArgs = [];
  final List<String> unmuteClubNotificationsClubIdArgs = [];

  @override
  Future<bool> isClubMuted(String clubId) async => isMutedResult;

  @override
  Future<void> muteClubNotifications(String clubId) async {
    muteClubNotificationsCalls++;
    muteClubNotificationsClubIdArgs.add(clubId);
    isMutedResult = true;
  }

  @override
  Future<void> unmuteClubNotifications(String clubId) async {
    unmuteClubNotificationsCalls++;
    unmuteClubNotificationsClubIdArgs.add(clubId);
    isMutedResult = false;
  }

  /// WYN-117: returned by [fetchClubInsights] regardless of the days
  /// argument -- a test that needs different 7-day vs 30-day results
  /// should override this method directly instead.
  ClubInsights clubInsightsResult;
  Object? fetchClubInsightsResultError;
  int fetchClubInsightsCalls = 0;
  final List<int> fetchClubInsightsDaysArgs = [];

  @override
  Future<ClubInsights> fetchClubInsights({
    required String clubId,
    required int days,
  }) async {
    fetchClubInsightsCalls++;
    fetchClubInsightsDaysArgs.add(days);
    if (fetchClubInsightsResultError != null) throw fetchClubInsightsResultError!;
    return clubInsightsResult;
  }

  @override
  Future<Club> createClub({
    required String name,
    required String description,
    String? category,
    required ClubPrivacy privacy,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    createClubCalls++;
    lastCreateImageBytes = imageBytes;
    lastCreateImageExtension = imageExtension;
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

  int createChannelCalls = 0;
  int renameChannelCalls = 0;
  int deleteChannelCalls = 0;
  final List<String> deleteChannelIdArgs = [];
  final List<String?> renameChannelCategoryIdArgs = [];

  @override
  Future<List<ClubChannel>> fetchChannels(String clubId) async =>
      channels.where((c) => c.clubId == clubId).toList();

  @override
  Future<ClubChannel> createChannel({
    required String clubId,
    required String name,
    String? categoryId,
  }) async {
    createChannelCalls++;
    final created = ClubChannel(
      id: 'created-channel-$createChannelCalls',
      clubId: clubId,
      name: name,
      createdBy: 'me',
      createdAt: DateTime.now(),
      categoryId: categoryId,
    );
    channels = [...channels, created];
    return created;
  }

  @override
  Future<void> renameChannel({
    required String channelId,
    required String name,
    String? categoryId,
  }) async {
    renameChannelCalls++;
    renameChannelCategoryIdArgs.add(categoryId);
    channels = channels
        .map((c) => c.id == channelId
            ? ClubChannel(
                id: c.id,
                clubId: c.clubId,
                name: name,
                createdBy: c.createdBy,
                createdAt: c.createdAt,
                categoryId: categoryId,
              )
            : c)
        .toList();
  }

  @override
  Future<void> deleteChannel(String channelId) async {
    deleteChannelCalls++;
    deleteChannelIdArgs.add(channelId);
    channels = channels.where((c) => c.id != channelId).toList();
  }

  int createChannelCategoryCalls = 0;
  int renameChannelCategoryCalls = 0;
  int deleteChannelCategoryCalls = 0;
  final List<String> deleteChannelCategoryIdArgs = [];

  @override
  Future<List<ClubChannelCategory>> fetchChannelCategories(String clubId) async =>
      categories.where((c) => c.clubId == clubId).toList();

  @override
  Future<ClubChannelCategory> createChannelCategory({
    required String clubId,
    required String name,
  }) async {
    createChannelCategoryCalls++;
    final created = ClubChannelCategory(
      id: 'created-category-$createChannelCategoryCalls',
      clubId: clubId,
      name: name,
      createdBy: 'me',
      createdAt: DateTime.now(),
    );
    categories = [...categories, created];
    return created;
  }

  @override
  Future<void> renameChannelCategory({required String categoryId, required String name}) async {
    renameChannelCategoryCalls++;
    categories = categories
        .map((c) => c.id == categoryId
            ? ClubChannelCategory(
                id: c.id,
                clubId: c.clubId,
                name: name,
                createdBy: c.createdBy,
                createdAt: c.createdAt,
              )
            : c)
        .toList();
  }

  /// Mirrors `category_id`'s real `on delete set null` (see
  /// supabase/schema.sql) -- any channel in this category falls back to
  /// "ไม่มีกลุ่ม" (`categoryId: null`), never gets deleted.
  @override
  Future<void> deleteChannelCategory(String categoryId) async {
    deleteChannelCategoryCalls++;
    deleteChannelCategoryIdArgs.add(categoryId);
    categories = categories.where((c) => c.id != categoryId).toList();
    channels = channels
        .map((c) => c.categoryId == categoryId
            ? ClubChannel(
                id: c.id,
                clubId: c.clubId,
                name: c.name,
                createdBy: c.createdBy,
                createdAt: c.createdAt,
              )
            : c)
        .toList();
  }

  void Function()? _membershipCallback;

  // Deliberately never calls `.subscribe()` on the channel it returns
  // (see RecordingChatRepository's identical comment on
  // subscribeToConversationMessages) -- the real callback is captured
  // separately for [emitBannedOrRemoved] to invoke directly.
  @override
  RealtimeChannel subscribeToMyMembership(
    String clubId,
    void Function() onBannedOrRemoved,
  ) {
    _membershipCallback = onBannedOrRemoved;
    return _fakeChannelClient.channel('test-club-membership-$clubId');
  }

  @override
  void unsubscribe(RealtimeChannel channel) {
    // No-op -- the channel was never actually subscribed.
  }

  /// Test helper: simulates this user's own `club_members` row for
  /// [subscribeToMyMembership]'s club being banned/removed.
  void emitBannedOrRemoved() => _membershipCallback?.call();
}
