import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/hashtag_text.dart';
import '../../../core/widgets/restriction_banner.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/shared_content_type.dart';
import '../../chat/presentation/share_sheet.dart';
import '../../follow/data/follow_repository.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../moderation/data/appeal_status.dart';
import '../../moderation/data/moderation_repository.dart';
import '../../moderation/presentation/appeal_form_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../saved/data/saved_repository.dart';
import '../data/drop.dart';
import '../data/drop_comment.dart';
import '../data/drop_repository.dart';
import 'widgets/confirm_delete_drop_dialog.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../report/data/report_repository.dart';
import '../../report/data/report_target_type.dart';
import '../../report/presentation/report_sheet.dart';

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
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
    required this.drop,
    this.moderationRepository,
    this.appealRepository,
    this.chatRepository,
  });

  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final Drop drop;

  // Optional -- defaults to a real Supabase-backed instance (see
  // _DropDetailScreenState's late final below), same "existing call
  // sites don't need to thread one through" shape as every other
  // optional repository param in this app. Tests inject a Recording*
  // fake here instead of touching Supabase.instance. WYN-029.
  final ModerationRepository? moderationRepository;

  // Same shape again -- WYN-030's appeal entry point on the Restrict banner.
  final AppealRepository? appealRepository;

  // Same shape again -- WYN-033's "แชร์เข้า Chat" option on the share sheet.
  final ChatRepository? chatRepository;

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
  // WYN-022: set while composing a reply to a top-level comment; null
  // means the next send is a new top-level comment.
  DropComment? _replyingTo;

  // Whether the *current viewer* follows the Drop's author -- null until
  // the real status has loaded from the backend. The Follow button is
  // hidden while null rather than defaulting to "not following", so it
  // never briefly shows the wrong state (this is exactly the bug
  // PopClipView's WYN-006 Follow button had before WYN-008). See
  // .wyn/docs/design/wyn-008-follow.md, Screen 1.
  bool? _isFollowing;

  final _reportRepository = ReportRepository(Supabase.instance.client);
  late final ModerationRepository _moderationRepository =
      widget.moderationRepository ?? ModerationRepository(Supabase.instance.client);
  late final AppealRepository _appealRepository =
      widget.appealRepository ?? AppealRepository(Supabase.instance.client);
  late final ChatRepository _chatRepository =
      widget.chatRepository ?? ChatRepository(Supabase.instance.client);

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
    _drop = widget.drop;
    _loadComments();
    _loadModerationStatus();
    if (_drop.authorId != Supabase.instance.client.auth.currentUser!.id) {
      _loadFollowStatus();
    }
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

  Future<void> _loadFollowStatus() async {
    try {
      final isFollowing = await widget.followRepository.isFollowing(
        userId: _drop.authorId,
      );
      if (!mounted) return;
      setState(() => _isFollowing = isFollowing);
    } catch (_) {
      // Leave _isFollowing null -- the button stays hidden rather than
      // showing a possibly-wrong state.
    }
  }

  Future<void> _toggleFollow() async {
    final previous = _isFollowing;
    if (previous == null) return;
    setState(() => _isFollowing = !previous);
    try {
      await widget.followRepository.toggleFollow(
        userId: _drop.authorId,
        currentlyFollowing: previous,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFollowing = previous);
    }
  }

  void _openAuthorProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: _drop.authorId,
        ),
      ),
    );
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

  Future<void> _openShareSheet() async {
    await showShareSheet(
      context,
      chatRepository: _chatRepository,
      profileRepository: widget.profileRepository,
      sharedContentType: SharedContentType.drop,
      sharedContentId: _drop.id,
      previewLabel: 'แชร์ Drop',
      nativeShareText: dropShareLink(_drop.id),
      nativeShareTitle: 'Drop บน WYN',
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: dropShareLink(_drop.id)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
    );
  }

  Future<void> _reportDrop() {
    return showReportSheet(
      context,
      reportRepository: _reportRepository,
      targetType: ReportTargetType.drop,
      targetId: _drop.id,
      targetLabel: 'รายงานโพสต์ของ ${_drop.authorNameOrUsername}',
      associatedUserId: _drop.authorId,
    );
  }

  Future<void> _openDropMoreMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('รายงานโพสต์'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _reportDrop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportComment(DropComment comment) {
    return showReportSheet(
      context,
      reportRepository: _reportRepository,
      targetType: ReportTargetType.dropComment,
      targetId: comment.id,
      targetLabel: 'รายงานคอมเมนต์ของ ${comment.authorNameOrUsername}',
      associatedUserId: comment.authorId,
    );
  }

  // Long-press fallback for both "ลบคอมเมนต์"/"รายงานคอมเมนต์" -- the
  // existing delete icon (own comments only) stays as-is; this is an
  // additional entry point, not a replacement, per
  // .wyn/docs/design/wyn-026-report-system.md, Screen 5.
  Future<void> _openCommentMenu(DropComment comment, String currentUserId) async {
    final isOwnComment = comment.authorId == currentUserId;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (isOwnComment)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('ลบคอมเมนต์'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _deleteComment(comment.id);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('รายงานคอมเมนต์'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _reportComment(comment);
                },
              ),
          ],
        ),
      ),
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
        parentCommentId: _replyingTo?.id,
      );
      if (!mounted) return;
      setState(() {
        _comments = [...?_comments, comment];
        _drop = _drop.withExtraComment();
        _commentController.clear();
        _replyingTo = null;
      });
    } catch (_) {
      // Keep the typed text in the box so the user can just retry sending.
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  void _startReply(DropComment comment) {
    setState(() => _replyingTo = comment);
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() => setState(() => _replyingTo = null);

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
          padding: const EdgeInsets.all(WynSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _openAuthorProfile,
                      borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                      child: Row(
                        children: [
                          AvatarCircle(
                            imageUrl: _drop.authorAvatarUrl,
                            fallbackText: _drop.authorUsername,
                            radius: 18,
                          ),
                          const SizedBox(width: WynSpacing.space2),
                          Expanded(
                            child: Text(
                              _drop.authorNameOrUsername,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isOwnDrop && _isFollowing != null)
                    Semantics(
                      label: _isFollowing!
                          ? 'กำลังติดตาม กดเพื่อเลิกติดตาม'
                          : 'กดเพื่อติดตาม',
                      excludeSemantics: true,
                      child: SizedBox(
                        height: WynSpacing.touchTargetMin,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: _toggleFollow,
                          child: Text(_isFollowing! ? 'กำลังติดตาม' : 'ติดตาม'),
                        ),
                      ),
                    ),
                  if (isOwnDrop)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'ลบ Drop',
                      onPressed: _deleteDrop,
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'เพิ่มเติม',
                      onPressed: _openDropMoreMenu,
                    ),
                ],
              ),
              if (_drop.caption != null && _drop.caption!.isNotEmpty) ...[
                const SizedBox(height: WynSpacing.space2),
                HashtagText(_drop.caption!),
              ],
              const SizedBox(height: WynSpacing.space3),
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
                  const SizedBox(width: WynSpacing.space3),
                  IconButton(
                    icon: const Icon(Icons.mode_comment_outlined),
                    tooltip: 'ความคิดเห็น',
                    onPressed: () => _commentFocusNode.requestFocus(),
                  ),
                  Text('${_drop.commentCount}'),
                  const SizedBox(width: WynSpacing.space3),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'แชร์',
                    onPressed: _openShareSheet,
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
            padding: const EdgeInsets.all(WynSpacing.space6),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('โหลดคอมเมนต์ไม่สำเร็จ'),
                  const SizedBox(height: WynSpacing.space2),
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
          // replies (WYN-022) -- one flat fetch already returns every
          // comment for this Drop, so this just orders them for display
          // rather than issuing a second query.
          for (final comment in comments.where((c) => c.parentCommentId == null)) ...[
            _buildCommentRow(comment, currentUserId, isReply: false),
            for (final reply in comments.where((c) => c.parentCommentId == comment.id))
              _buildCommentRow(reply, currentUserId, isReply: true),
          ],
      ],
    );
  }

  Widget _buildCommentRow(DropComment comment, String currentUserId, {required bool isReply}) {
    final isOwnComment = comment.authorId == currentUserId;

    return Semantics(
      // A CustomSemanticsAction gives screen-reader users a way to reach
      // the report/delete menu without needing the long-press gesture
      // itself -- see .wyn/docs/design/wyn-026-report-system.md, Screen 5.
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
                // Replies don't get their own "ตอบกลับ" button -- that's
                // what keeps nesting to one level in the UI (the DB
                // trigger is the real enforcement either way).
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
          Column(
            children: [
              Semantics(
                label: comment.likedByMe
                    ? 'ถูกใจคอมเมนต์นี้แล้ว กดเพื่อเลิกถูกใจ'
                    : 'กดเพื่อถูกใจคอมเมนต์นี้',
                excludeSemantics: true,
                child: SizedBox(
                  width: WynSpacing.touchTargetMin,
                  height: WynSpacing.touchTargetMin,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(
                      comment.likedByMe ? Icons.favorite : Icons.favorite_border,
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
