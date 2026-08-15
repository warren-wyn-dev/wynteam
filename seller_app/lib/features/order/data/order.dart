/// The 8 statuses master prompt Section 10 defines -- duplicated from
/// `app/lib/features/zoky/data/order.dart` (SELLER-003, separate
/// Flutter binary, same pattern SELLER-001/002 already established for
/// every other duplicated model). See supabase/schema.sql (SELLER-003
/// section) and .wyn/tasks/backlog/SELLER-003-order-management.md,
/// Requirements #1. [pendingPayment] can never actually be produced by
/// any RPC this round (there's no payment gateway in this project) --
/// it's scaffolded here purely so a future payment-gateway integration
/// doesn't need another schema/enum migration.
enum OrderStatus {
  pendingPayment,
  paid,
  sellerProcessing,
  readyToShip,
  shipped,
  delivered,
  cancelled,
  refunded,
}

/// Falls back to [OrderStatus.pendingPayment] for any value the switch
/// doesn't recognize -- the DB CHECK constraint guarantees this never
/// actually happens in practice, this is defense-in-depth only.
OrderStatus orderStatusFromString(String value) => switch (value) {
      'paid' => OrderStatus.paid,
      'seller_processing' => OrderStatus.sellerProcessing,
      'ready_to_ship' => OrderStatus.readyToShip,
      'shipped' => OrderStatus.shipped,
      'delivered' => OrderStatus.delivered,
      'cancelled' => OrderStatus.cancelled,
      'refunded' => OrderStatus.refunded,
      _ => OrderStatus.pendingPayment,
    };

/// The reverse of [orderStatusFromString] -- needed here (unlike
/// `app/`'s ZOKY Marketplace, which only ever *reads* a status) because
/// `SellerOrderListScreen`'s filter chips need to turn a selected
/// [OrderStatus] back into the DB literal `SellerRepository.
/// fetchStoreOrders` filters on.
String orderStatusToDbValue(OrderStatus status) => switch (status) {
      OrderStatus.pendingPayment => 'pending_payment',
      OrderStatus.paid => 'paid',
      OrderStatus.sellerProcessing => 'seller_processing',
      OrderStatus.readyToShip => 'ready_to_ship',
      OrderStatus.shipped => 'shipped',
      OrderStatus.delivered => 'delivered',
      OrderStatus.cancelled => 'cancelled',
      OrderStatus.refunded => 'refunded',
    };

/// One Order belonging to the caller's own store -- duplicated from
/// `app/`'s Customer-facing `Order` model (see that file's own doc
/// comment for the full field-by-field reasoning). [recipientName]/
/// [recipientPhone]/[shippingAddress] are the same buyer-entered
/// snapshot the Customer app sees; the seller has no way to edit them.
class Order {
  const Order({
    required this.id,
    required this.storeId,
    required this.status,
    required this.recipientName,
    required this.recipientPhone,
    required this.shippingAddress,
    required this.subtotal,
    required this.feePercent,
    required this.feeAmount,
    required this.total,
    required this.createdAt,
    this.shippingProvider,
    this.trackingNumber,
  });

  final String id;
  final String storeId;
  final OrderStatus status;
  final String recipientName;
  final String recipientPhone;
  final String shippingAddress;
  final double subtotal;
  final double feePercent;
  final double feeAmount;
  final double total;
  final DateTime createdAt;

  /// Set together by seller_ship_order once the order reaches
  /// [OrderStatus.shipped] -- null before that.
  final String? shippingProvider;
  final String? trackingNumber;

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      status: orderStatusFromString(map['status'] as String),
      recipientName: map['recipient_name'] as String,
      recipientPhone: map['recipient_phone'] as String,
      shippingAddress: map['shipping_address'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      feePercent: (map['fee_percent'] as num).toDouble(),
      feeAmount: (map['fee_amount'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      shippingProvider: map['shipping_provider'] as String?,
      trackingNumber: map['tracking_number'] as String?,
    );
  }
}
