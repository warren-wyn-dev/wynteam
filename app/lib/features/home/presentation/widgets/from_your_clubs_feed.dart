import 'package:flutter/material.dart';

import '../../../club/data/club_member.dart';
import '../../../club/data/club_post.dart';
import '../../../club/data/club_post_repository.dart';
import '../../../club/data/club_repository.dart';
import '../../../club/presentation/club_post_detail_screen.dart';
import '../../../club/presentation/widgets/club_post_card.dart';

/// Screen 5 (right half) — the "จาก Club ของคุณ" side of Home's toggle
/// (WYN-015). Posts from every Club the user has joined, newest first --
/// ClubPostRepository.fetchFromJoinedClubs relies on club_posts' own RLS
/// to scope this (no explicit club_id filter needed).
///
/// Unlike ClubPostsTab (WYN-014, scoped to one Club so myRole is a
/// single fixed value), posts here can come from different Clubs with
/// different roles for the same viewer, so myRole is resolved per
/// distinct club_id present on the current page and cached rather than
/// being one constant passed down.
class FromYourClubsFeed extends StatefulWidget {
  const FromYourClubsFeed({
    super.key,
    required this.clubRepository,
    required this.clubPostRepository,
  });

  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  @override
  State<FromYourClubsFeed> createState() => _FromYourClubsFeedState();
}

class _FromYourClubsFeedState extends State<FromYourClubsFeed> {
  final _scrollController = ScrollController();
  final List<ClubPost> _posts = [];
  final Map<String, ClubMemberRole?> _roleByClubId = {};
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

  Future<void> _resolveRolesFor(List<ClubPost> posts) async {
    final unknownClubIds =
        posts.map((p) => p.clubId).toSet().difference(_roleByClubId.keys.toSet());
    if (unknownClubIds.isEmpty) return;

    final entries = await Future.wait(unknownClubIds.map((clubId) async {
      final membership = await widget.clubRepository.fetchMyMembership(clubId);
      final role = membership?.status == ClubMemberStatus.approved ? membership!.role : null;
      return MapEntry(clubId, role);
    }));
    if (!mounted) return;
    setState(() => _roleByClubId.addEntries(entries));
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final posts = await widget.clubPostRepository.fetchFromJoinedClubs(page: 0);
      await _resolveRolesFor(posts);
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _page = 0;
        _hasMore = posts.length == ClubPostRepository.pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดโพสต์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final posts = await widget.clubPostRepository.fetchFromJoinedClubs(page: nextPage);
      await _resolveRolesFor(posts);
      if (!mounted) return;
      setState(() {
        _posts.addAll(posts);
        _page = nextPage;
        _hasMore = posts.length == ClubPostRepository.pageSize;
      });
    } catch (_) {
      // Silent -- same infinite-scroll convention as every other feed.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _toggleLike(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final previous = _posts[index];

    setState(() => _posts[index] = previous.toggledLike());
    try {
      await widget.clubPostRepository.toggleLike(
        postId: previous.id,
        currentlyLiked: previous.likedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = previous);
    }
  }

  Future<void> _toggleSave(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final previous = _posts[index];

    setState(() => _posts[index] = previous.toggledSave());
    try {
      await widget.clubPostRepository.toggleSave(
        postId: previous.id,
        currentlySaved: previous.savedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = previous);
    }
  }

  Future<void> _togglePin(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final previous = _posts[index];

    setState(() => _posts[index] = previous.toggledPin());
    try {
      await widget.clubPostRepository.togglePin(
        postId: previous.id,
        currentlyPinned: previous.pinned,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = previous);
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await widget.clubPostRepository.deletePost(postId);
      if (!mounted) return;
      setState(() => _posts.removeWhere((p) => p.id == postId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _openPost(ClubPost post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPostDetailScreen(
          clubPostRepository: widget.clubPostRepository,
          post: post,
          myRole: _roleByClubId[post.clubId],
        ),
      ),
    );
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
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

    if (_posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text('เข้าร่วม Club เพื่อดูโพสต์ที่นี่', textAlign: TextAlign.center),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final post = _posts[index];
          return ClubPostCard(
            key: ValueKey(post.id),
            post: post,
            myRole: _roleByClubId[post.clubId],
            onTap: () => _openPost(post),
            onToggleLike: () => _toggleLike(post.id),
            onToggleSave: () => _toggleSave(post.id),
            onTogglePin: () => _togglePin(post.id),
            onDelete: () => _deletePost(post.id),
          );
        },
      ),
    );
  }
}
