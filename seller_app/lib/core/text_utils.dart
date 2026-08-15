/// Converts an empty text field to `null`. Duplicated from
/// `app/lib/core/text_utils.dart` -- used for optional product fields
/// (description/sku) backed by a DB constraint/convention that expects
/// either NULL or a non-empty value, same reasoning as WYN-003's
/// original use. See .wyn/docs/design/seller-002-product-management.md.
String? normalizeOptionalText(String value) => value.isEmpty ? null : value;

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
