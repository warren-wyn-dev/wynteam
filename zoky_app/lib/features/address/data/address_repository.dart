import '../domain/address_models.dart';

/// The signed-in customer's saved delivery addresses.
///
/// Interface + Demo now; the Supabase implementation (ZOKY-105) reads
/// `food_customer_addresses` for the current user only (RLS owner policy),
/// like the web's customer bootstrap, and saves through
/// `food_upsert_customer_address_v3`.
abstract interface class AddressRepository {
  /// Saved addresses, default first then newest (web order).
  Future<List<ZokyDeliveryAddress>> fetchSavedAddresses();
}
