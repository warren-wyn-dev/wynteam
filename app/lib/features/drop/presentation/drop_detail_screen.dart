import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/action_sheet_row.dart';
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
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../saved/data/saved_repository.dart';
import '../data/drop.dart';
import '../data/drop_comment.dart';
import '../data/drop_repository.dart';
import 'edit_drop_caption_screen.dart';
import 'quote_redrop_screen.dart';
import 'widgets/confirm_delete_drop_dialog.dart';
import 'widgets/drop_image_gallery.dart';
import 'widgets/poll_card.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/text_utils.dart';
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

  /// Comment pagination (see [_loadMoreComments]). [_hasMoreComments] is
  /// true whenever the last page came back full, which is the only
  /// signal a range query gives that there may be more behind it.
  int _commentPage = 0;
  bool _hasMoreComments = false;
  bool _isLoadingMoreComments = false;
  bool _moreCommentsErrored = false;
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

  // WYN-038: guards recordView() to fire at most once per screen open --
  // mirrors PopClipView's _viewRecorded exactly.
  bool _viewRecorded = false;

  // 07-post-detail.tsx: the comment composer shows the *current viewer's*
  // own avatar, not the Drop author's -- null until loaded, same
  // "AvatarCircle falls back to a letter, never a broken image" posture
  // as every other avatar on this screen.
  Profile? _myProfile;

  bool get _isOwnDrop =>
      _drop.authorId == Supabase.instance.client.auth.currentUser!.id;

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
    _loadMyProfile();
    if (_drop.authorId != Supabase.instance.client.auth.currentUser!.id) {
      _loadFollowStatus();
    }
    // Deferred one microtask past initState() -- same "setState() only
    // ever fires after an async gap" posture PopClipView's own
    // _recordViewOnce() has (there, the gap is `await
    // controller.initialize()`; a Drop has no equivalent async load
    // step, so a microtask stands in for it) rather than calling
    // setState() synchronously while this State is still being built.
    Future.microtask(_recordViewOnce);
  }

  Future<void> _loadMyProfile() async {
    try {
      final profile = await widget.profileRepository
          .fetchProfile(Supabase.instance.client.auth.currentUser!.id);
      if (!mounted) return;
      setState(() => _myProfile = profile);
    } catch (_) {
      // Leave it null -- the composer avatar just stays a placeholder
      // letter, same posture as every other best-effort fetch here.
    }
  }

  // WYN-038: opening DropDetailScreen is what counts as a "View" (not
  // just a Home Feed card scrolling past) -- mirrors PopClipView's
  // _recordViewOnce() exactly.
  //
  // WYN-083 (Wynos V1.0.0 Beta2, item 21): Founder wants the Drop's own
  // author counted too ("รวมถึงเจ้าของโพสต์ด้วย") -- the old
  // `if (_isOwnDrop) return;` skip here (and the matching server-side
  // exclusion in record_drop_view()) is gone, bringing this in line
  // with PopClipView's own _recordViewOnce(), which never had an
  // owner-skip in the first place.
  void _recordViewOnce() {
    if (!mounted || _viewRecorded) return;
    _viewRecorded = true;
    setState(() => _drop = _drop.withExtraView());
    widget.dropRepository.recordView(_drop.id).catchError((_) {
      // A failed view-count RPC isn't worth surfacing to the user --
      // the optimistic UI bump already happened and isn't rolled back,
      // same posture as PopClipView._recordViewOnce().
    });
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
      _commentPage = 0;
      _hasMoreComments = false;
    });
    try {
      final comments = await widget.dropRepository.fetchComments(_drop.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _hasMoreComments =
            comments.length == DropRepository.commentPageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _commentsErrored = true);
    }
  }

  /// Appends the next page of comments (see
  /// [DropRepository.fetchComments], which explains why paging keeps the
  /// reply nesting correct). Explicit button rather than infinite scroll:
  /// a comment thread has an end the reader is walking towards, unlike
  /// the feed.
  Future<void> _loadMoreComments() async {
    if (_isLoadingMoreComments) return;
    setState(() {
      _isLoadingMoreComments = true;
      _moreCommentsErrored = false;
    });
    try {
      final nextPage = _commentPage + 1;
      final more =
          await widget.dropRepository.fetchComments(_drop.id, page: nextPage);
      if (!mounted) return;
      setState(() {
        _comments = [...?_comments, ...more];
        _commentPage = nextPage;
        _hasMoreComments = more.length == DropRepository.commentPageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _moreCommentsErrored = true);
    } finally {
      if (mounted) setState(() => _isLoadingMoreComments = false);
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

  Future<void> _votePoll(int optionIndex) async {
    final previous = _drop;
    final pollId = previous.pollId;
    if (pollId == null) return;
    setState(() => _drop = _drop.votedPoll(optionIndex));
    try {
      await widget.dropRepository.votePoll(
        pollId: pollId,
        optionIndex: optionIndex,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _drop = previous);
    }
  }

  Future<void> _toggleRedrop() async {
    final previous = _drop;
    setState(() => _drop = _drop.toggledRedrop());
    try {
      await widget.dropRepository.toggleRedrop(
        dropId: previous.id,
        currentlyRedropped: previous.redroppedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _drop = previous);
    }
  }

  Future<void> _openRedropSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(_drop.redroppedByMe ? 'ยกเลิกรีโพสต์' : '🔄 รีโพสต์'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _toggleRedrop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('💬 Quote รีโพสต์'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final posted = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => QuoteRedropScreen(
                      dropRepository: widget.dropRepository,
                      drop: _drop,
                    ),
                  ),
                );
                if (posted == true && mounted) {
                  setState(() => _drop = _drop.withExtraRedrop());
                }
              },
            ),
          ],
        ),
      ),
    );
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
      previewLabel: 'แชร์โพสต์',
      nativeShareText: dropShareLink(_drop.id),
      nativeShareTitle: 'โพสต์บน WYN',
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
      builder: (sheetContext) => ActionSheetBody(rows: [
        ActionSheetRow(
          icon: Icons.flag_outlined,
          label: 'รายงานโพสต์',
          onTap: () {
            Navigator.of(sheetContext).pop();
            _reportDrop();
          },
        ),
      ]),
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
        const SnackBar(content: Text('ลบโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  /// WYN-037: 30 minutes, matching `edit_drop()`'s own server-side
  /// window -- this is only a UI convenience (hide the "แก้ไข" option
  /// once it would just fail server-side); the real enforcement is the
  /// RPC's own check, not this client-side clock read.
  static const _editWindow = Duration(minutes: 30);

  bool get _canEditDrop =>
      DateTime.now().difference(_drop.createdAt) < _editWindow;

  Future<void> _openOwnDropMoreMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        if (_canEditDrop)
          ActionSheetRow(
            icon: Icons.edit_outlined,
            label: 'แก้ไข',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _editDrop();
            },
          ),
        ActionSheetRow(
          icon: Icons.delete_outline,
          label: 'ลบ',
          color: Theme.of(sheetContext).colorScheme.error,
          onTap: () {
            Navigator.of(sheetContext).pop();
            _deleteDrop();
          },
        ),
      ]),
    );
  }

  Future<void> _editDrop() async {
    final newCaption = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EditDropCaptionScreen(
          dropRepository: widget.dropRepository,
          dropId: _drop.id,
          initialCaption: _drop.caption,
          isPollQuestion: _drop.isPoll,
          hasImage: _drop.imageUrl != null,
        ),
      ),
    );
    if (newCaption == null || !mounted) return;
    setState(() {
      _drop = _drop.withEditedCaption(newCaption.isEmpty ? null : newCaption);
    });
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
      backgroundColor: WynColors.paper,
      // Beta3: the title bar is a *sliver* inside the post's own scroll
      // view now (see [_buildAppBarSliver]), not a Scaffold `appBar:`
      // pinned above it -- Founder: the post "เห็นแค่ประมาณครึ่งเดียว...
      // ไม่สามารถเลื่อนขึ้นไปใช้พื้นที่ได้เต็มที่". A permanently fixed
      // 57px strip is exactly that: viewport this screen never gets
      // back, on the one screen whose entire job is showing one post as
      // large as it will go. The composer below stays fixed, because a
      // text field you have to scroll to reach is a worse trade.
      body: Column(
        children: [
          Expanded(child: _buildBody(currentUserId)),
          _buildCommentInput(),
        ],
      ),
    );
  }

  /// The screen's title bar, as the first sliver of the post's own
  /// scroll view: it scrolls away with the post's author row on the way
  /// down and comes straight back on the first upward flick
  /// (`floating` + `snap`), so the back affordance is never more than
  /// one gesture away while the reader gets the full viewport for
  /// reading.
  Widget _buildAppBarSliver() {
    return SliverAppBar(
      backgroundColor: WynColors.paper,
      surfaceTintColor: WynColors.paper,
      floating: true,
      snap: true,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'โพสต์',
        style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink),
      ),
      titleSpacing: 0,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: WynColors.hairline),
      ),
    );
  }

  /// Every part of this screen -- title bar, author row, caption,
  /// media, stat line, action bar, comments -- in one scroll view, so
  /// they move together as one continuous page rather than as a fixed
  /// frame around a scrolling middle.
  ///
  /// [SliverChildListDelegate] rather than a builder because these
  /// children are already built eagerly by the callers below (exactly
  /// as `ListView(children: ...)`, which this replaces, always did) --
  /// this is a change of scroll *structure*, not of what gets built.
  Widget _buildScrollView(List<Widget> children) {
    return CustomScrollView(
      slivers: [
        _buildAppBarSliver(),
        SliverList(delegate: SliverChildListDelegate(children)),
      ],
    );
  }

  // The Drop header (image, caption, interaction row) and the comment
  // list are scrolled together as one list -- see WYN-004's
  // PostDetailScreen fix for why: a fixed-height header above a
  // separately-scrolled comment list overflows on a short/wide viewport
  // instead of just scrolling out of view.
  Widget _buildBody(String currentUserId) {
    final isOwnDrop = _isOwnDrop;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // WYN-086 (Wynos V1.0.0 Beta2, item 25): the author row + caption
        // now come before the image/poll, not after -- Founder: "อยากให้
        // ข้อความที่โพสต์อยู่ด้านบน ส่วนรูปอยู่ด้านล่าง". Used to be one
        // Padding/Column holding author row + caption + _buildStatLine,
        // placed *after* the image/poll -- split in two so the
        // image/poll can sit between caption and stat line instead.
        // WYNOS V1.0.0 Beta requirement 2: a caption-only Drop has no
        // image area at all -- its caption still renders here the same
        // way either way.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WynSpacing.space4, WynSpacing.space4, WynSpacing.space4, WynSpacing.space2,
          ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AvatarCircle(
                            imageUrl: _drop.authorAvatarUrl,
                            fallbackText: _drop.authorUsername,
                            radius: 22,
                            ring: true,
                          ),
                          const SizedBox(width: WynSpacing.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _drop.authorDisplayName ??
                                            _drop.authorUsername,
                                        overflow: TextOverflow.ellipsis,
                                        style: _textStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: WynColors.ink,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: WynSpacing.space2),
                                    Flexible(
                                      child: Text(
                                        // WYN-098, Design spec Screen 4:
                                        // same "appended to the time
                                        // text, not a new row" treatment
                                        // as HomeDropCard's identical
                                        // spot -- see that file's own
                                        // comment.
                                        _drop.location != null
                                            ? '${relativeTimeLabel(_drop.createdAt, now: DateTime.now())} · 📍 ${_drop.location}'
                                            : relativeTimeLabel(_drop.createdAt,
                                                now: DateTime.now()),
                                        overflow: TextOverflow.ellipsis,
                                        style: _textStyle(
                                            fontSize: 13,
                                            color: WynColors.mutedNeutral),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '@${_drop.authorUsername}',
                                  style: _textStyle(
                                      fontSize: 13, color: WynColors.mutedNeutral),
                                ),
                                if (_drop.wasEdited)
                                  Text(
                                    'แก้ไขแล้ว',
                                    style: _textStyle(
                                        fontSize: 13, color: WynColors.faint),
                                  ),
                              ],
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
                            foregroundColor: WynColors.sapphire,
                            side: const BorderSide(color: WynColors.sapphire),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: _toggleFollow,
                          child: Text(_isFollowing! ? 'กำลังติดตาม' : 'ติดตาม'),
                        ),
                      ),
                    ),
                  if (isOwnDrop)
                    IconButton(
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: WynColors.faint),
                      tooltip: 'เพิ่มเติม',
                      onPressed: _openOwnDropMoreMenu,
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: WynColors.faint),
                      tooltip: 'เพิ่มเติม',
                      onPressed: _openDropMoreMenu,
                    ),
                ],
              ),
              if (_drop.caption != null && _drop.caption!.isNotEmpty) ...[
                const SizedBox(height: WynSpacing.space3),
                // 07-post-detail.tsx: the focused post's own text renders
                // larger (16px) than a feed row's 14.5px -- a permalink
                // view is the one place a single post has the whole
                // screen to itself.
                HashtagText(
                  _drop.caption!,
                  style: _textStyle(fontSize: 16, color: WynColors.ink, height: 1.5),
                ),
              ],
            ],
          ),
        ),
        if (_drop.isPoll)
          PollCard(
            options: _drop.pollOptions!,
            expiresAt: _drop.pollExpiresAt!,
            myVoteIndex: _drop.pollMyVoteIndex,
            totalVotes: _drop.pollTotalVotes,
            optionCounts: _drop.pollOptionCounts,
            isOwnPoll: isOwnDrop,
            onVote: _votePoll,
          )
        else if (_drop.imageUrl != null)
          DropImageGallery(
            drop: _drop,
            dropRepository: widget.dropRepository,
            onLike: _toggleLike,
            onDropChanged: (updated) => setState(() => _drop = updated),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WynSpacing.space4, WynSpacing.space3, WynSpacing.space4, WynSpacing.space2,
          ),
          child: _buildStatLine(),
        ),
        _buildFocusedActionBar(),
      ],
    );

    if (_commentsErrored) {
      return _buildScrollView(
        [
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
      return _buildScrollView(
        [
          header,
          const Padding(
            padding: EdgeInsets.all(WynSpacing.space6),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return _buildScrollView(
      [
        header,
        if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(WynSpacing.space6),
            child: Center(child: Text('ยังไม่มีคอมเมนต์ เป็นคนแรกสิ!')),
          )
        else ...[
          // Each top-level comment immediately followed by its own
          // replies (WYN-022) -- one flat fetch already returns every
          // comment for this Drop, so this just orders them for display
          // rather than issuing a second query. 07-post-detail.tsx: a
          // hairline divider between comments, never after the last one.
          for (final (index, comment)
              in comments.where((c) => c.parentCommentId == null).indexed) ...[
            if (index > 0) const Divider(height: 1, color: WynColors.hairline),
            _buildCommentRow(comment, currentUserId, isReply: false),
            for (final reply in comments.where((c) => c.parentCommentId == comment.id))
              _buildCommentRow(reply, currentUserId, isReply: true),
          ],
          // "That's all of them" is only true once there is nothing
          // left to page in -- otherwise the reader gets the button.
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
                        key: const Key('drop_detail_load_more_comments'),
                        onPressed: _loadMoreComments,
                        child: Text(_moreCommentsErrored
                            ? 'โหลดคอมเมนต์เพิ่มไม่สำเร็จ แตะเพื่อลองใหม่'
                            : 'ดูคอมเมนต์เพิ่มเติม'),
                      ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: WynSpacing.space6, vertical: WynSpacing.space8),
              child: Center(
                child: Text(
                  'ไม่มีความคิดเห็นเพิ่มเติมแล้ว',
                  style: _textStyle(fontSize: 13, color: WynColors.faint),
                ),
              ),
            ),
        ],
        // Replaces the bottom padding the ListView this replaced
        // carried, so the last comment still clears the composer.
        const SizedBox(height: WynSpacing.space4),
      ],
    );
  }

  /// 07-post-detail.tsx: engagement shown as a plain-language stat line
  /// under the caption -- "for reading" -- distinct from the tappable
  /// icon row below ("for acting", see [_buildFocusedActionBar]). The
  /// view-count Semantics label moves here from the old icon row
  /// (07-post-detail.tsx's own FocusedActionBar has no separate views
  /// icon at all -- views only ever appears in this stat line).
  ///
  /// Founder decision (2026-08-29): the reference's own stat line omits
  /// a comment count entirely (likes/ReDrop/views only) -- but the real
  /// app previously showed one, and there's no other number on this
  /// screen a viewer could read it from (the reference's own comment
  /// thread just below makes the count visually redundant there; the
  /// real app's comment thread paginates/scrolls, so it doesn't). Kept
  /// here, one segment beyond the reference's own 3.
  Widget _buildStatLine() {
    TextSpan countSpan(int count, String label) => TextSpan(children: [
          TextSpan(
            text: '$count',
            style: _textStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: WynColors.ink),
          ),
          TextSpan(text: ' $label'),
        ]);

    return DefaultTextStyle.merge(
      style: _textStyle(fontSize: 13, color: WynColors.graphite),
      child: Row(
        children: [
          Text.rich(countSpan(_drop.likeCount, 'ถูกใจ')),
          const Text(' · '),
          Text.rich(countSpan(_drop.commentCount, 'คอมเมนต์')),
          const Text(' · '),
          Text.rich(countSpan(_drop.redropCount, 'รีโพสต์')),
          const Text(' · '),
          Semantics(
            label: 'เข้าชมแล้ว ${_drop.viewCount} ครั้ง',
            excludeSemantics: true,
            child: Text.rich(countSpan(_drop.viewCount, 'การเข้าชม')),
          ),
        ],
      ),
    );
  }

  /// 07-post-detail.tsx's FocusedActionBar -- 5 equally-spaced, icon-only
  /// buttons (counts live in [_buildStatLine] instead, "acting" not
  /// "reading") between two hairline borders. Copy-link folds into
  /// [_openShareSheet]'s own sheet instead of a 6th icon here -- see
  /// share_sheet.dart's own doc comment.
  Widget _buildFocusedActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: WynColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: _drop.likedByMe
                  ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ'
                  : 'กดเพื่อถูกใจ',
              excludeSemantics: true,
              child: IconButton(
                icon: Icon(
                  _drop.likedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 19,
                  color: _drop.likedByMe ? Colors.red : WynColors.graphite,
                ),
                onPressed: _toggleLike,
              ),
            ),
          ),
          Expanded(
            child: IconButton(
              icon: const Icon(Icons.mode_comment_outlined,
                  size: 19, color: WynColors.graphite),
              tooltip: 'ความคิดเห็น',
              onPressed: () => _commentFocusNode.requestFocus(),
            ),
          ),
          // WYN-097, Design spec Screen 6: same "hide entirely, not
          // disable" posture as HomeDropCard's identical guard (see
          // that file's own comment) -- the remaining buttons simply
          // re-space themselves evenly across the bar (still
          // `Expanded`, just one fewer of them).
          if (_drop.audience == AudienceOption.everyone)
            Expanded(
              child: Semantics(
                label: _drop.redroppedByMe
                    ? 'รีโพสต์แล้ว กดเพื่อเลือกดำเนินการ'
                    : 'กดเพื่อรีโพสต์',
                excludeSemantics: true,
                child: IconButton(
                  icon: Icon(
                    Icons.repeat,
                    size: 19,
                    color:
                        _drop.redroppedByMe ? WynColors.sapphire : WynColors.graphite,
                  ),
                  onPressed: _openRedropSheet,
                ),
              ),
            ),
          Expanded(
            child: IconButton(
              icon: const Icon(Icons.share_outlined,
                  size: 18, color: WynColors.graphite),
              tooltip: 'แชร์',
              onPressed: _openShareSheet,
            ),
          ),
          Expanded(
            child: Semantics(
              label: _drop.savedByMe
                  ? 'บันทึกแล้ว กดเพื่อเอาออกจาก Saved'
                  : 'กดเพื่อบันทึก',
              excludeSemantics: true,
              child: IconButton(
                icon: Icon(
                  _drop.savedByMe ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                  color: WynColors.graphite,
                ),
                onPressed: _toggleSave,
              ),
            ),
          ),
        ],
      ),
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
      padding: EdgeInsets.fromLTRB(
          isReply ? 52 : WynSpacing.space4, WynSpacing.space3, WynSpacing.space4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 07-post-detail.tsx: a reply is visually connected to its
          // parent by a short hairline stub, the same idea as the
          // reference's own indented `CommentReply`.
          if (isReply)
            const Padding(
              padding: EdgeInsets.only(right: WynSpacing.space2),
              child: SizedBox(
                width: 1,
                height: 44,
                child: ColoredBox(color: WynColors.hairline),
              ),
            ),
          AvatarCircle(
            imageUrl: comment.authorAvatarUrl,
            fallbackText: comment.authorUsername,
            radius: isReply ? 16 : 18,
            ring: true,
          ),
          const SizedBox(width: WynSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        comment.authorNameOrUsername,
                        overflow: TextOverflow.ellipsis,
                        style: _textStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: WynColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: WynSpacing.space2),
                    Text(
                      relativeTimeLabel(comment.createdAt, now: DateTime.now()),
                      style: _textStyle(fontSize: 13, color: WynColors.mutedNeutral),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    comment.textContent,
                    style: _textStyle(
                        fontSize: 15, color: WynColors.ink, height: 1.45),
                  ),
                ),
                // Replies don't get their own "ตอบกลับ" button -- that's
                // what keeps nesting to one level in the UI (the DB
                // trigger is the real enforcement either way).
                if (!isReply)
                  Padding(
                    padding: const EdgeInsets.only(top: WynSpacing.space2),
                    child: InkWell(
                      onTap: () => _startReply(comment),
                      child: Text(
                        'ตอบกลับ',
                        style: _textStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: WynColors.graphite,
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
                icon: const Icon(Icons.delete_outline, color: WynColors.graphite),
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
                      color: comment.likedByMe
                          ? Colors.red
                          : WynColors.graphite,
                    ),
                    onPressed: () => _toggleCommentLike(comment.id),
                  ),
                ),
              ),
              if (comment.likeCount > 0)
                Text(
                  '${comment.likeCount}',
                  style: _textStyle(fontSize: 13, color: WynColors.graphite),
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
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
        decoration: const BoxDecoration(
          color: WynColors.paper,
          border: Border(top: BorderSide(color: WynColors.hairline)),
        ),
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
                      style: _textStyle(fontSize: 13, color: WynColors.graphite),
                    ),
                    const SizedBox(width: WynSpacing.space1),
                    InkWell(
                      onTap: _cancelReply,
                      child: const Icon(Icons.close,
                          size: 16, color: WynColors.graphite),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                AvatarCircle(
                  imageUrl: _myProfile?.avatarUrl,
                  fallbackText: _myProfile?.username ??
                      Supabase.instance.client.auth.currentUser!.id,
                  radius: 16,
                  ring: true,
                ),
                const SizedBox(width: WynSpacing.space3),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    enabled: !_isSendingComment,
                    style: _textStyle(fontSize: 16, color: WynColors.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'แสดงความคิดเห็น...',
                      hintStyle:
                          _textStyle(fontSize: 16, color: WynColors.faint),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Semantics(
                  label: _isRestricted ? 'ส่งคอมเมนต์ ปิดใช้งานเนื่องจากบัญชีถูกจำกัดการโพสต์ชั่วคราว' : null,
                  excludeSemantics: _isRestricted,
                  child: IconButton(
                    icon: Icon(
                      Icons.send,
                      size: 18,
                      color: canSend ? WynColors.sapphire : WynColors.faint,
                    ),
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

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? height,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
