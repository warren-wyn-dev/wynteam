import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/chat_repository.dart';
import '../data/conversation.dart';
import 'conversation_screen.dart';
import 'message_request_list_screen.dart';

/// Screen 2 -- the Chat Inbox: every conversation this user is part of,
/// sorted by most recent activity first. See
/// .wyn/docs/design/wyn-031-chat-1to1.md, Screen 2.
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key, required this.chatRepository});

  final ChatRepository chatRepository;

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final _scrollController = ScrollController();
  final List<Conversation> _conversations = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  RealtimeChannel? _channel;
  int _pendingRequestCount = 0;

  String get _myUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _loadPendingRequestCount();
    _scrollController.addListener(_onScroll);
    // Any new message across any of this user's conversations can
    // change this list's ordering/preview/unread state -- simplest
    // correct reaction is a full reload rather than trying to patch one
    // row in place (Basic DM, inbox size is small, not worth the extra
    // complexity of a partial merge). This also fires for a brand new
    // Message Request's first message (its own INSERT into `messages`
    // is what this subscribes to, same as any other message) -- refresh
    // the banner count too so it doesn't wait for the next screen open.
    _channel = widget.chatRepository.subscribeToMyMessages((_) {
      if (mounted) {
        _loadInitial();
        _loadPendingRequestCount();
      }
    });
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) widget.chatRepository.unsubscribe(channel);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final conversations = await widget.chatRepository.fetchInbox(page: 0);
      if (!mounted) return;
      setState(() {
        _conversations
          ..clear()
          ..addAll(conversations);
        _page = 0;
        _hasMore = conversations.length == ChatRepository.pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'โหลดรายการไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadPendingRequestCount() async {
    try {
      final count = await widget.chatRepository.countPendingMessageRequests();
      if (mounted) setState(() => _pendingRequestCount = count);
    } catch (_) {
      // Silent -- a missed badge count isn't worth a blocking error; the
      // banner just stays hidden until the next successful load.
    }
  }

  Future<void> _openMessageRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageRequestListScreen(chatRepository: widget.chatRepository),
      ),
    );
    // Requests may have been accepted/deleted while that screen was
    // open -- both the banner count and (if any were accepted) this
    // list itself may need to change.
    if (mounted) {
      _loadPendingRequestCount();
      _loadInitial();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final conversations = await widget.chatRepository.fetchInbox(page: nextPage);
      if (!mounted) return;
      setState(() {
        _conversations.addAll(conversations);
        _page = nextPage;
        _hasMore = conversations.length == ChatRepository.pageSize;
      });
    } catch (_) {
      // Silent, same posture as every other list's load-more failure.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openConversation(Conversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          chatRepository: widget.chatRepository,
          conversationId: conversation.id,
          otherUserId: conversation.otherUserId,
          otherUsername: conversation.otherUsername,
          otherDisplayName: conversation.otherDisplayName,
          otherAvatarUrl: conversation.otherAvatarUrl,
        ),
      ),
    );
    // The conversation's read state and last message may have changed
    // while that screen was open -- reload rather than guess.
    if (mounted) _loadInitial();
  }

  Future<void> _showConversationMenu(Conversation conversation) async {
    final isMuted = await widget.chatRepository.isConversationMuted(conversation.id);
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
                    await widget.chatRepository.unmuteConversation(conversation.id);
                  } else {
                    await widget.chatRepository.muteConversation(conversation.id);
                  }
                } catch (_) {
                  // Silent -- same optimistic-toggle posture as WYN-028's
                  // profile mute toggle; a failed mute isn't worth a
                  // blocking error for a reversible, low-stakes action.
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ข้อความ')),
      body: Column(
        children: [
          if (_pendingRequestCount > 0) _buildRequestsBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildRequestsBanner() {
    return Semantics(
      label: 'คำขอข้อความ $_pendingRequestCount รายการ',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: _openMessageRequests,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainer,
          padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space4,
            vertical: WynSpacing.space3,
          ),
          child: Row(
            children: [
              Icon(Icons.mail_outline, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: WynSpacing.space3),
              Expanded(child: Text('คำขอข้อความ ($_pendingRequestCount)')),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: WynSpacing.space4),
              const Text('ยังไม่มีบทสนทนา', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _conversations.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _conversations.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final conversation = _conversations[index];
          return _ConversationRow(
            conversation: conversation,
            isUnread: conversation.isUnread(_myUserId),
            onTap: () => _openConversation(conversation),
            onLongPress: () => _showConversationMenu(conversation),
          );
        },
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.isUnread,
    required this.onTap,
    required this.onLongPress,
  });

  final Conversation conversation;
  final bool isUnread;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  String get _preview {
    if (conversation.lastMessageAt == null) return 'เริ่มบทสนทนา';
    if (conversation.lastMessageDeletedAt != null) return 'ข้อความถูกลบ';
    final text = conversation.lastMessageText;
    if (text != null && text.isNotEmpty) return text;
    if (conversation.lastMessageImageUrl != null) return '📷 รูปภาพ';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = conversation.otherDisplayName?.isNotEmpty == true
        ? conversation.otherDisplayName!
        : '@${conversation.otherUsername}';
    final time = conversation.lastMessageAt == null
        ? ''
        : relativeTimeLabel(conversation.lastMessageAt!, now: DateTime.now());
    final isDeleted = conversation.lastMessageDeletedAt != null;

    return Semantics(
      label: '$displayName. $_preview. $time. ${isUnread ? 'ยังไม่อ่าน' : ''}',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space4,
            vertical: WynSpacing.space2,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AvatarCircle(
                    imageUrl: conversation.otherAvatarUrl,
                    fallbackText: displayName,
                    radius: 24,
                  ),
                  if (isUnread)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: isUnread ? FontWeight.bold : null,
                          ),
                    ),
                    Text(
                      _preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: isDeleted ? FontStyle.italic : null,
                            color: isDeleted || !isUnread
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : null,
                            fontWeight: isUnread ? FontWeight.bold : null,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WynSpacing.space2),
              Text(
                time,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
