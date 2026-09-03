import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/data/profile_repository.dart';

/// A ProfileRepository whose network-touching methods are overridden to
/// just return canned data instead of making a real Supabase call.
/// Mirrors RecordingDropRepository -- see .wyn/learning/PATTERNS.md.
class RecordingProfileRepository extends ProfileRepository {
  RecordingProfileRepository({
    this.profile = const Profile(id: 'unused', username: 'unused'),
    List<Profile>? searchResults,
    this.byUsernameResult,
  })  : searchResults = searchResults ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  // WYN-039: mutable (not final) so a single shared instance (the
  // project's setUpAll convention -- see PATTERNS.md) can be reused
  // across testWidgets cases that each need a different canned Profile,
  // same "reassign a canned field in setUp/per-test" approach
  // RecordingMuteRepository.isMutedResult already establishes.
  Profile profile;

  /// Returned by [fetchProfileByUsername], regardless of the username
  /// asked for -- WYN-021.
  final Profile? byUsernameResult;

  /// Returned by [searchProfiles] for page 0 only (page 1+ returns empty),
  /// regardless of query -- callers assert on [searchProfilesQueryArgs] to
  /// check what was searched for, same "recording" approach as the rest
  /// of this file's siblings.
  final List<Profile> searchResults;

  int searchProfilesCalls = 0;
  final List<String> searchProfilesQueryArgs = [];

  /// Recorded calls to [updateIsPrivate] -- WYN-039's Settings toggle.
  final List<bool> updateIsPrivateArgs = [];

  /// Recorded calls to WYN-045's 3 permission update methods -- one
  /// list per method, same "one recording list per overridden method"
  /// shape as [updateIsPrivateArgs].
  final List<InteractionPermission> updateDmPermissionArgs = [];
  final List<InteractionPermission> updateMentionPermissionArgs = [];
  final List<InteractionPermission> updateCommentPermissionArgs = [];

  @override
  Future<Profile> fetchProfile(String userId) async => profile;

  @override
  Future<void> updateIsPrivate({
    required String userId,
    required bool isPrivate,
  }) async {
    updateIsPrivateArgs.add(isPrivate);
  }

  @override
  Future<void> updateDmPermission({
    required String userId,
    required InteractionPermission value,
  }) async {
    updateDmPermissionArgs.add(value);
  }

  @override
  Future<void> updateMentionPermission({
    required String userId,
    required InteractionPermission value,
  }) async {
    updateMentionPermissionArgs.add(value);
  }

  @override
  Future<void> updateCommentPermission({
    required String userId,
    required InteractionPermission value,
  }) async {
    updateCommentPermissionArgs.add(value);
  }

  /// Recorded calls to [updateLikesVisibility] -- WYN-099.
  final List<LikesVisibility> updateLikesVisibilityArgs = [];

  @override
  Future<void> updateLikesVisibility({
    required String userId,
    required LikesVisibility value,
  }) async {
    updateLikesVisibilityArgs.add(value);
  }

  /// Returned by [canViewLikes], regardless of targetUserId -- WYN-099.
  /// Defaults to true (the ordinary case for almost every profile,
  /// since `likes_visibility` itself defaults to `everyone`).
  bool canViewLikesResult = true;

  @override
  Future<bool> canViewLikes(String targetUserId) async => canViewLikesResult;

  @override
  Future<Profile?> fetchProfileByUsername(String username) async =>
      byUsernameResult;

  @override
  Future<List<Profile>> searchProfiles({
    required String query,
    required int page,
  }) async {
    searchProfilesCalls++;
    searchProfilesQueryArgs.add(query);
    return page == 0 ? searchResults : [];
  }

  /// Recorded calls to [updateProfile]'s arguments, in order -- WYNOS
  /// V1.0.0 Beta requirement 5's EditProfileScreen tests need this
  /// overridden (unlike before, that screen can now reach the real
  /// network-touching method once "บันทึก" is tapped).
  final List<Map<String, String>> updateProfileArgs = [];

  @override
  Future<void> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
  }) async {
    updateProfileArgs.add({'displayName': displayName, 'bio': bio});
  }

  /// Usernames already "taken" as far as [isUsernameAvailable] is
  /// concerned -- WYNOS V1.0.0 Beta requirement 5. Empty by default (no
  /// username taken).
  Set<String> takenUsernames = {};

  @override
  Future<bool> isUsernameAvailable(
    String username, {
    required String currentUserId,
  }) async {
    return !takenUsernames.contains(username);
  }

  /// Each call to [updateUsername]'s username argument, in order.
  final List<String> updateUsernameArgs = [];
  Object? updateUsernameError;

  @override
  Future<void> updateUsername({
    required String userId,
    required String username,
  }) async {
    if (updateUsernameError != null) throw updateUsernameError!;
    updateUsernameArgs.add(username);
  }
}
