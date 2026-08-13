import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../data/post.dart';
import '../data/post_repository.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'widgets/confirm_delete_dialog.dart';
import 'widgets/post_card.dart';

/// Screen 1 — Feed. Replaces WYN-002/003's HomeScreen placeholder.
/// See .wyn/docs/design/wyn-004-feed-and-post.md
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.postRepository});

  final PostRepository postRepository;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  PostRepository get _postRepository => widget.postRepository;
  final _scrollController = ScrollController();

  final List<Post> _posts = [];
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
      final posts = await _postRepository.fetchFeed(page: 0);
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _page = 0;
        _hasMore = posts.length == PostRepository.pageSize;
      });
    } catch (_) {
      setState(() => _error = 'โหลด Feed ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final posts = await _postRepository.fetchFeed(page: nextPage);
      setState(() {
        _posts.addAll(posts);
        _page = nextPage;
        _hasMore = posts.length == PostRepository.pageSize;
      });
    } catch (_) {
      // Silent: an infinite-scroll load-more failure doesn't need a
      // blocking error state -- scrolling again just retries it.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // Takes only the id and re-reads the live _posts[index] instead of a
  // Post captured at the last build -- the caller's closure is bound to
  // whatever `post` looked like at build time, so a rapid double-tap
  // before the next rebuild would otherwise reuse the same stale
  // pre-toggle state twice, firing a duplicate insert against the likes
  // table's (post_id, user_id) primary key and reverting the UI to the
  // wrong state when that second call fails. Mirrors the pattern already
  // used correctly in PostDetailScreen._toggleLike. See
  // .wyn/tasks/bugs/WYN-004-feed-and-post.md (QA round 1).
  Future<void> _toggleLike(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final previous = _posts[index];
    setState(() => _posts[index] = previous.toggledLike());
    try {
      await _postRepository.toggleLike(
        postId: postId,
        currentlyLiked: previous.likedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = previous);
    }
  }

  Future<void> _deletePost(Post post) async {
    final confirmed = await confirmDeletePost(context);
    if (!confirmed) return;

    final index = _posts.indexOf(post);
    setState(() => _posts.removeWhere((p) => p.id == post.id));
    try {
      await _postRepository.deletePost(post.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts.insert(index.clamp(0, _posts.length), post));
    }
  }

  Future<void> _openCreatePost() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(postRepository: _postRepository),
      ),
    );
    if (created == true) _loadInitial();
  }

  Future<void> _openPostDetail(Post post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          postRepository: _postRepository,
          post: post,
        ),
      ),
    );
    // The detail screen can change like/comment counts or delete the post
    // entirely -- reload rather than trying to sync partial state back.
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WYN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'โปรไฟล์ของฉัน',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ViewProfileScreen(
                  profileRepository:
                      ProfileRepository(Supabase.instance.client),
                  userId: userId,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreatePost,
        tooltip: 'สร้างโพสต์ใหม่',
        child: const Icon(Icons.add),
      ),
      body: _buildBody(userId),
    );
  }

  Widget _buildBody(String userId) {
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ยังไม่มีใครโพสต์เลย เป็นคนแรกสิ!'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _openCreatePost,
              child: const Text('สร้างโพสต์'),
            ),
          ],
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
          return PostCard(
            post: post,
            currentUserId: userId,
            onTapComments: () => _openPostDetail(post),
            onTapLike: () => _toggleLike(post.id),
            onTapDelete: () => _deletePost(post),
          );
        },
      ),
    );
  }
}
