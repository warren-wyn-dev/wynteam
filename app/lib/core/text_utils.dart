/// Converts an empty text field to `null`. Used for optional fields backed
/// by a DB constraint that requires either NULL or a non-empty value (e.g.
/// profiles_display_name_length, posts_text_content_length in
/// supabase/schema.sql), where sending '' would violate the constraint.
/// See .wyn/learning/MISTAKES.md for the bug this fixed in WYN-003.
String? normalizeOptionalText(String value) => value.isEmpty ? null : value;

/// The display name to show for a user: their display name if set, else
/// "@username" as a fallback. Shared by Profile, Post, and Comment so the
/// three don't drift.
String displayNameOrUsername({
  required String? displayName,
  required String username,
}) =>
    (displayName != null && displayName.isNotEmpty)
        ? displayName
        : '@$username';

/// A Thai relative-time label ("เมื่อสักครู่" / "X นาทีที่แล้ว" / ... /
/// a full date once it's a week old or more) -- introduced for WYN-012's
/// notification list, where recency is the whole point of the screen
/// (unlike Drop/Pop's own timestamps, which WYN-005 deliberately left as
/// a non-blocking Minor since a post's age isn't central to viewing it).
/// Takes [now] as a parameter (rather than reading DateTime.now()
/// internally) so callers/tests can pass a fixed reference time instead
/// of a real wall-clock value that would make assertions flaky.
String relativeTimeLabel(DateTime dateTime, {required DateTime now}) {
  final diff = now.difference(dateTime);
  if (diff.inSeconds < 60) return 'เมื่อสักครู่';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
  if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}

/// A Thai Baht price label with thousand separators ("฿1,000" or
/// "฿1,299.50") -- introduced for ZOKY-001's product cards/detail page.
/// Drops the decimal part entirely when it's a whole number rather than
/// always showing ".00", since most seed/demo prices are round numbers.
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
