import 'package:flutter/material.dart';

import '../../../drop/data/drop_repository.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../home/presentation/pop_single_clip_screen.dart';
import '../../../pop/data/pop.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../pop/presentation/widgets/pop_grid_tile.dart';
import '../../../saved/data/saved_repository.dart';
import '../../data/profile_repository.dart';

/// Pop grid tab on a profile (WYN-013) -- same 3-column grid as
/// ProfileDropGridTab (not Pop Feed's full-screen vertical swipe, which
/// doesn't suit a tab embedded in another screen). Tapping a tile opens
/// PopSingleClipScreen (WYN-007) -- one clip, no swipe to the next --
/// same reasoning as tapping a Pop card from Home.
class ProfilePopGridTab extends StatefulWidget {
  const ProfilePopGridTab({
    super.key,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.dropRepository,
    required this.savedRepository,
    required this.authorId,
    required this.emptyText,
  });

  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final DropRepository dropRepository;
  final SavedRepository savedRepository;
  final String authorId;
  final String emptyText;

  @override
  State<ProfilePopGridTab> createState() => _ProfilePopGridTabState();
}

class _ProfilePopGridTabState extends State<ProfilePopGridTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<Pop> _pops = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final pops = await widget.popRepository.fetchByAuthor(
        authorId: widget.authorId,
        page: 0,
      );
      setState(() {
        _pops
          ..clear()
          ..addAll(pops);
        _page = 0;
        _hasMore = pops.length == PopRepository.pageSize;
      });
    } catch (_) {
      setState(() => _error = 'โหลด Pop ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final pops = await widget.popRepository.fetchByAuthor(
        authorId: widget.authorId,
        page: nextPage,
      );
      setState(() {
        _pops.addAll(pops);
        _page = nextPage;
        _hasMore = pops.length == PopRepository.pageSize;
      });
    } catch (_) {
      // Silent: an infinite-scroll load-more failure doesn't need a
      // blocking error state -- scrolling again just retries it.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
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
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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

    if (_pops.isEmpty) {
      return Center(child: Text(widget.emptyText));
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
                final pop = _pops[index];
                return PopGridTile(
                  pop: pop,
                  onTap: () => _openPop(pop),
                );
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
      ),
    );
  }
}
