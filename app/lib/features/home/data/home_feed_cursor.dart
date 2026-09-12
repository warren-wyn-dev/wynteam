import 'dart:convert';

/// Small stateless cursor for one feed session. It carries only opaque content
/// identities already returned to this user; no scores or ranking weights.
class HomeFeedCursor {
  const HomeFeedCursor({required this.userId, required this.seen});

  static const _version = 1;
  static const maxSeen = 200;

  final String userId;
  final Set<String> seen;

  String encode() => base64Url.encode(utf8.encode(jsonEncode({
        'v': _version,
        'u': userId,
        's': seen.take(maxSeen).toList(),
      })));

  static HomeFeedCursor decode(String value, {required String expectedUserId}) {
    try {
      final decoded = jsonDecode(utf8.decode(base64Url.decode(value)));
      if (decoded is! Map<String, dynamic> ||
          decoded['v'] != _version ||
          decoded['u'] != expectedUserId ||
          decoded['s'] is! List) {
        throw const FormatException('Invalid feed cursor');
      }
      final seen = (decoded['s'] as List).whereType<String>().toSet();
      if (seen.length > maxSeen ||
          seen.length != (decoded['s'] as List).length) {
        throw const FormatException('Invalid feed cursor identities');
      }
      return HomeFeedCursor(userId: expectedUserId, seen: seen);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid feed cursor');
    }
  }
}

class HomeFeedPage<T> {
  const HomeFeedPage({required this.items, this.nextCursor});
  final List<T> items;
  final String? nextCursor;
}
