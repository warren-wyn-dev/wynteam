import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/drop/data/location_repository.dart';
import 'package:wyn/features/drop/data/location_result.dart';

/// A LocationRepository whose network-touching methods are overridden to
/// just record what they were called with / return canned data, instead
/// of making a real Edge Function call. Mirrors RecordingDropRepository
/// -- see .wyn/learning/PATTERNS.md.
class RecordingLocationRepository extends LocationRepository {
  RecordingLocationRepository()
      : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [search], keyed by the exact query string passed --
  /// missing keys return an empty list (not an error).
  Map<String, List<LocationResult>> searchResultsByQuery = {};
  final List<String> searchQueryArgs = [];
  Object? searchError;

  @override
  Future<List<LocationResult>> search(String query) async {
    searchQueryArgs.add(query);
    if (searchError != null) throw searchError!;
    return searchResultsByQuery[query] ?? [];
  }

  /// Returned by [reverseGeocode], regardless of lat/lon.
  List<LocationResult> reverseGeocodeResults = [];
  int reverseGeocodeCalls = 0;
  Object? reverseGeocodeError;

  @override
  Future<List<LocationResult>> reverseGeocode({
    required double lat,
    required double lon,
  }) async {
    reverseGeocodeCalls++;
    if (reverseGeocodeError != null) throw reverseGeocodeError!;
    return reverseGeocodeResults;
  }
}
