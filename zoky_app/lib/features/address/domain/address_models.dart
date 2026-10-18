/// A saved delivery address. Mirrors the subset of the web's
/// `FoodCustomerAddress` (web/lib/food-customer.ts; table
/// `food_customer_addresses`, owner-only via RLS) that Home and the
/// address sheet show:
/// - [id], [label], [address]: `id`, `label` (1-80 chars, e.g. "บ้าน"),
///   `address` (full formatted text, 1-800 chars)
/// - [latitude], [longitude]: the delivery pin (nullable; the web asks the
///   customer to pin it before ordering)
/// - [deliveryNote]: `delivery_note` (<= 500 chars, nullable)
/// - [isDefault]: `is_default` (at most one per customer)
///
/// Recipient name/phone and the structured Thai fields stay out of this
/// model until checkout needs them (privacy: load only what is shown).
class ZokyDeliveryAddress {
  const ZokyDeliveryAddress({
    required this.id,
    required this.label,
    required this.address,
    this.latitude,
    this.longitude,
    this.deliveryNote,
    this.isDefault = false,
    this.isDemo = false,
  });

  final String id;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? deliveryNote;
  final bool isDefault;

  /// Sample address (demo mode): the UI must label it as such.
  final bool isDemo;
}
