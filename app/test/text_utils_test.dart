import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/core/text_utils.dart';

/// Regression tests for thaiBahtLabel (ZOKY-001), covering the
/// thousand-separator and whole-vs-decimal formatting logic.
void main() {
  test('formats a whole number without decimals', () {
    expect(thaiBahtLabel(199), '฿199');
  });

  test('adds a thousand separator past 3 digits', () {
    expect(thaiBahtLabel(1000), '฿1,000');
  });

  test('adds multiple thousand separators for large numbers', () {
    expect(thaiBahtLabel(1234567), '฿1,234,567');
  });

  test('keeps decimals when the price is not a whole number', () {
    expect(thaiBahtLabel(1299.5), '฿1,299.50');
  });

  test('formats zero correctly', () {
    expect(thaiBahtLabel(0), '฿0');
  });
}
