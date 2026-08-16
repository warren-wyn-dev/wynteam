/// The subset of `public.notifications`' `type` CHECK constraint that
/// can ever actually be addressed to a seller -- `new_order` (every
/// order, always) and `order_cancelled` (only the buyer-cancelled
/// direction; the seller-cancelled direction has the seller as actor,
/// not recipient, so it can never land here). The other 2 ZOKY-005 R1
/// types (`order_shipped`/`order_refunded`) and every WYN-012/WYN-015
/// social type are always addressed to a different recipient than a
/// store owner acting as a seller, and the buyer-side social types have
/// no equivalent UI in this app at all -- see
/// SellerNotificationRepository.fetchNotifications, which filters the
/// query itself to just these two rather than relying on this model
/// never seeing anything else.
enum SellerNotificationType { newOrder, orderCancelled }

SellerNotificationType _typeFromString(String value) => switch (value) {
      'new_order' => SellerNotificationType.newOrder,
      'order_cancelled' => SellerNotificationType.orderCancelled,
      _ => throw ArgumentError('Unknown seller notification type: $value'),
    };

/// One row of `public.notifications`, joined with the buyer's profile
/// info -- mirrors `app/`'s `WynNotification` (WYN-012/WYN-015), scoped
/// down to just the 2 types a seller can ever receive. See
/// supabase/schema.sql's ZOKY-005 R1 section.
class SellerNotification {
  const SellerNotification({
    required this.id,
    required this.type,
    required this.buyerUsername,
    this.buyerDisplayName,
    required this.orderId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final SellerNotificationType type;
  final String buyerUsername;
  final String? buyerDisplayName;
  final String orderId;
  final bool isRead;
  final DateTime createdAt;

  factory SellerNotification.fromMap(Map<String, dynamic> map) {
    final buyer = map['actor'] as Map<String, dynamic>;
    return SellerNotification(
      id: map['id'] as String,
      type: _typeFromString(map['type'] as String),
      buyerUsername: buyer['username'] as String? ?? '',
      buyerDisplayName: buyer['display_name'] as String?,
      orderId: map['order_id'] as String,
      isRead: map['is_read'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
