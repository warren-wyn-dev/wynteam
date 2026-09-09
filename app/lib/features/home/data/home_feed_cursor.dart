import 'dart:convert';

/// Small stateless cursor for one feed session. It carries only opaque content
/// identities already returned to this user; no scores or ranking weights.
class HomeFeedCursor {
  const HomeFeedCursor({required this.userId, required this.seen});

  static const _version = 1;
  static const maxSeen = 200;
  static const maxEncodedLength = 64 * 1024;
  static const _maxIdentityLength = 512;

  final String userId;
  final Set<String> seen;

  String encode() {
    // Never silently truncate pagination state. Dropping older identities can
    // make already-rendered content eligible again and surface duplicates.
    // A cursor beyond the supported ranked window is a programming error, so
    // fail closed instead of emitting a lossy cursor.
    if (seen.length > maxSeen) {
      throw StateError('Feed cursor contains too many identities');
    }
    if (seen.any((identity) =>
        identity.isEmpty || identity.length > _maxIdentityLength)) {
      throw StateError('Feed cursor contains an invalid identity');
    }

    return base64Url.encode(utf8.encode(jsonEncode({
      'v': _version,
      'u': userId,
      's': seen.toList(),
    })));
  }

  static HomeFeedCursor decode(String value, {required String expectedUserId}) {
    try {
      // Reject obviously corrupted/unbounded input before allocating and
      // decoding a potentially large JSON payload.
      if (value.isEmpty || value.length > maxEncodedLength) {
        throw const FormatException('Invalid feed cursor');
      }

      final decoded = jsonDecode(utf8.decode(base64Url.decode(value)));
      if (decoded is! Map<String, dynamic> ||
          decoded['v'] != _version ||
          decoded['u'] != expectedUserId ||
          decoded['s'] is! List) {
        throw const FormatException('Invalid feed cursor');
      }

      final rawSeen = decoded['s'] as List;
      if (rawSeen.length > maxSeen) {
        throw const FormatException('Invalid feed cursor identities');
      }

      final seen = rawSeen.whereType<String>().toSet();
      if (seen.length != rawSeen.length ||
          seen.any((identity) =>
              identity.isEmpty || identity.length > _maxIdentityLength)) {
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
