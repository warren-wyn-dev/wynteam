import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
import '../../../core/widgets/empty_state_block.dart';
import '../../presence/data/presence_repository.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/chat_repository.dart';
import '../data/message_request.dart';
import 'conversation_screen.dart';

/// Screen 2 (WYN-032) -- every pending conversation someone else
/// started that this user hasn't decided on yet. See
/// .wyn/docs/design/wyn-032-message-request.md, Screen 2. Reached only
/// from the banner on `ChatInboxScreen` -- never a Bottom Nav tab or a
/// direct entry point of its own.
class MessageRequestListScreen extends StatefulWidget {
  const MessageRequestListScreen({
    super.key,
    required this.chatRepository,
    this.presenceRepository,
  });

  final ChatRepository chatRepository;

  /// Optional/defaulted to Supabase.instance.client when omitted, same
  /// shape as every other repository this app threads through
  /// optionally -- threaded down to [ConversationScreen]'s own WYN-139
  /// presence subscriptions.
  final PresenceRepository? presenceRepository;

  @override
  State<MessageRequestListScreen> createState() =>
      _MessageRequestListScreenState();
}

class _MessageRequestListScreenState extends State<MessageRequestListScreen> {
  final _scrollController = ScrollController();
  final List<MessageRequest> _requests = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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
      final requests =
          await widget.chatRepository.fetchMessageRequests(page: 0);
      if (!mounted) return;
      setState(() {
        _requests
          ..clear()
          ..addAll(requests);
        _page = 0;
        _hasMore = requests.length == ChatRepository.pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'โหลดรายการไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final requests =
          await widget.chatRepository.fetchMessageRequests(page: nextPage);
      if (!mounted) return;
      setState(() {
        _requests.addAll(requests);
        _page = nextPage;
        _hasMore = requests.length == ChatRepository.pageSize;
      });
    } catch (_) {
      // Silent, same posture as every other list's load-more failure.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openRequest(MessageRequest request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          chatRepository: widget.chatRepository,
          conversationId: request.conversationId,
          otherUserId: request.otherUserId,
          otherUsername: request.otherUsername,
          otherDisplayName: request.otherDisplayName,
          otherAvatarUrl: request.otherAvatarUrl,
          presenceRepository: widget.presenceRepository,
        ),
      ),
    );
    // Accept/Delete/Block, all decided inside ConversationScreen, each
    // remove this request from the list -- reload rather than guess
    // which one happened.
    if (mounted) _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        surfaceTintColor: WynColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 58,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const BrowserSystemText(
          'คำขอข้อความ',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: WynColors.ink),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(46),
          child: Column(
            children: [
              Divider(height: 1, color: WynColors.hairline),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  WynSpacing.space4,
                  WynSpacing.space2,
                  WynSpacing.space4,
                  WynSpacing.space2,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BrowserSystemText(
                    'ข้อความจากคนที่คุณยังไม่ได้เริ่มแชทด้วยจะอยู่ที่นี่',
                    style: TextStyle(fontSize: 12.5, color: WynColors.graphite),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return const Center(
          child: CircularProgressIndicator(color: WynColors.ink));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrowserSystemText(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _loadInitial, child: const BrowserSystemText('ลองใหม่')),
          ],
        ),
      );
    }

    if (_requests.isEmpty) {
      return const Center(
        child: EmptyStateBlock(
          icon: Icons.chat_bubble_outline,
          title: 'ยังไม่มีคำขอข้อความ',
          subtitle: 'คำขอจากคนที่ยังไม่ได้เริ่มแชทกับคุณจะอยู่ตรงนี้',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _requests.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _requests.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final request = _requests[index];
          return _MessageRequestRow(
            request: request,
            onTap: () => _openRequest(request),
          );
        },
      ),
    );
  }
}

class _MessageRequestRow extends StatelessWidget {
  const _MessageRequestRow({required this.request, required this.onTap});

  final MessageRequest request;
  final VoidCallback onTap;

  String get _preview {
    final text = request.lastMessageText;
    if (text != null && text.isNotEmpty) return text;
    if (request.lastMessageImageUrl != null) return '📷 รูปภาพ';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = request.otherDisplayName?.isNotEmpty == true
        ? request.otherDisplayName!
        : '@${request.otherUsername}';
    final time = request.lastMessageAt == null
        ? ''
        : relativeTimeLabel(request.lastMessageAt!, now: DateTime.now());

    return Semantics(
      label: '$displayName. $_preview. $time.',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space4,
            vertical: 12,
          ),
          child: Row(
            children: [
              AvatarCircle(
                imageUrl: request.otherAvatarUrl,
                fallbackText: displayName,
                radius: 24,
                ring: false,
              ),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrowserSystemText(
                      displayName,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: WynColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    BrowserSystemText(
                      _preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, color: WynColors.graphite),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WynSpacing.space2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BrowserSystemText(
                    time,
                    style: const TextStyle(
                        fontSize: 12.5, color: WynColors.graphite),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: WynColors.surfaceTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_right,
                        size: 17, color: WynColors.ink),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
