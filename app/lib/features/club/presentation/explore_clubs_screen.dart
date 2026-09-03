import 'package:flutter/material.dart';

import '../data/club.dart';
import '../data/club_post_repository.dart';
import '../data/club_repository.dart';
import 'club_page.dart';
import 'create_club_screen.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';

typedef _Sections = ({
  List<Club> popular,
  List<Club> newest,
  Set<String> pendingClubIds,
});

/// Screen 1 — Explore Clubs, restyled to 09-club-explore.tsx.
///
/// Founder decisions (2026-08-29):
/// - Category chips/filter removed from this screen (the reference's
///   own stated reason -- "no category concept exists anywhere else in
///   the app" -- doesn't actually hold here, since Create Club/Club
///   Page both still keep a real `Club.category` field, but the
///   Founder chose to follow the reference's simplification on this
///   one screen anyway and keep category as a Club attribute only,
///   never a discovery filter).
/// - "Club แนะนำสำหรับคุณ" (personalized carousel) and the ranked
///   "กำลังนิยม" row are gone -- both "กำลังนิยม" and "ใหม่ล่าสุด" are now
///   plain avatar+name+member-count+join-button rows (same shape as a
///   suggested-account row on Search), not a 2-column image grid.
///   ClubRecommendedCard/ClubRankedRow (and the ClubJoinButton variant
///   they built on) are unreferenced after this -- kept in the
///   codebase, not deleted, same "orphan rather than delete a shared
///   widget on a restyle pass" posture as every prior page.
/// See .wyn/docs/design/wyn-015-club-discovery-integration.md, Screen 1.
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

class _ExploreClubsScreenState extends State<ExploreClubsScreen> {
  static const _limit = 10;

  String _searchQuery = '';
  late Future<_Sections> _loadFuture;

  // Only one Join action can be in flight at a time (mirrors ClubPage's
  // single _isJoinActionInFlight flag) -- tracked by club id so the
  // right row shows its own spinner, not every row at once.
  String? _joinInFlightClubId;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<_Sections> _load() async {
    final popular = await widget.clubRepository.fetchPopularClubs(limit: _limit);
    final newest = await widget.clubRepository.fetchNewClubs(limit: _limit);
    final pendingClubIds = await widget.clubRepository.fetchPendingClubIds();
    return (popular: popular, newest: newest, pendingClubIds: pendingClubIds);
  }

  void _reload() {
    setState(() {
      _loadFuture = _load();
    });
  }

