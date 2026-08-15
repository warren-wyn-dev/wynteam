enum VariantType { color, size }

VariantType variantTypeFromString(String value) =>
    value == 'size' ? VariantType.size : VariantType.color;

/// The reverse of [variantTypeFromString] -- needed here (unlike
/// `app/`'s ZOKY Marketplace, which only ever *reads* variants) because
/// this app is the one that writes `product_variants.variant_type`.
String variantTypeToDbValue(VariantType type) =>
    type == VariantType.size ? 'size' : 'color';

/// A single Color/Size option for a Product (`public.product_variants`).
/// Duplicated from `app/lib/features/zoky/data/product_variant.dart`
/// (same table, same flat-list-per-type shape -- see the Product spec's
/// Requirements #3: "ยึด data model แบบ flat list ต่อ type เดิมจาก
/// ZOKY-001 ตรง ๆ ไม่ทำเป็น combination matrix ใหม่"). See
/// .wyn/docs/design/seller-002-product-management.md, Data Model.
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

/// Local, not-yet-persisted form state for a single row in
/// `ProductVariantEditor` -- never written directly to the DB. [id] is
/// null for a variant added during this editing session (not yet in
/// the DB, so `SellerRepository.updateProduct` inserts it, [stock] and
/// all) and set for one that already exists (so it's updated in place
/// instead, and any existing id no longer present in the submitted
/// list is hard-deleted -- see
/// .wyn/docs/design/seller-002-product-management.md, Widget:
/// ProductVariantEditor). [stock] is mutable only to let a *new* row's
/// initial value be edited before submit (same reasoning as a new
/// product's initial stock, see the Product spec's Requirements #5) --
/// `SellerRepository.updateProduct` never sends it for a row that
/// already has an [id]; only `StockAdjustmentSheet`'s RPC call may
/// change an existing variant's stock.
class VariantInput {
  VariantInput({
    this.id,
    required this.type,
    required this.value,
    this.priceDelta,
    required this.stock,
  });

  final String? id;
  final VariantType type;
  String value;
  double? priceDelta;
  int stock;
}
