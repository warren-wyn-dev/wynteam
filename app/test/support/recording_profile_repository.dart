import 'dart:typed_data';

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
        super(SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          // No network call is ever made through this fake, so the real
          // GoTrue client's background auto-refresh Timer.periodic serves
          // no purpose here -- it only risks tripping flutter_test's "A
          // Timer is still pending" invariant check if this repository is
          // ever constructed directly inside a testWidgets() body (inside
          // its fake-async zone) instead of setUp(). See
          // .wyn/learning/PATTERNS.md.
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  final Profile profile;

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

  // WYN-024 -- lets Edit Profile tests prove the fail-fast ordering
  // (nothing else is written when the username save fails) without
  // touching a real Supabase project.
  int updateProfileCalls = 0;
  int uploadAvatarCalls = 0;
  int uploadCoverCalls = 0;

  @override
  Future<Profile> fetchProfile(String userId) async => profile;

  @override
  Future<Profile?> fetchProfileByUsername(String username) async => byUsernameResult;

  @override
  Future<List<Profile>> searchProfiles({
    required String query,
    required int page,
  }) async {
    searchProfilesCalls++;
    searchProfilesQueryArgs.add(query);
    return page == 0 ? searchResults : [];
  }

  @override
  Future<void> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
    required String website,
  }) async {
    updateProfileCalls++;
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    uploadAvatarCalls++;
    return 'https://example.supabase.co/avatars/$userId/avatar.$fileExtension';
  }

  @override
  Future<String> uploadCover({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    uploadCoverCalls++;
    return 'https://example.supabase.co/avatars/$userId/cover.$fileExtension';
  }
}
