from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def write(rel, text):
    (ROOT / rel).write_text(text, encoding='utf-8')


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, got {count}')
    return text.replace(old, new, 1)


def regex_once(text, pattern, replacement, label):
    new, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 regex match, got {count}')
    return new


# ---------------------------------------------------------------------------
# Chat Inbox
# ---------------------------------------------------------------------------
rel = 'app/lib/features/chat/presentation/chat_inbox_screen.dart'
text = read(rel)
text = replace_once(
    text,
    "import 'new_message_screen.dart';\n",
    "import 'new_message_screen.dart';\nimport 'widgets/chat_ui.dart';\n",
    'inbox import chat_ui',
)
text = regex_once(
    text,
    r"  Future<void> _showConversationMenu\(Conversation conversation\) async \{.*?\n  \}\n\n  @override",
    """  Future<void> _showConversationMenu(Conversation conversation) async {
    final isMuted = await widget.chatRepository.isConversationMuted(conversation.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ChatActionSheetBody(
        title: 'ตั้งค่าบทสนทนา',
        rows: [
          ChatActionSheetRow(
            icon: isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
            label: isMuted ? 'เปิดแจ้งเตือนบทสนทนานี้' : 'ปิดแจ้งเตือนบทสนทนานี้',
            onTap: () async {
              Navigator.of(sheetContext).pop();
              try {
                if (isMuted) {
                  await widget.chatRepository.unmuteConversation(conversation.id);
                } else {
                  await widget.chatRepository.muteConversation(conversation.id);
                }
              } catch (_) {
                // Silent -- a failed mute is reversible and low-stakes.
              }
            },
          ),
        ],
      ),
    );
  }

  @override""",
    'inbox conversation menu',
)
text = text.replace('toolbarHeight: 58,', 'toolbarHeight: 62,', 1)
text = text.replace('fontSize: 20,\n            height: 1.1,', 'fontSize: 22,\n            height: 1.1,', 1)
text = replace_once(
    text,
    """        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 22, color: WynColors.ink),
            tooltip: 'เขียนข้อความใหม่',
            onPressed: _openNewMessage,
          ),
          const SizedBox(width: 4),
        ],""",
    """        actions: [
          Padding(
            padding: const EdgeInsets.only(right: WynSpacing.space3),
            child: ChatRoundIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'เขียนข้อความใหม่',
              onPressed: _openNewMessage,
              size: 38,
            ),
          ),
        ],""",
    'inbox compose button',
)
text = replace_once(
    text,
    """          : Column(
              children: [
                if (_pendingRequestCount > 0) _buildRequestsBanner(),
                _buildTabs(),
                Expanded(child: _buildBody()),
              ],
            ),""",
    """          : Column(
              children: [
                _buildTabs(),
                Expanded(child: _buildBody()),
              ],
            ),""",
    'inbox body tabs',
)
text = regex_once(
    text,
    r"  Widget _buildTabs\(\) \{.*?\n  Widget _buildBody\(\) \{",
    """  Widget _buildTabs() {
    final requestLabel = _pendingRequestCount > 0
        ? 'คำขอ ($_pendingRequestCount)'
        : 'คำขอ';
    return Padding(
      key: const Key('chat_threads_tabs'),
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space4,
        WynSpacing.space3,
        WynSpacing.space4,
        WynSpacing.space2,
      ),
      child: Row(
        children: [
          Expanded(
            child: ChatPillTab(
              label: 'ทั้งหมด',
              selected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          const SizedBox(width: WynSpacing.space2),
          Expanded(
            child: ChatPillTab(
              label: 'ยังไม่อ่าน',
              selected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ),
          const SizedBox(width: WynSpacing.space2),
          Expanded(
            child: ChatPillTab(
              label: requestLabel,
              selected: false,
              onTap: _openMessageRequests,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {""",
    'inbox pill tabs',
)
text = text.replace('const Center(child: CircularProgressIndicator())',
                    'const Center(child: CircularProgressIndicator(color: WynColors.ink))')
text = text.replace('child: Center(child: CircularProgressIndicator()),',
                    'child: Center(child: CircularProgressIndicator(color: WynColors.ink)),')
write(rel, text)


