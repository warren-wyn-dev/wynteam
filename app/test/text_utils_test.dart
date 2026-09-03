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

  group('compactCountLabel (WYN-095)', () {
    test('leaves a count under 1000 untouched', () {
      expect(compactCountLabel(0), '0');
      expect(compactCountLabel(999), '999');
    });

    test('formats thousands as "X.XK", dropping a trailing .0', () {
      expect(compactCountLabel(1000), '1K');
      expect(compactCountLabel(1200), '1.2K');
      expect(compactCountLabel(500000), '500K');
    });

    test('formats millions as "X.XM", dropping a trailing .0', () {
      expect(compactCountLabel(1000000), '1M');
      expect(compactCountLabel(2500000), '2.5M');
    });

    test('rounds to 1 decimal place rather than truncating', () {
      // 1,260 / 1000 = 1.26 -> rounds to 1.3, not truncates to 1.2.
      expect(compactCountLabel(1260), '1.3K');
    });
  });

  group('quotePostgrestFilterValue', () {
    test('wraps an ordinary value in double quotes', () {
      expect(quotePostgrestFilterValue('%wyn%'), '"%wyn%"');
    });

    test('a comma stays inside the quoted value instead of splitting the '
        'filter -- the "John, Jane" search that used to 400', () {
      expect(quotePostgrestFilterValue('%John, Jane%'), '"%John, Jane%"');
    });

    test('parentheses and dots stay inside the quoted value too', () {
      expect(
        quotePostgrestFilterValue('%a.b(c)%'),
        '"%a.b(c)%"',
      );
    });

    test('escapes a double quote so a crafted query cannot close the value '
        'early and append a filter of its own', () {
      expect(
        quotePostgrestFilterValue('%",id.eq.x%'),
        r'"%\",id.eq.x%"',
      );
    });

    test('escapes a backslash before quotes, so a trailing backslash cannot '
        'escape the closing quote', () {
      expect(quotePostgrestFilterValue(r'%a\%'), r'"%a\\%"');
    });

    test('leaves an empty value as a valid empty quoted string', () {
      expect(quotePostgrestFilterValue(''), '""');
    });
  });
}
