import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import '../../../core/widgets/action_sheet_row.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/hashtag_text.dart';
import '../../../core/widgets/restriction_banner.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../moderation/data/appeal_status.dart';
import '../../moderation/data/moderation_repository.dart';
import '../../moderation/presentation/appeal_form_screen.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/club_member.dart';
import '../data/club_post.dart';
import '../data/club_post_comment.dart';
import '../data/club_post_repository.dart';
import 'widgets/club_post_card.dart' show ClubPostImages;
import '../../../core/design/wyn_spacing.dart';
import '../../report/data/report_repository.dart';
import '../../report/data/report_target_type.dart';
import '../../report/presentation/report_sheet.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/widgets/wyn_heart_icon.dart';

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
    this.moderationRepository,
    this.appealRepository,
  });

  final ClubPostRepository clubPostRepository;
  final ClubPost post;
  final ClubMemberRole? myRole;

  // Optional -- see DropDetailScreen.moderationRepository's identical
  // doc comment. WYN-029.
  final ModerationRepository? moderationRepository;

  // Same shape again -- WYN-030's appeal entry point on the Restrict banner.
  final AppealRepository? appealRepository;

  @override
  State<ClubPostDetailScreen> createState() => _ClubPostDetailScreenState();
}

class _ClubPostDetailScreenState extends State<ClubPostDetailScreen> {
  late ClubPost _post;
  List<ClubPostComment>? _comments;
  bool _commentsErrored = false;

  /// Comment pagination -- mirrors DropDetailScreen's, see
  /// ClubPostRepository.fetchComments. [_hasMoreComments] is true
  /// whenever the last page came back full, the only signal a range
  /// query gives that there may be more behind it.
  int _commentPage = 0;
  bool _hasMoreComments = false;
  bool _isLoadingMoreComments = false;
  bool _moreCommentsErrored = false;
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _isSendingComment = false;
  // WYN-022: see DropDetailScreen's identical field.
  ClubPostComment? _replyingTo;

  bool get _isOwnPost =>
      _post.authorId == Supabase.instance.client.auth.currentUser!.id;
  bool get _canModerate => widget.myRole?.canModeratePosts ?? false;

  final _reportRepository = ReportRepository(Supabase.instance.client);
  late final ModerationRepository _moderationRepository =
      widget.moderationRepository ?? ModerationRepository(Supabase.instance.client);
  late final AppealRepository _appealRepository =
      widget.appealRepository ?? AppealRepository(Supabase.instance.client);