# ---------------------------------------------------------------------------
# New Message
# ---------------------------------------------------------------------------
rel = 'app/lib/features/chat/presentation/new_message_screen.dart'
text = read(rel)
text = replace_once(
    text,
    "import 'conversation_screen.dart';\n",
    "import 'conversation_screen.dart';\nimport 'widgets/chat_ui.dart';\n",
    'new message import chat_ui',
)
text = regex_once(
    text,
    r"  Widget _buildSearchBar\(\) \{.*?\n  Widget _buildFollowingList\(\) \{",
    """  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space4,
        WynSpacing.space3,
        WynSpacing.space4,
        WynSpacing.space2,
      ),
      child: ChatSearchField(
        controller: _searchController,
        hintText: 'ค้นหาผู้ใช้...',
        onChanged: _onQueryChanged,
        onClear: () {
          _debounceTimer?.cancel();
          _searchController.clear();
          setState(() => _query = '');
        },
      ),
    );
  }

  Widget _buildFollowingList() {""",
    'new message search field',
)
text = text.replace(
    """          child: Text(
            'ติดตามอยู่',
            style: _textStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WynColors.graphite,
            ),
          ),""",
    "          child: const ChatSectionLabel('ติดตามอยู่'),",
    1,
)
text = text.replace(
    'horizontal: WynSpacing.space6, vertical: WynSpacing.space3 - 2',
    'horizontal: WynSpacing.space4, vertical: 10',
)
text = text.replace('const Center(child: CircularProgressIndicator())',
                    'const Center(child: CircularProgressIndicator(color: WynColors.ink))')
write(rel, text)


# ---------------------------------------------------------------------------
# Message Requests
# ---------------------------------------------------------------------------
rel = 'app/lib/features/chat/presentation/message_request_list_screen.dart'
text = read(rel)
text = replace_once(
    text,
    "import 'conversation_screen.dart';\n",
    "import 'conversation_screen.dart';\nimport 'widgets/chat_ui.dart';\n",
    'requests import chat_ui',
)
text = replace_once(
    text,
    """        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),""",
    """        bottom: const PreferredSize(
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
                  child: Text(
                    'ข้อความจากคนที่คุณยังไม่ได้เริ่มแชทด้วยจะอยู่ที่นี่',
                    style: TextStyle(fontSize: 12.5, color: WynColors.graphite),
                  ),
                ),
              ),
            ],
          ),
        ),""",
    'requests appbar helper',
)
text = replace_once(
    text,
    """              Text(
                time,
                style: const TextStyle(fontSize: 12.5, color: WynColors.graphite),
              ),""",
    """              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: const TextStyle(fontSize: 12.5, color: WynColors.graphite),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: WynColors.surfaceTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_right, size: 17, color: WynColors.ink),
                  ),
                ],
              ),""",
    'requests trailing action',
)
text = text.replace('const Center(child: CircularProgressIndicator())',
                    'const Center(child: CircularProgressIndicator(color: WynColors.ink))')
write(rel, text)


