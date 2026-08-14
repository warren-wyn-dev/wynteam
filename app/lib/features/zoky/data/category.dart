/// A ZOKY commerce category row (`public.categories`). Unlike
/// `clubCategories`, which is a plain Dart constant, this is a real FK
/// table because `products.category_id` needs referential integrity --
/// see supabase/schema.sql (ZOKY-001 section).
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
