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

/// Screen 1 — the CLUB section on Home: a height-capped (~180px) block
/// between the top row (search bar + notification bell, WYN-012) and the
/// main Feed, showing shortcut buttons plus a horizontal row of the
/// current user's joined Clubs. Discovery ("Club ที่กำลังนิยม") is
/// WYN-015 -- this round only shows "Club ของฉัน". See
/// .wyn/docs/design/wyn-014-club-core.md, Screen 1.
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
  late Future<List<Club>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.clubRepository.fetchMyClubs();
  }

  void _reload() => setState(() => _loadFuture = widget.clubRepository.fetchMyClubs());

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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: Column(
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
          Expanded(child: _buildClubRow()),
        ],
      ),
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
}