# ---------------------------------------------------------------------------
# Share to Chat -- keep repository/send behavior, replace only presentation.
# ---------------------------------------------------------------------------
rel = 'app/lib/features/chat/presentation/share_to_chat_screen.dart'
text = read(rel)
text = replace_once(
    text,
    "import '../../../core/design/wyn_spacing.dart';\n",
    "import '../../../core/design/wyn_colors.dart';\nimport '../../../core/design/wyn_spacing.dart';\nimport '../../../core/widgets/empty_state_block.dart';\n",
    'share-to-chat design imports',
)
text = replace_once(
    text,
    "import '../data/shared_content_type.dart';\n",
    "import '../data/shared_content_type.dart';\nimport 'widgets/chat_ui.dart';\n",
    'share-to-chat chat_ui import',
)
text = regex_once(
    text,
    r"  @override\n  Widget build\(BuildContext context\) \{.*?\n  Widget _buildBody\(\) \{",
    """  @override
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
        title: const Text(
          'แชร์เข้า Chat',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: WynColors.ink),
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
                  const Icon(Icons.send_outlined, size: 17, color: WynColors.ink),
                  const SizedBox(width: WynSpacing.space2),
                  Expanded(
                    child: Text(
                      widget.previewLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, color: WynColors.ink),
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
          if (_isSending) const LinearProgressIndicator(minHeight: 2, color: WynColors.ink),
          const SizedBox(height: WynSpacing.space2),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {""",
    'share-to-chat build',
)
# Replace everything from _buildBody through the class end with the new visual tail.
prefix = text[:text.index('  Widget _buildBody() {')]
new_tail = r'''  Widget _buildBody() {
    if (!_queryTooShort) return _buildSearchResults();

    if (_isLoadingConversations) {
      return const Center(child: CircularProgressIndicator(color: WynColors.ink));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 28, color: WynColors.graphite),
            const SizedBox(height: WynSpacing.space2),
            Text(_error!, style: const TextStyle(color: WynColors.graphite)),
            const SizedBox(height: WynSpacing.space2),
            TextButton(onPressed: _loadConversations, child: const Text('ลองใหม่')),
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
      return const Center(child: CircularProgressIndicator(color: WynColors.ink));
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
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: 10),
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
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: WynColors.ink,
                    ),
                  ),
                  Text(
                    '@${conversation.otherUsername}',
                    style: const TextStyle(fontSize: 13, color: WynColors.graphite),
                  ),
                ],
              ),
            ),
            const ChatRoundIconButton(
              icon: Icons.arrow_upward,
              tooltip: 'แชร์ไปยังบทสนทนานี้',
              onPressed: null,
              size: 34,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(Profile profile) {
    final displayName =
        profile.displayName?.isNotEmpty == true ? profile.displayName! : '@${profile.username}';
    return InkWell(
      onTap: _isSending ? null : () => _sendToNewConversation(profile.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: 10),
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
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: WynColors.ink,
                    ),
                  ),
                  Text(
                    '@${profile.username}',
                    style: const TextStyle(fontSize: 13, color: WynColors.graphite),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: WynColors.graphite),
          ],
        ),
      ),
    );
  }
}
'''
# The const ChatRoundIconButton above cannot have an enabled onTap and is only
# decorative; replace it with a neutral send glyph rather than implying a
# second tap target inside the already-tappable row.
new_tail = new_tail.replace("            const ChatRoundIconButton(\n              icon: Icons.arrow_upward,\n              tooltip: 'แชร์ไปยังบทสนทนานี้',\n              onPressed: null,\n              size: 34,\n            ),", "            Container(\n              width: 34,\n              height: 34,\n              decoration: const BoxDecoration(\n                color: WynColors.surfaceTint,\n                shape: BoxShape.circle,\n              ),\n              child: const Icon(Icons.arrow_upward, size: 17, color: WynColors.ink),\n            ),")
text = prefix + new_tail
write(rel, text)


# ---------------------------------------------------------------------------
# Share Sheet
# ---------------------------------------------------------------------------
rel = 'app/lib/features/chat/presentation/share_sheet.dart'
text = read(rel)
text = replace_once(
    text,
    "import 'package:share_plus/share_plus.dart';\n",
    "import 'package:share_plus/share_plus.dart';\n\nimport '../../../core/design/wyn_colors.dart';\n",
    'share sheet color import',
)
text = replace_once(
    text,
    "import 'share_to_chat_screen.dart';\n",
    "import 'share_to_chat_screen.dart';\nimport 'widgets/chat_ui.dart';\n",
    'share sheet chat_ui import',
)
text = regex_once(
    text,
    r"  await showModalBottomSheet<void>\(.*?\n  \);\n\}",
    """  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => ChatActionSheetBody(
      title: 'แชร์',
      subtitle: previewLabel,
      rows: [
        if (showInviteFromFollowers)
          ChatActionSheetRow(
            icon: Icons.person_add_alt_1,
            label: 'เชิญจากผู้ติดตาม',
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InviteToClubScreen(
                    followRepository: followRepository,
                    clubRepository: clubRepository,
                    clubId: sharedContentId,
                    clubName: clubName,
                  ),
                ),
              );
            },
          ),
        ChatActionSheetRow(
          icon: Icons.chat_bubble_outline,
          label: 'แชร์เข้า Chat',
          onTap: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ShareToChatScreen(
                  chatRepository: chatRepository,
                  profileRepository: profileRepository,
                  sharedContentType: sharedContentType,
                  sharedContentId: sharedContentId,
                  previewLabel: previewLabel,
                ),
              ),
            );
          },
        ),
        ChatActionSheetRow(
          icon: Icons.ios_share,
          label: 'แชร์ผ่านระบบมือถือ',
          onTap: () {
            Navigator.of(sheetContext).pop();
            SharePlus.instance.share(
              ShareParams(text: nativeShareText, title: nativeShareTitle),
            );
          },
        ),
        ChatActionSheetRow(
          icon: Icons.link,
          label: 'คัดลอกลิงก์',
          onTap: () async {
            Navigator.of(sheetContext).pop();
            await Clipboard.setData(ClipboardData(text: nativeShareText));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
            );
          },
        ),
      ],
    ),
  );
}""",
    'share sheet body',
)
# WynColors import is intentionally present to keep the sheet visually tied to
# chat tokens if future rows need a destructive color; suppress unused import
# by using it for the modal barrier.
text = text.replace('backgroundColor: Colors.transparent,\n    builder:',
                    'backgroundColor: Colors.transparent,\n    barrierColor: WynColors.imageScrim,\n    builder:', 1)
