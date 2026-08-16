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

  group('extractHashtags (WYN-020)', () {
    test('extracts a single hashtag, lowercased, without the leading #', () {
      expect(extractHashtags('เที่ยว #WYN วันนี้'), {'wyn'});
    });

    test('extracts multiple distinct hashtags', () {
      expect(
        extractHashtags('#WYN #เที่ยวไทย #มหาสารคาม'),
        {'wyn', 'เที่ยวไทย', 'มหาสารคาม'},
      );
    });

    test('does not treat #WYNfamily as containing the tag "wyn" -- full '
        'token match only, not substring', () {
      final tags = extractHashtags('#WYNfamily มารวมตัวกัน');
      expect(tags, {'wynfamily'});
      expect(tags.contains('wyn'), isFalse);
    });

    test('a trailing punctuation mark is not swept into the tag', () {
      expect(extractHashtags('สนุกมาก #WYN!'), {'wyn'});
    });

    test('deduplicates a hashtag repeated in the same text', () {
      expect(extractHashtags('#WYN สุดยอด #wyn'), {'wyn'});
    });

    test('returns an empty set when there are no hashtags', () {
      expect(extractHashtags('ไม่มีแฮชแท็กเลย'), isEmpty);
    });

    test('returns an empty set for an empty string', () {
      expect(extractHashtags(''), isEmpty);
    });
  });
}
