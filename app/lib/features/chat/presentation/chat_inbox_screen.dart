import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/text_utils.dart';
import '../../follow/data/follow_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/chat_repository.dart';
import '../data/conversation.dart';
import 'conversation_screen.dart';
import 'message_request_list_screen.dart';
import 'new_message_screen.dart';

/// Screen 2 -- the Chat Inbox: every conversation this user is part of,
/// sorted by most recent activity first. Restyled to 12-chat.tsx: chevron
/// back + Fraunces title + a compose (pencil) icon header, a "ทั้งหมด" /
/// "ยังไม่อ่าน" tab pair (a real client-side filter over the already-loaded
/// list -- [Conversation.isUnread] already exists, so this isn't a
/// placeholder), and rows styled like every other "list of people" screen
/// (avatar ring, hairline separators, an inline dot next to the preview
/// for unread instead of a corner badge on the avatar).
///
/// The compose icon now opens [NewMessageScreen] (design-reference's own
/// `17-new-message.tsx`) -- a person picker that starts a real
/// conversation, same call `ViewProfileScreen`'s own message button
/// makes.
///
/// The Message Requests banner (WYN-032) has no equivalent in the mockup
/// at all -- it's real, working functionality the mockup's static
/// screenshot simply doesn't depict, so it's kept, just restyled to the
/// same token system as everything else on this page. See
/// .wyn/docs/design/wyn-031-chat-1to1.md, Screen 2.
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({
    super.key,
    required this.chatRepository,
    this.profileRepository,
    this.followRepository,
  });

  final ChatRepository chatRepository;

  /// Optional/defaulted to Supabase.instance.client when omitted, same
  /// shape as every other repository this app threads through
  /// optionally -- needed only to open [NewMessageScreen].
  final ProfileRepository? profileRepository;
  final FollowRepository? followRepository;

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

  // 12-chat.tsx's "ทั้งหมด" (0) / "ยังไม่อ่าน" (1) tabs -- filters the
  // already-loaded [_conversations] list client-side, same "one shared
  // list, tab just filters it" pattern notification_list_screen.dart's
  // own tab pair uses.
  int _selectedTab = 0;

  late final ProfileRepository _profileRepository =
      widget.profileRepository ?? ProfileRepository(Supabase.instance.client);
  late final FollowRepository _followRepository =
      widget.followRepository ?? FollowRepository(Supabase.instance.client);

  String get _myUserId => Supabase.instance.client.auth.currentUser!.id;

  List<Conversation> get _visibleConversations => _selectedTab == 1
      ? _conversations.where((c) => c.isUnread(_myUserId)).toList()
      : _conversations;

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

  Future<void> _openNewMessage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewMessageScreen(
          chatRepository: widget.chatRepository,
          profileRepository: _profileRepository,
          followRepository: _followRepository,
        ),
      ),
    );
    // A new conversation may have started while that screen was open.
    if (mounted) _loadInitial();
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
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('ข้อความ', style: WynTypography.fraunces(fontSize: 17, color: WynColors.ink)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 19, color: WynColors.ink),
            tooltip: 'เขียนข้อความใหม่',
            onPressed: _openNewMessage,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: Column(
        children: [
          if (_pendingRequestCount > 0) _buildRequestsBanner(),
          _buildTabs(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WynColors.hairline)),
      ),
      child: Row(
        children: [
          _buildTab('ทั้งหมด', 0),
          const SizedBox(width: WynSpacing.space6),
          _buildTab('ยังไม่อ่าน', 1),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final selected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
              child: Text(
                label,
                style: _interStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? WynColors.ink : WynColors.mutedNeutral,
                ),
              ),
            ),
            Container(
              height: 2,
              color: selected ? WynColors.sapphire : Colors.transparent,
            ),
          ],
        ),
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
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: WynColors.hairline)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space6,
            vertical: WynSpacing.space3,
          ),
          child: Row(
            children: [
              const Icon(Icons.mail_outline, size: 18, color: WynColors.sapphire),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Text(
                  'คำขอข้อความ ($_pendingRequestCount)',
                  style: _interStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: WynColors.ink),
                ),
              ),
              const Icon(Icons.chevron_right, size: 15, color: WynColors.faint),
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

    final visible = _visibleConversations;

    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 56, color: WynColors.faint),
              const SizedBox(height: WynSpacing.space4),
              Text(
                _selectedTab == 1 ? 'ไม่มีบทสนทนาที่ยังไม่อ่าน' : 'ยังไม่มีบทสนทนา',
                textAlign: TextAlign.center,
                style: _interStyle(fontSize: 14, color: WynColors.graphite),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: visible.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= visible.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final conversation = visible[index];
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: WynColors.hairline)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarCircle(
                imageUrl: conversation.otherAvatarUrl,
                fallbackText: displayName,
                radius: 24,
                ring: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _interStyle(
                              fontSize: 14.5,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                              color: WynColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: WynSpacing.space2),
                        Text(
                          time,
                          style: _interStyle(fontSize: 11.5, color: WynColors.mutedNeutral),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isUnread)
                          const Padding(
                            padding: EdgeInsets.only(right: WynSpacing.space1),
                            child: _UnreadDot(),
                          ),
                        Expanded(
                          child: Text(
                            _preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _interStyle(
                              fontSize: 13,
                              fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                              fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                              color: isUnread ? WynColors.ink : WynColors.graphite,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(color: WynColors.sapphire, shape: BoxShape.circle),
    );
  }
}

TextStyle _interStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  FontStyle fontStyle = FontStyle.normal,
  Color? color,
}) =>
    GoogleFonts.inter(fontSize: fontSize, fontWeight: fontWeight, fontStyle: fontStyle, color: color);
