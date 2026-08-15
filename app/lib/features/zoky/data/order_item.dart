/// A single line within an Order, snapshotting the product's
/// name/price/image at the moment of purchase -- never re-queried from
/// the live `products` row, since an Order's historical record must
/// never change retroactively even if the product's price/name changes
/// (or the product is deleted) afterwards. See supabase/schema.sql
/// (ZOKY-003 section, order_items).
class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.variantSelection,
    required this.unitPrice,
    required this.quantity,
    required this.imageUrl,
  });

  final String id;

  /// Null when the underlying product has since been deleted --
  /// [productName]/[unitPrice] below remain accurate regardless.
  final String? productId;
  final String productName;
  final String variantSelection;
  final double unitPrice;
  final int quantity;
  final String? imageUrl;

  double get lineTotal => unitPrice * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String,
      productId: map['product_id'] as String?,
      productName: map['product_name'] as String,
      variantSelection: map['variant_selection'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      imageUrl: map['image_url'] as String?,
    );
  }
}
