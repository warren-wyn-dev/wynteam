import 'package:flutter/material.dart';

import '../../club/data/club_member.dart';
import '../../club/data/club_post.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/club_post_detail_screen.dart';
import '../../club/presentation/widgets/club_post_card.dart';
import '../../drop/data/drop.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../drop/presentation/quote_redrop_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../home/data/home_feed_item.dart';
import '../../home/presentation/widgets/home_drop_card.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../saved/data/saved_repository.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';

enum _HashtagTab { latest, trending }

/// One search result, either a [Drop] or a [ClubPost] -- WYN-020's
/// Hashtag Feed mixes both, sorted together. Only one of [drop]/
/// [clubPost] is ever set.
class _HashtagEntry {
  const _HashtagEntry.drop(this.drop) : clubPost = null;
  const _HashtagEntry.clubPost(this.clubPost) : drop = null;

  final Drop? drop;
  final ClubPost? clubPost;

  DateTime get createdAt => drop?.createdAt ?? clubPost!.createdAt;
  int get engagement =>
      (drop?.likeCount ?? clubPost!.likeCount) + (drop?.commentCount ?? clubPost!.commentCount);
}

/// WYN-020: everything using #[tag] across Drop and Club posts, with
/// Latest/Trending tabs. Pushed directly from HashtagText's tap handler
/// -- see .wyn/docs/design/wyn-020-hashtag-system.md for why this screen
/// takes a full repository set rather than being wired through
/// RootShell like the Bottom Nav tabs are.
class HashtagFeedScreen extends StatefulWidget {
  const HashtagFeedScreen({
    super.key,
    required this.tag,
    required this.dropRepository,
    required this.clubPostRepository,
    required this.clubRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
  });

  final String tag;
  final DropRepository dropRepository;
  final ClubPostRepository clubPostRepository;
  final ClubRepository clubRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;

