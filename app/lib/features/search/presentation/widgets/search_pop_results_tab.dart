import 'package:flutter/material.dart';

import '../../../drop/data/drop_repository.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../home/presentation/pop_single_clip_screen.dart';
import '../../../pop/data/pop.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../pop/presentation/widgets/pop_grid_tile.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../saved/data/saved_repository.dart';
import 'search_state_message.dart';

/// Search's Pop tab (WYN-009) -- same 3-column grid as ProfilePopGridTab
/// (WYN-013), reusing PopGridTile directly. Query is driven by [query], a
/// prop from the shared search box in SearchScreen, not typed here
/// directly -- resets and re-searches whenever it changes.
class SearchPopResultsTab extends StatefulWidget {
  const SearchPopResultsTab({
    super.key,
    required this.query,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.dropRepository,
    required this.savedRepository,
  });

  final String query;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final DropRepository dropRepository;
  final SavedRepository savedRepository;

  @override
  State<SearchPopResultsTab> createState() => _SearchPopResultsTabState();
}

class _SearchPopResultsTabState extends State<SearchPopResultsTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<Pop> _pops = [];
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
  void didUpdateWidget(covariant SearchPopResultsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _pops.clear();
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
      final results = await widget.popRepository.searchByCaption(
        query: widget.query.trim(),
        page: page,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _pops
            ..clear()
            ..addAll(results);
        } else {
          _pops.addAll(results);
        }
        _page = page;
        _hasMore = results.length == PopRepository.pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'ค้นหาไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPop(Pop pop) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PopSingleClipScreen(
          pop: pop,
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          dropRepository: widget.dropRepository,
          savedRepository: widget.savedRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_queryTooShort) {
      return const SearchStateMessage(
        icon: Icons.play_circle_outline,
        text: 'พิมพ์คำในแคปชันเพื่อค้นหา Pop',
      );
    }

    if (_isLoading && _pops.isEmpty) {
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

    if (_pops.isEmpty) {
      return SearchStateMessage(
        icon: Icons.play_circle_outline,
        text: 'ไม่พบ Pop สำหรับ "${widget.query.trim()}"',
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
              final pop = _pops[index];
              return PopGridTile(pop: pop, onTap: () => _openPop(pop));
            },
            childCount: _pops.length,
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