  // WYN-081 (Wynos V1.0.0 Beta2, item 16): RefreshIndicator needs an
  // awaitable Future to know when to stop spinning -- _reload() itself
  // is fire-and-forget (just triggers a setState), so this wraps it.
  Future<void> _onRefresh() async {
    final future = _load();
    setState(() {
      _loadFuture = future;
    });
    // Swallowed here only so RefreshIndicator itself doesn't propagate
    // it as an unhandled async error -- FutureBuilder below still reads
    // this same future.
    try {
      await future;
    } catch (_) {}
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

  bool _matchesSearch(Club club) {
    if (_searchQuery.isEmpty) return true;
    return club.name.toLowerCase().contains(_searchQuery.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        centerTitle: true,
        leading: IconButton(
          key: const Key('explore_clubs_back_button'),
          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'สำรวจ Club',
          style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: FutureBuilder<_Sections>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sections = snapshot.data!;
          final popular = sections.popular.where(_matchesSearch).toList();
          final newest = sections.newest.where(_matchesSearch).toList();

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: WynSpacing.space8),
              children: [
                _buildHero(),
                _buildSearchBar(),
                _buildListSection(
                  'กำลังนิยม',
                  popular,
                  sections.pendingClubIds,
                  emptyText: 'ยังไม่มี Club กำลังนิยมตอนนี้',
                ),
                _buildListSection(
                  'ใหม่ล่าสุด',
                  newest,
                  sections.pendingClubIds,
                  emptyText: 'ยังไม่มี Club ใหม่ตอนนี้',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space6, WynSpacing.space6, WynSpacing.space6, 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: WynTypography.screenTitle(fontSize: 20, color: WynColors.ink),
              children: const [
                TextSpan(text: 'เจอคอมมูนิตี้ที่ใช่'),
                TextSpan(text: 'สำหรับคุณ', style: TextStyle(color: WynColors.sapphire)),
              ],
            ),
          ),
          const SizedBox(height: WynSpacing.space2),
          Text(
            'ร่วมคอมมูนิตี้ที่คุณสนใจ เชื่อมต่อกับคนที่คิดเหมือนกัน',
            style: _textStyle(fontSize: 13, color: WynColors.graphite, height: 1.4),
          ),
          const SizedBox(height: WynSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
                backgroundColor: WynColors.sapphire,
                foregroundColor: WynColors.paper,
                textStyle: _textStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              onPressed: _openCreateClub,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('สร้าง Club'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space6, WynSpacing.space5, WynSpacing.space6, 0,
      ),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
        decoration: BoxDecoration(
          // Same one-off search-pill fill 03-search.tsx's own search bar
          // established (search_screen.dart) -- not one of SPEC.md's 7
          // named tokens, reused here rather than a new literal.
          color: const Color(0xFFF1EFE9),
          borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
          border: Border.all(color: WynColors.hairline),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 15, color: WynColors.mutedNeutral),
            const SizedBox(width: WynSpacing.space2),
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value.trim()),
                style: _textStyle(fontSize: 16, color: WynColors.ink),
                decoration: InputDecoration(
                  hintText: 'ค้นหา Club',
                  hintStyle: _textStyle(fontSize: 16, color: WynColors.mutedNeutral),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListSection(
    String label,
    List<Club> clubs,
    Set<String> pendingClubIds, {
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WynSpacing.space6, WynSpacing.space6, WynSpacing.space6, WynSpacing.space2,
          ),
          child: Text(
            label,
            style: _textStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WynColors.mutedNeutral,
              letterSpacing: 13 * 0.14,
            ),
          ),
        ),
        if (clubs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WynSpacing.space6, 0, WynSpacing.space6, WynSpacing.space2,
            ),
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'ไม่พบ Club ที่ตรงกับ "$_searchQuery"'
                  : emptyText,
              style: _textStyle(fontSize: 13, color: WynColors.faint),
            ),
          )
        else
          for (final club in clubs)
            _buildClubRow(club, isPending: pendingClubIds.contains(club.id)),
      ],
    );
  }

  Widget _buildClubRow(Club club, {required bool isPending}) {
    return InkWell(
      onTap: () => _openClub(club),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space6, vertical: WynSpacing.space2,
        ),
        child: Row(
          children: [
            AvatarCircle(
              imageUrl: club.identityImageUrl,
              fallbackText: club.name,
              radius: 22,
              ring: true,
            ),
            const SizedBox(width: WynSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    style: _textStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WynColors.ink),
                  ),
                  Text(
                    '${club.memberCount} สมาชิก',
                    style: _textStyle(fontSize: 13, color: WynColors.mutedNeutral),
                  ),
                ],
              ),
            ),
            const SizedBox(width: WynSpacing.space2),
            _buildJoinChip(club, isPending: isPending),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinChip(Club club, {required bool isPending}) {
    final isInFlight = _joinInFlightClubId == club.id;

    if (isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: 6),
        decoration: BoxDecoration(
          color: WynColors.hairline,
          borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
        ),
        child: Text(
          'รออนุมัติ',
          style: _textStyle(fontSize: 13, fontWeight: FontWeight.w600, color: WynColors.graphite),
        ),
      );
    }

    return OutlinedButton(
      onPressed: isInFlight ? null : () => _join(club),
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: 2),
        foregroundColor: WynColors.sapphire,
        side: const BorderSide(color: WynColors.sapphire),
        textStyle: _textStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: isInFlight
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('เข้าร่วม'),
    );
  }
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? height,
  double? letterSpacing,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
