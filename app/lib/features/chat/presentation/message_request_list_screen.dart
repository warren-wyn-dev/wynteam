import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
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
  const MessageRequestListScreen({super.key, required this.chatRepository});

  final ChatRepository chatRepository;

  @override
  State<MessageRequestListScreen> createState() => _MessageRequestListScreenState();
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
      final requests = await widget.chatRepository.fetchMessageRequests(page: 0);
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
      final requests = await widget.chatRepository.fetchMessageRequests(page: nextPage);
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
      appBar: AppBar(title: const Text('คำขอข้อความ')),
      body: _buildBody(),
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

    if (_requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mail_outline,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: WynSpacing.space4),
              const Text('ยังไม่มีคำขอข้อความ', textAlign: TextAlign.center),
            ],
          ),
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
            vertical: WynSpacing.space2,
          ),
          child: Row(
            children: [
              AvatarCircle(
                imageUrl: request.otherAvatarUrl,
                fallbackText: displayName,
                radius: 24,
              ),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      _preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
