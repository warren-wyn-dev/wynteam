import 'package:supabase_flutter/supabase_flutter.dart';

import 'location_result.dart';

/// Thrown by [LocationRepository] when the caller's own request rate
/// (Product spec's ชั้นที่ 2, server-side, mandatory -- see
/// supabase/functions/location-search/_lib.ts's RATE_LIMIT_* constants)
/// has been exceeded -- distinct from [LocationSearchFailedException]
/// so `LocationPickerSheet` can show the specific "ค้นหาบ่อยเกินไป..."
/// copy instead of the generic API-failure one.
class LocationSearchRateLimitedException implements Exception {}

/// Thrown for every other `location-search` failure -- LocationIQ
/// itself down/timed out, not yet configured
/// (`LOCATIONIQ_API_KEY` unset), a network error reaching the Edge
/// Function, or a malformed response. Deliberately not more granular
/// than this -- Product spec's Edge Cases table gives all of these the
/// exact same user-facing copy ("ค้นหาสถานที่ไม่สำเร็จตอนนี้...").
class LocationSearchFailedException implements Exception {}

/// Wraps the `location-search` Edge Function (WYN-098) -- the only
/// path that ever reaches LocationIQ; the API key itself never leaves
/// the server (see that function's own doc comment). See
/// .wyn/docs/product/wyn-098-location-checkin.md.
class LocationRepository {
  LocationRepository(this._client);

  final SupabaseClient _client;

  Future<List<LocationResult>> search(String query) =>
      _invoke({'mode': 'search', 'query': query});

  Future<List<LocationResult>> reverseGeocode({
    required double lat,
    required double lon,
  }) =>
      _invoke({'mode': 'reverse', 'lat': lat, 'lon': lon});

  Future<List<LocationResult>> _invoke(Map<String, dynamic> body) async {
    try {
      final response =
          await _client.functions.invoke('location-search', body: body);
      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>?) ?? const [];
      return results
          .map((r) => LocationResult.fromMap(r as Map<String, dynamic>))
          .toList();
    } on FunctionException catch (e) {
      if (e.status == 429) throw LocationSearchRateLimitedException();
      throw LocationSearchFailedException();
    }
  }
}
