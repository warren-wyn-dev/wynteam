import 'product.dart';

/// A single line in the caller's cart, joined with enough of its
/// product to render without a second round trip. [product] is used
/// for name/price/image/current stock (the stock ceiling a quantity
/// stepper must respect) -- the source of truth for what's actually
/// deducted still lives server-side in create_orders(), this is only
/// for display. See supabase/schema.sql (ZOKY-003 section).
class CartItem {
  const CartItem({
    required this.id,
    required this.product,
    required this.variantSelection,
    required this.quantity,
  });

  final String id;
  final Product product;

  /// Empty string means "no variant selected" (see cart_items'
  /// unique constraint comment in schema.sql for why this is '' and
  /// not null).
  final String variantSelection;
  final int quantity;

  double get lineTotal => product.price * quantity;

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] as String,
      product: Product.fromMap(map['product'] as Map<String, dynamic>),
      variantSelection: map['variant_selection'] as String,
      quantity: map['quantity'] as int,
    );
  }
}
