import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/widgets/action_sheet_row.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/restriction_banner.dart';
import '../../block/data/block_relationship.dart';
import '../../block/data/block_repository.dart';
import '../../block/presentation/block_dialogs.dart';
import '../../club/data/club.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/club_page.dart';
import '../../drop/data/drop.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../profile/data/profile.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../moderation/data/appeal_status.dart';
import '../../moderation/data/moderation_repository.dart';
import '../../moderation/presentation/appeal_form_screen.dart';
import '../../moderation/presentation/evidence_image_viewer.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../drop/data/drop_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../report/data/report_repository.dart';
import '../../report/data/report_target_type.dart';
import '../../report/presentation/report_sheet.dart';
import '../data/chat_message.dart';
import '../data/chat_repository.dart';
import '../data/shared_content_type.dart';

/// Screen 3 -- the conversation itself. Restyled to 13-chat-thread.tsx:
/// sapphire-filled bubbles (mine) vs. tinted #F1EFE9 bubbles (theirs).
///
/// Message grouping/bubble behavior (per
/// .wyn/docs/design/wyn-031-chat-message-grouping-bubble-spec.md):
/// consecutive messages from the same sender
/// within 60 seconds and the same calendar day form a group -- 4px apart
/// within a group, 16px between groups from the same sender, 20px
/// between groups from different senders (see
/// [_ConversationScreenState._isSameGroup]/[_gapBelowMessage]). The
/// avatar (incoming only) and the delivery/read-receipt row (outgoing,
/// last message in the whole conversation only) attach to the
/// chronologically-latest bubble of a group -- the one rendered at the
/// bottom of that group on screen (see [_ConversationScreenState._isGroupEnd]).
/// Corners tighten (18px -> 4px) on whichever side touches the next
/// bubble in the same group, stitching the group together visually,
/// while the true first/last bubble's outer corners stay full radius
/// (see [_MessageBubble._cornerRadius]). No per-bubble timestamp by
/// default -- only a centered date separator once per calendar day (see
/// [_ConversationScreenState._dateSeparatorAbove]); tapping any bubble
/// reveals its own time label for ~2 seconds (see
/// [_ConversationScreenState._onTapBubble]).
///
/// The "..." options menu (mute/block/report/view profile) has no
/// equivalent in 13-chat-thread.tsx's own header -- its third grid column
/// is empty -- but removing it would delete real, otherwise-unreachable
/// safety functionality (mute in particular exists nowhere else), so it's
/// kept as a trailing AppBar action rather than dropped, same posture as
/// Post Detail/Club keeping their own real action icons the mockups
/// omit. No verified badge -- same "no such field anywhere in the real
/// Profile model" finding as Side Menu/Chat Inbox.
///
/// Every other real capability the mockup doesn't depict at all --
/// replies, image attachments, WYN-033's shared-content preview cards,
/// the Message Request accept/delete/block/report flow, the Restrict/
/// Suspend/Ban composer states -- is untouched, just restyled to the
/// same token system. See .wyn/docs/design/wyn-031-chat-1to1.md,
/// Screen 3.
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.chatRepository,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUsername,
    this.otherDisplayName,
    this.otherAvatarUrl,
    BlockRepository? blockRepository,
    ModerationRepository? moderationRepository,
    ReportRepository? reportRepository,
    ProfileRepository? profileRepository,
    FollowRepository? followRepository,
    DropRepository? dropRepository,
    PopRepository? popRepository,
    SavedRepository? savedRepository,
    AppealRepository? appealRepository,
    ClubRepository? clubRepository,
    ClubPostRepository? clubPostRepository,
  })  : _blockRepository = blockRepository,
        _moderationRepository = moderationRepository,
        _reportRepository = reportRepository,
        _profileRepository = profileRepository,
        _followRepository = followRepository,
        _dropRepository = dropRepository,
        _popRepository = popRepository,
        _savedRepository = savedRepository,
        _appealRepository = appealRepository,
        _clubRepository = clubRepository,
        _clubPostRepository = clubPostRepository;

  final ChatRepository chatRepository;
  final String conversationId;
  final String otherUserId;
  final String otherUsername;
  final String? otherDisplayName;
  final String? otherAvatarUrl;

  // All optional -- default to real Supabase-backed instances, same
  // shape as every other optional repository param in this app. Only
  // needed here for the blocked/restricted composer states (Screen 3's
  // own States) and for opening ViewProfileScreen/ReportSheet/
  // AppealFormScreen from this screen without re-fetching them.
  final BlockRepository? _blockRepository;
  final ModerationRepository? _moderationRepository;
  final ReportRepository? _reportRepository;
  final ProfileRepository? _profileRepository;
  final FollowRepository? _followRepository;
  final DropRepository? _dropRepository;
  final PopRepository? _popRepository;
  final SavedRepository? _savedRepository;
  final AppealRepository? _appealRepository;

  // Same shape again -- WYN-033's shared-content preview card needs
  // these to open ClubPage when a shared Club card is tapped.
  final ClubRepository? _clubRepository;
  final ClubPostRepository? _clubPostRepository;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _textFieldFocusNode = FocusNode();
  final List<ChatMessage> _messages = [];

  late final BlockRepository _blockRepository =
      widget._blockRepository ?? BlockRepository(Supabase.instance.client);
  late final ModerationRepository _moderationRepository =
      widget._moderationRepository ?? ModerationRepository(Supabase.instance.client);
  late final ReportRepository _reportRepository =
      widget._reportRepository ?? ReportRepository(Supabase.instance.client);
  late final ProfileRepository _profileRepository =
      widget._profileRepository ?? ProfileRepository(Supabase.instance.client);
  late final FollowRepository _followRepository =
      widget._followRepository ?? FollowRepository(Supabase.instance.client);
  late final DropRepository _dropRepository =
      widget._dropRepository ?? DropRepository(Supabase.instance.client);
  late final PopRepository _popRepository =
      widget._popRepository ?? PopRepository(Supabase.instance.client);
  late final SavedRepository _savedRepository =
      widget._savedRepository ?? SavedRepository(Supabase.instance.client);
  late final AppealRepository _appealRepository =
      widget._appealRepository ?? AppealRepository(Supabase.instance.client);
  late final ClubRepository _clubRepository =
      widget._clubRepository ?? ClubRepository(Supabase.instance.client);
  late final ClubPostRepository _clubPostRepository =
      widget._clubPostRepository ?? ClubPostRepository(Supabase.instance.client);

  // WYN-033: caches a resolved shared Drop/Profile/Club by
  // "$type:$id" so scrolling (which rebuilds bubbles) doesn't re-fetch
  // the same content repeatedly. `Object?` because the 3 shared types
  // have no common base class -- a `Drop`/`Profile`/`Club`, or null
  // once resolution is confirmed to have failed (deleted/blocked).
  final Map<String, Object?> _sharedContentCache = {};

  String get _myUserId => Supabase.instance.client.auth.currentUser!.id;

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isSending = false;

  ChatMessage? _replyTo;
  Uint8List? _imageBytes;
  String? _imageExtension;

  BlockRelationship _blockRelationship = BlockRelationship.none;
  String? _restrictReason;
  DateTime? _restrictExpiresAt;
  String? _restrictActionId;
  AppealStatus _restrictAppealStatus = AppealStatus.none;
  bool _isSuspendedOrBanned = false;

  // WYN-032: defaults to 'active'/no requester until _loadConversationMeta()
  // confirms otherwise -- an optimistic default, same posture as
  // _blockRelationship starting at .none, so the composer doesn't
  // flash a pending-request state for an ordinary active conversation
  // while this one extra query is still in flight.
  String _conversationStatus = 'active';
  String? _requestedBy;
  bool _isDecidingRequest = false;

  /// The other participant's own last-read timestamp -- null until
  /// loaded, or if they've never read this conversation. Drives the
  /// last-outgoing-bubble delivery/read receipt (spec section 7):
  /// "read" once this is no earlier than that bubble's `createdAt`.
  DateTime? _otherUserLastReadAt;

  RealtimeChannel? _channel;
  RealtimeChannel? _metaChannel;

  /// Reserved id prefix for the optimistic placeholder `_send()` inserts
  /// immediately (before the network round-trip resolves) so the
  /// delivery-receipt row has a real "sending" state to show, instead of
  /// the removed spinner-over-bubble treatment the spec calls out.
  static const _pendingIdPrefix = 'pending-';

  /// Which bubble's tap-revealed time label (spec section 6) is
  /// currently shown, if any -- at most one at a time, auto-dismissed by
  /// [_revealTimer] after 2 seconds or replaced by tapping another bubble.
  String? _revealedTimestampMessageId;
  Timer? _revealTimer;

  /// True only for the recipient of a still-pending Message Request --
  /// the requester keeps a normal composer while waiting (see
  /// [_isPendingAsRequester]).
  bool get _isPendingAsRecipient => _conversationStatus == 'pending' && _requestedBy != _myUserId;

  bool get _isPendingAsRequester => _conversationStatus == 'pending' && _requestedBy == _myUserId;

  bool get _isComposerDisabled =>
      _blockRelationship.isBlockedEitherWay ||
      _restrictExpiresAt != null ||
      _isSuspendedOrBanned ||
      _isPendingAsRecipient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitial();
    _loadSafetyState();
    _loadConversationMeta();
    widget.chatRepository.markConversationRead(widget.conversationId);
    _scrollController.addListener(_onScroll);
    _channel = widget.chatRepository.subscribeToConversationMessages(
      widget.conversationId,
      _onRealtimeMessage,
    );
    _metaChannel = widget.chatRepository.subscribeToConversationMeta(
      widget.conversationId,
      _onConversationMetaUpdate,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final channel = _channel;
    if (channel != null) widget.chatRepository.unsubscribe(channel);
    final metaChannel = _metaChannel;
    if (metaChannel != null) widget.chatRepository.unsubscribe(metaChannel);
    _revealTimer?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  // A backgrounded PWA/browser tab commonly drops its websocket outright
  // (iOS Safari in particular suspends it aggressively) -- the realtime
  // subscription doesn't reconnect and re-deliver missed inserts on its
  // own, so messages sent while this screen was backgrounded would
  // otherwise only show up once something else happens to refetch. Redo
  // the subscription and pull the latest page on every resume so coming
  // back to the app catches up immediately, without the user having to
  // know to pull-to-refresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _resubscribeAndRefresh();
  }

  Future<void> _resubscribeAndRefresh() async {
    final oldChannel = _channel;
    if (oldChannel != null) widget.chatRepository.unsubscribe(oldChannel);
    _channel = widget.chatRepository.subscribeToConversationMessages(
      widget.conversationId,
      _onRealtimeMessage,
    );
    final oldMetaChannel = _metaChannel;
    if (oldMetaChannel != null) widget.chatRepository.unsubscribe(oldMetaChannel);
    _metaChannel = widget.chatRepository.subscribeToConversationMeta(
      widget.conversationId,
      _onConversationMetaUpdate,
    );
    await Future.wait([_refreshLatest(), _loadConversationMeta()]);
  }

  void _onConversationMetaUpdate(ConversationMeta meta) {
    if (!mounted) return;
    setState(() {
      _conversationStatus = meta.status;
      _requestedBy = meta.requestedBy;
      _otherUserLastReadAt = meta.otherUserLastReadAt;
    });
  }

  void _onRealtimeMessage(ChatMessage message) {
    if (!mounted) return;
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() => _messages.insert(0, message));
    if (message.senderId != _myUserId) {
      widget.chatRepository.markConversationRead(widget.conversationId);
    }
  }

  /// Pull-to-refresh, and the resume-from-background catch-up above --
  /// re-fetches the newest page and merges it into [_messages]: inserts
  /// anything missing (a message sent while disconnected), and replaces
  /// anything that already exists by id (picks up an edit-in-place like
  /// a delete that happened while this screen wasn't listening). Never
  /// touches older, already-loaded history below the newest page.
  Future<void> _refreshLatest() async {
    try {
      final fresh = await widget.chatRepository.fetchMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        for (final message in fresh) {
          final index = _messages.indexWhere((existing) => existing.id == message.id);
          if (index == -1) {
            _messages.insert(0, message);
          } else {
            _messages[index] = message;
          }
        }
        _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    } catch (_) {
      // Fails open -- a pull-to-refresh that silently does nothing beats
      // one that throws, matching every other list load's posture here.
    }
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoadingInitial = true);
    try {
      final messages = await widget.chatRepository.fetchMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _hasMore = messages.length == ChatRepository.messagePageSize;
      });
    } catch (_) {
      // Fails open to an empty list with a retry-by-pull-to-refresh --
      // matches every other list screen's load-failure posture.
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    if (_messages.isEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      final oldest = _messages.last.createdAt;
      final messages = await widget.chatRepository.fetchMessages(
        widget.conversationId,
        beforeCreatedAt: oldest,
      );
      if (!mounted) return;
      setState(() {
        _messages.addAll(messages);
        _hasMore = messages.length == ChatRepository.messagePageSize;
      });
    } catch (_) {
      // Silent, same posture as every other list's load-more failure.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadSafetyState() async {
    try {
      final relationship = await _blockRepository.blockRelationship(widget.otherUserId);
      if (mounted) setState(() => _blockRelationship = relationship);
    } catch (_) {
      // Fails open -- the RLS INSERT guard on `messages` is the real
      // boundary regardless of what this screen shows.
    }
    try {
      final status = await _moderationRepository.fetchMyStatus();
      if (!mounted) return;
      setState(() {
        _isSuspendedOrBanned = status.isSuspended || status.isBanned;
        if (status.isRestricted) {
          _restrictReason = status.restrictReason;
          _restrictExpiresAt = status.restrictExpiresAt;
          _restrictActionId = status.restrictActionId;
          _restrictAppealStatus = status.restrictAppealStatus;
        }
      });
    } catch (_) {
      // Same fail-open posture.
    }
  }

  Future<void> _loadConversationMeta() async {
    try {
      final meta = await widget.chatRepository.fetchConversationMeta(widget.conversationId);
      if (meta != null) _onConversationMetaUpdate(meta);
    } catch (_) {
      // Fails open to the 'active' default -- the messages INSERT
      // policy is the real boundary regardless of what this screen
      // shows (mirrors _loadSafetyState()'s identical posture).
    }
  }

  Future<void> _acceptRequest() async {
    setState(() => _isDecidingRequest = true);
    try {
      await widget.chatRepository.acceptMessageRequest(widget.conversationId);
      if (mounted) setState(() => _conversationStatus = 'active');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยอมรับคำขอไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isDecidingRequest = false);
    }
  }

  Future<void> _deleteRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบคำขอนี้?'),
        content: const Text('ผู้ส่งจะไม่ได้รับแจ้งเตือนว่าคำขอถูกลบ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDecidingRequest = true);
    try {
      await widget.chatRepository.deleteMessageRequest(widget.conversationId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDecidingRequest = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบคำขอไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _blockFromRequest() async {
    final confirmed = await confirmBlock(context, username: widget.otherUsername);
    if (!confirmed || !mounted) return;
    setState(() => _isDecidingRequest = true);
    try {
      await _blockRepository.blockUser(widget.otherUserId);
      if (mounted) setState(() => _blockRelationship = BlockRelationship.blockedByMe);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บล็อกไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isDecidingRequest = false);
    }
  }

  void _reportFromRequest() {
    showReportSheet(
      context,
      reportRepository: _reportRepository,
      targetType: ReportTargetType.user,
      targetId: widget.otherUserId,
      targetLabel: 'รายงานผู้ใช้นี้',
      associatedUserId: widget.otherUserId,
    );
  }

  Future<void> _openAppeal() async {
    final actionId = _restrictActionId;
    if (actionId == null) return;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppealFormScreen(
          appealRepository: _appealRepository,
          actionId: actionId,
          actionLabel: 'จำกัดสิทธิ์ (Restrict)',
        ),
      ),
    );
    if (submitted == true) _loadSafetyState();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final extension = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageExtension = extension;
    });
  }

  bool get _canSend =>
      !_isSending &&
      !_isComposerDisabled &&
      (_textController.text.trim().isNotEmpty || _imageBytes != null);

  /// Optimistic: a placeholder bubble (real content, temp id) appears
  /// immediately with a "sending" receipt (spec section 7), and the
  /// composer clears right away too -- Founder feedback: clearing only
  /// on success left the TextField disabled (`enabled: !_isSending`)
  /// while a send was in flight, which drops focus and dismisses the
  /// keyboard the instant "send" is tapped, exactly when someone wants
  /// to keep typing the next message. The TextField now stays enabled
  /// throughout (see its own comment below), so this is the only thing
  /// standing between "send" and typing again immediately.
  ///
  /// A failure restores what was cleared -- but only if the composer is
  /// still exactly as this left it (nothing retyped, no new image, no
  /// new reply picked in the meantime): restoring over a draft the user
  /// has already started composing while this was in flight would
  /// clobber it, which is worse than just losing the failed send (the
  /// error toast already says to try again).
  Future<void> _send() async {
    if (!_canSend) return;
    // Re-affirm focus synchronously, in the same tap that triggered this
    // -- on Flutter *Web*, tapping any other on-screen control (like the
    // send button itself) can blur the underlying native text-input
    // element the mobile browser uses to show its keyboard, even though
    // this TextField's own FocusNode never actually loses focus. Asking
    // again right here, before anything else runs, gives the browser the
    // best chance of treating it as still part of the same user gesture
    // and keeping the keyboard up (not guaranteed on every browser, but
    // costs nothing to try).
    _textFieldFocusNode.requestFocus();
    final text = _textController.text;
    final imageBytes = _imageBytes;
    final imageExtension = _imageExtension;
    final replyTo = _replyTo;
    final pendingId = '$_pendingIdPrefix${DateTime.now().microsecondsSinceEpoch}';
    final pending = ChatMessage(
      id: pendingId,
      conversationId: widget.conversationId,
      senderId: _myUserId,
      createdAt: DateTime.now(),
      text: text.trim().isEmpty ? null : text.trim(),
      replyToMessageId: replyTo?.id,
    );
    _textController.clear();
    setState(() {
      _isSending = true;
      _messages.insert(0, pending);
      _imageBytes = null;
      _imageExtension = null;
      _replyTo = null;
    });
    try {
      final sent = await widget.chatRepository.sendMessage(
        conversationId: widget.conversationId,
        text: text,
        imageBytes: imageBytes,
        imageExtension: imageExtension,
        replyToMessageId: replyTo?.id,
      );
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == pendingId);
        if (index != -1) _messages.removeAt(index);
        // The realtime echo of this same insert can win the race and
        // arrive first -- don't double-insert if it already has.
        if (!_messages.any((m) => m.id == sent.id)) {
          _messages.insert(0, sent);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == pendingId);
        if (_textController.text.isEmpty && _imageBytes == null && _replyTo == null) {
          _textController.text = text;
          _imageBytes = imageBytes;
          _imageExtension = imageExtension;
          _replyTo = replyTo;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งข้อความไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirmed = await confirmDeletePost(context, itemLabel: 'ข้อความ');
    if (!confirmed || !mounted) return;
    try {
      await widget.chatRepository.deleteMessage(message.id);
      if (!mounted) return;
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        setState(() {
          _messages[index] = ChatMessage(
            id: message.id,
            conversationId: message.conversationId,
            senderId: message.senderId,
            createdAt: message.createdAt,
            deletedAt: DateTime.now(),
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบข้อความไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _openEvidence(String path) async {
    final url = await widget.chatRepository.imageSignedUrl(path);
    if (!mounted || url == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EvidenceImageViewer(signedUrl: url)),
    );
  }

  /// WYN-033: resolves a shared-content reference through the normal
  /// repository fetch (never a raw join) so the existing RLS on
  /// drops/clubs/profiles decides visibility -- a deleted or (for
  /// Drop) blocked-author reference naturally resolves to null here,
  /// same as opening it any other way would. Cached by "$type:$id" so
  /// scrolling doesn't re-fetch on every rebuild.
  Future<Object?> _resolveSharedContent(SharedContentType type, String id) async {
    final cacheKey = '${type.wireValue}:$id';
    if (_sharedContentCache.containsKey(cacheKey)) {
      return _sharedContentCache[cacheKey];
    }
    Object? content;
    try {
      content = switch (type) {
        SharedContentType.drop => await _dropRepository.fetchById(id),
        SharedContentType.profile => await _profileRepository.fetchProfile(id),
        SharedContentType.club => await _clubRepository.fetchClub(id),
      };
    } catch (_) {
      content = null;
    }
    _sharedContentCache[cacheKey] = content;
    return content;
  }

  void _openSharedContent(SharedContentType type, Object content) {
    switch (type) {
      case SharedContentType.drop:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DropDetailScreen(
              dropRepository: _dropRepository,
              followRepository: _followRepository,
              profileRepository: _profileRepository,
              popRepository: _popRepository,
              savedRepository: _savedRepository,
              drop: content as Drop,
            ),
          ),
        );
      case SharedContentType.profile:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ViewProfileScreen(
              profileRepository: _profileRepository,
              followRepository: _followRepository,
              dropRepository: _dropRepository,
              popRepository: _popRepository,
              savedRepository: _savedRepository,
              userId: (content as Profile).id,
            ),
          ),
        );
      case SharedContentType.club:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ClubPage(
              clubRepository: _clubRepository,
              clubPostRepository: _clubPostRepository,
              clubId: (content as Club).id,
            ),
          ),
        );
    }
  }

  void _scrollToMessage(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    _scrollController.animateTo(
      index * 72.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _showMessageMenu(ChatMessage message) async {
    final isMine = message.senderId == _myUserId;
    // Replies are limited to 1 level -- a message that is itself a
    // reply can't be replied to again (Product spec: "reply ไปยัง
    // reply อื่นทำไม่ได้"). The DB trigger only rejects a
    // cross-conversation reply_to_message_id, not chain depth, so this
    // has to be enforced here.
    final canReply = message.replyToMessageId == null;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        if (canReply)
          ActionSheetRow(
            icon: Icons.reply_outlined,
            label: 'ตอบกลับ',
            onTap: () {
              Navigator.of(sheetContext).pop();
              setState(() => _replyTo = message);
            },
          ),
        if (isMine)
          ActionSheetRow(
            icon: Icons.delete_outline,
            label: 'ลบ',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _deleteMessage(message);
            },
          )
        else
          ActionSheetRow(
            icon: Icons.flag_outlined,
            label: 'รายงาน',
            onTap: () {
              Navigator.of(sheetContext).pop();
              showReportSheet(
                context,
                reportRepository: _reportRepository,
                targetType: ReportTargetType.message,
                targetId: message.id,
                targetLabel: 'รายงานข้อความนี้',
                associatedUserId: message.senderId,
              );
            },
          ),
      ]),
    );
  }

  Future<void> _showConversationMenu() async {
    final isMuted = await widget.chatRepository.isConversationMuted(widget.conversationId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        ActionSheetRow(
          icon: isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
          label: isMuted ? 'เปิดแจ้งเตือนบทสนทนานี้' : 'ปิดแจ้งเตือนบทสนทนานี้',
          onTap: () async {
            Navigator.of(sheetContext).pop();
            try {
              if (isMuted) {
                await widget.chatRepository.unmuteConversation(widget.conversationId);
              } else {
                await widget.chatRepository.muteConversation(widget.conversationId);
              }
            } catch (_) {
              // Silent -- see ChatInboxScreen's identical toggle.
            }
          },
        ),
        if (!_blockRelationship.isBlockedEitherWay)
          ActionSheetRow(
            icon: Icons.block,
            label: 'บล็อก',
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final confirmed = await confirmBlock(context, username: widget.otherUsername);
              if (!confirmed || !mounted) return;
              try {
                await _blockRepository.blockUser(widget.otherUserId);
                if (mounted) setState(() => _blockRelationship = BlockRelationship.blockedByMe);
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('บล็อกไม่สำเร็จ ลองใหม่อีกครั้ง')),
                );
              }
            },
          ),
        ActionSheetRow(
          icon: Icons.person_outline,
          label: 'ดูโปรไฟล์',
          onTap: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ViewProfileScreen(
                  profileRepository: _profileRepository,
                  followRepository: _followRepository,
                  dropRepository: _dropRepository,
                  popRepository: _popRepository,
                  savedRepository: _savedRepository,
                  userId: widget.otherUserId,
                ),
              ),
            );
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.otherDisplayName?.isNotEmpty == true
        ? widget.otherDisplayName!
        : '@${widget.otherUsername}';

    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ViewProfileScreen(
                profileRepository: _profileRepository,
                followRepository: _followRepository,
                dropRepository: _dropRepository,
                popRepository: _popRepository,
                savedRepository: _savedRepository,
                userId: widget.otherUserId,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarCircle(imageUrl: widget.otherAvatarUrl, fallbackText: displayName, radius: 14),
              const SizedBox(width: WynSpacing.space2),
              Flexible(
                child: Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: _textStyle(fontSize: 16, fontWeight: FontWeight.w700, color: WynColors.ink),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: WynColors.ink),
            tooltip: 'ตัวเลือกเพิ่มเติม',
            onPressed: _showConversationMenu,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshLatest,
                child: _buildMessageList(),
              ),
            ),
            _buildComposerArea(),
          ],
        ),
      ),
    );
  }

  static const _groupGapThreshold = Duration(seconds: 60);

  /// Grouping rule: same sender, within 60 seconds of each other, same
  /// calendar day. Symmetric -- order of [a]/[b] doesn't matter.
  bool _isSameGroup(ChatMessage a, ChatMessage b) {
    if (a.senderId != b.senderId) return false;
    if (a.createdAt.difference(b.createdAt).abs() > _groupGapThreshold) return false;
    final aLocal = a.createdAt.toLocal();
    final bLocal = b.createdAt.toLocal();
    return aLocal.year == bLocal.year && aLocal.month == bLocal.month && aLocal.day == bLocal.day;
  }

  /// True for the chronologically-*earliest* bubble of its group -- the
  /// one rendered at the *top* of the group on screen (index 0 = newest
  /// in this reverse-ordered list, so "earliest in the group" is the
  /// highest index whose next-older neighbor, index + 1, either doesn't
  /// exist or isn't part of the same group).
  bool _isGroupStart(int index) {
    if (index + 1 >= _messages.length) return true;
    return !_isSameGroup(_messages[index], _messages[index + 1]);
  }

  /// True for the chronologically-*latest* bubble of its group -- the
  /// one rendered at the *bottom* of the group on screen, where the
  /// avatar (incoming) and delivery/read receipt (outgoing, last message
  /// overall only) attach.
  bool _isGroupEnd(int index) {
    if (index == 0) return true;
    return !_isSameGroup(_messages[index - 1], _messages[index]);
  }

  /// Vertical gap to render below the bubble at [index] (toward its
  /// next-older neighbor, index + 1) -- 4px within a group, 16px between
  /// groups from the same sender, 20px between groups from different
  /// senders. Zero when there's no older neighbor in this list.
  double _gapBelowMessage(int index) {
    if (index + 1 >= _messages.length) return 0;
    final current = _messages[index];
    final older = _messages[index + 1];
    if (_isSameGroup(current, older)) return 4;
    return current.senderId == older.senderId ? 16 : 20;
  }

  /// A centered date-separator label belonging directly above
  /// (chronologically before) the message at [index], or null when none
  /// belongs there -- shown once per calendar day, never per-group and
  /// never carrying a time (tap-to-reveal handles time -- see
  /// [_onTapBubble]). The very first message ever (nothing older, and no
  /// more history left to load) always gets one.
  String? _dateSeparatorAbove(int index) {
    final current = _messages[index].createdAt.toLocal();
    if (index + 1 >= _messages.length) {
      return _hasMore ? null : _dateLabel(current);
    }
    final previous = _messages[index + 1].createdAt.toLocal();
    final sameDay =
        current.year == previous.year && current.month == previous.month && current.day == previous.day;
    return sameDay ? null : _dateLabel(current);
  }

  static const _thaiMonths = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', //
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  String _dateLabel(DateTime local) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    if (date == today) return 'วันนี้';
    if (date == today.subtract(const Duration(days: 1))) return 'เมื่อวาน';
    return '${local.day} ${_thaiMonths[local.month - 1]}';
  }

  String _timeLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  /// Tap-to-reveal timestamp (spec section 6): tapping a bubble shows its
  /// time for ~2 seconds, dismissed early by tapping any bubble again
  /// (including the same one, which just toggles it off) or by the timer.
  void _onTapBubble(String messageId) {
    _revealTimer?.cancel();
    if (_revealedTimestampMessageId == messageId) {
      setState(() => _revealedTimestampMessageId = null);
      return;
    }
    setState(() => _revealedTimestampMessageId = messageId);
    _revealTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _revealedTimestampMessageId = null);
    });
  }

  /// The index of the most recent message this user sent -- not
  /// necessarily index 0, since the other person may have sent the most
  /// recent message overall. Null if this user has never sent one.
  /// Computed once per list build, not per bubble.
  int? _lastMineMessageIndex() {
    for (var i = 0; i < _messages.length; i++) {
      if (_messages[i].senderId == _myUserId) return i;
    }
    return null;
  }

  /// The delivery/read receipt (spec section 7) for the bubble at
  /// [index], or null everywhere except the single last-outgoing-bubble
  /// in the whole conversation. [lastMineIndex] is
  /// [_lastMineMessageIndex]'s result, passed in rather than recomputed
  /// per bubble.
  _DeliveryStatus? _deliveryStatusAt(int index, int? lastMineIndex) {
    if (index != lastMineIndex) return null;
    final message = _messages[index];
    if (message.id.startsWith(_pendingIdPrefix)) return _DeliveryStatus.sending;
    final otherRead = _otherUserLastReadAt;
    if (otherRead != null && !otherRead.isBefore(message.createdAt)) return _DeliveryStatus.read;
    return _DeliveryStatus.sent;
  }

  Widget _buildMessageList() {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      final displayName = widget.otherDisplayName?.isNotEmpty == true
          ? widget.otherDisplayName!
          : '@${widget.otherUsername}';
      // A plain non-scrollable Center here would never receive the drag
      // RefreshIndicator (wrapping this whole build) needs to trigger --
      // CustomScrollView + SliverFillRemaining keeps this centered *and*
      // pull-to-refresh-able even for a brand new, empty conversation.
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(WynSpacing.space6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AvatarCircle(imageUrl: widget.otherAvatarUrl, fallbackText: displayName, radius: 40),
                    const SizedBox(height: WynSpacing.space4),
                    Text('เริ่มบทสนทนากับ $displayName', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final displayName = widget.otherDisplayName?.isNotEmpty == true
        ? widget.otherDisplayName!
        : '@${widget.otherUsername}';
    final lastMineIndex = _lastMineMessageIndex();

    return ListView.builder(
      controller: _scrollController,
      // Needed for RefreshIndicator's pull gesture to register even on a
      // short conversation that doesn't fill the viewport -- without
      // this, a list with no overflow to scroll never reports the drag.
      physics: const AlwaysScrollableScrollPhysics(),
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space3),
      itemCount: _messages.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return const Padding(
            padding: EdgeInsets.all(WynSpacing.space4),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final message = _messages[index];
        final isMine = message.senderId == _myUserId;
        final isPending = message.id.startsWith(_pendingIdPrefix);
        final isGroupStart = _isGroupStart(index);
        final isGroupEnd = _isGroupEnd(index);
        final dateSeparator = _dateSeparatorAbove(index);
        final bubble = _MessageBubble(
          message: message,
          isMine: isMine,
          showAvatar: !isMine && isGroupEnd,
          isGroupStart: isGroupStart,
          isGroupEnd: isGroupEnd,
          otherAvatarUrl: widget.otherAvatarUrl,
          otherDisplayName: displayName,
          isTimestampRevealed: _revealedTimestampMessageId == message.id,
          timeLabel: _timeLabel(message.createdAt),
          onTap: () => _onTapBubble(message.id),
          onLongPress: isPending ? null : () => _showMessageMenu(message),
          onTapReplyQuote: message.replyToMessageId == null
              ? null
              : () => _scrollToMessage(message.replyToMessageId!),
          onTapImage: (path) => _openEvidence(path),
          resolveSharedContent: _resolveSharedContent,
          onTapSharedContent: _openSharedContent,
          deliveryStatus: _deliveryStatusAt(index, lastMineIndex),
        );
        final gap = _gapBelowMessage(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (dateSeparator != null) _DateSeparator(label: dateSeparator),
            bubble,
            if (gap > 0) SizedBox(height: gap),
          ],
        );
      },
    );
  }

  Widget _buildComposerArea() {
    if (_blockRelationship.isBlockedEitherWay) {
      return Padding(
        padding: const EdgeInsets.all(WynSpacing.space4),
        child: Text(
          'คุณไม่สามารถส่งข้อความถึงผู้ใช้นี้ได้',
          textAlign: TextAlign.center,
          style: _textStyle(fontSize: 15, color: WynColors.graphite),
        ),
      );
    }
    if (_isSuspendedOrBanned) {
      return Padding(
        padding: const EdgeInsets.all(WynSpacing.space4),
        child: Text(
          'บัญชีของคุณถูกระงับ ไม่สามารถส่งข้อความได้ในขณะนี้',
          textAlign: TextAlign.center,
          style: _textStyle(fontSize: 15, color: WynColors.graphite),
        ),
      );
    }
    if (_restrictExpiresAt != null) {
      return RestrictionBanner(
        reason: _restrictReason,
        expiresAt: _restrictExpiresAt,
        actionId: _restrictActionId,
        appealStatus: _restrictAppealStatus,
        onAppeal: _openAppeal,
      );
    }
    if (_isPendingAsRecipient) {
      return _buildMessageRequestActionArea();
    }

    // WYN-084 (Wynos V1.0.0 Beta2, item 22): this used to be wrapped in
    // `Padding(bottom: MediaQuery.of(context).viewInsets.bottom)` --
    // double-compensating for the keyboard, since Scaffold already
    // resizes its body by that same viewInsets.bottom by default
    // (resizeToAvoidBottomInset defaults to true, never overridden on
    // this screen's Scaffold). The composer already sits right above
    // the keyboard once the body resizes; the extra manual padding
    // pushed it up a *second* keyboard-height's worth, which is the
    // "jumps up way too high" bug Founder reported. No Padding needed
    // here at all now -- Column, directly.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isPendingAsRequester) _buildAwaitingResponseLabel(),
        if (_replyTo != null) _buildReplyPreviewBar(),
        if (_imageBytes != null) _buildImagePreviewBar(),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: WynColors.hairline)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.image_outlined, size: 20, color: WynColors.graphite),
                tooltip: 'แนบรูป',
                onPressed: _isSending ? null : _pickImage,
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kBubbleFill,
                    borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                    border: Border.all(color: WynColors.hairline),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFieldFocusNode,
                    minLines: 1,
                    maxLines: 6,
                    maxLength: 2000,
                    // Deliberately never disabled while sending -- a
                    // disabled TextField drops focus and dismisses the
                    // keyboard, which used to happen the instant "send"
                    // was tapped. _send() is optimistic and clears the
                    // composer itself right away, so there's nothing
                    // left for disabling this to protect against.
                    style: _textStyle(fontSize: 16, color: WynColors.ink),
                    decoration: InputDecoration(
                      hintText: 'พิมพ์ข้อความ...',
                      hintStyle: _textStyle(fontSize: 16, color: WynColors.mutedNeutral),
                      border: InputBorder.none,
                      isCollapsed: true,
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: WynSpacing.space2),
              SizedBox(
                width: WynSpacing.touchTargetMin,
                height: WynSpacing.touchTargetMin,
                child: Material(
                  color: _canSend ? WynColors.sapphire : WynColors.hairline,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: _isSending
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _canSend ? WynColors.paper : WynColors.mutedNeutral,
                            ),
                          )
                        : Icon(Icons.send, size: 15, color: _canSend ? WynColors.paper : WynColors.mutedNeutral),
                    tooltip: 'ส่งข้อความ',
                    onPressed: _canSend ? _send : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// WYN-032 Design Screen 3: replaces the composer entirely for the
  /// recipient of a still-pending Message Request -- Accept/Delete are
  /// the primary decision (top row), Block/Report are secondary (smaller,
  /// bottom row). The message list above stays fully readable throughout.
  Widget _buildMessageRequestActionArea() {
    final displayName = widget.otherDisplayName?.isNotEmpty == true
        ? widget.otherDisplayName!
        : '@${widget.otherUsername}';
    return Padding(
      padding: const EdgeInsets.all(WynSpacing.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$displayName ต้องการส่งข้อความถึงคุณ', textAlign: TextAlign.center),
          const SizedBox(height: WynSpacing.space3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isDecidingRequest ? null : _deleteRequest,
                  child: const Text('ลบ'),
                ),
              ),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: FilledButton(
                  onPressed: _isDecidingRequest ? null : _acceptRequest,
                  child: _isDecidingRequest
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ยอมรับ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: WynSpacing.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _isDecidingRequest ? null : _blockFromRequest,
                child: const Text('บล็อก'),
              ),
              TextButton(
                onPressed: _isDecidingRequest ? null : _reportFromRequest,
                child: const Text('รายงาน'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAwaitingResponseLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
      child: Text(
        'รอการตอบรับ',
        style: _textStyle(fontSize: 13, color: WynColors.faint),
      ),
    );
  }

  Widget _buildReplyPreviewBar() {
    final replyTo = _replyTo!;
    final preview = replyTo.isDeleted
        ? 'ข้อความถูกลบ'
        : (replyTo.text?.isNotEmpty == true ? replyTo.text! : (replyTo.imageUrl != null ? '📷 รูปภาพ' : ''));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
      color: _kBubbleFill,
      child: Row(
        children: [
          Expanded(
            child: Text('ตอบกลับ: $preview', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
      color: _kBubbleFill,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
            child: Image.memory(_imageBytes!, width: 48, height: 48, fit: BoxFit.cover),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _imageBytes = null;
              _imageExtension = null;
            }),
          ),
        ],
      ),
    );
  }
}

