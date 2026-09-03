import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/location_result.dart';

void main() {
  group('LocationResult.fromMap', () {
    test('parses every field from the Edge Function response shape', () {
      final result = LocationResult.fromMap({
        'name': 'Starbucks',
        'address': 'สยามพารากอน, Bangkok, Thailand',
        'lat': 13.7466,
        'lon': 100.5347,
        'placeId': '12345',
      });

      expect(result.name, 'Starbucks');
      expect(result.address, 'สยามพารากอน, Bangkok, Thailand');
      expect(result.lat, 13.7466);
      expect(result.lon, 100.5347);
      expect(result.placeId, '12345');
    });

    test('address is nullable (a single-segment display_name has no '
        'disambiguating subtitle)', () {
      final result = LocationResult.fromMap({
        'name': 'Thailand',
        'address': null,
        'lat': 13.0,
        'lon': 100.0,
        'placeId': '1',
      });

      expect(result.address, isNull);
    });

    test('lat/lon parse correctly whether the JSON encodes them as int '
        'or double', () {
      final result = LocationResult.fromMap({
        'name': 'x',
        'address': null,
        'lat': 13, // int, not double -- e.g. exactly on a whole degree
        'lon': 100.5,
        'placeId': '1',
      });

      expect(result.lat, 13.0);
      expect(result.lon, 100.5);
    });
  });
}
