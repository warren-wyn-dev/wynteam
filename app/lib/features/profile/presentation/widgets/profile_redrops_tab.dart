import 'package:flutter/material.dart';

import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart';
import '../../../drop/presentation/quote_redrop_screen.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../home/data/home_feed_item.dart';
import '../../../home/data/home_repository.dart';
import '../../../home/presentation/widgets/home_drop_card.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../saved/data/saved_repository.dart';
import '../../data/profile_repository.dart';
import '../view_profile_screen.dart';
import '../../../../core/design/wyn_spacing.dart';

/// "ReDrops" tab on a profile (WYN-034, Master Spec section 9) --
/// Standard + Quote ReDrops made by this profile's owner, newest-
/// ReDropped-first. Reuses [HomeDropCard] as-is (it already renders
/// the "🔄 ReDrop โดย @username" label + quote text + original Drop
/// card when `redropId != null`) rather than a bespoke tile, fed from
/// [HomeRepository.fetchRedropsByUser] instead of the unified feed.
class ProfileRedropsTab extends StatefulWidget {
  const ProfileRedropsTab({
    super.key,
    required this.homeRepository,
    required this.dropRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
    required this.authorId,
    required this.emptyText,
    this.onRefreshHeader,
  });

  final HomeRepository homeRepository;
  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final String authorId;
  final String emptyText;

  // WYN-081 (Wynos V1.0.0 Beta2, item 16): see ProfileDropGridTab's
  // identical field for why this exists.
  final VoidCallback? onRefreshHeader;

  @override
  State<ProfileRedropsTab> createState() => _ProfileRedropsTabState();
}

class _ProfileRedropsTabState extends State<ProfileRedropsTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<HomeFeedItem> _items = [];
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
      final items = await widget.homeRepository.fetchRedropsByUser(
        userId: widget.authorId,
        page: 0,
      );
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _page = 0;
        _hasMore = items.length == HomeRepository.pageSize;
      });
    } catch (_) {
      setState(() => _error = 'โหลดรีโพสต์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  // Only used by RefreshIndicator's pull gesture, not initState's own
  // first load -- see [onRefreshHeader]'s doc comment.
  Future<void> _onPullToRefresh() async {
    widget.onRefreshHeader?.call();
    await _loadInitial();
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final items = await widget.homeRepository.fetchRedropsByUser(
        userId: widget.authorId,
        page: nextPage,
      );
      setState(() {
        _items.addAll(items);
        _page = nextPage;
        _hasMore = items.length == HomeRepository.pageSize;
      });
    } catch (_) {
      // Silent -- same posture as ProfileDropGridTab's own load-more.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // Index-based, not id-based -- the same Drop can appear twice in
  // this very tab (a Standard *and* a Quote ReDrop of it both made by
  // this profile's owner), so `id` alone doesn't uniquely identify a
  // row here either. See HomeFeedScreen's own toggle methods for the
  // full reasoning (WYN-034).
  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];
    setState(() => _items[index] = previous.copyWith(
          likedByMe: !previous.likedByMe,
          likeCount:
              previous.likedByMe ? previous.likeCount - 1 : previous.likeCount + 1,
        ));
    try {
      await widget.dropRepository.toggleLike(
        dropId: previous.id,
        currentlyLiked: previous.likedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = previous);
    }
  }

  Future<void> _toggleSave(int index) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];
    setState(() => _items[index] = previous.copyWith(savedByMe: !previous.savedByMe));
    try {
      await widget.dropRepository.toggleSave(
        dropId: previous.id,
        currentlySaved: previous.savedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = previous);
    }
  }

  Future<void> _toggleRedrop(int index) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];
    setState(() => _items[index] = previous.copyWith(
          redroppedByMe: !previous.redroppedByMe,
          redropCount: previous.redroppedByMe
              ? previous.redropCount - 1
              : previous.redropCount + 1,
        ));
    try {
      await widget.dropRepository.toggleRedrop(
        dropId: previous.id,
        currentlyRedropped: previous.redroppedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = previous);
    }
  }

  Future<void> _quoteRedrop(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];

    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuoteRedropScreen(
          dropRepository: widget.dropRepository,
          drop: item.toDrop(),
        ),
      ),
    );
    if (posted != true || !mounted) return;
    // A freshly-posted Quote ReDrop belongs on this very tab (same
    // author) -- reload rather than trying to splice in a synthetic
    // row, since fetchRedropsByUser is the only place that knows the
    // new row's real id/created_at.
    _loadInitial();
  }

  /// WYN-035: a ReDrop of a Poll Drop still carries its poll -- same
  /// optimistic-vote shape as HomeFeedScreen's own _votePoll.
  Future<void> _votePoll(int index, int optionIndex) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];
    final pollId = previous.pollId;
    if (pollId == null) return;

    setState(() => _items[index] = previous.votedPoll(optionIndex));
    try {
      await widget.dropRepository.votePoll(
        pollId: pollId,
        optionIndex: optionIndex,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = previous);
    }
  }

  /// Deletes the ReDrop entry at [index] outright (Standard or Quote)
  /// -- this tab only ever shows the profile owner's own ReDrops, so
  /// every card here is eligible (mirrors HomeFeedScreen's own
  /// _deleteRedrop).
  Future<void> _deleteRedrop(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    final redropId = item.redropId;
    if (redropId == null) return;

    setState(() => _items.removeAt(index));
    try {
      await widget.dropRepository.deleteRedrop(redropId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items.insert(index, item));
    }
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

  Future<void> _openDrop(HomeFeedItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: widget.dropRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          drop: item.toDrop(),
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
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(child: Text(widget.emptyText));
    }

    return RefreshIndicator(
      onRefresh: _onPullToRefresh,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => index + 1 < _items.length
            ? const Divider(height: 1)
            : const SizedBox.shrink(),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = _items[index];
          return HomeDropCard(
            key: ValueKey('${item.id}:${item.redropId ?? ''}'),
            item: item,
            onTap: () => _openDrop(item),
            onToggleLike: () => _toggleLike(index),
            onToggleSave: () => _toggleSave(index),
            onOpenProfile: () => _openProfile(item.authorId),
            onToggleRedrop: () => _toggleRedrop(index),
            onQuoteRedrop: () => _quoteRedrop(index),
            onOpenRedropperProfile: item.redropperId == null
                ? null
                : () => _openProfile(item.redropperId!),
            onDeleteRedrop: () => _deleteRedrop(index),
            onVotePoll: (optionIndex) => _votePoll(index, optionIndex),
          );
        },
      ),
    );
  }
}