/// 13-chat-thread.tsx's "list of #F1EFE9 fill" tint -- same literal
/// already established for input fields/pills elsewhere (search bar,
/// composer below), reused here for received bubbles.
const _kBubbleFill = WynColors.surfaceTint;

/// Delivery/read receipt states (spec section 7) -- applies only to the
/// single last-outgoing-bubble-in-the-conversation; see
/// [_ConversationScreenState._deliveryStatusAt].
enum _DeliveryStatus { sending, sent, read }

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showAvatar,
    required this.isGroupStart,
    required this.isGroupEnd,
    required this.otherAvatarUrl,
    required this.otherDisplayName,
    required this.isTimestampRevealed,
    required this.timeLabel,
    required this.onTap,
    required this.onLongPress,
    required this.onTapReplyQuote,
    required this.onTapImage,
    required this.resolveSharedContent,
    required this.onTapSharedContent,
    required this.deliveryStatus,
  });

  final ChatMessage message;
  final bool isMine;

  /// True only for the chronologically-latest (bottom-most on screen)
  /// bubble of a consecutive run from the other person -- see
  /// [_ConversationScreenState._isGroupEnd]. Always false when [isMine].
  final bool showAvatar;

  /// Group position, for corner radius only (spec section 5) -- see
  /// [_ConversationScreenState._isGroupStart]/[_isGroupEnd].
  final bool isGroupStart;
  final bool isGroupEnd;

  final String? otherAvatarUrl;
  final String otherDisplayName;

  /// Tap-to-reveal timestamp (spec section 6) -- see
  /// [_ConversationScreenState._onTapBubble].
  final bool isTimestampRevealed;
  final String timeLabel;
  final VoidCallback onTap;

  final VoidCallback? onLongPress;
  final VoidCallback? onTapReplyQuote;
  final void Function(String path) onTapImage;

  /// WYN-033 -- see `_ConversationScreenState._resolveSharedContent()`/
  /// `_openSharedContent()`.
  final Future<Object?> Function(SharedContentType type, String id) resolveSharedContent;
  final void Function(SharedContentType type, Object content) onTapSharedContent;

  /// Delivery/read receipt (spec section 7) -- null on every bubble
  /// except the single last-outgoing-message-in-the-conversation one.
  final _DeliveryStatus? deliveryStatus;

  // Reserves the same width whether or not the avatar is actually drawn
  // this bubble, so a multi-message burst from "them" stays left-aligned
  // instead of the bubble creeping left once the avatar disappears.
  static const _avatarSlotWidth = 36.0;

  static const _fullRadius = Radius.circular(18);
  static const _tightRadius = Radius.circular(4);

  /// Spec section 5: 18px on every corner, except the corner touching
  /// the *next* bubble in the same group -- that one tightens to 4px, to
  /// visually stitch the group together (the "tail" is always the
  /// group's true outer corner, left alone). A single-message group (both
  /// true) has no adjacent group-mate to stitch to, so stays full 18px
  /// on every corner.
  BorderRadius _cornerRadius() {
    if (isGroupStart && isGroupEnd) {
      return const BorderRadius.all(_fullRadius);
    }
    if (isMine) {
      return BorderRadius.only(
        topLeft: _fullRadius,
        bottomLeft: _fullRadius,
        topRight: isGroupStart ? _fullRadius : _tightRadius,
        bottomRight: isGroupEnd ? _fullRadius : _tightRadius,
      );
    }
    return BorderRadius.only(
      topRight: _fullRadius,
      bottomRight: _fullRadius,
      topLeft: isGroupStart ? _fullRadius : _tightRadius,
      bottomLeft: isGroupEnd ? _fullRadius : _tightRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.isDeleted ? WynColors.hairline : (isMine ? WynColors.sapphire : _kBubbleFill);
    final textColor = message.isDeleted ? WynColors.graphite : (isMine ? WynColors.paper : WynColors.ink);

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2 + 2),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: _cornerRadius(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.replyToMessageId != null && !message.isDeleted)
            GestureDetector(
              onTap: onTapReplyQuote,
              child: Container(
                margin: const EdgeInsets.only(bottom: WynSpacing.space2),
                padding: const EdgeInsets.symmetric(
                  horizontal: WynSpacing.space2,
                  vertical: WynSpacing.space1,
                ),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.08),
                  border: const Border(left: BorderSide(color: WynColors.sapphire, width: 2)),
                ),
                child: Text(
                  message.replyPreviewDeletedAt != null
                      ? 'ข้อความถูกลบ'
                      : (message.replyPreviewText?.isNotEmpty == true
                          ? message.replyPreviewText!
                          : (message.replyPreviewImageUrl != null ? '📷 รูปภาพ' : '')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _textStyle(fontSize: 13, color: textColor),
                ),
              ),
            ),
          if (message.isDeleted)
            Text(
              'ข้อความนี้ถูกลบ',
              style: _textStyle(fontSize: 15, fontStyle: FontStyle.italic, color: textColor),
            )
          else ...[
            if (message.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: WynSpacing.space1),
                child: GestureDetector(
                  onTap: () => onTapImage(message.imageUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                    child: Container(
                      width: 160,
                      height: 160,
                      color: WynColors.hairline,
                      child: const Icon(Icons.image_outlined, color: WynColors.graphite),
                    ),
                  ),
                ),
              ),
            if (message.sharedContentType != null && message.sharedContentId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: WynSpacing.space1),
                child: _SharedContentPreview(
                  type: message.sharedContentType!,
                  id: message.sharedContentId!,
                  textColor: textColor,
                  resolveSharedContent: resolveSharedContent,
                  onTapSharedContent: onTapSharedContent,
                ),
              ),
            if (message.text != null)
              Text(message.text!, style: _textStyle(fontSize: 15, color: textColor, height: 1.45)),
          ],
        ],
      ),
    );

    // Reserved for a left-aligned incoming bubble's timestamp/nothing;
    // right-aligned (mine) bubbles have no avatar slot to offset past.
    final leadingInset = isMine ? 0.0 : _avatarSlotWidth + WynSpacing.space2;

    return GestureDetector(
      onTap: message.isDeleted ? null : onTap,
      onLongPress: message.isDeleted ? null : onLongPress,
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMine) ...[
                SizedBox(
                  width: _avatarSlotWidth,
                  child: showAvatar
                      ? AvatarCircle(imageUrl: otherAvatarUrl, fallbackText: otherDisplayName, radius: 15, ring: true)
                      : null,
                ),
                const SizedBox(width: WynSpacing.space2),
              ],
              Flexible(child: bubble),
            ],
          ),
          // Spec section 6: hidden by default, revealed on tap for ~2s.
          if (isTimestampRevealed)
            Padding(
              padding: EdgeInsets.only(top: 2, left: leadingInset),
              child: Text(timeLabel, style: _textStyle(fontSize: 11, color: WynColors.faint)),
            ),
          // Spec section 7: only ever set on the single last-outgoing
          // bubble in the whole conversation.
          if (deliveryStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _DeliveryStatusIcon(status: deliveryStatus!),
            ),
        ],
      ),
    );
  }
}

