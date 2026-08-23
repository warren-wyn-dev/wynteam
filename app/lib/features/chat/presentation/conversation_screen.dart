import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/restriction_banner.dart';
import '../../block/data/block_relationship.dart';
import '../../block/data/block_repository.dart';
import '../../block/presentation/block_dialogs.dart';
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

/// Screen 3 -- the conversation itself. See
/// .wyn/docs/design/wyn-031-chat-1to1.md, Screen 3.
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
  })  : _blockRepository = blockRepository,
        _moderationRepository = moderationRepository,
        _reportRepository = reportRepository,
        _profileRepository = profileRepository,
        _followRepository = followRepository,
        _dropRepository = dropRepository,
        _popRepository = popRepository,
        _savedRepository = savedRepository,
        _appealRepository = appealRepository;

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

  RealtimeChannel? _channel;

  bool get _isComposerDisabled =>
      _blockRelationship.isBlockedEitherWay || _restrictExpiresAt != null || _isSuspendedOrBanned;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _loadSafetyState();
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
      appBar: AppBar(
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
              AvatarCircle(imageUrl: widget.otherAvatarUrl, fallbackText: displayName, radius: 16),
              const SizedBox(width: WynSpacing.space2),
              Flexible(child: Text(displayName, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'ตัวเลือกเพิ่มเติม',
            onPressed: _showConversationMenu,
          ),
        ],
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

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
      itemCount: _messages.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return const Padding(
            padding: EdgeInsets.all(WynSpacing.space4),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final message = _messages[index];
        return _MessageBubble(
          message: message,
          isMine: message.senderId == _myUserId,
          onLongPress: () => _showMessageMenu(message),
          onTapReplyQuote: message.replyToMessageId == null
              ? null
              : () => _scrollToMessage(message.replyToMessageId!),
          onTapImage: (path) => _openEvidence(path),
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    if (_isSuspendedOrBanned) {
      return Padding(
        padding: const EdgeInsets.all(WynSpacing.space4),
        child: Text(
          'บัญชีของคุณถูกระงับ ไม่สามารถส่งข้อความได้ในขณะนี้',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyTo != null) _buildReplyPreviewBar(),
          if (_imageBytes != null) _buildImagePreviewBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2, vertical: WynSpacing.space2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  tooltip: 'แนบรูป',
                  onPressed: _isSending ? null : _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 6,
                    maxLength: 2000,
                    enabled: !_isSending,
                    decoration: const InputDecoration(
                      hintText: 'พิมพ์ข้อความ...',
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: WynSpacing.touchTargetMin,
                  height: WynSpacing.touchTargetMin,
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    tooltip: 'ส่งข้อความ',
                    onPressed: _canSend ? _send : null,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      color: Theme.of(context).colorScheme.surfaceContainer,
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
      color: Theme.of(context).colorScheme.surfaceContainer,
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onLongPress,
    required this.onTapReplyQuote,
    required this.onTapImage,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback onLongPress;
  final VoidCallback? onTapReplyQuote;
  final void Function(String path) onTapImage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = message.isDeleted
        ? colorScheme.surfaceContainer
        : (isMine ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh);
    final textColor = message.isDeleted
        ? colorScheme.onSurfaceVariant
        : (isMine ? colorScheme.onPrimaryContainer : colorScheme.onSurface);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: message.isDeleted ? null : onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: WynSpacing.space1),
          padding: const EdgeInsets.all(WynSpacing.space3),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
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
                      border: Border(left: BorderSide(color: colorScheme.primary, width: 2)),
                    ),
                    child: Text(
                      message.replyPreviewDeletedAt != null
                          ? 'ข้อความถูกลบ'
                          : (message.replyPreviewText?.isNotEmpty == true
                              ? message.replyPreviewText!
                              : (message.replyPreviewImageUrl != null ? '📷 รูปภาพ' : '')),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor),
                    ),
                  ),
                ),
              if (message.isDeleted)
                Text(
                  'ข้อความนี้ถูกลบ',
                  style: TextStyle(color: textColor, fontStyle: FontStyle.italic),
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
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.image_outlined, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                if (message.text != null) Text(message.text!, style: TextStyle(color: textColor)),
              ],
              const SizedBox(height: WynSpacing.space1),
              Text(
                relativeTimeLabel(message.createdAt, now: DateTime.now()),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: textColor.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
