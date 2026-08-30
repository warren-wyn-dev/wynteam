import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
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
/// sapphire-filled bubbles (mine) vs. tinted #F1EFE9 bubbles (theirs) with
/// an asymmetric "tail" corner, a small avatar shown only on the first
/// bubble of each consecutive run from the other person (never repeated
/// down a burst), and no per-bubble timestamp -- only a centered, muted
/// divider when there's a real time gap between message groups (see
/// [_ConversationScreenState._isRunStart]/[_dividerLabelAbove]).
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

class _ConversationScreenState extends State<ConversationScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
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

  RealtimeChannel? _channel;

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
    _loadInitial();
    _loadSafetyState();
    _loadConversationMeta();
    widget.chatRepository.markConversationRead(widget.conversationId);
    _scrollController.addListener(_onScroll);
    _channel = widget.chatRepository.subscribeToConversationMessages(
      widget.conversationId,
      _onRealtimeMessage,
    );
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) widget.chatRepository.unsubscribe(channel);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onRealtimeMessage(ChatMessage message) {
    if (!mounted) return;
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() => _messages.insert(0, message));
    if (message.senderId != _myUserId) {
      widget.chatRepository.markConversationRead(widget.conversationId);
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
      if (!mounted || meta == null) return;
      setState(() {
        _conversationStatus = meta.status;
        _requestedBy = meta.requestedBy;
      });
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

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _isSending = true);
    try {
      final sent = await widget.chatRepository.sendMessage(
        conversationId: widget.conversationId,
        text: _textController.text,
        imageBytes: _imageBytes,
        imageExtension: _imageExtension,
        replyToMessageId: _replyTo?.id,
      );
      if (!mounted) return;
      if (!_messages.any((m) => m.id == sent.id)) {
        setState(() => _messages.insert(0, sent));
      }
      _textController.clear();
      setState(() {
        _imageBytes = null;
        _imageExtension = null;
        _replyTo = null;
      });
    } catch (_) {
      if (!mounted) return;
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
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (canReply)
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('ตอบกลับ'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _replyTo = message);
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('ลบ'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _deleteMessage(message);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('รายงาน'),
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
          ],
        ),
      ),
    );
  }

  Future<void> _showConversationMenu() async {
    final isMuted = await widget.chatRepository.isConversationMuted(widget.conversationId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
              title: Text(isMuted ? 'เปิดแจ้งเตือนบทสนทนานี้' : 'ปิดแจ้งเตือนบทสนทนานี้'),
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
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('บล็อก'),
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
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('ดูโปรไฟล์'),
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
          ],
        ),
      ),
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
                  style: _interStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: WynColors.ink),
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
            Expanded(child: _buildMessageList()),
            _buildComposerArea(),
          ],
        ),
      ),
    );
  }

  /// 13-chat-thread.tsx: avatar shows only on the first bubble of each
  /// consecutive run from the other person -- the chronologically
  /// *earliest* message in the run, which in this reverse-ordered list
  /// (index 0 = newest) is the one whose next-older neighbor (index + 1)
  /// either doesn't exist or is from someone else.
  bool _isRunStart(int index) {
    if (index + 1 >= _messages.length) return true;
    return _messages[index + 1].senderId != _messages[index].senderId;
  }

  /// The label for a centered time divider that belongs directly above
  /// (chronologically before) the message at [index], or null when no
  /// divider belongs there. Shown only for a real time gap (>30 minutes)
  /// or a day change between this message and the previous one -- never
  /// per-bubble, matching 13-chat-thread.tsx's own doc comment ("a
  /// centered, muted timestamp divider appears only when there's a
  /// meaningful time gap"). The very first message ever (nothing older,
  /// and no more history left to load) always gets one.
  String? _dividerLabelAbove(int index) {
    final current = _messages[index].createdAt;
    if (index + 1 >= _messages.length) {
      return _hasMore ? null : _dividerLabel(current);
    }
    final previous = _messages[index + 1].createdAt;
    final gap = current.difference(previous).abs();
    final sameDay = current.toLocal().year == previous.toLocal().year &&
        current.toLocal().month == previous.toLocal().month &&
        current.toLocal().day == previous.toLocal().day;
    if (gap > const Duration(minutes: 30) || !sameDay) {
      return _dividerLabel(current);
    }
    return null;
  }

  String _dividerLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}';
    if (date == today) return 'วันนี้ $time';
    if (date == today.subtract(const Duration(days: 1))) return 'เมื่อวาน $time';
    return '${local.day}/${local.month} $time';
  }

  Widget _buildMessageList() {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      final displayName = widget.otherDisplayName?.isNotEmpty == true
          ? widget.otherDisplayName!
          : '@${widget.otherUsername}';
      return Center(
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
      );
    }

    final displayName = widget.otherDisplayName?.isNotEmpty == true
        ? widget.otherDisplayName!
        : '@${widget.otherUsername}';

    return ListView.builder(
      controller: _scrollController,
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
        final dividerLabel = _dividerLabelAbove(index);
        final bubble = _MessageBubble(
          message: message,
          isMine: isMine,
          showAvatar: !isMine && _isRunStart(index),
          otherAvatarUrl: widget.otherAvatarUrl,
          otherDisplayName: displayName,
          onLongPress: () => _showMessageMenu(message),
          onTapReplyQuote: message.replyToMessageId == null
              ? null
              : () => _scrollToMessage(message.replyToMessageId!),
          onTapImage: (path) => _openEvidence(path),
          resolveSharedContent: _resolveSharedContent,
          onTapSharedContent: _openSharedContent,
        );
        if (dividerLabel == null) return bubble;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_TimeDivider(label: dividerLabel), bubble],
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
          style: _interStyle(fontSize: 13.5, color: WynColors.graphite),
        ),
      );
    }
    if (_isSuspendedOrBanned) {
      return Padding(
        padding: const EdgeInsets.all(WynSpacing.space4),
        child: Text(
          'บัญชีของคุณถูกระงับ ไม่สามารถส่งข้อความได้ในขณะนี้',
          textAlign: TextAlign.center,
          style: _interStyle(fontSize: 13.5, color: WynColors.graphite),
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
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
                      minLines: 1,
                      maxLines: 6,
                      maxLength: 2000,
                      enabled: !_isSending,
                      style: _interStyle(fontSize: 13.5, color: WynColors.ink),
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        hintStyle: _interStyle(fontSize: 13.5, color: WynColors.mutedNeutral),
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
      ),
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
        style: _interStyle(fontSize: 12, color: WynColors.faint),
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
const _kBubbleFill = Color(0xFFF1EFE9);

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showAvatar,
    required this.otherAvatarUrl,
    required this.otherDisplayName,
    required this.onLongPress,
    required this.onTapReplyQuote,
    required this.onTapImage,
    required this.resolveSharedContent,
    required this.onTapSharedContent,
  });

  final ChatMessage message;
  final bool isMine;

  /// True only for the chronologically-first bubble of a consecutive
  /// run from the other person -- see
  /// [_ConversationScreenState._isRunStart]. Always false when [isMine].
  final bool showAvatar;
  final String? otherAvatarUrl;
  final String otherDisplayName;

  final VoidCallback onLongPress;
  final VoidCallback? onTapReplyQuote;
  final void Function(String path) onTapImage;

  /// WYN-033 -- see `_ConversationScreenState._resolveSharedContent()`/
  /// `_openSharedContent()`.
  final Future<Object?> Function(SharedContentType type, String id) resolveSharedContent;
  final void Function(SharedContentType type, Object content) onTapSharedContent;

  // Reserves the same width whether or not the avatar is actually drawn
  // this bubble, so a multi-message burst from "them" stays left-aligned
  // instead of the bubble creeping left once the avatar disappears.
  static const _avatarSlotWidth = 36.0;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.isDeleted ? WynColors.hairline : (isMine ? WynColors.sapphire : _kBubbleFill);
    final textColor = message.isDeleted ? WynColors.graphite : (isMine ? WynColors.paper : WynColors.ink);

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2 + 2),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(WynSpacing.radiusLg),
          topRight: const Radius.circular(WynSpacing.radiusLg),
          bottomRight: Radius.circular(isMine ? 6 : WynSpacing.radiusLg),
          bottomLeft: Radius.circular(isMine ? WynSpacing.radiusLg : 6),
        ),
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
                  style: _interStyle(fontSize: 12.5, color: textColor),
                ),
              ),
            ),
          if (message.isDeleted)
            Text(
              'ข้อความนี้ถูกลบ',
              style: _interStyle(fontSize: 14, fontStyle: FontStyle.italic, color: textColor),
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
              Text(message.text!, style: _interStyle(fontSize: 14, color: textColor, height: 1.4)),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onLongPress: message.isDeleted ? null : onLongPress,
        child: Row(
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
      ),
    );
  }
}

/// 13-chat-thread.tsx's `TimeDivider` -- a centered, muted label shown
/// only for a real time gap between message groups. See
/// [_ConversationScreenState._dividerLabelAbove].
class _TimeDivider extends StatelessWidget {
  const _TimeDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
      child: Center(
        child: Text(label, style: _interStyle(fontSize: 11, color: WynColors.faint)),
      ),
    );
  }
}

TextStyle _interStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  FontStyle fontStyle = FontStyle.normal,
  Color? color,
  double? height,
}) =>
    GoogleFonts.inter(fontSize: fontSize, fontWeight: fontWeight, fontStyle: fontStyle, color: color, height: height);

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
