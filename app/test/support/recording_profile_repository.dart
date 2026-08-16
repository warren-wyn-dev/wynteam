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
}
