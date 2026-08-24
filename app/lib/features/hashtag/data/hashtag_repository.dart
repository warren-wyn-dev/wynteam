import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import '../../club/data/club_post_repository.dart';
import '../../drop/data/drop_repository.dart';

/// One hashtag autocomplete result -- a tag (lowercased, no leading `#`)
/// plus how many recent posts (Drop + Club post) use it. WYNOS V1.0.0
/// Beta requirement 7.
class HashtagSuggestion {
  const HashtagSuggestion({required this.tag, required this.postCount});

  final String tag;
  final int postCount;
}

/// Powers the "#" autocomplete dropdown in MentionInput. There is
/// deliberately no `hashtags` entity table (WYN-020's own Non-goals
/// already settled this -- hashtags stay substrings of `caption`/
/// `content`, ILIKE-matched), so [suggest] approximates counts by
/// scanning a bounded, most-recent candidate set client-side with the
/// same [extractHashtags] tokenizer every other hashtag-aware widget
/// already uses, rather than introducing new server-side aggregation
/// machinery for a beta feature. Good enough for "which of these tags
/// is more popular right now", not an exact global count.
class HashtagRepository {
  HashtagRepository(SupabaseClient client)
      : _dropRepository = DropRepository(client),
        _clubPostRepository = ClubPostRepository(client);

  /// Test/injection constructor -- takes already-constructed
  /// repositories directly (e.g. RecordingDropRepository/
  /// RecordingClubPostRepository fakes) instead of a SupabaseClient,
  /// same "construct the real thing by default, allow swapping the
  /// pieces in tests" shape as every other repository in this codebase.
  HashtagRepository.from({
    required DropRepository dropRepository,
    required ClubPostRepository clubPostRepository,
  })  : _dropRepository = dropRepository,
        _clubPostRepository = clubPostRepository;

  final DropRepository _dropRepository;
  final ClubPostRepository _clubPostRepository;

  /// Suggestions for the `#prefix` currently being typed, most-used
  /// first (ties broken alphabetically). Empty [prefix] returns no
  /// suggestions -- the composer only shows this dropdown once at least
  /// one character follows the `#`.
  Future<List<HashtagSuggestion>> suggest(
    String prefix, {
    int limit = 8,
  }) async {
    final lowerPrefix = prefix.toLowerCase();
    if (lowerPrefix.isEmpty) return const [];

    final results = await Future.wait([
      _dropRepository.fetchCaptionsForHashtagSuggestion('#$prefix'),
      _clubPostRepository.fetchContentForHashtagSuggestion('#$prefix'),
    ]);

    final counts = <String, int>{};
    for (final text in [...results[0], ...results[1]]) {
      for (final tag in extractHashtags(text)) {
        if (!tag.startsWith(lowerPrefix)) continue;
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }

    final suggestions = counts.entries
        .map((e) => HashtagSuggestion(tag: e.key, postCount: e.value))
        .toList()
      ..sort((a, b) {
        final byCount = b.postCount.compareTo(a.postCount);
        return byCount != 0 ? byCount : a.tag.compareTo(b.tag);
      });

    return suggestions.take(limit).toList();
  }
}
