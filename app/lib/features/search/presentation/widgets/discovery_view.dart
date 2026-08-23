import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../club/data/club.dart';
import '../../../club/data/club_post_repository.dart';
import '../../../club/data/club_repository.dart';
import '../../../club/presentation/club_page.dart';
import '../../../club/presentation/widgets/club_mini_card.dart';
import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../follow/data/follow_request_repository.dart';
import '../../../follow/presentation/widgets/follow_action_button.dart';
import '../../../hashtag/presentation/hashtag_feed_screen.dart';
import '../../../home/data/home_feed_item.dart';
import '../../../home/presentation/pop_single_clip_screen.dart';
import '../../../home/presentation/widgets/trending_tile.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../profile/data/profile.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/view_profile_screen.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../../saved/data/saved_repository.dart';
import '../../data/discovery_repository.dart';

/// Screen 1 — Discovery (WYN-040): the default state of `SearchScreen`
/// (WYN-009) shown while the query is empty/shorter than 2 characters.
/// 5 independent sections (Trending Now / Trending Hashtags / Rising /
/// Suggested Users / Suggested Clubs), each an independent `FutureBuilder`
/// that fails-safe to `SizedBox.shrink()` on error or while loading --
/// mirrors `ClubSection`'s existing fail-safe pattern (WYN-017) exactly,
/// so one slow/failing section never blocks the rest of the page. See
/// .wyn/docs/design/wyn-040-discovery-page.md.
class DiscoveryView extends StatefulWidget {
  const DiscoveryView({
    super.key,
    required this.discoveryRepository,
    required this.clubRepository,
    required this.clubPostRepository,
    required this.profileRepository,
    required this.followRepository,
    required this.followRequestRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.savedRepository,
  });

  final DiscoveryRepository discoveryRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;
  final ProfileRepository profileRepository;
  final FollowRepository followRepository;
  final FollowRequestRepository followRequestRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;

