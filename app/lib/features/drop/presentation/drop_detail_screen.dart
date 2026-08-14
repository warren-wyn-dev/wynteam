import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/drop.dart';
import '../data/drop_comment.dart';
import '../data/drop_repository.dart';
import 'widgets/confirm_delete_drop_dialog.dart';

/// Placeholder share link -- there's no real hosting/domain yet (see
/// .wyn/tasks/active/WYN-005-drop-post-image.md Risks). Not a reachable
/// URL; revisit once Founder confirms a real domain before Deploy.
String dropShareLink(String dropId) => 'https://wyn.app/drop/$dropId';

/// Screen 3 — Drop Detail (Comments).
/// See .wyn/docs/design/wyn-005-drop.md
class DropDetailScreen extends StatefulWidget {
  const DropDetailScreen({
    super.key,
    required this.dropRepository,
    required this.drop,
  });

  final DropRepository dropRepository;
  final Drop drop;

  @override
  State<DropDetailScreen> createState() => _DropDetailScreenState();
}

class _DropDetailScreenState extends State<DropDetailScreen> {
  late Drop _drop;
  // Held as a mutable list (not a cached Future) so individual comments
  // can be optimistically updated (Like) without re-fetching everything.
  // null while the initial load is in flight.
  List<DropComment>? _comments;
  bool _commentsErrored = false;
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _drop = widget.drop;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _comments = null;
      _commentsErrored = false;
    });
    try {
      final comments = await widget.dropRepository.fetchComments(_drop.id);
      if (!mounted) return;
      setState(() => _comments = comments);
    } catch (_) {
      if (!mounted) return;
      setState(() => _commentsErrored = true);
    }
  }

  Future<void> _toggleLike() async {
    final previous = _drop;
    setState(() => _drop = _drop.toggledLike());
    try {
      await widget.dropRepository.toggleLike(
        dropId: previous.id,
        currentlyLiked: previous.likedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _drop = previous);
    }
  }

  Future<void> _toggleSave() async {
    final previous = _drop;
    setState(() => _drop = _drop.toggledSave());
    try {
      await widget.dropRepository.toggleSave(
        dropId: previous.id,
        currentlySaved: previous.savedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _drop = previous);
    }
  }

  // Takes only the id and re-reads the live _comments[index] instead of a
  // DropComment captured at the last build -- see
  // .wyn/learning/PATTERNS.md and .wyn/tasks/bugs/WYN-004-feed-and-post.md
  // (QA round 1) for the bug class this guards against: a rapid
  // double-tap before the next rebuild would otherwise reuse the same
  // stale pre-toggle state twice.
  Future<void> _toggleCommentLike(String commentId) async {
    final comments = _comments;
    if (comments == null) return;
    final index = comments.indexWhere((c) => c.id == commentId);
    if (index == -1) return;

    final previous = comments[index];
    setState(() => _comments![index] = previous.toggledLike());
    try {
      await widget.dropRepository.toggleCommentLike(
        commentId: commentId,
        currentlyLiked: previous.likedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _comments![index] = previous);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await confirmDeletePost(context, itemLabel: 'คอมเมนต์');
    if (!confirmed) return;

    try {
      await widget.dropRepository.deleteComment(commentId);
      if (!mounted) return;
      setState(() {
        _comments = _comments?.where((c) => c.id != commentId).toList();
        _drop = _drop.withRemovedComment();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบคอมเมนต์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: dropShareLink(_drop.id),
        title: 'Drop บน WYN',
      ),
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: dropShareLink(_drop.id)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
    );
  }

  Future<void> _deleteDrop() async {
    final confirmed = await confirmDeleteDrop(context);
    if (!confirmed) return;

    try {
      await widget.dropRepository.deleteDrop(_drop.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบ Drop ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingComment = true);
    try {
      final comment = await widget.dropRepository.addComment(
        dropId: _drop.id,
        textContent: text,
      );
      if (!mounted) return;
      setState(() {
        _comments = [...?_comments, comment];
        _drop = _drop.withExtraComment();
        _commentController.clear();
      });
    } catch (_) {
      // Keep the typed text in the box so the user can just retry sending.
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Drop')),
      body: Column(
        children: [
          Expanded(child: _buildBody(currentUserId)),
          _buildCommentInput(),
        ],
      ),
    );
  }

  // The Drop header (image, caption, interaction row) and the comment
  // list are scrolled together as one list -- see WYN-004's
  // PostDetailScreen fix for why: a fixed-height header above a
  // separately-scrolled comment list overflows on a short/wide viewport
  // instead of just scrolling out of view.
  Widget _buildBody(String currentUserId) {
    final isOwnDrop = _drop.authorId == currentUserId;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Image.network(_drop.imageUrl, fit: BoxFit.cover),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarCircle(
                    imageUrl: _drop.authorAvatarUrl,
                    fallbackText: _drop.authorUsername,
                    radius: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _drop.authorNameOrUsername,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (isOwnDrop)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'ลบ Drop',
                      onPressed: _deleteDrop,
                    ),
                ],
              ),
              if (_drop.caption != null && _drop.caption!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_drop.caption!),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Semantics(
                    label: _drop.likedByMe
                        ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ'
                        : 'กดเพื่อถูกใจ',
                    excludeSemantics: true,
                    child: IconButton(
                      icon: Icon(
                        _drop.likedByMe ? Icons.favorite : Icons.favorite_border,
                        color: _drop.likedByMe ? Colors.red : null,
                      ),
                      onPressed: _toggleLike,
                    ),
                  ),
                  Text('${_drop.likeCount}'),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.mode_comment_outlined),
                    tooltip: 'ความคิดเห็น',
                    onPressed: () => _commentFocusNode.requestFocus(),
                  ),
                  Text('${_drop.commentCount}'),
                  const SizedBox(width: 12),
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
                    label: _drop.savedByMe
                        ? 'บันทึกแล้ว กดเพื่อเอาออกจาก Saved'
                        : 'กดเพื่อบันทึก',
                    excludeSemantics: true,
                    child: IconButton(
                      icon: Icon(
                        _drop.savedByMe ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      onPressed: _toggleSave,
                    ),
                  ),
                ],
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
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('โหลดคอมเมนต์ไม่สำเร็จ'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadComments,
                    child: const Text('ลองใหม่'),
                  ),
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
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        header,
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
                  if (comment.authorId == currentUserId)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'ลบคอมเมนต์',
                        onPressed: () => _deleteComment(comment.id),
                      ),
                    ),
                  Column(
                    children: [
                      Semantics(
                        label: comment.likedByMe
                            ? 'ถูกใจคอมเมนต์นี้แล้ว กดเพื่อเลิกถูกใจ'
                            : 'กดเพื่อถูกใจคอมเมนต์นี้',
                        excludeSemantics: true,
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            icon: Icon(
                              comment.likedByMe
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: comment.likedByMe ? Colors.red : null,
                            ),
                            onPressed: () => _toggleCommentLike(comment.id),
                          ),
                        ),
                      ),
                      if (comment.likeCount > 0)
                        Text(
                          '${comment.likeCount}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentInput() {
    final canSend =
        _commentController.text.trim().isNotEmpty && !_isSendingComment;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
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
