import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/data/home_feed_item.dart';
import '../../home/data/home_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import 'discovery_ranking.dart';

/// Data layer for the Discovery page (WYN-040) -- the default state of
/// `SearchScreen` (WYN-009) shown while the query is empty/shorter than
/// 2 characters. See .wyn/docs/design/wyn-040-discovery-page.md.
///
/// Trending Now/Trending Hashtags reuse `HomeRepository.fetchTrending`
/// directly rather than duplicating its 48h-window/candidate-fetch
/// logic here. Rising/Suggested Users call the two new SECURITY
/// DEFINER RPCs (`rising_profiles`/`suggested_users`, see
/// supabase/schema.sql) -- both return only an already-ranked
/// `profile_id` list (never the raw ranking signal itself, per the
/// Design doc's anti-gaming note), which this joins back to full
/// [Profile] rows through [ProfileRepository.fetchProfilesByIds].
/// Suggested Clubs deliberately has no method here at all -- the
/// Design doc calls for reusing `ClubRepository.fetchPopularClubs()`
/// directly from `DiscoveryView`, with no new wrapper needed.
class DiscoveryRepository {
  DiscoveryRepository(
    this._client, {
    required HomeRepository homeRepository,
    required ProfileRepository profileRepository,
  })  : _homeRepository = homeRepository,
        _profileRepository = profileRepository;

  final SupabaseClient _client;
  final HomeRepository _homeRepository;
  final ProfileRepository _profileRepository;

  // Non-goals (Design doc): no "ดูเพิ่มเติม"/pagination per section this
  // round -- each of these is a single bounded fetch.
  static const trendingNowLimit = 30;
  static const trendingHashtagsLimit = 20;
  static const risingLimit = 10;
  static const suggestedUsersLimit = 10;

  // design-reference `03-search.tsx` (2026-08-29, Founder-approved
  // re-brand -- see .wyn/company/DECISIONS.md): Discovery's preview
  // shows a short list of ranked hashtags, "Top 100" (Top100Screen) shows
  // up to this many -- same bound as the candidate window itself
  // ([HomeRepository.trendingCandidateLimit]), since ranking can never
  // surface more distinct tags than that many candidate posts anyway.
  static const top100PreviewLimit = 6;
  static const top100FullLimit = HomeRepository.trendingCandidateLimit;

  /// "กำลังนิยม" section -- same formula as Home's own Trending row (48h
  /// window, like+comment count), just a wider result [limit] (Home
  /// only ever shows the top 10; Discovery shows up to ~30).
  ///
  /// Unused by any screen since the `03-search.tsx` re-brand replaced
  /// Discovery's "Trending Now" photo grid with the Top 100 hashtag list
  /// below -- kept (not deleted) since it's a real, working capability
  /// Home's own Trending row also relies on ([HomeRepository.
  /// fetchTrending] itself, which this just thinly wraps).
  Future<List<HomeFeedItem>> fetchTrendingNow({int limit = trendingNowLimit}) {
    return _homeRepository.fetchTrending(limit: limit);
  }

  /// WYN-042: the original content-ranked "WYN Top 100" leaderboard --
  /// same shape as [fetchTrendingNow] (thin wrapper), but backed by
  /// [HomeRepository.fetchTopContent] instead (its own 7-day window/
  /// wider candidate pool, entirely separate from fetchTrending's).
  ///
  /// Unused by any screen since the `03-search.tsx` re-brand redefined
  /// "Top 100" as a hashtag leaderboard (see [fetchTrendingHashtags])
  /// instead of a content leaderboard -- kept (not deleted): a real,
  /// working, previously-shipped ranking capability, not dead code to
  /// clean up on a styling pass.
  Future<List<HomeFeedItem>> fetchTopContent({
    int limit = HomeRepository.topContentResultLimit,
  }) {
    return _homeRepository.fetchTopContent(limit: limit);
  }

  /// "Top 100" (both Discovery's preview and Top100Screen's full list) --
  /// reuses fetchTrending's own 48h/100-candidate window purely as a
  /// source of recent captions (passing
  /// [HomeRepository.trendingCandidateLimit] as the result limit
  /// returns every candidate in the window, not just the usual top
  /// 10/30), then ranks by tag frequency via [rankTrendingHashtags].
  Future<List<RankedHashtag>> fetchTrendingHashtags({
    int limit = trendingHashtagsLimit,
  }) async {
    final items = await _homeRepository.fetchTrending(
      limit: HomeRepository.trendingCandidateLimit,
    );
    return rankTrendingHashtags(
      items.map((item) => item.caption),
      limit: limit,
    );
  }

  /// "กำลังเติบโต" section -- calls the `rising_profiles()` RPC
  /// (SECURITY DEFINER, see supabase/schema.sql) for an already-ranked,
  /// already-filtered (self/followed/blocked/`p_min_followers`
  /// excluded) id list, then re-hydrates full Profile rows for it.
  Future<List<Profile>> fetchRisingProfiles({int limit = risingLimit}) async {
    final ids = await _fetchRankedProfileIds('rising_profiles', limit: limit);
    return _profileRepository.fetchProfilesByIds(ids);
  }

  /// "แนะนำให้ติดตาม" section -- same shape as [fetchRisingProfiles],
  /// backed by the `suggested_users()` RPC instead (self/followed/
  /// blocked/muted excluded, ranked by total follower count).
  Future<List<Profile>> fetchSuggestedUsers({
    int limit = suggestedUsersLimit,
  }) async {
    final ids = await _fetchRankedProfileIds('suggested_users', limit: limit);
    return _profileRepository.fetchProfilesByIds(ids);
  }

  /// WYN-071: Profile's Recommendation Section (Design doc Screen 5) --
  /// permanently hides [profileId] from this user's `suggested_users()`
  /// results everywhere it's shown (here and Discovery), not just for
  /// the current screen/session. A plain insert is enough: RLS on
  /// `profile_recommendation_dismissals` already restricts this to the
  /// caller's own rows (see schema.sql), so there's no need for a
  /// wrapper RPC the way write paths that need extra validation have.
  Future<void> dismissSuggestedUser(String profileId) {
    return _client.from('profile_recommendation_dismissals').insert({
      'user_id': _client.auth.currentUser!.id,
      'dismissed_profile_id': profileId,
    });
  }

  /// Both ranking RPCs return the identical shape -- a single
  /// `profile_id` column, already ordered/limited server-side -- so
  /// this one helper covers both rather than duplicating the RPC-call/
  /// row-mapping boilerplate twice.
  Future<List<String>> _fetchRankedProfileIds(
    String rpcName, {
    required int limit,
  }) async {
    final rows =
        await _client.rpc(rpcName, params: {'p_limit': limit}) as List<dynamic>;
    return rows.map((row) => row['profile_id'] as String).toList();
  }
}