  @override
  State<DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<DiscoveryView> {
  late Future<List<HomeFeedItem>> _trendingNowFuture;
  late Future<List<String>> _trendingHashtagsFuture;
  late Future<List<Profile>> _risingFuture;
  late Future<List<Profile>> _suggestedUsersFuture;
  late Future<List<Club>> _suggestedClubsFuture;

  @override
  void initState() {
    super.initState();
    // Every section fetches independently, all at once on open -- Design
    // doc's Interactions: "ทุก section ยิง fetch พร้อมกันตอนเปิด
    // DiscoveryView (ไม่ lazy-load ตาม scroll ในรอบนี้)".
    _trendingNowFuture = widget.discoveryRepository.fetchTrendingNow();
    _trendingHashtagsFuture =
        widget.discoveryRepository.fetchTrendingHashtags();
    _risingFuture = widget.discoveryRepository.fetchRisingProfiles();
    _suggestedUsersFuture = widget.discoveryRepository.fetchSuggestedUsers();
    _suggestedClubsFuture = widget.clubRepository.fetchPopularClubs();
  }

  Future<void> _openDrop(HomeFeedItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: widget.dropRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          drop: item.toDrop(),
        ),
      ),
    );
  }

  Future<void> _openPop(HomeFeedItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PopSingleClipScreen(
          pop: item.toPop(),
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          dropRepository: widget.dropRepository,
          savedRepository: widget.savedRepository,
        ),
      ),
    );
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: userId,
        ),
      ),
    );
  }

  void _openHashtagFeed(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HashtagFeedScreen(
          tag: tag,
          dropRepository: widget.dropRepository,
          clubPostRepository: widget.clubPostRepository,
          clubRepository: widget.clubRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
        ),
      ),
    );
  }

  void _openClub(Club club) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPage(
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
          clubId: club.id,
        ),
      ),
    );
  }

  Color _growthIndicatorColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? WynColors.successDark
          : WynColors.successLight;

  Widget _sectionHeader(BuildContext context, String title) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            WynSpacing.space3, WynSpacing.space4, WynSpacing.space3, 0),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: WynSpacing.space8),
      children: [
        _sectionHeader(context, 'กำลังนิยม'),
        _buildTrendingNowSection(context),
        _sectionHeader(context, 'แฮชแท็กกำลังนิยม'),
        _buildTrendingHashtagsSection(context),
        _sectionHeader(context, 'กำลังเติบโต'),
        _buildRisingSection(context),
        _sectionHeader(context, 'แนะนำให้ติดตาม'),
        _buildSuggestedUsersSection(context),
        _sectionHeader(context, 'Club แนะนำ'),
        _buildSuggestedClubsSection(context),
      ],
    );
  }

  // ------------------------------------------------------------
  // 1. Trending Now -- 3-column grid of TrendingTile (WYN-017, reused
  // unmodified).
  // ------------------------------------------------------------
  Widget _buildTrendingNowSection(BuildContext context) {
    return FutureBuilder<List<HomeFeedItem>>(
      future: _trendingNowFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(
                horizontal: WynSpacing.space3, vertical: WynSpacing.space4),
            child: Text('ยังไม่มี content กำลังนิยมตอนนี้'),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return TrendingTile(
                item: item,
                onTap: () => item.contentType == HomeContentType.drop
                    ? _openDrop(item)
                    : _openPop(item),
              );
            },
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // 2. Trending Hashtags -- neutral chips, cyan `#tag` text.
  // ------------------------------------------------------------
  Widget _buildTrendingHashtagsSection(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _trendingHashtagsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final tags = snapshot.data!;
        if (tags.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(
                horizontal: WynSpacing.space3, vertical: WynSpacing.space4),
            child: Text('ยังไม่มีแฮชแท็กกำลังนิยมตอนนี้'),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
          child: Wrap(
            spacing: WynSpacing.space2,
            runSpacing: WynSpacing.space2,
            children: [
              for (final tag in tags)
                Semantics(
                  label: 'แฮชแท็ก #$tag กดเพื่อดูโพสต์ที่มีแฮชแท็กนี้',
                  button: true,
                  excludeSemantics: true,
                  child: ActionChip(
                    // DS-001 #6 -- neutral chip surface, never Cyan (20
                    // chips of solid Cyan side by side would blow past
                    // the "no large continuous background" ≤15% rule).
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHigh,
                    label: Text(
                      '#$tag',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _openHashtagFeed(tag),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // 3. Rising -- horizontal row of small vertical cards.
  // ------------------------------------------------------------
  Widget _buildRisingSection(BuildContext context) {
    return FutureBuilder<List<Profile>>(
      future: _risingFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final profiles = snapshot.data!;
        if (profiles.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(
                horizontal: WynSpacing.space3, vertical: WynSpacing.space4),
            child: Text('ยังไม่มีบัญชีที่กำลังเติบโตตอนนี้'),
          );
        }

        return SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
            itemCount: profiles.length,
            itemBuilder: (context, index) =>
                _buildRisingCard(context, profiles[index]),
          ),
        );
      },
    );
  }

  Widget _buildRisingCard(BuildContext context, Profile profile) {
    return SizedBox(
      width: 120,
      child: Semantics(
        label: '${profile.nameOrUsername} ยูสเซอร์เนม ${profile.username} '
            'บัญชีนี้กำลังเติบโต กดเพื่อดูโปรไฟล์',
        button: true,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => _openProfile(profile.id),
          borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(WynSpacing.space2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarCircle(
                  imageUrl: profile.avatarUrl,
                  fallbackText: profile.username,
                  radius: 28,
                ),
                const SizedBox(height: WynSpacing.space1),
                Text(
                  profile.nameOrUsername,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 16,
                      color: _growthIndicatorColor(context),
                    ),
                    const SizedBox(width: WynSpacing.space1),
                    Flexible(
                      child: Text(
                        '@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: WynSpacing.space1),
                FollowActionButton(
                  profile: profile,
                  followRepository: widget.followRepository,
                  followRequestRepository: widget.followRequestRepository,
                  compact: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // 4. Suggested Users -- FollowListScreen's own row layout (WYN-008/
  // 013), plus a trailing Follow button (Design doc's one addition).
  // ------------------------------------------------------------
  Widget _buildSuggestedUsersSection(BuildContext context) {
    return FutureBuilder<List<Profile>>(
      future: _suggestedUsersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final profiles = snapshot.data!;
        if (profiles.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(
                horizontal: WynSpacing.space3, vertical: WynSpacing.space4),
            child: Text('ยังไม่มีบัญชีแนะนำให้ติดตามตอนนี้'),
          );
        }

        return Column(
          children: [
            for (final profile in profiles)
              _buildSuggestedUserRow(context, profile),
          ],
        );
      },
    );
  }

  Widget _buildSuggestedUserRow(BuildContext context, Profile profile) {
    return Semantics(
      label:
          'ผู้ใช้ ${profile.nameOrUsername} ยูสเซอร์เนม ${profile.username} กดเพื่อดูโปรไฟล์',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _openProfile(profile.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
          child: Row(
            children: [
              AvatarCircle(
                imageUrl: profile.avatarUrl,
                fallbackText: profile.username,
                radius: 20,
              ),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.nameOrUsername,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '@${profile.username}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WynSpacing.space2),
              FollowActionButton(
                profile: profile,
                followRepository: widget.followRepository,
                followRequestRepository: widget.followRequestRepository,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // 5. Suggested Clubs -- ClubMiniCard (WYN-017, reused unmodified).
  // ------------------------------------------------------------
  Widget _buildSuggestedClubsSection(BuildContext context) {
    return FutureBuilder<List<Club>>(
      future: _suggestedClubsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final clubs = snapshot.data!;
        if (clubs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(
                horizontal: WynSpacing.space3, vertical: WynSpacing.space4),
            child: Text('ยังไม่มี Club แนะนำตอนนี้'),
          );
        }

        return SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              return ClubMiniCard(club: club, onTap: () => _openClub(club));
            },
          ),
        );
      },
    );
  }
}
