import '../../../core/text_utils.dart';

/// One hashtag's rank -- [tag] plus how many of the ranking window's
/// candidate captions mentioned it ([postCount]).
class RankedHashtag {
  const RankedHashtag({required this.tag, required this.postCount});

  final String tag;
  final int postCount;
}

/// Counts every `#hashtag` occurring across [captions] (via
/// [extractHashtags] -- WYN-020's own tokenizer, reused as-is, not a
/// new regex) and returns the top [limit] tags ranked by frequency,
/// most-mentioned first, each paired with its count. Pure/no I/O,
/// mirroring `home_ranking.dart`'s `rankingScore()` shape -- lets
/// `DiscoveryRepository.fetchTrendingHashtags`'s ranking logic be
/// unit-tested without a live Supabase call.
///
/// design-reference `03-search.tsx`'s Top 100 (2026-08-29, Founder-
/// approved re-brand) shows this count per row ("214 โพสต์"), which
/// supersedes .wyn/docs/design/wyn-040-discovery-page.md's original
/// "the frequency count itself is never shown to the user" decision --
/// see .wyn/company/DECISIONS.md.
List<RankedHashtag> rankTrendingHashtags(
  Iterable<String?> captions, {
  required int limit,
}) {
  final frequency = <String, int>{};
  for (final caption in captions) {
    if (caption == null) continue;
    for (final tag in extractHashtags(caption)) {
      frequency[tag] = (frequency[tag] ?? 0) + 1;
    }
  }

  final ranked = frequency.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return ranked
      .take(limit)
      .map((entry) => RankedHashtag(tag: entry.key, postCount: entry.value))
      .toList();
}
