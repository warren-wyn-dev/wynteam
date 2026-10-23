/// Formats Thai baht like the web's `foodMoney()` (web/lib/food-customer.ts):
/// Intl th-TH THB currency, no decimals for whole amounts, two otherwise.
/// Examples: 59 -> ฿59, 1250 -> ฿1,250, 59.5 -> ฿59.50.
///
/// Display only: confirmed totals always come from the server quote.
String formatBaht(num amount) {
  final negative = amount < 0;
  final absolute = amount.abs();
  final whole = absolute % 1 == 0;
  final fixed = absolute.toStringAsFixed(whole ? 0 : 2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final decimals = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}฿$buffer$decimals';
}
