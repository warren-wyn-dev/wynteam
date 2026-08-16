import 'package:flutter/material.dart';

import '../../data/club.dart';
import '../../data/club_member.dart';
import '../../data/club_post.dart';
import '../../data/club_post_repository.dart';
import '../club_post_detail_screen.dart';
import '../create_club_post_screen.dart';
import 'club_post_card.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Screen 4-5 — Posts tab. Gated behind approved membership: non-members
/// (myRole == null) see a join-prompt placeholder instead of the list,
/// per the Product spec ("โพสต์ Club มองเห็นเฉพาะสมาชิกที่ approved แล้ว
/// ไม่ว่า Public/Private"). See .wyn/docs/design/wyn-014-club-core.md,
/// Screens 4-5.
class ClubPostsTab extends StatefulWidget {
  const ClubPostsTab({
    super.key,
    required this.clubPostRepository,
    required this.club,
    required this.myRole,
    required this.onJoinTapped,
  });

  final ClubPostRepository clubPostRepository;
  final Club club;
  final ClubMemberRole? myRole;
  final VoidCallback onJoinTapped;

  @override
  State<ClubPostsTab> createState() => _ClubPostsTabState();
}

class _ClubPostsTabState extends State<ClubPostsTab> {
  final _scrollController = ScrollController();
  final List<ClubPost> _posts = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  bool get _isMember => widget.myRole != null;

  @override
  void initState() {
    super.initState();
    if (_isMember) _loadInitial();
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
      final posts = await widget.clubPostRepository.fetchPosts(
        clubId: widget.club.id,
        page: 0,
      );
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
      final posts = await widget.clubPostRepository.fetchPosts(
        clubId: widget.club.id,
        page: nextPage,
      );
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

  // Re-reads the live _posts[index] by id instead of a ClubPost captured
  // at the last build -- same double-tap-safety pattern as
  // DropDetailScreen/HomeFeedScreen. See .wyn/learning/PATTERNS.md.
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
      // Pin state affects sort order (pinned-first), so a full reload
      // keeps the list correctly ordered rather than leaving the row in
      // its pre-toggle position.
      _loadInitial();
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
          myRole: widget.myRole,
        ),
      ),
    );
    _loadInitial();
  }

  Future<void> _openCreatePost() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateClubPostScreen(
          clubPostRepository: widget.clubPostRepository,
          club: widget.club,
        ),
      ),
    );
    if (created == true) _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMember) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('เข้าร่วม Club เพื่อดูโพสต์', textAlign: TextAlign.center),
              const SizedBox(height: WynSpacing.space3),
              OutlinedButton(onPressed: widget.onJoinTapped, child: const Text('เข้าร่วม')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreatePost,
        tooltip: 'สร้างโพสต์',
        child: const Icon(Icons.add),
      ),
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
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return const Center(child: Text('ยังไม่มีโพสต์ใน Club นี้ เป็นคนแรกสิ!'));
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final post = _posts[index];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index == 0 && post.pinned)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.push_pin, size: 14, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: WynSpacing.space1),
                      Text(
                        'ปักหมุด',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              ClubPostCard(
                key: ValueKey(post.id),
                post: post,
                myRole: widget.myRole,
                onTap: () => _openPost(post),
                onToggleLike: () => _toggleLike(post.id),
                onToggleSave: () => _toggleSave(post.id),
                onTogglePin: () => _togglePin(post.id),
                onDelete: () => _deletePost(post.id),
              ),
            ],
          );
        },
      ),
    );
  }
}
