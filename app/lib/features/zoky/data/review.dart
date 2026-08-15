import '../../../core/text_utils.dart';

/// A single product review, always tied to the order_item the reviewer
/// actually bought and had delivered (see supabase/schema.sql, ZOKY-004
/// section). [productName] is only populated when the query needs to
/// disambiguate across multiple products (e.g. a store's combined
/// Reviews tab) -- null everywhere else.
class Review {
  const Review({
    required this.id,
    required this.orderItemId,
    required this.productId,
    required this.userId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.rating,
    this.textContent,
    required this.createdAt,
    required this.updatedAt,
    this.productName,
  });

  final String id;
  final String orderItemId;
  final String productId;
  final String userId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final int rating;
  final String? textContent;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? productName;

  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  factory Review.fromMap(Map<String, dynamic> map) {
    final author = map['author'] as Map<String, dynamic>?;
    final product = map['product'] as Map<String, dynamic>?;

    return Review(
      id: map['id'] as String,
      orderItemId: map['order_item_id'] as String,
      productId: map['product_id'] as String,
      userId: map['user_id'] as String,
      authorUsername: author?['username'] as String? ?? '',
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      rating: map['rating'] as int,
      textContent: map['text_content'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      productName: product?['name'] as String?,
    );
  }
}
