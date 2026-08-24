import 'package:flutter/material.dart';

import '../data/club.dart';
import '../data/club_member.dart';
import '../data/club_post_repository.dart';
import '../data/club_repository.dart';
import 'club_page.dart';
import 'create_club_screen.dart';
import 'widgets/club_discovery_card.dart';
import 'widgets/club_ranked_row.dart';
import 'widgets/club_recommended_card.dart';
import '../../../core/design/wyn_spacing.dart';

/// Screen 1 — Explore Clubs (replaces WYN-014's placeholder, redesigned
/// in WYN-056). Clubs the current user hasn't joined: a hero block, a
/// personalized "Club แนะนำสำหรับคุณ" row, a ranked "กำลังนิยม" row,
/// then the original search+Category filter+2-section browse list --
/// now rendered as a 2-column image grid instead of full-width rows. See
/// .wyn/docs/design/wyn-015-club-discovery-integration.md, Screen 1, and
/// .wyn/docs/design/wyn-056-club-discovery-visual-refresh.md, Screen 1.
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

typedef _Sections = ({
  List<Club> recommended,
  List<Club> popular,
  List<Club> newest,
  Set<String> pendingClubIds,
});

class _ExploreClubsScreenState extends State<ExploreClubsScreen> {
  static const _recommendedLimit = 8;
  static const _rankedLimit = 5;

  String? _category;
  String _searchQuery = '';
  late Future<_Sections> _loadFuture;

  // Only one Join action can be in flight at a time (mirrors ClubPage's
  // single _isJoinActionInFlight flag) -- tracked by club id so the
  // right card shows its own spinner, not every card at once.
  String? _joinInFlightClubId;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<_Sections> _load() async {
    // The recommended row is personalized and intentionally ignores the
    // Category filter (same as Home's "Club แนะนำ" row, WYN-017) --
    // fetched without a category so it doesn't shrink/empty out just
    // because the user picked a chip.
    final recommended = await widget.clubRepository.fetchPopularClubs(limit: _recommendedLimit);
    final popular = await widget.clubRepository.fetchPopularClubs(category: _category);
    final newest = await widget.clubRepository.fetchNewClubs(category: _category);
    final pendingClubIds = await widget.clubRepository.fetchPendingClubIds();
    return (
      recommended: recommended,
      popular: popular,
      newest: newest,
      pendingClubIds: pendingClubIds,
    );
  }

  void _reload() {
    setState(() => _loadFuture = _load());
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

  Future<void> _join(Club club) async {
    if (_joinInFlightClubId != null) return;
    setState(() => _joinInFlightClubId = club.id);
    try {
      await widget.clubRepository.joinClub(club);
      // A public join makes the club "approved" (excluded from
      // discovery from now on); a private join makes it "pending"
      // (stays visible, button becomes "รออนุมัติ") -- either way, a
      // full reload re-derives the correct set from the server rather
      // than guessing which case just happened.
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เข้าร่วม Club ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _joinInFlightClubId = null);
    }
  }

  Future<void> _reportClub(Club club) async {
    // Report entry point kept minimal here (no dedicated flow wired to
    // this card yet) -- open the Club itself, where the full report
    // sheet (ClubPage's More menu, WYN-014) is already available. Avoids
    // duplicating ReportRepository wiring into a discovery card whose
    // main job is browsing, not moderation.
    _openClub(club);
  }

  bool _matchesSearch(Club club) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return club.name.toLowerCase().contains(query) ||
        (club.category?.toLowerCase().contains(query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สำรวจ Club')),
      body: FutureBuilder<_Sections>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sections = snapshot.data!;
          final popular = sections.popular.where(_matchesSearch).toList();
          final newest = sections.newest.where(_matchesSearch).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: WynSpacing.space8),
            children: [
              _buildHero(context),
              _buildCreateCta(context),
              const SizedBox(height: WynSpacing.space4),
              _buildRecommendedRow(sections.recommended, sections.pendingClubIds),
              _buildRankedRow(sections.popular.take(_rankedLimit).toList(), sections.pendingClubIds),
              const SizedBox(height: WynSpacing.space2),
              _buildSearchBar(),
              _buildCategoryChips(),
              _buildGridSection('กำลังนิยม', popular),
              _buildGridSection('ใหม่ล่าสุด', newest),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space4,
        WynSpacing.space4,
        WynSpacing.space4,
        WynSpacing.space2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLUB',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: WynSpacing.space1),
                Text.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    children: [
                      const TextSpan(text: 'เจอคอมมูนิตี้ที่ใช่สำหรับ'),
                      TextSpan(text: 'คุณ', style: TextStyle(color: scheme.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: WynSpacing.space1),
                Text(
                  'ร่วมคอมมูนิตี้ที่คุณสนใจ เชื่อมต่อกับคนที่คิดเหมือนกัน',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: WynSpacing.space3),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(Icons.groups_rounded, size: 28, color: scheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
      child: FilledButton.icon(
        onPressed: _openCreateClub,
        icon: const Icon(Icons.add),
        label: const Text('สร้าง Club'),
      ),
    );
  }

  Widget _buildRecommendedRow(List<Club> clubs, Set<String> pendingClubIds) {
    if (clubs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: WynSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(WynSpacing.space4, 0, WynSpacing.space4, WynSpacing.space2),
            child: Text(
              'Club แนะนำสำหรับคุณ',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
              itemCount: clubs.length,
              separatorBuilder: (_, __) => const SizedBox(width: WynSpacing.space3),
              itemBuilder: (context, index) {
                final club = clubs[index];
                return ClubRecommendedCard(
                  club: club,
                  status: pendingClubIds.contains(club.id) ? ClubMemberStatus.pending : null,
                  isJoinInFlight: _joinInFlightClubId == club.id,
                  onTap: () => _openClub(club),
                  onJoinTapped: () => _join(club),
                  onReport: () => _reportClub(club),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankedRow(List<Club> clubs, Set<String> pendingClubIds) {
    if (clubs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: WynSpacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(WynSpacing.space4, 0, WynSpacing.space4, WynSpacing.space2),
            child: Text(
              'กำลังนิยม',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
              itemCount: clubs.length,
              separatorBuilder: (_, __) => const SizedBox(width: WynSpacing.space2),
              itemBuilder: (context, index) {
                final club = clubs[index];
                return ClubRankedRow(
                  rank: index + 1,
                  club: club,
                  status: pendingClubIds.contains(club.id) ? ClubMemberStatus.pending : null,
                  isJoinInFlight: _joinInFlightClubId == club.id,
                  onTap: () => _openClub(club),
                  onJoinTapped: () => _join(club),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(WynSpacing.space4, WynSpacing.space2, WynSpacing.space4, 0),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
        decoration: InputDecoration(
          hintText: 'ค้นหา Club หรือหมวดหมู่',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
            borderSide: BorderSide.none,
          ),
        ),
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

  Widget _buildGridSection(String label, List<Club> clubs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (clubs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'ไม่พบ Club ที่ตรงกับ "$_searchQuery"'
                  : 'ยังไม่มี Club ในหมวดนี้',
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: WynSpacing.space3,
              crossAxisSpacing: WynSpacing.space3,
              childAspectRatio: 0.72,
            ),
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              return ClubDiscoveryCard(
                club: club,
                onTap: () => _openClub(club),
                layout: ClubDiscoveryCardLayout.grid,
              );
            },
          ),
      ],
    );
  }
}