class _DeliveryStatusIcon extends StatelessWidget {
  const _DeliveryStatusIcon({required this.status});

  final _DeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      _DeliveryStatus.sending => const Icon(Icons.fiber_manual_record, size: 8, color: WynColors.faint),
      _DeliveryStatus.sent => const Icon(Icons.check, size: 14, color: WynColors.faint),
      _DeliveryStatus.read => const Icon(Icons.check, size: 14, color: WynColors.sapphire),
    };
  }
}

/// Spec section 6: a centered, muted date-only label shown once per
/// calendar day -- never per-group, never carrying a time. See
/// [_ConversationScreenState._dateSeparatorAbove].
class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
      child: Center(
        child: Text(label, style: _textStyle(fontSize: 13, color: WynColors.faint)),
      ),
    );
  }
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  FontStyle fontStyle = FontStyle.normal,
  Color? color,
  double? height,
}) =>
    TextStyle(fontSize: fontSize, fontWeight: fontWeight, fontStyle: fontStyle, color: color, height: height);

/// Screen 4 (WYN-033) -- the shared Drop/Profile/Club preview card
/// inside a message bubble. See
/// .wyn/docs/design/wyn-033-share-to-chat.md, Screen 4. Resolves the
/// referenced content once (a `StatefulWidget`, not a `FutureBuilder`
/// built fresh on every rebuild, which would re-trigger the lookup --
/// see `resolveSharedContent`'s own cache, which this still relies on
/// for scroll-driven bubble rebuilds elsewhere in the list).
class _SharedContentPreview extends StatefulWidget {
  const _SharedContentPreview({
    required this.type,
    required this.id,
    required this.textColor,
    required this.resolveSharedContent,
    required this.onTapSharedContent,
  });