  // WYN-029 (Restrict) -- see CreateDropScreen's identical fields/doc
  // comment for why this is loaded once, not re-polled.
  String? _restrictReason;
  DateTime? _restrictExpiresAt;
  String? _restrictActionId;
  AppealStatus _restrictAppealStatus = AppealStatus.none;
  bool get _isRestricted => _restrictExpiresAt != null;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
    _loadModerationStatus();
  }

  Future<void> _loadModerationStatus() async {
    try {
      final status = await _moderationRepository.fetchMyStatus();
      if (!mounted) return;
      if (status.isRestricted) {
        setState(() {
          _restrictReason = status.restrictReason;
          _restrictExpiresAt = status.restrictExpiresAt;
          _restrictActionId = status.restrictActionId;
          _restrictAppealStatus = status.restrictAppealStatus;
        });
      }
    } catch (_) {
      // Silent -- see CreateDropScreen's identical method.
    }
  }

  // WYN-030 -- see CreateDropScreen's identical method.
  Future<void> _openAppeal() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppealFormScreen(
          appealRepository: _appealRepository,
          actionId: _restrictActionId!,
          actionLabel: 'จำกัดสิทธิ์ (Restrict)',
        ),
      ),
    );
    if (submitted == true) _loadModerationStatus();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  /// Appends the next page of comments -- see
  /// ClubPostRepository.fetchComments for why paging keeps the reply
  /// nesting correct. Explicit button, not infinite scroll: a thread has
  /// an end the reader is walking towards, unlike a feed. Mirrors
  /// DropDetailScreen._loadMoreComments exactly.
  Future<void> _loadMoreComments() async {
    if (_isLoadingMoreComments) return;
    setState(() {
      _isLoadingMoreComments = true;
      _moreCommentsErrored = false;
    });
    try {
      final nextPage = _commentPage + 1;
      final more = await widget.clubPostRepository
          .fetchComments(_post.id, page: nextPage);
      if (!mounted) return;
      setState(() {
        _comments = [...?_comments, ...more];
        _commentPage = nextPage;
        _hasMoreComments =
            more.length == ClubPostRepository.commentPageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _moreCommentsErrored = true);
    } finally {
      if (mounted) setState(() => _isLoadingMoreComments = false);
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _comments = null;
      _commentsErrored = false;
      _commentPage = 0;
      _hasMoreComments = false;
    });
    try {
      final comments = await widget.clubPostRepository.fetchComments(_post.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _hasMoreComments =
            comments.length == ClubPostRepository.commentPageSize;
      });
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
        parentCommentId: _replyingTo?.id,
      );
      if (!mounted) return;
      setState(() {
        _comments = [...?_comments, comment];
        _post = _post.withExtraComment();
        _commentController.clear();
        _replyingTo = null;
      });
    } catch (_) {
      // Keep the typed text so the user can retry.
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _reportComment(ClubPostComment comment) {
    return showReportSheet(
      context,
      reportRepository: _reportRepository,
      targetType: ReportTargetType.clubPostComment,
      targetId: comment.id,
      targetLabel: 'รายงานคอมเมนต์ของ ${comment.authorNameOrUsername}',
      associatedUserId: comment.authorId,
    );
  }

  // Long-press fallback, additional to the existing own-comment delete
  // icon -- see .wyn/docs/design/wyn-026-report-system.md, Screen 6.
  Future<void> _openCommentMenu(ClubPostComment comment, String currentUserId) async {
    final isOwnComment = comment.authorId == currentUserId;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        if (isOwnComment)
          ActionSheetRow(
            icon: Icons.delete_outline,
            label: 'ลบคอมเมนต์',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _deleteComment(comment.id);
            },
          )
        else
          ActionSheetRow(
            icon: Icons.flag_outlined,
            label: 'รายงานคอมเมนต์',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _reportComment(comment);
            },
          ),
      ]),
    );
  }

  void _startReply(ClubPostComment comment) {
    setState(() => _replyingTo = comment);
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() => setState(() => _replyingTo = null);

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
                  icon: WynHeartIcon(
                    filled: _post.likedByMe,
                    size: 24,
                    // Was `null` -- IconButton's own default, which
                    // resolves to onSurfaceVariant, which is graphite,
                    // which is iconIdle. Naming it changes no pixel and
                    // means the idle heart is the same token here as
                    // everywhere else.
                    color: _post.likedByMe
                        ? WynColors.iconLikeActive
                        : WynColors.iconIdle,
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
          // Each top-level comment immediately followed by its own
          // replies (WYN-022) -- same ordering DropDetailScreen builds.
          for (final comment in comments.where((c) => c.parentCommentId == null)) ...[
            _buildCommentRow(comment, currentUserId, isReply: false),
            for (final reply in comments.where((c) => c.parentCommentId == comment.id))
              _buildCommentRow(reply, currentUserId, isReply: true),
          ],
        if (_hasMoreComments || _moreCommentsErrored)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: WynSpacing.space6, vertical: WynSpacing.space6),
            child: Center(
              child: _isLoadingMoreComments
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      key: const Key('club_post_load_more_comments'),
                      onPressed: _loadMoreComments,
                      child: Text(_moreCommentsErrored
                          ? 'โหลดคอมเมนต์เพิ่มไม่สำเร็จ แตะเพื่อลองใหม่'
                          : 'ดูคอมเมนต์เพิ่มเติม'),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentRow(
    ClubPostComment comment,
    String currentUserId, {
    required bool isReply,
  }) {
    final isOwnComment = comment.authorId == currentUserId;

    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(
          label: isOwnComment ? 'ลบคอมเมนต์' : 'รายงานคอมเมนต์',
        ): () => _openCommentMenu(comment, currentUserId),
      },
      child: GestureDetector(
        onLongPress: () => _openCommentMenu(comment, currentUserId),
        child: Padding(
      padding: EdgeInsets.fromLTRB(isReply ? 52 : 16, 12, 16, 0),
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
                if (!isReply)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: InkWell(
                      onTap: () => _startReply(comment),
                      child: Text(
                        'ตอบกลับ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
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
    );
  }

  Widget _buildCommentInput() {
    final canSend = _commentController.text.trim().isNotEmpty &&
        !_isSendingComment &&
        !_isRestricted;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(WynSpacing.space2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRestricted)
              RestrictionBanner(
                reason: _restrictReason,
                expiresAt: _restrictExpiresAt,
                actionId: _restrictActionId,
                appealStatus: _restrictAppealStatus,
                onAppeal: _openAppeal,
              ),
            if (_replyingTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ตอบกลับ ${_replyingTo!.authorNameOrUsername}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: WynSpacing.space1),
                    InkWell(
                      onTap: _cancelReply,
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
            Row(
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
                Semantics(
                  label: _isRestricted ? 'ส่งคอมเมนต์ ปิดใช้งานเนื่องจากบัญชีถูกจำกัดการโพสต์ชั่วคราว' : null,
                  excludeSemantics: _isRestricted,
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    tooltip: 'ส่งคอมเมนต์',
                    onPressed: canSend ? _sendComment : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
