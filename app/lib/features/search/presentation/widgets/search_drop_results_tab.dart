import 'package:flutter/material.dart';

import '../../../drop/data/drop.dart';
import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart';
import '../../../drop/presentation/quote_redrop_screen.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../home/data/home_feed_item.dart';
import '../../../home/presentation/widgets/home_drop_card.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/view_profile_screen.dart';
import '../../../saved/data/saved_repository.dart';
import 'search_state_message.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Search's Drop tab (WYN-009) -- a plain vertical list of [HomeDropCard],
/// same "feed HomeDropCard from a plain Drop list via
/// HomeFeedItem.fromDrop" pattern ProfileDropGridTab (WYN-013) and
/// HashtagFeedScreen (WYN-019) already established, scoped here to a
/// caption search instead of one author or one hashtag.
///
/// Was a 3-column [DropGridTile] grid. That fit a *profile's own* posts
/// tab, where every tile is already known to be yours; it did not fit a
/// search result, which mixes every author on the platform into one
/// dense wall of near-identical squares -- doubly so for a caption-only
/// Drop, which WYNOS posts are text-first (per ProfileDropGridTab's own
/// doc comment) and rendered as just truncated text on a flat colour
/// with nothing else to identify it. Founder, after seeing the grid on
/// a real search result: "อยากให้เหมือน/คล้ายหน้า Home" -- Home's own
/// card is exactly what ProfileDropGridTab already reuses for the same
/// reason, so this reuses it too rather than inventing a third shape.
///
/// Query is driven by [query], a prop from the shared search box in
/// SearchScreen, not typed here directly -- resets and re-searches
/// whenever it changes.
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

  // Everything below (_toggleLike/_toggleSave/_toggleRedrop/_votePoll/
  // _quoteRedrop/_openProfile/_openDropDetail) mirrors
  // ProfileDropGridTab's identical methods -- same optimistic-update/
  // rollback shape, same navigation targets. Kept as its own copy
  // rather than a shared mixin: the two screens' surrounding state
  // (pagination/search vs. profile header refresh) differs enough that
  // extracting one now would be a speculative abstraction over two data
  // points, not a real duplication problem yet.

  Future<void> _toggleLike(String dropId) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final previous = _drops[index];
    setState(() => _drops[index] = previous.toggledLike());
    try {
      await widget.dropRepository
          .toggleLike(dropId: dropId, currentlyLiked: previous.likedByMe);
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops[index] = previous);
    }
  }

  Future<void> _toggleSave(String dropId) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final previous = _drops[index];
    setState(() => _drops[index] = previous.toggledSave());
    try {
      await widget.dropRepository
          .toggleSave(dropId: dropId, currentlySaved: previous.savedByMe);
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops[index] = previous);
    }
  }

  Future<void> _toggleRedrop(String dropId) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final previous = _drops[index];
    setState(() => _drops[index] = previous.toggledRedrop());
    try {
      await widget.dropRepository.toggleRedrop(
        dropId: dropId,
        currentlyRedropped: previous.redroppedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops[index] = previous);
    }
  }

  Future<void> _votePoll(String dropId, int optionIndex) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final previous = _drops[index];
    setState(() => _drops[index] = previous.votedPoll(optionIndex));
    try {
      await widget.dropRepository.votePoll(
        pollId: previous.pollId!,
        optionIndex: optionIndex,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops[index] = previous);
    }
  }

  Future<void> _quoteRedrop(String dropId) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final drop = _drops[index];

    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuoteRedropScreen(
          dropRepository: widget.dropRepository,
          drop: drop,
        ),
      ),
    );
    if (posted != true || !mounted) return;
    final currentIndex = _drops.indexWhere((d) => d.id == dropId);
    if (currentIndex == -1) return;
    setState(
        () => _drops[currentIndex] = _drops[currentIndex].withExtraRedrop());
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: userId,
        ),
      ),
    );
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
        text: 'พิมพ์คำในแคปชันเพื่อค้นหาโพสต์',
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
            const SizedBox(height: WynSpacing.space3),
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
        text: 'ไม่พบโพสต์สำหรับ "${widget.query.trim()}"',
      );
    }

    return ListView.separated(
      controller: _scrollController,
      itemCount: _drops.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => index + 1 < _drops.length
          ? const Divider(height: 1)
          : const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index >= _drops.length) {
          return const Padding(
            padding: EdgeInsets.all(WynSpacing.space4),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final drop = _drops[index];
        return HomeDropCard(
          key: ValueKey(drop.id),
          item: HomeFeedItem.fromDrop(drop),
          dropRepository: widget.dropRepository,
          onTap: () => _openDropDetail(drop),
          onToggleLike: () => _toggleLike(drop.id),
          onToggleSave: () => _toggleSave(drop.id),
          onOpenProfile: () => _openProfile(drop.authorId),
          onToggleRedrop: () => _toggleRedrop(drop.id),
          onQuoteRedrop: () => _quoteRedrop(drop.id),
          onVotePoll: (optionIndex) => _votePoll(drop.id, optionIndex),
        );
      },
    );
  }
}
