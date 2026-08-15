/// A seller's own product row (`public.products`), joined with its
/// store's name (and category name, when a category is set) for
/// display without an extra round trip -- same shape as `app/`'s
/// Customer-facing `Product` model, duplicated here (separate Flutter
/// binary) plus the 2 fields SELLER-002 needs that Customers never see:
/// [isActive]/[sku]. See .wyn/docs/design/seller-002-product-management.md,
/// Data Model.
class Product {
  const Product({
    required this.id,
    required this.storeId,
    required this.storeName,
    this.categoryId,
    this.categoryName,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    required this.stock,
    required this.imageUrls,
    required this.isActive,
    this.sku,
    required this.createdAt,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String? categoryId;
  final String? categoryName;
  final String name;
  final String? description;
  final double price;
  final double? originalPrice;
  final int stock;
  final List<String> imageUrls;
  final bool isActive;
  final String? sku;
  final DateTime createdAt;

  bool get hasDiscount => originalPrice != null && originalPrice! > price;

  factory Product.fromMap(Map<String, dynamic> map) {
    final store = map['store'] as Map<String, dynamic>?;
    final category = map['category'] as Map<String, dynamic>?;
    return Product(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      storeName: store?['name'] as String? ?? '',
      categoryId: map['category_id'] as String?,
      categoryName: category?['name'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      originalPrice: (map['original_price'] as num?)?.toDouble(),
      stock: map['stock'] as int,
      imageUrls: (map['image_urls'] as List).cast<String>(),
      isActive: map['is_active'] as bool? ?? true,
      sku: map['sku'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
