import 'package:flutter/material.dart';

import '../data/drop.dart';
import '../data/drop_repository.dart';
import 'create_drop_screen.dart';
import 'drop_detail_screen.dart';
import 'widgets/drop_grid_tile.dart';

/// Screen 1 — Drop tab (Bottom Nav). A 3-column grid, deliberately
/// different from Home's chronological single-column feed -- same
/// underlying content, different browsing mode, so the tab has a reason
/// to exist distinct from Home. See .wyn/docs/design/wyn-005-drop.md.
class DropFeedScreen extends StatefulWidget {
  const DropFeedScreen({super.key, required this.dropRepository});

  final DropRepository dropRepository;

  @override
  State<DropFeedScreen> createState() => _DropFeedScreenState();
}

class _DropFeedScreenState extends State<DropFeedScreen> {
  DropRepository get _dropRepository => widget.dropRepository;
  final _scrollController = ScrollController();

  final List<Drop> _drops = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final drops = await _dropRepository.fetchFeed(page: 0);
      setState(() {
        _drops
          ..clear()
          ..addAll(drops);
        _page = 0;
        _hasMore = drops.length == DropRepository.pageSize;
      });
    } catch (_) {
      setState(() => _error = 'โหลด Drop ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final drops = await _dropRepository.fetchFeed(page: nextPage);
      setState(() {
        _drops.addAll(drops);
        _page = nextPage;
        _hasMore = drops.length == DropRepository.pageSize;
      });
    } catch (_) {
      // Silent: an infinite-scroll load-more failure doesn't need a
      // blocking error state -- scrolling again just retries it.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openCreateDrop() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateDropScreen(dropRepository: _dropRepository),
      ),
    );
    if (created == true) _loadInitial();
  }

  Future<void> _openDropDetail(Drop drop) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: _dropRepository,
          drop: drop,
        ),
      ),
    );
    // The detail screen can change like/comment/save state or delete the
    // Drop entirely -- reload rather than trying to sync partial state
    // back into the grid.
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: 'สร้าง Drop ใหม่',
            onPressed: _openCreateDrop,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_drops.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ยังไม่มีใครแชร์รูปเลย เป็นคนแรกสิ!'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _openCreateDrop,
              child: const Text('สร้าง Drop'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: CustomScrollView(
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
      ),
    );
  }
}
