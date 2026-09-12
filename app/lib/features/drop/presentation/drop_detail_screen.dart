import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/interaction/wyn_feedback.dart';
import '../../../core/interaction/wyn_state_pop.dart';
import '../../../core/widgets/action_sheet_row.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/hashtag_text.dart';
import '../../../core/widgets/restriction_banner.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/shared_content_type.dart';
import '../../chat/presentation/share_sheet.dart';
import '../../follow/data/follow_repository.dart';
import '../../home/presentation/widgets/verified_badge.dart';
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
import 'widgets/redrop_action_sheet.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/design/wynos_founder_metrics.dart';
import '../../../core/text_utils.dart';
import '../../report/data/report_repository.dart';
import '../../report/data/report_target_type.dart';
import '../../report/presentation/report_sheet.dart';
import '../../../core/widgets/wyn_heart_icon.dart';

/// WYN-114 (Tier 1, done + deployed 2026-09-06): real wynos.online
/// domain + a Vercel SPA rewrite so this path no longer 404s at the
/// hosting layer -- see .wyn/tasks/completed/WYN-114-share-link-real-domain.md.
/// WYN-119 (Tier 2, partial): DeepLinkService (app/lib/core/navigation/)
/// now opens this destination directly, but only once RootShell has
/// already mounted -- a guest who has never signed in still lands on
/// Welcome first, not this content. WYN-119's own guest-preview
/// requirement is not met yet; see that task's Known Follow-up.
String dropShareLink(String dropId) => 'https://wynos.online/drop/$dropId';

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
      widget.moderationRepository ??
          ModerationRepository(Supabase.instance.client);
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
        _hasMoreComments = comments.length == DropRepository.commentPageSize;
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
    // This screen's action bar is plain IconButtons, not the feed's
    // shared ActionMetric, so it carries its own haptic -- without this
    // the exact same Like felt different depending on whether you tapped
    // it on the feed card or after opening the post.
    WynFeedback.like();
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
    WynFeedback.save();
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

  /// Beta4 §6: the same [showRedropSheet] the feed card opens, rather
  /// than this screen's own second copy of it -- see that function's
  /// doc comment for why the emoji labels are gone.
  Future<void> _openRedropSheet() async {
    await showRedropSheet(
      context,
      isRedropped: _drop.redroppedByMe,
      onToggleRedrop: _toggleRedrop,
      onQuoteRedrop: _openQuoteRedrop,
    );
  }

  Future<void> _openQuoteRedrop() async {
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
      WynFeedback.deleted();
      setState(() {
        _comments = _comments?.where((c) => c.id != commentId).toList();
        _drop = _drop.withRemovedComment();
      });
    } catch (_) {
      if (!mounted) return;
      WynFeedback.failed();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: BrowserSystemText('ลบคอมเมนต์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
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
  Future<void> _openCommentMenu(
      DropComment comment, String currentUserId) async {
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
      WynFeedback.deleted();
      Navigator.of(context).pop();
    } catch (_) {
      // WYN-121: `deleteDrop()` throwing does not mean the delete never
      // happened -- a response lost to a flaky connection *after* the
      // database already committed looks identical, client-side, to a
      // genuine failure (confirmed against production: a Founder report
      // of this exact SnackBar lined up, to the second, with
      // `deleted_at` already being set on that Drop). Before telling the
      // user it failed, check the one thing that actually matters: is
      // the Drop still live? `fetchById()` (WYN-120) already returns
      // null for a Drop that's gone, whatever the reason.
      Drop? stillLive;
      try {
        stillLive = await widget.dropRepository.fetchById(_drop.id);
      } catch (_) {
        stillLive =
            _drop; // can't tell either way -- fall through to reporting failure
      }
      if (!mounted) return;
      if (stillLive == null) {
        WynFeedback.deleted();
        Navigator.of(context).pop();
        return;
      }
      WynFeedback.failed();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: BrowserSystemText('ลบโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
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
      // Only once the comment actually exists server-side -- an
      // optimistic buzz for a comment that then fails to send is worse
      // than no buzz at all.
      WynFeedback.commentSent();
      setState(() {
        _comments = [...?_comments, comment];
        _drop = _drop.withExtraComment();
        _commentController.clear();
        _replyingTo = null;
      });
    } catch (_) {
      // Keep the typed text in the box so the user can just retry sending.
      WynFeedback.failed();
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
      title: BrowserSystemText(
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
            WynSpacing.space4,
            WynSpacing.space4,
            WynSpacing.space4,
            WynSpacing.space2,
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Flexible(
                                      child: BrowserSystemText(
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
                                    if (_drop.authorIsVerified) ...[
                                      const SizedBox(width: WynSpacing.space1),
                                      const VerifiedBadge(),
                                    ],
                                    const SizedBox(width: WynSpacing.space2),
                                    Flexible(
                                      child: BrowserSystemText(
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
                                BrowserSystemText(
                                  '@${_drop.authorUsername}',
                                  style: _textStyle(
                                      fontSize: 13,
                                      color: WynColors.mutedNeutral),
                                ),
                                if (_drop.wasEdited)
                                  BrowserSystemText(
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
                          child: BrowserSystemText(
                              _isFollowing! ? 'กำลังติดตาม' : 'ติดตาม'),
                        ),
                      ),
                    ),
                  if (isOwnDrop)
                    BrowserSystemTooltip(
                        message: 'เพิ่มเติม',
                        child: IconButton(
                          icon: const Icon(Icons.more_vert,
                              size: 18, color: WynColors.faint),
                          tooltip: null,
                          onPressed: _openOwnDropMoreMenu,
                        ))
                  else
                    BrowserSystemTooltip(
                        message: 'เพิ่มเติม',
                        child: IconButton(
                          icon: const Icon(Icons.more_vert,
                              size: 18, color: WynColors.faint),
                          tooltip: null,
                          onPressed: _openDropMoreMenu,
                        )),
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
                  style: _textStyle(
                      fontSize: 16, color: WynColors.ink, height: 1.5),
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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WynosFounderMetrics.detailEdgeInset,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                WynosFounderMetrics.detailMediaRadius,
              ),
              child: DropImageGallery(
                drop: _drop,
                dropRepository: widget.dropRepository,
                onLike: _toggleLike,
                onDropChanged: (updated) => setState(() => _drop = updated),
              ),
            ),
          ),
        const SizedBox(height: 7),
        _buildFocusedActionBar(),
        _buildActivityRow(),
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
                  const BrowserSystemText('โหลดคอมเมนต์ไม่สำเร็จ'),
                  const SizedBox(height: WynSpacing.space2),
                  TextButton(
                    onPressed: _loadComments,
                    child: const BrowserSystemText('ลองใหม่'),
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
            child: Center(
                child: BrowserSystemText('ยังไม่มีคอมเมนต์ เป็นคนแรกสิ!')),
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
            for (final reply
                in comments.where((c) => c.parentCommentId == comment.id))
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
                        child: BrowserSystemText(_moreCommentsErrored
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
                child: BrowserSystemText(
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

  Widget _detailAction({
    required Widget icon,
    required String semanticsLabel,
    required VoidCallback? onPressed,
    int? count,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        label: semanticsLabel,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onPressed,
          radius: 25,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                if (count != null) ...[
                  const SizedBox(width: 7),
                  BrowserSystemText(
                    '$count',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1,
                      color: WynColors.graphite,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFocusedActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _detailAction(
            icon: WynStatePop(
              state: _drop.likedByMe,
              child: WynHeartIcon(
                filled: _drop.likedByMe,
                size: 26,
                color:
                    _drop.likedByMe ? WynColors.iconLikeActive : WynColors.ink,
              ),
            ),
            count: _drop.likeCount,
            semanticsLabel: _drop.likedByMe
                ? 'ถูกใจแล้ว ${_drop.likeCount} คน กดเพื่อเลิกถูกใจ'
                : 'ถูกใจ ${_drop.likeCount} คน กดเพื่อถูกใจ',
            onPressed: _toggleLike,
          ),
          _detailAction(
            icon: const Icon(
              Icons.mode_comment_outlined,
              size: 25,
              color: WynColors.ink,
            ),
            count: _drop.commentCount,
            semanticsLabel: 'ความคิดเห็น ${_drop.commentCount} รายการ',
            onPressed: () => _commentFocusNode.requestFocus(),
          ),
          if (_drop.audience == AudienceOption.everyone)
            _detailAction(
              icon: Icon(
                Icons.repeat_rounded,
                size: 27,
                color:
                    _drop.redroppedByMe ? WynColors.iconActive : WynColors.ink,
              ),
              count: _drop.redropCount,
              semanticsLabel: 'รีโพสต์ ${_drop.redropCount} ครั้ง',
              onPressed: _openRedropSheet,
            ),
          _detailAction(
            icon: const Icon(
              Icons.ios_share_outlined,
              size: 24,
              color: WynColors.ink,
            ),
            semanticsLabel: 'แชร์โพสต์',
            onPressed: _openShareSheet,
          ),
          _detailAction(
            icon: WynStatePop(
              state: _drop.savedByMe,
              child: Icon(
                _drop.savedByMe
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                size: 26,
                color: WynColors.ink,
              ),
            ),
            semanticsLabel:
                _drop.savedByMe ? 'บันทึกแล้ว กดเพื่อเอาออก' : 'บันทึกโพสต์',
            onPressed: _toggleSave,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynosFounderMetrics.detailEdgeInset,
        2,
        WynosFounderMetrics.detailEdgeInset,
        10,
      ),
      child: Material(
        color: WynColors.surfaceTint,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _openActivitySheet,
          borderRadius: BorderRadius.circular(18),
          child: const SizedBox(
            height: WynosFounderMetrics.activityRowHeight,
            child: Row(
              children: [
                SizedBox(width: 14),
                SizedBox(
                  width: 42,
                  child: Icon(
                    Icons.insights_outlined,
                    size: 22,
                    color: WynColors.graphite,
                  ),
                ),
                SizedBox(width: 7),
                Expanded(
                  child: BrowserSystemText(
                    'ดูกิจกรรม',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: WynColors.ink,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 27,
                  color: WynColors.graphite,
                ),
                SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openActivitySheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: WynColors.paper,
      builder: (context) => _DropActivitySheet(
        dropId: _drop.id,
        dropRepository: widget.dropRepository,
        followRepository: widget.followRepository,
        profileRepository: widget.profileRepository,
        popRepository: widget.popRepository,
        savedRepository: widget.savedRepository,
      ),
    );
  }

  Widget _buildCommentRow(DropComment comment, String currentUserId,
      {required bool isReply}) {
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
          padding: EdgeInsets.fromLTRB(isReply ? 52 : WynSpacing.space4,
              WynSpacing.space3, WynSpacing.space4, 0),
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
                          child: BrowserSystemText(
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
                        BrowserSystemText(
                          relativeTimeLabel(comment.createdAt,
                              now: DateTime.now()),
                          style: _textStyle(
                              fontSize: 13, color: WynColors.mutedNeutral),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: BrowserSystemText(
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
                          child: BrowserSystemText(
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
                  child: BrowserSystemTooltip(
                      message: 'ลบคอมเมนต์',
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        icon: const Icon(Icons.delete_outline,
                            color: WynColors.graphite),
                        tooltip: null,
                        onPressed: () => _deleteComment(comment.id),
                      )),
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
                        // WYN-108: the size lives on the heart itself now.
                        // IconButton's `iconSize` reaches an [Icon] through
                        // IconTheme and cannot reach a widget that sizes
                        // itself, so leaving the 16 here and a 24 below drew
                        // the comment heart half again as large as the one
                        // it replaced.
                        icon: WynHeartIcon(
                          filled: comment.likedByMe,
                          size: 16,
                          color: comment.likedByMe
                              ? WynColors.iconLikeActive
                              : WynColors.iconIdle,
                        ),
                        onPressed: () => _toggleCommentLike(comment.id),
                      ),
                    ),
                  ),
                  if (comment.likeCount > 0)
                    BrowserSystemText(
                      '${comment.likeCount}',
                      style:
                          _textStyle(fontSize: 13, color: WynColors.graphite),
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
        padding: const EdgeInsets.fromLTRB(14, 9, 9, 9),
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
                padding: const EdgeInsets.fromLTRB(45, 0, 0, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrowserSystemText(
                      'ตอบกลับ ${_replyingTo!.authorNameOrUsername}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WynColors.graphite,
                      ),
                    ),
                    const SizedBox(width: 5),
                    InkWell(
                      onTap: _cancelReply,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: WynColors.graphite,
                      ),
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
                  radius: 18,
                  ring: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: WynosFounderMetrics.commentComposerHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: WynColors.surfaceTint,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: BrowserSystemTextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      enabled: !_isSendingComment,
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (canSend) _sendComment();
                      },
                      style: const TextStyle(
                        fontSize: 15,
                        color: WynColors.ink,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        hint: BrowserSystemText('แสดงความคิดเห็น...'),
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: WynColors.faint,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Semantics(
                  label: _isRestricted
                      ? 'ส่งคอมเมนต์ ปิดใช้งานเนื่องจากบัญชีถูกจำกัดการโพสต์ชั่วคราว'
                      : 'ส่งคอมเมนต์',
                  button: true,
                  child: IconButton(
                    onPressed: canSend ? _sendComment : null,
                    icon: Icon(
                      Icons.send_rounded,
                      size: 25,
                      color: canSend ? WynColors.ink : WynColors.faint,
                    ),
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

class _DropActivitySheet extends StatefulWidget {
  const _DropActivitySheet({
    required this.dropId,
    required this.dropRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
  });

  final String dropId;
  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;

  @override
  State<_DropActivitySheet> createState() => _DropActivitySheetState();
}

class _DropActivitySheetState extends State<_DropActivitySheet> {
  late Future<({List<Profile> liked, List<Profile> redropped})> _activity;

  @override
  void initState() {
    super.initState();
    _activity = _loadActivity();
  }

  Future<({List<Profile> liked, List<Profile> redropped})>
      _loadActivity() async {
    final idLists = await Future.wait<List<String>>([
      widget.dropRepository.fetchLikeUserIds(widget.dropId),
      widget.dropRepository.fetchRedropperIds(widget.dropId),
    ]);
    final likedIds = idLists[0];
    final redroppedIds = idLists[1];

    final allIds = <String>[];
    final seen = <String>{};
    for (final id in [...likedIds, ...redroppedIds]) {
      if (seen.add(id)) allIds.add(id);
    }

    final profiles = await widget.profileRepository.fetchProfilesByIds(allIds);
    final byId = {for (final profile in profiles) profile.id: profile};

    return (
      liked: [
        for (final id in likedIds)
          if (byId[id] != null) byId[id]!,
      ],
      redropped: [
        for (final id in redroppedIds)
          if (byId[id] != null) byId[id]!,
      ],
    );
  }

  void _retry() {
    setState(() => _activity = _loadActivity());
  }

  void _openProfile(Profile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: profile.id,
        ),
      ),
    );
  }

  Widget _peopleList(List<Profile> profiles, {required String emptyLabel}) {
    if (profiles.isEmpty) {
      return Center(
        child: BrowserSystemText(
          emptyLabel,
          style: const TextStyle(fontSize: 14, color: WynColors.graphite),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: profiles.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 72,
        color: WynColors.hairline,
      ),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return ListTile(
          onTap: () => _openProfile(profile),
          leading: AvatarCircle(
            imageUrl: profile.avatarUrl,
            fallbackText: profile.username,
            radius: 21,
          ),
          title: Row(
            children: [
              Flexible(
                child: BrowserSystemText(
                  profile.nameOrUsername,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: WynColors.ink,
                  ),
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 4),
                const VerifiedBadge(),
              ],
            ],
          ),
          subtitle: profile.username.isEmpty
              ? null
              : BrowserSystemText(
                  '@${profile.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: WynColors.mutedNeutral,
                  ),
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
                child: BrowserSystemText(
                  'กิจกรรมโพสต์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: WynColors.ink,
                  ),
                ),
              ),
              const TabBar(
                labelColor: WynColors.ink,
                unselectedLabelColor: WynColors.graphite,
                indicatorColor: WynColors.sapphire,
                tabs: [
                  Tab(child: BrowserSystemText('ถูกใจ')),
                  Tab(child: BrowserSystemText('รีโพสต์')),
                ],
              ),
              const Divider(height: 1, color: WynColors.hairline),
              Expanded(
                child: FutureBuilder<
                    ({List<Profile> liked, List<Profile> redropped})>(
                  future: _activity,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BrowserSystemText('โหลดกิจกรรมไม่สำเร็จ'),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _retry,
                              child: const BrowserSystemText('ลองใหม่'),
                            ),
                          ],
                        ),
                      );
                    }
                    final data = snapshot.data!;
                    return TabBarView(
                      children: [
                        _peopleList(
                          data.liked,
                          emptyLabel: 'ยังไม่มีใครถูกใจโพสต์นี้',
                        ),
                        _peopleList(
                          data.redropped,
                          emptyLabel: 'ยังไม่มีใครรีโพสต์โพสต์นี้',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