  final SharedContentType type;
  final String id;
  final Color textColor;
  final Future<Object?> Function(SharedContentType type, String id) resolveSharedContent;
  final void Function(SharedContentType type, Object content) onTapSharedContent;

  @override
  State<_SharedContentPreview> createState() => _SharedContentPreviewState();
}

class _SharedContentPreviewState extends State<_SharedContentPreview> {
  late final Future<Object?> _future = widget.resolveSharedContent(widget.type, widget.id);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<Object?>(
      future: _future,
      builder: (context, snapshot) {
        final cardDecoration = BoxDecoration(
          color: widget.textColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
          border: Border.all(color: widget.textColor.withValues(alpha: 0.15)),
        );

        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            width: 220,
            height: 64,
            decoration: cardDecoration,
          );
        }

        final content = snapshot.data;
        if (content == null) {
          return Container(
            width: 220,
            padding: const EdgeInsets.all(WynSpacing.space2),
            decoration: cardDecoration,
            child: Text(
              'เนื้อหานี้ไม่พร้อมใช้งาน',
              style: TextStyle(color: widget.textColor, fontStyle: FontStyle.italic),
            ),
          );
        }

        final (leading, title, subtitle) = switch (widget.type) {
          SharedContentType.drop => (
              _thumbnail(colorScheme, Icons.image_outlined),
              '@${(content as Drop).authorUsername}',
              content.caption ?? '',
            ),
          SharedContentType.profile => (
              AvatarCircle(
                imageUrl: (content as Profile).avatarUrl,
                fallbackText: content.username,
                radius: 24,
              ),
              content.displayName?.isNotEmpty == true ? content.displayName! : '@${content.username}',
              content.bio ?? '@${content.username}',
            ),
          SharedContentType.club => (
              _thumbnail(colorScheme, Icons.groups_outlined),
              (content as Club).name,
              content.description ?? '',
            ),
        };

        return GestureDetector(
          onTap: () => widget.onTapSharedContent(widget.type, content),
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(WynSpacing.space2),
            decoration: cardDecoration,
            child: Row(
              children: [
                leading,
                const SizedBox(width: WynSpacing.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: widget.textColor, fontWeight: FontWeight.bold),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: widget.textColor.withValues(alpha: 0.8),
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _thumbnail(ColorScheme colorScheme, IconData icon) => ClipRRect(
        borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
        child: Container(
          width: 48,
          height: 48,
          color: colorScheme.surfaceContainerHighest,
          child: Icon(icon, color: colorScheme.onSurfaceVariant),
        ),
      );
}
