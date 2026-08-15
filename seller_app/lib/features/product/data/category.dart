/// A ZOKY commerce category row (`public.categories`). Duplicated from
/// `app/lib/features/zoky/data/category.dart` (WYN Social / ZOKY
/// Marketplace's `Category` model, same table) since this is a separate
/// Flutter binary -- see .wyn/docs/design/seller-002-product-management.md,
/// Data Model.
class Category {
  const Category({required this.id, required this.name});

  final String id;
  final String name;

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}
