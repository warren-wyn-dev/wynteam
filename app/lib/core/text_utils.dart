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

/// Matches a `#hashtag` token -- Unicode letters/marks/digits/underscore
/// (so a trailing punctuation mark like "#WYN!" doesn't get swept into
/// the tag), shared by [extractHashtags] and the tap-rendering widget
/// (`core/widgets/hashtag_text.dart`) so there is exactly one definition
/// of what counts as a hashtag. `\p{M}` (combining marks) is required,
/// not optional, for Thai: vowels/tone marks like "ี"/"่" in "เที่ยว"
/// are Unicode category Mn, not L -- without it the tag truncates after
/// the first such mark (caught by extractHashtags's own test suite).
/// WYN-020.
final RegExp hashtagPattern = RegExp(r'#([\p{L}\p{M}\p{N}_]+)', unicode: true);

/// The exact set of hashtags (lowercased, without the leading `#`) used
/// in [text]. Used both to render tappable spans and, on the search
/// side, to confirm a real match rather than trusting a broad ILIKE
/// substring result -- ILIKE `%#WYN%` also matches `#WYNfamily`, which
/// is a different hashtag; re-checking with this exact tokenizer after
/// the DB call is what keeps that from being treated as a match. See
/// .wyn/docs/design/wyn-020-hashtag-system.md.
Set<String> extractHashtags(String text) => hashtagPattern
    .allMatches(text)
    .map((m) => m.group(1)!.toLowerCase())
    .toSet();

/// Matches an `@username` mention token -- usernames are ASCII
/// alphanumeric/underscore only (unlike hashtags, which allow any
/// Unicode letter -- see `username_setup_screen.dart`'s own validation),
/// so this deliberately doesn't need the `\p{M}` combining-mark fix
/// [hashtagPattern] needed for Thai. WYN-021.
final RegExp mentionPattern = RegExp(r'@([A-Za-z0-9_]+)');

/// A zero-padded `dd/MM/yyyy` date label -- introduced for WYN-029's
/// Restrict/Suspend/Ban messaging (`RestrictionBanner`/
/// `AccountRestrictedScreen`), which both need an exact expiry date
/// rather than [relativeTimeLabel]'s relative phrasing.
String dateLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

/// A compact label for a large count ("999" stays as-is, "1,200" becomes
/// "1.2K", "1,200,000" becomes "1.2M") -- introduced for WYN-095's Profile
/// header redesign (Wynos V1.0.0 Beta2, item 24), where the follower/
/// following/post counts now sit in a 3-way row squeezed next to the
/// avatar rather than spanning the full screen width, so a large raw
/// number risks overflowing at narrow phone widths (360px). Drops a
/// trailing ".0" (e.g. exactly 1000 -> "1K", not "1.0K") since that's
/// visual noise for a round number, same "no decimal when it's whole"
/// posture as [thaiBahtLabel].
String compactCountLabel(int count) {
  if (count < 1000) return '$count';
  double scaled;
  String suffix;
  if (count < 1000000) {
    scaled = count / 1000;
    suffix = 'K';
  } else {
    scaled = count / 1000000;
    suffix = 'M';
  }
  final rounded = (scaled * 10).round() / 10;
  final isWhole = rounded == rounded.roundToDouble();
  final numberPart =
      isWhole ? rounded.toStringAsFixed(0) : rounded.toStringAsFixed(1);
  return '$numberPart$suffix';
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

/// Quotes [value] so it can be embedded safely inside a PostgREST
/// filter-DSL string such as the one `.or()` takes.
///
/// `.or('username.ilike.%$query%,display_name.ilike.%$query%')` builds
/// *filter grammar*, not a parameterized value: `,` separates filters,
/// `.` separates column/operator/value, and `()` groups them. A raw
/// user-typed query containing any of those characters therefore either
/// breaks the whole filter (a search for "John, Jane" comes back as a
/// 400, surfacing to the user as "ค้นหาไม่สำเร็จ" when nothing is
/// actually wrong) or lets the user append filters of their own.
///
/// PostgREST's own answer is to double-quote the value, with `\` and `"`
/// backslash-escaped inside it -- which is exactly what this returns,
/// including the surrounding quotes. Single-value builder methods
/// (`.ilike()`, `.eq()`, ...) are already safe on their own and must NOT
/// use this: they send the value as its own query-string parameter, so
/// quotes added here would be matched literally.
String quotePostgrestFilterValue(String value) {
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}
