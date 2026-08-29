import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../drop/data/drop.dart';
import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart';
import '../../../drop/presentation/quote_redrop_screen.dart';
import '../../../drop/presentation/widgets/poll_card.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../home/data/home_feed_item.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../saved/data/saved_repository.dart';
import '../../data/profile_repository.dart';
import '../view_profile_screen.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wynos_home_tokens.dart';
import 'wynos_post_row.dart';

/// One row's worth of data for [WynosProfilePostListTab] -- always
/// carries a full [Drop] (so the same [DropDetailScreen] every other
/// Drop-opening call site in the app already uses can open it
/// unchanged), plus optional ReDrop-attribution fields when the row
/// came from a ReDrop rather than directly from `drops`. Mirrors
/// [HomeFeedItem]'s own "ReDrop metadata alongside the underlying Drop's
/// own fields" shape, scoped down to just what a [WynosPostRow] needs.
class PostRowData {
  const PostRowData({
    required this.drop,
    this.redropAttributionUsername,
    this.redropperId,
    this.redropId,
    this.quoteText,
  });

  final Drop drop;

  /// Non-null only when this row is a ReDrop -- the redropper's own
  /// username, for the "ReDrop โดย @username" attribution line.
  final String? redropAttributionUsername;
  final String? redropperId;

  /// Non-null only when this row is *the viewer's own* ReDrop entry
  /// (always true for every row [WynosProfilePostListTab] shows on the
  /// "ReDrop" tab, since that tab only ever fetches the profile owner's
  /// own ReDrops) -- lets the ReDrop action sheet offer "ลบ ReDrop".
  final String? redropId;

  /// Set only for a Quote ReDrop -- the redropper's own commentary,
  /// distinct from (and shown above) [drop]'s own caption, same as
  /// [HomeFeedItem.quoteText]/HomeDropCard's own quote block. Unlike
  /// `/05-profile.tsx`'s flat mock data (no separate "quote text"
  /// concept), the real data model genuinely has this as separate
  /// content the redropper wrote -- dropping it would silently hide
  /// something the user typed, so it's carried through and rendered as
  /// [WynosPostRow.quoteText].
  final String? quoteText;

  factory PostRowData.fromDrop(Drop drop) => PostRowData(drop: drop);

  factory PostRowData.fromHomeFeedItem(HomeFeedItem item) => PostRowData(
        drop: item.toDrop(),
        redropAttributionUsername:
            item.redropId != null ? item.redropperUsername : null,
        redropperId: item.redropperId,
        redropId: item.redropId,
        quoteText: item.quoteText,
      );

  PostRowData withDrop(Drop drop) => PostRowData(
        drop: drop,
        redropAttributionUsername: redropAttributionUsername,
        redropperId: redropperId,
        quoteText: quoteText,
        redropId: redropId,
      );
}

/// WYN-073's own-profile "โพสต์"/"ReDrop"/"ถูกใจ" tabs -- one generic,
/// paginated, full-width [WynosPostRow] list, parameterized by
/// [fetchPage] so the 3 different backing queries (DropRepository.
/// fetchByAuthor/fetchLikedByAuthor, HomeRepository.fetchRedropsByUser)
/// share one implementation instead of 3 near-duplicates. Mirrors the
/// pagination/loading-state shape every other paginated profile tab
/// widget already uses (ProfileDropGridTab, ProfileRedropsTab, ...) --
/// see those files' own comments for why that shape exists.
class WynosProfilePostListTab extends StatefulWidget {
  const WynosProfilePostListTab({
    super.key,
    required this.fetchPage,
    required this.pageSize,
    required this.emptyText,
    required this.errorText,
    required this.dropRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
    this.allowRedropActions = false,
  });

  final Future<List<PostRowData>> Function(int page) fetchPage;

  /// The backing repository method's own page size -- used for the
  /// same "did this page come back full" `_hasMore` check every other
  /// paginated tab already uses (DropRepository.pageSize for Posts/
  /// Likes, HomeRepository.pageSize for ReDrop -- the two differ, 21 vs
  /// 10, so this can't be hardcoded here).
  final int pageSize;

  final String emptyText;
  final String errorText;
  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;

  /// Only true for the "ReDrop" tab -- every row there is already the
  /// viewer's own ReDrop, so the Repost icon opens the same "🔄 ReDrop /
  /// 💬 Quote ReDrop / ลบ ReDrop" action sheet `HomeDropCard`/
  /// `ProfileRedropsTab` already offer. False (display-only Repost
  /// icon) for "โพสต์"/"ถูกใจ", which never offered a ReDrop action even
  /// before this row style existed (the 3-column grid they replaced had
  /// none either -- see [WynosPostRow.onTapRedrop]'s own doc comment).
  final bool allowRedropActions;

