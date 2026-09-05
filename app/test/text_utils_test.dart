import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/core/text_utils.dart';

void main() {
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

  group('relativeTimeLabel', () {
    test('under a minute reads "เมื่อสักครู่"', () {
      final now = DateTime(2026, 1, 1, 12, 0, 30);
      expect(relativeTimeLabel(now.subtract(const Duration(seconds: 10)), now: now), 'เมื่อสักครู่');
    });

    test('under an hour counts minutes', () {
      final now = DateTime(2026, 1, 1, 12, 30);
      expect(relativeTimeLabel(now.subtract(const Duration(minutes: 5)), now: now), '5 นาทีที่แล้ว');
    });

    test('under a day counts hours', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      expect(relativeTimeLabel(now.subtract(const Duration(hours: 3)), now: now), '3 ชั่วโมงที่แล้ว');
    });

    test('under a week counts days', () {
      final now = DateTime(2026, 1, 10, 12, 0);
      expect(relativeTimeLabel(now.subtract(const Duration(days: 4)), now: now), '4 วันที่แล้ว');
    });

    test('a week or older falls back to a full local date', () {
      final now = DateTime(2026, 1, 20, 12, 0);
      final dateTime = now.subtract(const Duration(days: 10));
      expect(relativeTimeLabel(dateTime, now: now), '${dateTime.day}/${dateTime.month}/${dateTime.year}');
    });

    // Founder feedback: a chat/notification timestamp older than a week
    // was reading off the raw UTC calendar date instead of the user's
    // local one -- for anyone east of UTC (Thailand is UTC+7), a message
    // sent late at night UTC lands in the *next* local calendar day, so
    // the date shown was a day behind. Mirrors dateLabel's own
    // .toLocal() convention just below in the same file.
    test('a week-old-plus UTC timestamp uses the local calendar date, not '
        'the raw UTC one -- the day-behind bug for UTC+ timezones', () {
      // 23:30 UTC on Jan 1st is 06:30 local the *next* day at UTC+7.
      final dateTimeUtc = DateTime.utc(2026, 1, 1, 23, 30);
      final now = DateTime.utc(2026, 1, 20, 12, 0);
      final expectedLocalDate = dateTimeUtc.toLocal();

      expect(
        relativeTimeLabel(dateTimeUtc, now: now),
        '${expectedLocalDate.day}/${expectedLocalDate.month}/${expectedLocalDate.year}',
      );
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
