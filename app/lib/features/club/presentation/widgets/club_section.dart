import 'package:flutter/material.dart';

import '../../data/club.dart';
import '../../data/club_post_repository.dart';
import '../../data/club_repository.dart';
import '../club_page.dart';
import '../create_club_screen.dart';
import '../explore_clubs_screen.dart';
import '../my_clubs_screen.dart';
import 'club_mini_card.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Screen 1 — the CLUB section on Home: a block between the top row
/// (search bar + notification bell, WYN-012) and the main Feed, showing
/// shortcut buttons, a horizontal row of the current user's joined
/// Clubs, and (WYN-017) a "Club แนะนำ" row when the user has joined
/// fewer than 3 Clubs. See .wyn/docs/design/wyn-014-club-core.md, Screen
/// 1, and .wyn/docs/design/wyn-017-home-trending-recommended-clubs.md.
class ClubSection extends StatefulWidget {
  const ClubSection({
    super.key,
    required this.clubRepository,
    required this.clubPostRepository,
  });

  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  @override
  State<ClubSection> createState() => _ClubSectionState();
}

class _ClubSectionState extends State<ClubSection> {
  // Below this many joined Clubs, "Club แนะนำ" shows to help the user
  // discover new communities -- see the Design spec's reasoning for why
  // this isn't always-on.
  static const _recommendedThreshold = 3;

  late Future<List<Club>> _loadFuture;
  late Future<List<Club>> _recommendedFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.clubRepository.fetchMyClubs();
    _recommendedFuture = widget.clubRepository.fetchPopularClubs();
  }

  void _reload() => setState(() {
        _loadFuture = widget.clubRepository.fetchMyClubs();
        _recommendedFuture = widget.clubRepository.fetchPopularClubs();
      });

  Future<void> _openCreateClub() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateClubScreen(
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
        ),
      ),
    );
    _reload();
  }

  Future<void> _openExploreClubs() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExploreClubsScreen(
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
        ),
      ),
    );
    _reload();
  }

  Future<void> _openMyClubs() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyClubsScreen(
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
        ),
      ),
    );
    _reload();
  }

  Future<void> _openClub(Club club) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPage(
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
          clubId: club.id,
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed-height rows instead of a ConstrainedBox+Expanded ceiling --
    // the recommended row's visibility is conditional (depends on the my-
    // Clubs count once it loads), and Expanded inside a height-capped box
    // fights a variable-content child in exactly the way that already
    // caused the WYN-015 ViewProfileScreen overflow bug. A
    // Column(mainAxisSize: min) of fixed-height children needs no
    // ambient constraint, so it can't repeat that failure mode. See the
    // Design spec.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: [
              Text(
                'CLUB',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              TextButton(onPressed: _openMyClubs, child: const Text('ดูทั้งหมด')),
            ],
          ),
        ),
        SizedBox(
          height: WynSpacing.touchTargetMin,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
            children: [
              OutlinedButton.icon(
                onPressed: _openCreateClub,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('สร้าง Club'),
              ),
              const SizedBox(width: WynSpacing.space2),
              OutlinedButton.icon(
                onPressed: _openExploreClubs,
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: const Text('สำรวจ Club'),
              ),
            ],
          ),
        ),
        SizedBox(height: 108, child: _buildClubRow()),
        FutureBuilder<List<Club>>(
          future: _loadFuture,
          builder: (context, snapshot) {
            final myClubCount = snapshot.data?.length ?? 0;
            if (!snapshot.hasData || myClubCount >= _recommendedThreshold) {
              return const SizedBox.shrink();
            }
            return _buildRecommendedSection();
          },
        ),
      ],
    );
  }

  Widget _buildClubRow() {
    return FutureBuilder<List<Club>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final clubs = snapshot.data!;
        if (clubs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: WynSpacing.space3),
            child: Center(
              child: Text(
                'ยังไม่ได้เข้าร่วม Club ไหนเลย ลองสร้างหรือค้นหาดูสิ',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
          itemCount: clubs.length,
          itemBuilder: (context, index) {
            final club = clubs[index];
            return ClubMiniCard(club: club, onTap: () => _openClub(club));
          },
        );
      },
    );
  }

  Widget _buildRecommendedSection() {
    return SizedBox(
      height: 108,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              'Club แนะนำ',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Club>>(
              future: _recommendedFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final clubs = snapshot.data!;
                if (clubs.isEmpty) return const SizedBox.shrink();

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
                  itemCount: clubs.length,
                  itemBuilder: (context, index) {
                    final club = clubs[index];
                    return ClubMiniCard(club: club, onTap: () => _openClub(club));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