  @override
  State<WynosProfilePostListTab> createState() =>
      _WynosProfilePostListTabState();
}

class _WynosProfilePostListTabState extends State<WynosProfilePostListTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<PostRowData> _items = [];
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
      final items = await widget.fetchPage(0);
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _page = 0;
        _hasMore = items.length == widget.pageSize;
      });
    } catch (_) {
      setState(() => _error = widget.errorText);
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final items = await widget.fetchPage(nextPage);
      setState(() {
        _items.addAll(items);
        _page = nextPage;
        _hasMore = items.length == widget.pageSize;
      });
    } catch (_) {
      // Silent -- same posture as every other paginated tab's load-more.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];
    final drop = previous.drop;
    setState(() => _items[index] = previous.withDrop(drop.toggledLike()));
    try {
      await widget.dropRepository
          .toggleLike(dropId: drop.id, currentlyLiked: drop.likedByMe);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = previous);
    }
  }

  Future<void> _toggleRedrop(int index) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];
    final drop = previous.drop;
    setState(() => _items[index] = previous.withDrop(drop.toggledRedrop()));
    try {
      await widget.dropRepository.toggleRedrop(
          dropId: drop.id, currentlyRedropped: drop.redroppedByMe);
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
          drop: item.drop,
        ),
      ),
    );
    if (posted != true || !mounted) return;
    // A freshly-posted Quote ReDrop belongs on this very tab -- reload
    // rather than splicing in a synthetic row, same reasoning as
    // ProfileRedropsTab._quoteRedrop.
    _loadInitial();
  }

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

  Future<void> _openRedropSheet(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.repeat),
              title:
                  Text(item.drop.redroppedByMe ? 'ยกเลิก ReDrop' : '🔄 ReDrop'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _toggleRedrop(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('💬 Quote ReDrop'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _quoteRedrop(index);
              },
            ),
            if (item.redropId != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('ลบ ReDrop'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _deleteRedrop(index);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _votePoll(int index, int optionIndex) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];
    final pollId = previous.drop.pollId;
    if (pollId == null) return;

    setState(
        () => _items[index] = previous.withDrop(previous.drop.votedPoll(optionIndex)));
    try {
      await widget.dropRepository
          .votePoll(pollId: pollId, optionIndex: optionIndex);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = previous);
    }
  }

  Future<void> _openDetail(int index) async {
    if (index < 0 || index >= _items.length) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: widget.dropRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          drop: _items[index].drop,
        ),
      ),
    );
    _loadInitial();
  }

  void _openRedropperProfile(String userId) {
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
            Text(_error!, style: WynosHomeTokens.caption()),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(widget.emptyText, style: WynosHomeTokens.caption()),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = _items[index];
          final drop = item.drop;
          final isOwnDrop =
              drop.authorId == Supabase.instance.client.auth.currentUser!.id;

          return WynosPostRow(
            key: ValueKey('${drop.id}:${item.redropId ?? ''}'),
            createdAt: drop.createdAt,
            caption: drop.caption ?? '',
            likeCount: drop.likeCount,
            likedByMe: drop.likedByMe,
            commentCount: drop.commentCount,
            redropCount: drop.redropCount,
            viewCount: drop.viewCount,
            redroppedByMe: drop.redroppedByMe,
            onTap: () => _openDetail(index),
            onToggleLike: () => _toggleLike(index),
            onTapRedrop:
                widget.allowRedropActions ? () => _openRedropSheet(index) : null,
            attributionLabel: item.redropAttributionUsername != null
                ? 'ReDrop โดย @${item.redropAttributionUsername}'
                : null,
            onTapAttribution: item.redropperId != null
                ? () => _openRedropperProfile(item.redropperId!)
                : null,
            quoteText: item.quoteText,
            trailing: drop.isPoll
                ? PollCard(
                    options: drop.pollOptions!,
                    expiresAt: drop.pollExpiresAt!,
                    myVoteIndex: drop.pollMyVoteIndex,
                    totalVotes: drop.pollTotalVotes,
                    optionCounts: drop.pollOptionCounts,
                    isOwnPoll: isOwnDrop,
                    onVote: (optionIndex) => _votePoll(index, optionIndex),
                  )
                : null,
            showBottomDivider: index != _items.length - 1 || _hasMore,
          );
        },
      ),
    );
  }
}
