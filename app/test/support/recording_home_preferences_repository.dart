import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/home/data/home_preferences_repository.dart';

/// A HomePreferencesRepository whose network-touching methods are
/// overridden to just record what they were called with / return canned
/// data, instead of making a real Supabase call. Mirrors
/// RecordingFollowRequestRepository -- see .wyn/learning/PATTERNS.md.
class RecordingHomePreferencesRepository extends HomePreferencesRepository {
  RecordingHomePreferencesRepository({
    this.explainerBannerDismissedResult = false,
  }) : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchExplainerBannerDismissed].
  bool explainerBannerDismissedResult;

  int dismissExplainerBannerCalls = 0;

  @override
  Future<bool> fetchExplainerBannerDismissed() async =>
      explainerBannerDismissedResult;

  @override
  Future<void> dismissExplainerBanner() async {
    dismissExplainerBannerCalls++;
    explainerBannerDismissedResult = true;
  }
}
