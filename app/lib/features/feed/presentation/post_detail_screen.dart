import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/comment.dart';
import '../data/post.dart';
import '../data/post_repository.dart';
import 'widgets/confirm_delete_dialog.dart';
import 'widgets/post_card.dart';

/// Screen 3 — Post Detail (Comments).
/// See .wyn/docs/design/wyn-004-feed-and-post.md
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postRepository,
    required this.post,
  });

  final PostRepository postRepository;
  final Post post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post;
  late Future<List<Comment>> _commentsFuture;
  final _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _commentsFuture = widget.postRepository.fetchComments(_post.id);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final previous = _post;
    setState(() => _post = _post.toggledLike());
    try {
      await widget.postRepository.toggleLike(
        postId: previous.id,
        currentlyLiked: previous.likedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _post = previous);
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await confirmDeletePost(context);
    if (!confirmed) return;

    try {
      await widget.postRepository.deletePost(_post.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final comment = await widget.postRepository.addComment(
        postId: _post.id,
        textContent: text,
      );
      if (!mounted) return;
      setState(() {
        _commentsFuture =
            _commentsFuture.then((comments) => [...comments, comment]);
        _post = _post.withExtraComment();
        _commentController.clear();
      });
    } catch (_) {
      // Keep the typed text in the box so the user can just retry sending.
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(title: const Text('โพสต์')),
      body: Column(
        children: [
          Expanded(child: _buildBody(currentUserId)),
          _buildCommentInput(),
        ],
      ),
    );
  }

  // The post header (PostCard) and the comment list are scrolled together
  // as one list -- PostCard can grow tall (e.g. with an image), and on a
  // short/wide viewport a fixed-height header above a separately-scrolled
  // comment list would overflow instead of just scrolling out of view.
  Widget _buildBody(String currentUserId) {
    final header = PostCard(
      post: _post,
      currentUserId: currentUserId,
      onTapLike: _toggleLike,
      onTapComments: () {},
      onTapDelete: _deletePost,
    );

    return FutureBuilder<List<Comment>>(
      future: _commentsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            children: [
              header,
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('โหลดคอมเมนต์ไม่สำเร็จ')),
              ),
            ],
          );
        }

        if (!snapshot.hasData) {
          return ListView(
            children: [
              header,
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }

        final comments = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            header,
            const Divider(height: 1),
            if (comments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('ยังไม่มีคอมเมนต์ เป็นคนแรกสิ!')),
              )
            else
              ...comments.map(
                (comment) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AvatarCircle(
                        imageUrl: comment.authorAvatarUrl,
                        fallbackText: comment.authorUsername,
                        radius: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comment.authorNameOrUsername,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(comment.textContent),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCommentInput() {
    final canSend = _commentController.text.trim().isNotEmpty && !_isSending;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                enabled: !_isSending,
                decoration: const InputDecoration(hintText: 'เขียนคอมเมนต์'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              tooltip: 'ส่งคอมเมนต์',
              onPressed: canSend ? _sendComment : null,
            ),
          ],
        ),
      ),
    );
  }
}