  @override
  State<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends State<HashtagFeedScreen> {
  final List<Drop> _drops = [];
  final List<ClubPost> _clubPosts = [];
  final Map<String, ClubMemberRole?> _roleByClubId = {};
  bool _isLoading = true;
  String? _error;
  _HashtagTab _tab = _HashtagTab.latest;

  String get _lowerTag => widget.tag.toLowerCase();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dropResults = await widget.dropRepository.searchByCaption(
        query: '#${widget.tag}',
        page: 0,
      );
      final clubPostResults = await widget.clubPostRepository.searchByContent(
        query: '#${widget.tag}',
        page: 0,
      );

      // Exact-match re-check -- the ILIKE call above is a broad
      // candidate filter (also matches e.g. "#WYNfamily" when searching
      // "WYN"), so only keep results whose real hashtag set contains
      // this exact tag. See extractHashtags's doc comment.
      final drops = dropResults
          .where((d) => extractHashtags(d.caption ?? '').contains(_lowerTag))
          .toList();
      final clubPosts = clubPostResults
          .where((p) => extractHashtags(p.content ?? '').contains(_lowerTag))
          .toList();

      await _resolveRolesFor(clubPosts);
      if (!mounted) return;
      setState(() {
        _drops
          ..clear()
          ..addAll(drops);
        _clubPosts
          ..clear()
          ..addAll(clubPosts);
      });
    } catch (_) {
      setState(() => _error = 'โหลดผลการค้นหาไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveRolesFor(List<ClubPost> posts) async {
    final unknownClubIds =
        posts.map((p) => p.clubId).toSet().difference(_roleByClubId.keys.toSet());
    if (unknownClubIds.isEmpty) return;

    final entries = await Future.wait(unknownClubIds.map((clubId) async {
      final membership = await widget.clubRepository.fetchMyMembership(clubId);
      final role = membership?.status == ClubMemberStatus.approved ? membership!.role : null;
      return MapEntry(clubId, role);
    }));
    _roleByClubId.addEntries(entries);
  }

  List<_HashtagEntry> get _sortedEntries {
    final entries = [
      ..._drops.map(_HashtagEntry.drop),
      ..._clubPosts.map(_HashtagEntry.clubPost),
    ];
    if (_tab == _HashtagTab.latest) {
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      entries.sort((a, b) => b.engagement.compareTo(a.engagement));
    }
    return entries;
  }

  Future<void> _toggleDropLike(String dropId) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final previous = _drops[index];
    setState(() => _drops[index] = previous.toggledLike());
    try {
      await widget.dropRepository.toggleLike(dropId: dropId, currentlyLiked: previous.likedByMe);
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops[index] = previous);
    }
  }

  Future<void> _toggleDropSave(String dropId) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final previous = _drops[index];
    setState(() => _drops[index] = previous.toggledSave());
    try {
      await widget.dropRepository.toggleSave(dropId: dropId, currentlySaved: previous.savedByMe);
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops[index] = previous);
    }
  }

  Future<void> _toggleDropRedrop(String dropId) async {
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

  Future<void> _quoteDropRedrop(String dropId) async {
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
    setState(() => _drops[currentIndex] = _drops[currentIndex].withExtraRedrop());
  }

  Future<void> _toggleClubPostLike(String postId) async {
    final index = _clubPosts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final previous = _clubPosts[index];
    setState(() => _clubPosts[index] = previous.toggledLike());
    try {
      await widget.clubPostRepository
          .toggleLike(postId: postId, currentlyLiked: previous.likedByMe);
    } catch (_) {
      if (!mounted) return;
      setState(() => _clubPosts[index] = previous);
    }
  }

  Future<void> _toggleClubPostSave(String postId) async {
    final index = _clubPosts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final previous = _clubPosts[index];
    setState(() => _clubPosts[index] = previous.toggledSave());
    try {
      await widget.clubPostRepository
          .toggleSave(postId: postId, currentlySaved: previous.savedByMe);
    } catch (_) {
      if (!mounted) return;
      setState(() => _clubPosts[index] = previous);
    }
  }

  Future<void> _togglePin(String postId) async {
    final index = _clubPosts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final previous = _clubPosts[index];
    setState(() => _clubPosts[index] = previous.toggledPin());
    try {
      await widget.clubPostRepository
          .togglePin(postId: previous.id, currentlyPinned: previous.pinned);
    } catch (_) {
      if (!mounted) return;
      setState(() => _clubPosts[index] = previous);
    }
  }

  Future<void> _deleteClubPost(String postId) async {
    try {
      await widget.clubPostRepository.deletePost(postId);
      if (!mounted) return;
      setState(() => _clubPosts.removeWhere((p) => p.id == postId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _openDrop(Drop drop) async {
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
    _load();
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

  Future<void> _openClubPost(ClubPost post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPostDetailScreen(
          clubPostRepository: widget.clubPostRepository,
          post: post,
          myRole: _roleByClubId[post.clubId],
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('#${widget.tag}'),
          bottom: TabBar(
            tabs: const [Tab(text: 'Latest'), Tab(text: 'Trending')],
            onTap: (index) => setState(
              () => _tab = index == 0 ? _HashtagTab.latest : _HashtagTab.trending,
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    final entries = _sortedEntries;
    if (entries.isEmpty) {
      return Center(child: Text('ยังไม่มีโพสต์ที่ใช้ #${widget.tag}'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          if (entry.drop != null) {
            final drop = entry.drop!;
            return HomeDropCard(
              key: ValueKey('drop_${drop.id}'),
              item: HomeFeedItem.fromDrop(drop),
              onTap: () => _openDrop(drop),
              onToggleLike: () => _toggleDropLike(drop.id),
              onToggleSave: () => _toggleDropSave(drop.id),
              onOpenProfile: () => _openProfile(drop.authorId),
              onToggleRedrop: () => _toggleDropRedrop(drop.id),
              onQuoteRedrop: () => _quoteDropRedrop(drop.id),
            );
          }

          final post = entry.clubPost!;
          return ClubPostCard(
            key: ValueKey('club_post_${post.id}'),
            post: post,
            myRole: _roleByClubId[post.clubId],
            onTap: () => _openClubPost(post),
            onToggleLike: () => _toggleClubPostLike(post.id),
            onToggleSave: () => _toggleClubPostSave(post.id),
            onTogglePin: () => _togglePin(post.id),
            onDelete: () => _deleteClubPost(post.id),
          );
        },
      ),
    );
  }
}