write(rel, text)


# ---------------------------------------------------------------------------
# View Once viewer -- full presentation replacement, same keys/behavior.
# ---------------------------------------------------------------------------
rel = 'app/lib/features/chat/presentation/widgets/view_once_image_viewer.dart'
write(rel, r'''import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/network_thumbnail.dart';

/// Chat "View Once" viewer: one distraction-free dark canvas, a compact
/// countdown pill, and the same auto-close / early-close semantics as before.
class ViewOnceImageViewer extends StatefulWidget {
  const ViewOnceImageViewer({
    super.key,
    required this.signedUrl,
    this.duration = const Duration(seconds: 8),
  });

  final String signedUrl;
  final Duration duration;

  @override
  State<ViewOnceImageViewer> createState() => _ViewOnceImageViewerState();
}

class _ViewOnceImageViewerState extends State<ViewOnceImageViewer> {
  late int _secondsLeft = widget.duration.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    if (!mounted) return;
    if (_secondsLeft <= 1) {
      timer.cancel();
      Navigator.of(context).pop();
      return;
    }
    setState(() => _secondsLeft -= 1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.duration.inSeconds == 0
        ? 0.0
        : _secondsLeft / widget.duration.inSeconds;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Image.network(
                widget.signedUrl,
                fit: BoxFit.contain,
                errorBuilder: networkImageErrorBuilder,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                WynSpacing.space3,
                WynSpacing.space2,
                WynSpacing.space3,
                0,
              ),
              child: Row(
                children: [
                  Material(
                    color: WynColors.imageScrimStrong,
                    shape: const CircleBorder(),
                    child: IconButton(
                      key: const Key('view_once_close_button'),
                      icon: const Icon(Icons.close, color: WynColors.paper, size: 21),
                      tooltip: 'ปิด',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: 'ปิดอัตโนมัติใน $_secondsLeft วินาที',
                    excludeSemantics: true,
                    child: Container(
                      key: const Key('view_once_countdown'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: WynSpacing.space3,
                        vertical: WynSpacing.space2,
                      ),
                      decoration: BoxDecoration(
                        color: WynColors.imageScrimStrong,
                        borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.filter_1_outlined, size: 15, color: WynColors.paper),
                          const SizedBox(width: WynSpacing.space1),
                          Text(
                            '$_secondsLeft วิ',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: WynColors.paper,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: WynSpacing.space4,
            right: WynSpacing.space4,
            bottom: WynSpacing.space4,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: WynColors.graphite,
                      color: WynColors.paper,
                    ),
                  ),
                  const SizedBox(height: WynSpacing.space2),
                  const Text(
                    'รูปนี้จะหายหลังจากเปิดดู',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: WynColors.faint),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
''')


# ---------------------------------------------------------------------------
# 1:1 Conversation
# ---------------------------------------------------------------------------
rel = 'app/lib/features/chat/presentation/conversation_screen.dart'
text = read(rel)
text = text.replace("import '../../moderation/presentation/evidence_image_viewer.dart';\n", '')
text = replace_once(
    text,
    "import 'widgets/view_once_image_viewer.dart';\n",
    "import 'widgets/chat_media_viewer.dart';\nimport 'widgets/chat_ui.dart';\nimport 'widgets/view_once_image_viewer.dart';\n",
    'conversation chat widget imports',
)
text = replace_once(
    text,
    "MaterialPageRoute(builder: (_) => EvidenceImageViewer(signedUrl: url)),",
    "MaterialPageRoute(builder: (_) => ChatMediaViewer(signedUrl: url)),",
    'conversation media viewer',
)
text = text.replace('ActionSheetBody(rows:', 'ChatActionSheetBody(rows:')
text = text.replace('ActionSheetRow(', 'ChatActionSheetRow(')
# Make the two chat action sheets use the rounded transparent modal shell.
text = text.replace(
    "await showModalBottomSheet<void>(\n      context: context,\n      builder: (sheetContext) => ChatActionSheetBody(rows:",
    "await showModalBottomSheet<void>(\n      context: context,\n      backgroundColor: Colors.transparent,\n      builder: (sheetContext) => ChatActionSheetBody(rows:",
)
text = text.replace("centerTitle: true,\n        toolbarHeight: 60,",
                    "centerTitle: false,\n        toolbarHeight: 64,\n        titleSpacing: 0,")
