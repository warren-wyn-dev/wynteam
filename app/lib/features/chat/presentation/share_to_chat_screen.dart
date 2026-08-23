import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/chat_repository.dart';
import '../data/conversation.dart';
import '../data/shared_content_type.dart';

/// Screen 3 (WYN-033) -- pick a conversation (existing or new, via
/// search) to send a shared Drop/Profile/Club into. See
/// .wyn/docs/design/wyn-033-share-to-chat.md, Screen 3.
///
/// Single-tap-to-send by design (Product spec's Risk, accepted for
/// simplicity) -- no multi-select, no separate confirm step. Tapping
/// an existing conversation sends directly; tapping a search result
/// starts (or resumes) a conversation via `getOrCreateConversation()`
/// first, going through WYN-032's Message Request gate exactly like
/// any other first contact -- no shortcut for sharing.
class ShareToChatScreen extends StatefulWidget {
  const ShareToChatScreen({
    super.key,
    required this.chatRepository,
    required this.profileRepository,
    required this.sharedContentType,
    required this.sharedContentId,
    required this.previewLabel,
  });

  final ChatRepository chatRepository;
  final ProfileRepository profileRepository;
  final SharedContentType sharedContentType;
  final String sharedContentId;

  /// e.g. "แชร์ Drop" / "แชร์โปรไฟล์ @namfah" / "แชร์ Club ชมรมถ่ายภาพ" --
  /// shown once at the top, not re-fetched here (the caller already
  /// has the full Drop/Club/Profile in hand when Share is invoked).
  final String previewLabel;

  @override
  State<ShareToChatScreen> createState() => _ShareToChatScreenState();
}

class _ShareToChatScreenState extends State<ShareToChatScreen> {
  final _searchController = TextEditingController();
  final List<Conversation> _conversations = [];
  List<Profile> _searchResults = [];
  bool _isLoadingConversations = true;
  bool _isSearching = false;
  bool _isSending = false;
  String? _error;

  bool get _queryTooShort => _searchController.text.trim().length < 2;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoadingConversations = true);
    try {
      final conversations = await widget.chatRepository.fetchInbox(page: 0);
      if (!mounted) return;
      setState(() {
        _conversations
          ..clear()
          ..addAll(conversations);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'โหลดรายการไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingConversations = false);
    }
  }

  void _onQueryChanged() {
    if (_queryTooShort) {
      setState(() => _searchResults = []);
      return;
    }
    _search();
  }

  Future<void> _search() async {
    setState(() => _isSearching = true);
    try {
      final results = await widget.profileRepository.searchProfiles(
        query: _searchController.text.trim(),
        page: 0,
      );
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (_) {
      // Silent -- same posture as SearchUserResultsTab's own search failure.
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  /// Existing conversation -- send is the entire flow, so this owns
  /// the `_isSending` guard itself.
  Future<void> _sendToExisting(String conversationId) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    await _doSend(conversationId);
  }

  /// A search result -- starts (or resumes) the conversation first,
  /// then sends. Owns `_isSending` itself for the same reason
  /// [_sendToExisting] does -- [_doSend] is a shared step both call
  /// into, not a second guarded entry point, so a search-result tap
  /// isn't silently swallowed by an already-true guard it just set.
  Future<void> _sendToNewConversation(String otherUserId) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      final conversationId = await widget.chatRepository.getOrCreateConversation(otherUserId);
      await _doSend(conversationId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _doSend(String conversationId) async {
    try {
      await widget.chatRepository.sendMessage(
        conversationId: conversationId,
        sharedContentType: widget.sharedContentType,
        sharedContentId: widget.sharedContentId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('แชร์แล้ว')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แชร์เข้า Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
            child: Text(
              widget.previewLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'ค้นหาผู้ใช้...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: WynSpacing.space2),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_queryTooShort) return _buildSearchResults();

    if (_isLoadingConversations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _loadConversations, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }
    if (_conversations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Text('ยังไม่มีบทสนทนา — ค้นหาผู้ใช้เพื่อเริ่มแชร์', textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final displayName = conversation.otherDisplayName?.isNotEmpty == true
            ? conversation.otherDisplayName!
            : '@${conversation.otherUsername}';
        return ListTile(
          leading: AvatarCircle(
            imageUrl: conversation.otherAvatarUrl,
            fallbackText: displayName,
            radius: 20,
          ),
          title: Text(displayName),
          enabled: !_isSending,
          onTap: () => _sendToExisting(conversation.id),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(child: Text('ไม่พบผู้ใช้'));
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final profile = _searchResults[index];
        final displayName =
            profile.displayName?.isNotEmpty == true ? profile.displayName! : '@${profile.username}';
        return ListTile(
          leading: AvatarCircle(
            imageUrl: profile.avatarUrl,
            fallbackText: displayName,
            radius: 20,
          ),
          title: Text(displayName),
          subtitle: Text('@${profile.username}'),
          enabled: !_isSending,
          onTap: () => _sendToNewConversation(profile.id),
        );
      },
    );
  }
}
