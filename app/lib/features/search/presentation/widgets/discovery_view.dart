import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../club/data/club_post_repository.dart';
import '../../../club/data/club_repository.dart';
import '../../../drop/data/drop_repository.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../follow/data/follow_request_repository.dart';
import '../../../follow/presentation/widgets/follow_action_button.dart';
import '../../../hashtag/presentation/hashtag_feed_screen.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../profile/data/profile.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/view_profile_screen.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../../saved/data/saved_repository.dart';
import '../../data/discovery_ranking.dart';
import '../../data/discovery_repository.dart';
import '../top_100_screen.dart';
import 'hashtag_rank_row.dart';

/// Screen 1 — Discovery (WYN-040), restyled to `03-search.tsx`'s 2-section
/// layout (2026-08-29, Founder-approved re-brand -- see
/// .wyn/company/DECISIONS.md): the default state of `SearchScreen`
/// (WYN-009) shown while the query is empty/shorter than 2 characters.
///
/// The original 5 sections (Trending Now grid, Trending Hashtags chip
/// cloud, Rising accounts, Suggested Users, Suggested Clubs) are down to
/// 2 -- "Top 100 IS the trending surface now" per the reference's own
/// doc comment, replacing 3 sections at once, and "แนะนำให้ติดตาม" is the
/// only section left besides it (no "Club แนะนำ" here). Trending Now/
/// Rising/Suggested Clubs aren't deleted anywhere in the data layer --
/// see DiscoveryRepository.fetchTrendingNow/fetchTopContent's own doc
/// comments, and ClubSection (Home)/ExploreClubsScreen both still call
/// ClubRepository.fetchPopularClubs directly, same as before.
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
  late Future<List<RankedHashtag>> _top100Future;
  late Future<List<Profile>> _suggestedUsersFuture;

  @override
  void initState() {
    super.initState();
    _top100Future = widget.discoveryRepository.fetchTrendingHashtags(
      limit: DiscoveryRepository.top100PreviewLimit,
    );
    _suggestedUsersFuture = widget.discoveryRepository.fetchSuggestedUsers();
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

  void _openTop100() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Top100Screen(
          discoveryRepository: widget.discoveryRepository,
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: WynSpacing.space8),
      children: [
        const SizedBox(height: WynSpacing.space1),
        const _SectionLabel('แฮชแท็กกำลังนิยม'),
        _buildTop100Section(),
        const _SectionLabel('แนะนำให้ติดตาม'),
        _buildSuggestedUsersSection(),
      ],
    );
  }

  // ------------------------------------------------------------
  // Top 100 (WYN-042, redefined 2026-08-29 as a hashtag leaderboard --
  // see discovery_repository.dart's fetchTrendingHashtags doc comment)
  // -- 03-search.tsx's RankRow: right-aligned title-style rank numeral,
  // bold tag, "N โพสต์" meta, hairline divider between rows (none after
  // the last), then a centered "ดูอันดับทั้งหมด (Top 100)" link.
  // ------------------------------------------------------------
  Widget _buildTop100Section() {
    return FutureBuilder<List<RankedHashtag>>(
      future: _top100Future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final ranked = snapshot.data!;
        if (ranked.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(
                horizontal: WynSpacing.space4, vertical: WynSpacing.space4),
            child: Text('ยังไม่มีแฮชแท็กกำลังนิยมตอนนี้'),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < ranked.length; i++)
              HashtagRankRow(
                rank: i + 1,
                item: ranked[i],
                showDivider: i < ranked.length - 1,
                onTap: () => _openHashtagFeed(ranked[i].tag),
              ),
            InkWell(
              onTap: _openTop100,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: WynSpacing.space4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ดูอันดับทั้งหมด (Top 100)',
                      style: _textStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: WynColors.sapphire),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 14, color: WynColors.sapphire),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // Suggested Users -- unchanged real data/logic (FollowListScreen's own
  // row shape, FollowActionButton's real 3-state follow logic), restyled
  // to 03-search.tsx's avatar-ring + name/handle + outline button row.
  // ------------------------------------------------------------
  Widget _buildSuggestedUsersSection() {
    return FutureBuilder<List<Profile>>(
      future: _suggestedUsersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final profiles = snapshot.data!;
        if (profiles.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(
                horizontal: WynSpacing.space4, vertical: WynSpacing.space4),
            child: Text('ยังไม่มีบัญชีแนะนำให้ติดตามตอนนี้'),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
          child: Column(
            children: [
              for (final profile in profiles) _buildSuggestedUserRow(profile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestedUserRow(Profile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
      child: Semantics(
        label:
            'ผู้ใช้ ${profile.nameOrUsername} ยูสเซอร์เนม ${profile.username} กดเพื่อดูโปรไฟล์',
        button: true,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => _openProfile(profile.id),
          child: Row(
            children: [
              AvatarCircle(
                imageUrl: profile.avatarUrl,
                fallbackText: profile.username,
                radius: 19,
                ring: true,
              ),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.nameOrUsername,
                      style:
                          _textStyle(fontSize: 14, fontWeight: FontWeight.w600, color: WynColors.ink),
                    ),
                    Text(
                      '@${profile.username}',
                      style: _textStyle(fontSize: 12, color: WynColors.faint),
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
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(WynSpacing.space4,
          WynSpacing.space2, WynSpacing.space4, WynSpacing.space3),
      child: Text(
        label,
        style: _textStyle(fontSize: 11, fontWeight: FontWeight.w600, color: WynColors.mutedNeutral)
            .copyWith(letterSpacing: 11 * 0.14),
      ),
    );
  }
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) =>
    TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
