import 'package:flutter/material.dart';

import '../../../club/data/club.dart';
import '../../../club/data/club_post_repository.dart';
import '../../../club/data/club_repository.dart';
import '../../../club/presentation/club_page.dart';
import '../../../club/presentation/widgets/club_discovery_card.dart';
import 'search_state_message.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Search's Club tab (WYN-015) -- vertical list of ClubDiscoveryCard,
/// same widget Explore Clubs uses. Query is driven by [query], a prop
/// from the shared search box in SearchScreen, same debounce/reset
/// pattern as SearchDropResultsTab/SearchPopResultsTab (WYN-009).
class SearchClubResultsTab extends StatefulWidget {
  const SearchClubResultsTab({
    super.key,
    required this.query,
    required this.clubRepository,
    required this.clubPostRepository,
  });

  final String query;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  @override
  State<SearchClubResultsTab> createState() => _SearchClubResultsTabState();
}

class _SearchClubResultsTabState extends State<SearchClubResultsTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<Club> _clubs = [];
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  bool get _queryTooShort => widget.query.trim().length < 2;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (!_queryTooShort) _search(reset: true);
  }

  @override
  void didUpdateWidget(covariant SearchClubResultsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _clubs.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      if (!_queryTooShort) _search(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || !_hasMore || _queryTooShort) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _search(reset: false);
    }
  }

  Future<void> _search({required bool reset}) async {
    setState(() {
      _isLoading = true;
      if (reset) _error = null;
    });
    try {
      final page = reset ? 0 : _page + 1;
      final results = await widget.clubRepository.searchClubs(
        query: widget.query.trim(),
        page: page,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _clubs
            ..clear()
            ..addAll(results);
        } else {
          _clubs.addAll(results);
        }
        _page = page;
        _hasMore = results.length == ClubRepository.searchPageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'ค้นหาไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_queryTooShort) {
      return const SearchStateMessage(
        icon: Icons.groups_outlined,
        text: 'พิมพ์ชื่อ Club เพื่อค้นหา',
      );
    }

    if (_isLoading && _clubs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(
              onPressed: () => _search(reset: true),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_clubs.isEmpty) {
      return SearchStateMessage(
        icon: Icons.groups_outlined,
        text: 'ไม่พบ Club สำหรับ "${widget.query.trim()}"',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _clubs.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _clubs.length) {
          return const Padding(
            padding: EdgeInsets.all(WynSpacing.space4),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final club = _clubs[index];
        return ClubDiscoveryCard(club: club, onTap: () => _openClub(club));
      },
    );
  }
}