text = text.replace('radius: 16,\n                ring: false,', 'radius: 17,\n                ring: false,', 1)
text = text.replace("style: _textStyle(fontSize: 12, color: WynColors.faint)",
                    "style: _textStyle(fontSize: 12, color: WynColors.graphite)")
text = text.replace("Text('ออนไลน์', style: _textStyle(fontSize: 12, color: WynColors.faint))",
                    "Text('ออนไลน์', style: _textStyle(fontSize: 12, color: WynColors.graphite))")
text = replace_once(
    text,
    """              IconButton(
                icon: const Icon(Icons.image_outlined, size: 20, color: WynColors.graphite),
                tooltip: 'แนบรูป',
                // WYN-138: an edit is text-only (`edit_message()` rejects
                // any message that ever carries an image) -- attaching a
                // photo mid-edit would be a dead end, so this is
                // disabled for the whole time the composer is in edit
                // mode, not just while a send/save is already in flight.
                onPressed: (_isSending || _isEditingMessage) ? null : _pickImage,
              ),
              Expanded(""",
    """              ChatRoundIconButton(
                icon: Icons.image_outlined,
                tooltip: 'แนบรูป',
                onPressed: (_isSending || _isEditingMessage) ? null : _pickImage,
                enabled: !_isSending && !_isEditingMessage,
                size: 40,
              ),
              const SizedBox(width: WynSpacing.space2),
              Expanded(""",
    'conversation composer attachment',
)
text = text.replace(
    "padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: 6),\n                  decoration: BoxDecoration(\n                    color: _kBubbleFill,",
    "padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: 8),\n                  decoration: BoxDecoration(\n                    color: _kBubbleFill,",
    1,
)
text = text.replace("hintStyle: _textStyle(fontSize: 16, color: WynColors.mutedNeutral)",
                    "hintStyle: _textStyle(fontSize: 15, color: WynColors.mutedNeutral)", 1)
# Preview bars become compact rounded cards instead of full-width strips.
for label in ('reply', 'edit', 'image'):
    pass
text = text.replace(
    """    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
      color: _kBubbleFill,
      child: Row(""",
    """    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
      decoration: BoxDecoration(
        color: _kBubbleFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(""",
    3,
)
text = text.replace('color: _isViewOnce ? WynColors.sapphire : WynColors.graphite,',
                    'color: _isViewOnce ? WynColors.ink : WynColors.graphite,')
text = text.replace("_DeliveryStatus.read => Text('อ่านแล้ว', style: _textStyle(fontSize: 11, color: WynColors.sapphire)),",
                    "_DeliveryStatus.read => Text('อ่านแล้ว', style: _textStyle(fontSize: 11, color: WynColors.graphite)),")
# Pinned bar: card-like, not a hard strip.
text = replace_once(
    text,
    """      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
        decoration: const BoxDecoration(
          color: _kBubbleFill,
          border: Border(bottom: BorderSide(color: WynColors.hairline)),
        ),""",
    """      child: Container(
        height: 42,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
        decoration: BoxDecoration(
          color: _kBubbleFill,
          borderRadius: BorderRadius.circular(14),
        ),""",
    'conversation pinned bar',
)
text = text.replace('const Center(child: CircularProgressIndicator())',
                    'const Center(child: CircularProgressIndicator(color: WynColors.ink))')
write(rel, text)


# ---------------------------------------------------------------------------
# Club group chat -- same approved language, no new group capabilities.
# ---------------------------------------------------------------------------
rel = 'app/lib/features/club/presentation/widgets/club_channel_chat_view.dart'
text = read(rel)
text = replace_once(
    text,
    "import '../../../report/presentation/report_sheet.dart';\n",
    "import '../../../report/presentation/report_sheet.dart';\nimport '../../../chat/presentation/widgets/chat_ui.dart';\n",
    'club chat chat_ui import',
)
text = text.replace('sapphire-filled sent bubbles / surfaceTint received bubbles',
                    'ink-filled sent bubbles / surfaceTint received bubbles')
