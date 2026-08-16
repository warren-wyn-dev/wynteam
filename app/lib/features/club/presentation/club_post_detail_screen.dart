import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/hashtag_text.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/club_member.dart';
import '../data/club_post.dart';
import '../data/club_post_comment.dart';
import '../data/club_post_repository.dart';
import 'widgets/club_post_card.dart' show ClubPostImages;
import '../../../core/design/wyn_spacing.dart';

/// Placeholder share link -- same "no real hosting/domain yet" caveat as
/// dropShareLink/popShareLink (WYN-005/006).
String clubPostShareLink(String postId) => 'https://wyn.app/club-post/$postId';

/// Club post detail + full comment thread. Mirrors DropDetailScreen
/// (WYN-005) -- Design's Posts tab spec describes the Posts list itself
/// as mirroring DropDetailScreen's comment-list structure, and Product's
/// AC only requires "Comment โพสต์ใน Club ได้" without specifying a new
/// UI paradigm, so the existing Drop pattern (tap the card/comment icon
/// to open a full thread) is the minimal, consistent choice. Unlike
/// Drop, Club post comments have no per-comment like (not specified for
/// WYN-014 -- see ClubPostComment).
class ClubPostDetailScreen extends StatefulWidget {
  const ClubPostDetailScreen({
    super.key,
    required this.clubPostRepository,
    required this.post,
    required this.myRole,
  });

  final ClubPostRepository clubPostRepository;
  final ClubPost post;
  final ClubMemberRole? myRole;

  @override
  State<ClubPostDetailScreen> createState() => _ClubPostDetailScreenState();
}

class _ClubPostDetailScreenState extends State<ClubPostDetailScreen> {
  late ClubPost _post;
  List<ClubPostComment>? _comments;
  bool _commentsErrored = false;
  final _commentController = TextEditingController();
  bool _isSendingComment = false;

  bool get _isOwnPost =>
      _post.authorId == Supabase.instance.client.auth.currentUser!.id;
  bool get _canModerate => widget.myRole?.canModeratePosts ?? false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _comments = null;
      _commentsErrored = false;
    });
    try {
      final comments = await widget.clubPostRepository.fetchComments(_post.id);
      if (!mounted) return;
      setState(() => _comments = comments);
    } catch (_) {
      if (!mounted) return;
      setState(() => _commentsErrored = true);
    }
  }

  Future<void> _toggleLike() async {
    final previous = _post;
    setState(() => _post = _post.toggledLike());
    try {
      await widget.clubPostRepository.toggleLike(
        postId: previous.id,
        currentlyLiked: previous.likedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _post = previous);
    }
  }

  Future<void> _toggleSave() async {
    final previous = _post;
    setState(() => _post = _post.toggledSave());
    try {
      await widget.clubPostRepository.toggleSave(
        postId: previous.id,
        currentlySaved: previous.savedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _post = previous);
    }
  }

  Future<void> _togglePin() async {
    final previous = _post;
    setState(() => _post = _post.toggledPin());
    try {
      await widget.clubPostRepository.togglePin(
        postId: previous.id,
        currentlyPinned: previous.pinned,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _post = previous);
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: clubPostShareLink(_post.id), title: 'โพสต์ใน Club บน WYN'),
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: clubPostShareLink(_post.id)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
    );
  }

  Future<void> _deletePost() async {
    final confirmed = await confirmDeletePost(context);
    if (!confirmed) return;

    try {
      await widget.clubPostRepository.deletePost(_post.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await confirmDeletePost(context, itemLabel: 'คอมเมนต์');
    if (!confirmed) return;

    try {
      await widget.clubPostRepository.deleteComment(commentId);
      if (!mounted) return;
      setState(() {
        _comments = _comments?.where((c) => c.id != commentId).toList();
        _post = _post.withRemovedComment();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบคอมเมนต์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingComment = true);
    try {
      final comment = await widget.clubPostRepository.addComment(
        postId: _post.id,
        textContent: text,
      );
      if (!mounted) return;
      setState(() {
        _comments = [...?_comments, comment];
        _post = _post.withExtraComment();
        _commentController.clear();
      });
    } catch (_) {
      // Keep the typed text so the user can retry.
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('โพสต์'),
        actions: [
          if (_isOwnPost || _canModerate)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'ลบโพสต์',
              onPressed: _deletePost,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(currentUserId)),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildBody(String currentUserId) {
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(WynSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarCircle(
                    imageUrl: _post.authorAvatarUrl,
                    fallbackText: _post.authorUsername,
                    radius: 18,
                  ),
                  const SizedBox(width: WynSpacing.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _post.authorNameOrUsername,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          relativeTimeLabel(_post.createdAt, now: DateTime.now()),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isOwnPost && _canModerate)
                    IconButton(
                      icon: Icon(_post.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                      tooltip: _post.pinned ? 'เลิกปักหมุด' : 'ปักหมุด',
                      onPressed: _togglePin,
                    ),
                ],
              ),
              if (_post.content != null && _post.content!.isNotEmpty) ...[
                const SizedBox(height: WynSpacing.space2),
                HashtagText(_post.content!),
              ],
              if (_post.linkUrl != null && _post.linkUrl!.isNotEmpty) ...[
                const SizedBox(height: WynSpacing.space2),
                Row(
                  children: [
                    const Icon(Icons.link, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_post.linkUrl!)),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (_post.imageUrls != null && _post.imageUrls!.isNotEmpty)
          ClubPostImages(imageUrls: _post.imageUrls!),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
          child: Row(
            children: [
              Semantics(
                label: _post.likedByMe ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ' : 'กดเพื่อถูกใจ',
                excludeSemantics: true,
                child: IconButton(
                  icon: Icon(
                    _post.likedByMe ? Icons.favorite : Icons.favorite_border,
                    color: _post.likedByMe ? Colors.red : null,
                  ),
                  onPressed: _toggleLike,
                ),
              ),
              Text('${_post.likeCount}'),
              const SizedBox(width: WynSpacing.space3),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'แชร์',
                onPressed: _share,
              ),
              IconButton(
                icon: const Icon(Icons.link),
                tooltip: 'คัดลอกลิงก์',
                onPressed: _copyLink,
              ),
              const Spacer(),
              Semantics(
                label: _post.savedByMe ? 'บันทึกแล้ว กดเพื่อเอาออกจาก Saved' : 'กดเพื่อบันทึก',
                excludeSemantics: true,
                child: IconButton(
                  icon: Icon(_post.savedByMe ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: _toggleSave,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );

    if (_commentsErrored) {
      return ListView(
        children: [
          header,
          Padding(
            padding: const EdgeInsets.all(WynSpacing.space6),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('โหลดคอมเมนต์ไม่สำเร็จ'),
                  const SizedBox(height: WynSpacing.space2),
                  TextButton(onPressed: _loadComments, child: const Text('ลองใหม่')),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final comments = _comments;
    if (comments == null) {
      return ListView(
        children: [
          header,
          const Padding(
            padding: EdgeInsets.all(WynSpacing.space6),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: WynSpacing.space4),
      children: [
        header,
        if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(WynSpacing.space6),
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
                  const SizedBox(width: WynSpacing.space2),
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
                  if (comment.authorId == currentUserId)
                    SizedBox(
                      width: WynSpacing.touchTargetMin,
                      height: WynSpacing.touchTargetMin,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'ลบคอมเมนต์',
                        onPressed: () => _deleteComment(comment.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentInput() {
    final canSend = _commentController.text.trim().isNotEmpty && !_isSendingComment;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(WynSpacing.space2),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                enabled: !_isSendingComment,
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
