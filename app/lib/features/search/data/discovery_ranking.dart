import '../../../core/text_utils.dart';

/// Counts every `#hashtag` occurring across [captions] (via
/// [extractHashtags] -- WYN-020's own tokenizer, reused as-is, not a
/// new regex) and returns the top [limit] tags ranked by frequency,
/// most-mentioned first. Pure/no I/O, mirroring `home_ranking.dart`'s
/// `rankingScore()` shape -- lets
/// `DiscoveryRepository.fetchTrendingHashtags`'s ranking logic be
/// unit-tested without a live Supabase call. See
/// .wyn/docs/design/wyn-040-discovery-page.md, Screen 1, section 2
/// ("Trending Hashtags"): the frequency count itself is never shown to
/// the user (only used to order the chips), so this deliberately
/// returns just the ordered tag list, no counts.
List<String> rankTrendingHashtags(
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
  return ranked.take(limit).map((entry) => entry.key).toList();
}
