import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/widgets/empty_state_block.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/chat_repository.dart';
import '../data/conversation.dart';
import '../data/shared_content_type.dart';
import 'widgets/chat_ui.dart';

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
      final conversationId =
          await widget.chatRepository.getOrCreateConversation(otherUserId);
      await _doSend(conversationId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: BrowserSystemText('แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
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
        const SnackBar(content: BrowserSystemText('แชร์แล้ว')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: BrowserSystemText('แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
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
          'แชร์เข้า Chat',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: WynColors.ink),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WynSpacing.space4,
              WynSpacing.space3,
              WynSpacing.space4,
              WynSpacing.space2,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: WynSpacing.space3,
                vertical: WynSpacing.space2,
              ),
              decoration: BoxDecoration(
                color: WynColors.surfaceTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.send_outlined,
                      size: 17, color: WynColors.ink),
                  const SizedBox(width: WynSpacing.space2),
                  Expanded(
                    child: BrowserSystemText(
                      widget.previewLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 13.5, color: WynColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
            child: ChatSearchField(
              controller: _searchController,
              hintText: 'ค้นหาคนหรือชื่อผู้ใช้...',
              onChanged: (_) => setState(() {}),
              onClear: () {
                _searchController.clear();
                setState(() => _searchResults = []);
              },
            ),
          ),
          if (_isSending)
            const LinearProgressIndicator(minHeight: 2, color: WynColors.ink),
          const SizedBox(height: WynSpacing.space2),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_queryTooShort) return _buildSearchResults();

    if (_isLoadingConversations) {
      return const Center(
          child: CircularProgressIndicator(color: WynColors.ink));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 28, color: WynColors.graphite),
            const SizedBox(height: WynSpacing.space2),
            BrowserSystemText(_error!,
                style: const TextStyle(color: WynColors.graphite)),
            const SizedBox(height: WynSpacing.space2),
            TextButton(
                onPressed: _loadConversations,
                child: const BrowserSystemText('ลองใหม่')),
          ],
        ),
      );
    }
    if (_conversations.isEmpty) {
      return const Center(
        child: EmptyStateBlock(
          icon: Icons.forum_outlined,
          title: 'ยังไม่มีบทสนทนา',
          subtitle: 'ค้นหาผู้ใช้ด้านบนเพื่อเริ่มแชร์',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: WynSpacing.space4),
      itemCount: _conversations.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(
              WynSpacing.space4,
              WynSpacing.space3,
              WynSpacing.space4,
              WynSpacing.space2,
            ),
            child: ChatSectionLabel('บทสนทนาล่าสุด'),
          );
        }
        return _buildConversationRow(_conversations[index - 1]);
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
          child: CircularProgressIndicator(color: WynColors.ink));
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: EmptyStateBlock(
          icon: Icons.person_search_outlined,
          title: 'ไม่พบผู้ใช้',
          subtitle: 'ลองค้นหาด้วยชื่อหรือ @username อื่น',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: WynSpacing.space4),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) => _buildProfileRow(_searchResults[index]),
    );
  }

  Widget _buildConversationRow(Conversation conversation) {
    final displayName = conversation.otherDisplayName?.isNotEmpty == true
        ? conversation.otherDisplayName!
        : '@${conversation.otherUsername}';
    return InkWell(
      onTap: _isSending ? null : () => _sendToExisting(conversation.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space4, vertical: 10),
        child: Row(
          children: [
            AvatarCircle(
              imageUrl: conversation.otherAvatarUrl,
              fallbackText: displayName,
              radius: 23,
              ring: false,
            ),
            const SizedBox(width: WynSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrowserSystemText(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: WynColors.ink,
                    ),
                  ),
                  BrowserSystemText(
                    '@${conversation.otherUsername}',
                    style: const TextStyle(
                        fontSize: 13, color: WynColors.graphite),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: WynColors.surfaceTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward,
                  size: 17, color: WynColors.ink),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(Profile profile) {
    final displayName = profile.displayName?.isNotEmpty == true
        ? profile.displayName!
        : '@${profile.username}';
    return InkWell(
      onTap: _isSending ? null : () => _sendToNewConversation(profile.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space4, vertical: 10),
        child: Row(
          children: [
            AvatarCircle(
              imageUrl: profile.avatarUrl,
              fallbackText: displayName,
              radius: 23,
              ring: false,
            ),
            const SizedBox(width: WynSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrowserSystemText(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: WynColors.ink,
                    ),
                  ),
                  BrowserSystemText(
                    '@${profile.username}',
                    style: const TextStyle(
                        fontSize: 13, color: WynColors.graphite),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: WynColors.graphite),
          ],
        ),
      ),
    );
  }
}
