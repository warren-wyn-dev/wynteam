import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/data/profile_repository.dart';

/// A ProfileRepository whose network-touching methods are overridden to
/// just return canned data instead of making a real Supabase call.
/// Mirrors RecordingDropRepository -- see .wyn/learning/PATTERNS.md.
class RecordingProfileRepository extends ProfileRepository {
  RecordingProfileRepository({required this.profile})
      : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  final Profile profile;

  @override
  Future<Profile> fetchProfile(String userId) async => profile;
}
