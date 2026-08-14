enum VariantType { color, size }

VariantType variantTypeFromString(String value) =>
    value == 'size' ? VariantType.size : VariantType.color;

/// A single Color/Size option for a Product. Preview-only this round --
/// selecting one doesn't affect price/stock shown anywhere, since Cart
/// (ZOKY-003) doesn't exist yet to make that a real transactional
/// state. See supabase/schema.sql (ZOKY-001 section).
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.type,
    required this.value,
    this.priceDelta,
    required this.stock,
  });

  final String id;
  final String productId;
  final VariantType type;
  final String value;
  final double? priceDelta;
  final int stock;

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      type: variantTypeFromString(map['variant_type'] as String),
      value: map['variant_value'] as String,
      priceDelta: (map['price_delta'] as num?)?.toDouble(),
      stock: map['stock'] as int,
    );
  }
}
