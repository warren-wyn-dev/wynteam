import 'package:flutter/material.dart';

import '../data/club.dart';
import '../data/club_post_repository.dart';
import '../data/club_repository.dart';
import 'club_page.dart';
import 'widgets/club_discovery_card.dart';
import '../../../core/design/wyn_spacing.dart';

/// Screen 1 — Explore Clubs (replaces WYN-014's placeholder). Clubs the
/// current user hasn't joined, split into "กำลังนิยม"/"ใหม่ล่าสุด" with a
/// Category filter. See
/// .wyn/docs/design/wyn-015-club-discovery-integration.md, Screen 1.
class ExploreClubsScreen extends StatefulWidget {
  const ExploreClubsScreen({
    super.key,
    required this.clubRepository,
    required this.clubPostRepository,
  });

  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  @override
  State<ExploreClubsScreen> createState() => _ExploreClubsScreenState();
}

typedef _Sections = ({List<Club> popular, List<Club> newest});

class _ExploreClubsScreenState extends State<ExploreClubsScreen> {
  String? _category;
  late Future<_Sections> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<_Sections> _load() async {
    final popular = await widget.clubRepository.fetchPopularClubs(category: _category);
    final newest = await widget.clubRepository.fetchNewClubs(category: _category);
    return (popular: popular, newest: newest);
  }

  void _selectCategory(String? category) {
    setState(() {
      _category = category;
      _loadFuture = _load();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สำรวจ Club')),
      body: Column(
        children: [
          _buildCategoryChips(),
          Expanded(
            child: FutureBuilder<_Sections>(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sections = snapshot.data!;
                return ListView(
                  children: [
                    _buildSection('กำลังนิยม', sections.popular),
                    _buildSection('ใหม่ล่าสุด', sections.newest),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: WynSpacing.space2),
            child: ChoiceChip(
              label: const Text('ทั้งหมด'),
              selected: _category == null,
              onSelected: (_) => _selectCategory(null),
            ),
          ),
          ...clubCategories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: WynSpacing.space2),
              child: ChoiceChip(
                label: Text(category),
                selected: _category == category,
                onSelected: (_) => _selectCategory(category),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String label, List<Club> clubs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (clubs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
            child: Text('ยังไม่มี Club ในหมวดนี้'),
          )
        else
          ...clubs.map(
            (club) => ClubDiscoveryCard(club: club, onTap: () => _openClub(club)),
          ),
      ],
    );
  }
}
