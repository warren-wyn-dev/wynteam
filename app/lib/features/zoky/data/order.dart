enum OrderStatus { pending, delivered, cancelled }

OrderStatus orderStatusFromString(String value) => switch (value) {
      'delivered' => OrderStatus.delivered,
      'cancelled' => OrderStatus.cancelled,
      _ => OrderStatus.pending,
    };

/// One Order -- always scoped to a single store (Product spec: "1
/// Order ต่อ 1 ร้านค้า"), created only by create_orders() (see
/// supabase/schema.sql, ZOKY-003 section). [feePercent]/[feeAmount]
/// are snapshots of the platform fee at the moment this Order was
/// placed, not the current live config value -- see
/// ZokyRepository.createOrders.
class Order {
  const Order({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.status,
    required this.recipientName,
    required this.recipientPhone,
    required this.shippingAddress,
    required this.subtotal,
    required this.feePercent,
    required this.feeAmount,
    required this.total,
    required this.createdAt,
  });

  final String id;
  final String storeId;
  final String storeName;
  final OrderStatus status;
  final String recipientName;
  final String recipientPhone;
  final String shippingAddress;
  final double subtotal;
  final double feePercent;
  final double feeAmount;
  final double total;
  final DateTime createdAt;

  factory Order.fromMap(Map<String, dynamic> map) {
    final store = map['store'] as Map<String, dynamic>?;
    return Order(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      storeName: store?['name'] as String? ?? '',
      status: orderStatusFromString(map['status'] as String),
      recipientName: map['recipient_name'] as String,
      recipientPhone: map['recipient_phone'] as String,
      shippingAddress: map['shipping_address'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      feePercent: (map['fee_percent'] as num).toDouble(),
      feeAmount: (map['fee_amount'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
