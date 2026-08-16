/// Converts an empty text field to `null`. Duplicated from
/// `app/lib/core/text_utils.dart` -- used for optional product fields
/// (description/sku) backed by a DB constraint/convention that expects
/// either NULL or a non-empty value, same reasoning as WYN-003's
/// original use. See .wyn/docs/design/seller-002-product-management.md.
String? normalizeOptionalText(String value) => value.isEmpty ? null : value;

/// Duplicated from `app/lib/core/text_utils.dart` -- used by
/// SellerNotificationListScreen (ZOKY-005 R1) to show the buyer's name
/// on a new_order/order_cancelled notification, same fallback rule
/// NotificationListScreen already uses on the Customer side.
String displayNameOrUsername({
  required String? displayName,
  required String username,
}) =>
    (displayName != null && displayName.isNotEmpty) ? displayName : '@$username';

/// A Thai relative-time label ("เมื่อสักครู่" / "X นาทีที่แล้ว" / ... / a
/// full date once it's a week old or more). Duplicated from
/// `app/lib/core/text_utils.dart` (WYN Social, WYN-012) -- used by
/// `SellerOrderListTile` (SELLER-003) for the order date, same as
/// `OrderSummaryCard` uses it on the Customer side. Takes [now] as a
/// parameter (rather than reading DateTime.now() internally) so callers/
/// tests can pass a fixed reference time instead of a real wall-clock
/// value that would make assertions flaky.
String relativeTimeLabel(DateTime dateTime, {required DateTime now}) {
  final diff = now.difference(dateTime);
  if (diff.inSeconds < 60) return 'เมื่อสักครู่';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
  if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}

/// Formats [price] as a Thai Baht amount with thousands separators, e.g.
/// `thaiBahtLabel(1234.5)` -> `฿1,234.50`, `thaiBahtLabel(1234)` ->
/// `฿1,234`. Duplicated from `app/lib/core/text_utils.dart` (WYN Social)
/// so every money amount in this app formats consistently with ZOKY
/// Marketplace's Customer-facing screens -- see
/// .wyn/docs/design/seller-001-foundation.md, SellerDashboardScreen
/// Design Rules.
String thaiBahtLabel(double price) {
  final isWhole = price == price.roundToDouble();
  final fixed = price.toStringAsFixed(isWhole ? 0 : 2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final wholePart = buffer.toString();
  return parts.length > 1 ? '฿$wholePart.${parts[1]}' : '฿$wholePart';
}
