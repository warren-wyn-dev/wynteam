import 'package:flutter/material.dart';

import '../../../drop/data/drop.dart';
import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart';
import '../../../drop/presentation/widgets/drop_grid_tile.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../saved/data/saved_repository.dart';
import 'search_state_message.dart';

/// Search's Drop tab (WYN-009) -- same 3-column grid as ProfileDropGridTab
/// (WYN-013), reusing DropGridTile directly. Query is driven by [query], a
/// prop from the shared search box in SearchScreen, not typed here
/// directly -- resets and re-searches whenever it changes.
class SearchDropResultsTab extends StatefulWidget {
  const SearchDropResultsTab({
    super.key,
    required this.query,
    required this.dropRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
  });

  final String query;
  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;

  @override
  State<SearchDropResultsTab> createState() => _SearchDropResultsTabState();
}

class _SearchDropResultsTabState extends State<SearchDropResultsTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<Drop> _drops = [];
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
  void didUpdateWidget(covariant SearchDropResultsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _drops.clear();
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
      final results = await widget.dropRepository.searchByCaption(
        query: widget.query.trim(),
        page: page,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _drops
            ..clear()
            ..addAll(results);
        } else {
          _drops.addAll(results);
        }
        _page = page;
        _hasMore = results.length == DropRepository.pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'ค้นหาไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDropDetail(Drop drop) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: widget.dropRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          drop: drop,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_queryTooShort) {
      return const SearchStateMessage(
        icon: Icons.grid_view_outlined,
        text: 'พิมพ์คำในแคปชันเพื่อค้นหา Drop',
      );
    }

    if (_isLoading && _drops.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _search(reset: true),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_drops.isEmpty) {
      return SearchStateMessage(
        icon: Icons.grid_view_outlined,
        text: 'ไม่พบ Drop สำหรับ "${widget.query.trim()}"',
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final drop = _drops[index];
              return DropGridTile(
                drop: drop,
                onTap: () => _openDropDetail(drop),
              );
            },
            childCount: _drops.length,
          ),
        ),
        if (_hasMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
