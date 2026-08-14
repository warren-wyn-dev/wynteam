import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../feed/presentation/widgets/confirm_delete_dialog.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/pop_comment.dart';
import '../../data/pop_repository.dart';

/// Comment bottom sheet for Screen 1 (Pop Feed) -- reuses
/// DropDetailScreen's comment-list-with-Like-and-Delete pattern (WYN-005,
/// post-Debug-round-2), just hosted in a modal sheet instead of a
/// dedicated detail screen, since Pop stays on the vertical feed instead
/// of navigating away. See .wyn/docs/design/wyn-006-pop.md (Screen 1,
/// Comment sheet).
///
/// [onCommentCountChanged] reports the net change (+1 added, -1 removed)
/// so the caller (PopFeedScreen) can keep the feed's Pop.commentCount in
/// sync without a full feed refresh.
Future<void> showPopCommentSheet(
  BuildContext context, {
  required PopRepository popRepository,
  required String popId,
  required ValueChanged<int> onCommentCountChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.65,
      child: PopCommentSheet(
        popRepository: popRepository,
        popId: popId,
        onCommentCountChanged: onCommentCountChanged,
      ),
    ),
  );
}

class PopCommentSheet extends StatefulWidget {
  const PopCommentSheet({
    super.key,
    required this.popRepository,
    required this.popId,
    required this.onCommentCountChanged,
  });

  final PopRepository popRepository;
  final String popId;
  final ValueChanged<int> onCommentCountChanged;

  @override
  State<PopCommentSheet> createState() => _PopCommentSheetState();
}

class _PopCommentSheetState extends State<PopCommentSheet> {
  List<PopComment>? _comments;
  bool _commentsErrored = false;
  final _commentController = TextEditingController();
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
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
      final comments = await widget.popRepository.fetchComments(widget.popId);
      if (!mounted) return;
      setState(() => _comments = comments);
    } catch (_) {
      if (!mounted) return;
      setState(() => _commentsErrored = true);
    }
  }

  // Takes only the id and re-reads the live _comments[index] instead of a
  // PopComment captured at the last build -- same double-tap-safety
  // pattern as DropDetailScreen._toggleCommentLike. See
  // .wyn/learning/PATTERNS.md.
  Future<void> _toggleCommentLike(String commentId) async {
    final comments = _comments;
    if (comments == null) return;
    final index = comments.indexWhere((c) => c.id == commentId);
    if (index == -1) return;

    final previous = comments[index];
    setState(() => _comments![index] = previous.toggledLike());
    try {
      await widget.popRepository.toggleCommentLike(
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
      await widget.popRepository.deleteComment(commentId);
      if (!mounted) return;
      setState(() {
        _comments = _comments?.where((c) => c.id != commentId).toList();
      });
      widget.onCommentCountChanged(-1);
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
      final comment = await widget.popRepository.addComment(
        popId: widget.popId,
        textContent: text,
      );
      if (!mounted) return;
      setState(() {
        _comments = [...?_comments, comment];
        _commentController.clear();
      });
      widget.onCommentCountChanged(1);
    } catch (_) {
      // Keep the typed text in the box so the user can just retry sending.
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('ความคิดเห็น', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(child: _buildCommentList(currentUserId)),
          const Divider(height: 1),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentList(String currentUserId) {
    if (_commentsErrored) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('โหลดคอมเมนต์ไม่สำเร็จ'),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadComments, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    final comments = _comments;
    if (comments == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (comments.isEmpty) {
      return const Center(child: Text('ยังไม่มีคอมเมนต์ เป็นคนแรกสิ!'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Padding(
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
        );
      },
    );
  }

  Widget _buildCommentInput() {
    final canSend =
        _commentController.text.trim().isNotEmpty && !_isSendingComment;

    return Padding(
      padding: const EdgeInsets.all(8),
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
    );
  }
}
