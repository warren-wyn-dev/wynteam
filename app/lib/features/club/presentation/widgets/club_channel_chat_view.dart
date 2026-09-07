import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/action_sheet_row.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/widgets/empty_state_block.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/club_channel_chat_repository.dart';
import '../../data/club_channel_message.dart';
import '../../data/club_member.dart';
import '../../data/club_repository.dart';
import '../../../report/data/report_repository.dart';
import '../../../report/data/report_target_type.dart';
import '../../../report/presentation/report_sheet.dart';

/// WYN-128 -- the group chat room for one WYN-127 channel, embedded
/// inline under the "โพสต์ | แชท" toggle (ClubPostsTab hosts this, not a
/// separate route -- Design Rules: "ไม่ต้องสร้าง navigation ชั้นใหม่").
///
/// Reuses ConversationScreen's (WYN-031) visual language as closely as
/// this being embedded (not a full Scaffold/AppBar of its own) allows --
/// sapphire-filled sent bubbles / surfaceTint received bubbles, the same
/// pill TextField + circular send button input bar -- per Design Rules:
/// "ห้ามสร้าง UI chat ใหม่ตั้งแต่ศูนย์ -- reuse component จาก WYN-031 ให้
/// มากที่สุด". `ConversationScreen`'s own bubble widget
/// (`_MessageBubble`) is private and tightly coupled to 1:1-only
/// concepts this room doesn't have (View Once, delivery receipts scoped
/// to one other participant, shared-content preview cards) -- so this
/// file has its own small `_ChatBubble`, styled identically, rather than
/// forcing an incompatible reuse. See this task's own Handoff notes for
/// the full reasoning.
///
/// Differences from 1:1 chat, exactly the 2 the Design spec calls for:
/// (1) a sender-name label above every incoming bubble (a group needs
/// it, a 1:1 thread doesn't), (2) online-member-count in the header
/// instead of one peer's online/offline status.
class ClubChannelChatView extends StatefulWidget {
  const ClubChannelChatView({
    super.key,
    required this.repository,
    required this.clubRepository,
    required this.clubId,
    required this.channelId,
    required this.channelName,
    required this.myRole,
    this.onBanned,
  });

  final ClubChannelChatRepository repository;

  /// WYN-128: only used here to watch this user's own membership row for
  /// the ban-mid-chat check below -- see [ClubRepository.subscribeToMyMembership].
  final ClubRepository clubRepository;
  final String clubId;
  final String channelId;
  final String channelName;
  final ClubMemberRole? myRole;

  /// Called once if this user's own `club_members` row for [clubId] is
  /// removed/banned while this view is open -- Design's States: "ถูก ban
  /// ระหว่างเปิดหน้าแชทอยู่ -> เด้งออกจากหน้าทันที". Since this view is
  /// embedded (no route of its own to pop -- see the class doc comment),
  /// the caller (ClubPostsTab) is the one that actually reacts: switches
  /// back to the Posts view and reloads the Club, which then falls back
  /// to the ordinary non-member gating on its own.
  final VoidCallback? onBanned;

  @override
  State<ClubChannelChatView> createState() => _ClubChannelChatViewState();
}