text = text.replace('ActionSheetBody(rows:', 'ChatActionSheetBody(rows:')
text = text.replace('ActionSheetRow(', 'ChatActionSheetRow(')
text = text.replace(
    "await showModalBottomSheet<void>(\n      context: context,\n      builder: (sheetContext) => ChatActionSheetBody(rows:",
    "await showModalBottomSheet<void>(\n      context: context,\n      backgroundColor: Colors.transparent,\n      builder: (sheetContext) => ChatActionSheetBody(rows:",
)
text = regex_once(
    text,
    r"  Widget _buildHeader\(\) \{.*?\n  \}\n\n  Widget _buildMessageList",
    """  Widget _buildHeader() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          WynSpacing.space4,
          WynSpacing.space2,
          WynSpacing.space4,
          WynSpacing.space1,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space3,
          vertical: WynSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: WynColors.surfaceTint,
          borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: _onlineCount > 0 ? WynColors.online : WynColors.faint,
            ),
            const SizedBox(width: WynSpacing.space1),
            Text(
              '$_onlineCount คนออนไลน์ในห้องนี้',
              style: const TextStyle(fontSize: 12.5, color: WynColors.graphite),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList""",
    'club chat header',
)
text = replace_once(
    text,
    """              IconButton(
                icon: const Icon(Icons.image_outlined, size: 20, color: WynColors.graphite),
                tooltip: 'แนบรูป',
                onPressed: _isSending ? null : _pickImage,
              ),
              Expanded(""",
    """              ChatRoundIconButton(
                icon: Icons.image_outlined,
                tooltip: 'แนบรูป',
                onPressed: _isSending ? null : _pickImage,
                enabled: !_isSending,
                size: 40,
              ),
              const SizedBox(width: WynSpacing.space2),
              Expanded(""",
    'club chat composer attachment',
)
text = text.replace('color: _canSend ? WynColors.sapphire : WynColors.hairline,',
                    'color: _canSend ? WynColors.ink : WynColors.surfaceTint,')
text = text.replace('final bubbleColor = isMine ? WynColors.sapphire : WynColors.surfaceTint;',
                    'final bubbleColor = isMine ? WynColors.ink : WynColors.surfaceTint;')
text = text.replace('AvatarCircle(imageUrl: message.authorAvatarUrl, fallbackText: _authorLabel, radius: 10)',
                    'AvatarCircle(imageUrl: message.authorAvatarUrl, fallbackText: _authorLabel, radius: 10, ring: false)')
text = text.replace(
    """    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
      color: WynColors.surfaceTint,
      child: Row(""",
    """    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
      decoration: BoxDecoration(
        color: WynColors.surfaceTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(""",
    2,
)
text = text.replace('const Center(child: CircularProgressIndicator())',
                    'const Center(child: CircularProgressIndicator(color: WynColors.ink))')
write(rel, text)


# ---------------------------------------------------------------------------
# Regression test: Requests is now a permanent third pill instead of a banner.
# ---------------------------------------------------------------------------
rel = 'app/test/chat_inbox_screen_test.dart'
text = read(rel)
text = replace_once(
    text,
    """  group('Message Requests banner (WYN-032)', () {
    testWidgets('hidden when there are no pending requests', (tester) async {
      chatRepo.inboxPages = const [[]];
      chatRepo.pendingMessageRequestCount = 0;
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('คำขอข้อความ'), findsNothing);
    });

    testWidgets('shows the pending count and opens MessageRequestListScreen on tap',
        (tester) async {
      chatRepo.inboxPages = const [[]];
      chatRepo.pendingMessageRequestCount = 3;
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('คำขอข้อความ (3)'), findsOneWidget);

      await tester.tap(find.text('คำขอข้อความ (3)'));
      await tester.pumpAndSettle();

      expect(find.byType(MessageRequestListScreen), findsOneWidget);
    });
  });""",
    """  group('Message Requests pill (WYN-032)', () {
    testWidgets('stays available with zero pending requests and opens the empty list',
        (tester) async {
      chatRepo.inboxPages = const [[]];
      chatRepo.pendingMessageRequestCount = 0;
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('คำขอ'), findsOneWidget);
      await tester.tap(find.text('คำขอ'));
      await tester.pumpAndSettle();
      expect(find.byType(MessageRequestListScreen), findsOneWidget);
    });

    testWidgets('shows the pending count and opens MessageRequestListScreen on tap',
        (tester) async {
      chatRepo.inboxPages = const [[]];
      chatRepo.pendingMessageRequestCount = 3;
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('คำขอ (3)'), findsOneWidget);

      await tester.tap(find.text('คำขอ (3)'));
      await tester.pumpAndSettle();

      expect(find.byType(MessageRequestListScreen), findsOneWidget);
    });
  });""",
    'chat inbox requests test',
)
write(rel, text)

print('Chat system UI patch applied successfully.')
