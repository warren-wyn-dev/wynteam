/// A place LocationIQ returned (WYN-098 -- Location Check-in), already
/// selected by the user in `LocationPickerSheet`. Mirrors
/// `location-search`'s own `LocationResult` shape (see
/// supabase/functions/location-search/_lib.ts) 1:1.
///
/// [address] is only used to disambiguate same-named results inside
/// the picker sheet itself (Product spec's "Starbucks — สยามพารากอน"
/// example) -- once attached to a Drop, only [name] is ever displayed
/// anywhere (Product spec's Privacy section: coordinates/place id are
/// stored for a possible future feature, never shown to a user).
class LocationResult {
  const LocationResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
    required this.placeId,
  });

  factory LocationResult.fromMap(Map<String, dynamic> map) => LocationResult(
        name: map['name'] as String,
        address: map['address'] as String?,
        lat: (map['lat'] as num).toDouble(),
        lon: (map['lon'] as num).toDouble(),
        placeId: map['placeId'] as String,
      );

  final String name;
  final String? address;
  final double lat;
  final double lon;
  final String placeId;
}