class _ClubChannelChatViewState extends State<ClubChannelChatView> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final List<ClubChannelMessage> _messages = [];

  // WYN-128 fast-follow (.wyn/tasks/bugs/WYN-128-group-chat-missing-report-action.md):
  // reuses the exact same ReportRepository/showReportSheet flow every
  // other user-generated-content surface in the app already goes
  // through (club_post_card.dart/club_post_detail_screen.dart) -- no
  // new report UI built for this.
  final _reportRepository = ReportRepository(Supabase.instance.client);

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isSending = false;
  int _onlineCount = 0;

  ClubChannelMessage? _replyTo;
  Uint8List? _imageBytes;
  String? _imageExtension;

  RealtimeChannel? _channel;
  RealtimeChannel? _membershipChannel;

  String get _myUserId => Supabase.instance.client.auth.currentUser!.id;
  bool get _canModerate => widget.myRole?.canModeratePosts ?? false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    widget.repository.markChannelRead(widget.channelId).catchError((_) {});
    _channel = widget.repository.subscribeToChannel(
      widget.channelId,
      _onRealtimeMessage,
      onPresenceChange: (count) {
        if (mounted) setState(() => _onlineCount = count);
      },
    );
    _subscribeMembership();
  }

  /// See the class doc comment / [ClubChannelChatView.onBanned]. Routed
  /// through [ClubRepository] (not a raw `Supabase.instance.client` call
  /// here) purely so a widget test can stub it out -- a real `.subscribe()`
  /// call attempts a genuine WebSocket connection that leaves a pending
  /// Timer behind in `flutter_test` (.wyn/learning/PATTERNS.md).
  void _subscribeMembership() {
    _membershipChannel = widget.clubRepository.subscribeToMyMembership(
      widget.clubId,
      () => widget.onBanned?.call(),
    );
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) widget.repository.unsubscribe(channel);
    final membershipChannel = _membershipChannel;
    if (membershipChannel != null) widget.clubRepository.unsubscribe(membershipChannel);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onRealtimeMessage(ClubChannelMessage message) {
    if (!mounted) return;
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() => _messages.insert(0, message));
    if (message.authorId != _myUserId) {
      widget.repository.markChannelRead(widget.channelId).catchError((_) {});
    }
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoadingInitial = true);
    try {
      final messages = await widget.repository.fetchMessages(widget.channelId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _hasMore = messages.length == ClubChannelChatRepository.messagePageSize;
      });
    } catch (_) {
      // Fails open to an empty list, same posture as ConversationScreen.
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_messages.isEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      final oldest = _messages.last.createdAt;
      final more =
          await widget.repository.fetchMessages(widget.channelId, beforeCreatedAt: oldest);
      if (!mounted) return;
      setState(() {
        _messages.addAll(more);
        _hasMore = more.length == ClubChannelChatRepository.messagePageSize;
      });
    } catch (_) {
      // Silent, same posture as every other list's load-more failure.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
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
      !_isSending && (_textController.text.trim().isNotEmpty || _imageBytes != null);

  Future<void> _send() async {
    if (!_canSend) return;
    final text = _textController.text;
    final imageBytes = _imageBytes;
    final imageExtension = _imageExtension;
    final replyTo = _replyTo;
    _textController.clear();
    setState(() {
      _isSending = true;
      _imageBytes = null;
      _imageExtension = null;
      _replyTo = null;
    });
    try {
      final sent = await widget.repository.sendMessage(
        clubId: widget.clubId,
        channelId: widget.channelId,
        content: text,
        imageBytes: imageBytes,
        imageExtension: imageExtension,
        replyToMessageId: replyTo?.id,
      );
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m.id == sent.id)) _messages.insert(0, sent);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
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

  Future<void> _deleteMessage(ClubChannelMessage message) async {
    final confirmed = await confirmDeletePost(context, itemLabel: 'ข้อความ');
    if (!confirmed || !mounted) return;
    try {
      await widget.repository.deleteMessage(message.id);
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.id == message.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบข้อความไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _reportMessage(ClubChannelMessage message) {
    return showReportSheet(
      context,
      reportRepository: _reportRepository,
      targetType: ReportTargetType.clubChannelMessage,
      targetId: message.id,
      targetLabel: 'รายงานข้อความของ ${message.authorNameOrUsername}',
      associatedUserId: message.authorId,
    );
  }

  Future<void> _showMessageMenu(ClubChannelMessage message) async {
    final isMine = message.authorId == _myUserId;
    final canDelete = isMine || _canModerate;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        ActionSheetRow(
          icon: Icons.reply_outlined,
          label: 'ตอบกลับ',
          onTap: () {
            Navigator.of(sheetContext).pop();
            setState(() => _replyTo = message);
          },
        ),
        if (canDelete)
          ActionSheetRow(
            icon: Icons.delete_outline,
            label: 'ลบข้อความ',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _deleteMessage(message);
            },
          ),
        // Report is always the last item and only ever shown for
        // someone else's message -- same posture as club_post_card.dart's
        // own "รายงานโพสต์" row (wyn-026-report-system.md, Screen 6).
        if (!isMine)
          ActionSheetRow(
            icon: Icons.flag_outlined,
            label: 'รายงานข้อความ',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _reportMessage(message);
            },
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1, color: WynColors.hairline),
        Expanded(child: _buildMessageList()),
        _buildComposer(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: _onlineCount > 0 ? WynColors.sapphire : WynColors.faint),
          const SizedBox(width: WynSpacing.space1),
          Text(
            '$_onlineCount คนออนไลน์ในห้องนี้',
            style: const TextStyle(fontSize: 12, color: WynColors.graphite),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return const Center(
        child: EmptyStateBlock(
          icon: Icons.forum_outlined,
          title: 'ยังไม่มีใครพิมพ์เลย',
          subtitle: 'เริ่มบทสนทนาในห้องนี้เป็นคนแรก',
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _onScroll();
        return false;
      },
      child: ListView.builder(
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
          return Padding(
            padding: const EdgeInsets.only(bottom: WynSpacing.space3),
            child: _ChatBubble(
              message: message,
              isMine: message.authorId == _myUserId,
              onLongPress: () => _showMessageMenu(message),
              resolveImageUrl: widget.repository.imageSignedUrl,
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                    color: WynColors.surfaceTint,
                    borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                    border: Border.all(color: WynColors.hairline),
                  ),
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 6,
                    maxLength: 2000,
                    style: const TextStyle(fontSize: 16, color: WynColors.ink),
                    decoration: const InputDecoration(
                      hintText: 'พิมพ์ข้อความ...',
                      hintStyle: TextStyle(fontSize: 16, color: WynColors.mutedNeutral),
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

  Widget _buildReplyPreviewBar() {
    final replyTo = _replyTo!;
    final preview =
        replyTo.content?.isNotEmpty == true ? replyTo.content! : (replyTo.imageUrl != null ? '📷 รูปภาพ' : '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
      color: WynColors.surfaceTint,
      child: Row(
        children: [
          Expanded(
            child: Text('ตอบกลับ ${replyTo.authorUsername}: $preview',
                maxLines: 1, overflow: TextOverflow.ellipsis),
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
      color: WynColors.surfaceTint,
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

/// Styled identically to ConversationScreen's own bubble (sapphire fill/
/// white text sent, surfaceTint fill received, asymmetric tail corner)
/// -- see the class doc comment above for why this is its own small
/// widget rather than reusing that screen's private `_MessageBubble`.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.onLongPress,
    required this.resolveImageUrl,
  });

  final ClubChannelMessage message;
  final bool isMine;
  final VoidCallback onLongPress;
  final Future<String?> Function(String path) resolveImageUrl;

  String get _authorLabel => message.authorDisplayName?.isNotEmpty == true
      ? message.authorDisplayName!
      : '@${message.authorUsername}';

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? WynColors.sapphire : WynColors.surfaceTint;
    final textColor = isMine ? WynColors.paper : WynColors.ink;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 18),
    );

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: bubbleColor, borderRadius: radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.replyToMessageId != null) _buildReplyQuote(isMine),
              if (message.imageUrl != null) _buildImage(),
              if (message.content != null && message.content!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: message.imageUrl != null ? WynSpacing.space1 : 0),
                  child: Text(message.content!, style: TextStyle(fontSize: 15, color: textColor)),
                ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // WYN-128's own addition vs. 1:1 chat -- a group needs the
        // sender's name above every incoming bubble.
        if (!isMine)
          Padding(
            padding: const EdgeInsets.only(left: WynSpacing.space2, bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarCircle(imageUrl: message.authorAvatarUrl, fallbackText: _authorLabel, radius: 10),
                const SizedBox(width: WynSpacing.space1),
                Text(_authorLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WynColors.graphite)),
              ],
            ),
          ),
        bubble,
      ],
    );
  }

  Widget _buildReplyQuote(bool isMine) {
    final preview = message.replyPreviewContent?.isNotEmpty == true
        ? message.replyPreviewContent!
        : (message.replyPreviewImageUrl != null ? '📷 รูปภาพ' : 'ข้อความ');
    return Container(
      margin: const EdgeInsets.only(bottom: WynSpacing.space1),
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2, vertical: 4),
      decoration: BoxDecoration(
        color: (isMine ? WynColors.paper : WynColors.hairline).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
      ),
      child: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: isMine ? WynColors.paper : WynColors.graphite,
        ),
      ),
    );
  }

  Widget _buildImage() {
    final path = message.imageUrl!;
    return FutureBuilder<String?>(
      future: resolveImageUrl(path),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) {
          return const SizedBox(
            width: 160,
            height: 160,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
          child: Image.network(url, width: 200, height: 200, fit: BoxFit.cover),
        );
      },
    );
  }
}
