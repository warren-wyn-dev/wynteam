from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly 1 match, found {count}: {old[:80]!r}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


# ---------------------------------------------------------------------------
# Chat Inbox — align hierarchy, tabs and rows with the Founder-approved
# Profile surface: white canvas, Ink active state, quieter metadata, less chrome.
# ---------------------------------------------------------------------------
inbox = "app/lib/features/chat/presentation/chat_inbox_screen.dart"
replace_once(inbox, "import '../../../core/design/wyn_typography.dart';\n", "")
replace_once(
    inbox,
    """      appBar: AppBar(\n        backgroundColor: WynColors.paper,\n        centerTitle: true,\n        leading: IconButton(\n          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),\n          onPressed: () => Navigator.of(context).pop(),\n        ),\n        title: Text('ข้อความ', style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink)),\n        actions: [\n          IconButton(\n            icon: const Icon(Icons.edit_outlined, size: 19, color: WynColors.ink),\n            tooltip: 'เขียนข้อความใหม่',\n            onPressed: _openNewMessage,\n          ),\n        ],\n        bottom: const PreferredSize(\n          preferredSize: Size.fromHeight(1),\n          child: Divider(height: 1, color: WynColors.hairline),\n        ),\n      ),\n""",
    """      appBar: AppBar(\n        backgroundColor: WynColors.paper,\n        surfaceTintColor: WynColors.paper,\n        elevation: 0,\n        scrolledUnderElevation: 0,\n        centerTitle: false,\n        toolbarHeight: 58,\n        titleSpacing: 0,\n        leading: IconButton(\n          icon: const Icon(Icons.arrow_back, size: 22, color: WynColors.ink),\n          onPressed: () => Navigator.of(context).pop(),\n        ),\n        title: const Text(\n          'ข้อความ',\n          style: TextStyle(\n            fontSize: 20,\n            height: 1.1,\n            fontWeight: FontWeight.w700,\n            color: WynColors.ink,\n          ),\n        ),\n        actions: [\n          IconButton(\n            icon: const Icon(Icons.edit_outlined, size: 22, color: WynColors.ink),\n            tooltip: 'เขียนข้อความใหม่',\n            onPressed: _openNewMessage,\n          ),\n          const SizedBox(width: 4),\n        ],\n        bottom: const PreferredSize(\n          preferredSize: Size.fromHeight(1),\n          child: Divider(height: 1, color: WynColors.hairline),\n        ),\n      ),\n""",
)
replace_once(
    inbox,
    """  Widget _buildTabs() {\n    return Container(\n      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),\n      decoration: const BoxDecoration(\n        border: Border(bottom: BorderSide(color: WynColors.hairline)),\n      ),\n      child: Row(\n        children: [\n          _buildTab('ทั้งหมด', 0),\n          const SizedBox(width: WynSpacing.space6),\n          _buildTab('ยังไม่อ่าน', 1),\n        ],\n      ),\n    );\n  }\n\n  Widget _buildTab(String label, int index) {\n    final selected = _selectedTab == index;\n    return InkWell(\n      onTap: () => setState(() => _selectedTab = index),\n      child: IntrinsicWidth(\n        child: Column(\n          mainAxisSize: MainAxisSize.min,\n          children: [\n            Padding(\n              padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),\n              child: Text(\n                label,\n                style: _textStyle(\n                  fontSize: 13,\n                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,\n                  color: selected ? WynColors.ink : WynColors.mutedNeutral,\n                ),\n              ),\n            ),\n            Container(\n              height: 2,\n              color: selected ? WynColors.sapphire : Colors.transparent,\n            ),\n          ],\n        ),\n      ),\n    );\n  }\n""",
    """  Widget _buildTabs() {\n    return Container(\n      key: const Key('chat_threads_tabs'),\n      height: 48,\n      decoration: const BoxDecoration(\n        border: Border(bottom: BorderSide(color: WynColors.hairline)),\n      ),\n      child: Row(\n        children: [\n          Expanded(child: _buildTab('ทั้งหมด', 0)),\n          Expanded(child: _buildTab('ยังไม่อ่าน', 1)),\n        ],\n      ),\n    );\n  }\n\n  Widget _buildTab(String label, int index) {\n    final selected = _selectedTab == index;\n    return InkWell(\n      onTap: () => setState(() => _selectedTab = index),\n      child: Column(\n        mainAxisAlignment: MainAxisAlignment.end,\n        children: [\n          Expanded(\n            child: Center(\n              child: Text(\n                label,\n                style: _textStyle(\n                  fontSize: 13.5,\n                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,\n                  color: selected ? WynColors.ink : WynColors.graphite,\n                ),\n              ),\n            ),\n          ),\n          Container(\n            width: 34,\n            height: 2,\n            color: selected ? WynColors.ink : Colors.transparent,\n          ),\n        ],\n      ),\n    );\n  }\n""",
)
replace_once(
    inbox,
    """          padding: const EdgeInsets.symmetric(\n            horizontal: WynSpacing.space6,\n            vertical: WynSpacing.space3,\n          ),\n          child: Row(\n            children: [\n              const Icon(Icons.mail_outline, size: 18, color: WynColors.sapphire),\n              const SizedBox(width: WynSpacing.space3),\n              Expanded(\n                child: Text(\n                  'คำขอข้อความ ($_pendingRequestCount)',\n                  style: _textStyle(fontSize: 15, fontWeight: FontWeight.w500, color: WynColors.ink),\n                ),\n              ),\n              const Icon(Icons.chevron_right, size: 15, color: WynColors.faint),\n            ],\n          ),\n""",
    """          padding: const EdgeInsets.symmetric(\n            horizontal: WynSpacing.space4,\n            vertical: 10,\n          ),\n          child: Row(\n            children: [\n              Container(\n                width: 40,\n                height: 40,\n                decoration: const BoxDecoration(\n                  color: WynColors.surfaceTint,\n                  shape: BoxShape.circle,\n                ),\n                child: const Icon(\n                  Icons.chat_bubble_outline,\n                  size: 18,\n                  color: WynColors.ink,\n                ),\n              ),\n              const SizedBox(width: WynSpacing.space3),\n              Expanded(\n                child: Column(\n                  crossAxisAlignment: CrossAxisAlignment.start,\n                  children: [\n                    Text(\n                      'คำขอข้อความ ($_pendingRequestCount)',\n                      style: _textStyle(\n                        fontSize: 15,\n                        fontWeight: FontWeight.w600,\n                        color: WynColors.ink,\n                      ),\n                    ),\n                    const SizedBox(height: 1),\n                    Text(\n                      'รายการที่รอการตอบรับ',\n                      style: _textStyle(fontSize: 12.5, color: WynColors.graphite),\n                    ),\n                  ],\n                ),\n              ),\n              const Icon(Icons.chevron_right, size: 18, color: WynColors.graphite),\n            ],\n          ),\n""",
)
replace_once(
    inbox,
    """        child: Container(\n          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6, vertical: 14),\n          decoration: const BoxDecoration(\n            border: Border(bottom: BorderSide(color: WynColors.hairline)),\n          ),\n          child: Row(\n            crossAxisAlignment: CrossAxisAlignment.start,\n""",
    """        child: Container(\n          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: 12),\n          child: Row(\n            crossAxisAlignment: CrossAxisAlignment.center,\n""",
)
replace_once(inbox, """                radius: 24,\n                ring: true,\n""", """                radius: 24,\n                ring: false,\n""")
replace_once(inbox, """              const SizedBox(width: 14),\n""", """              const SizedBox(width: 12),\n""")
replace_once(
    inbox,
    """                              fontSize: 15,\n                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,\n""",
    """                              fontSize: 15.5,\n                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,\n""",
)
replace_once(inbox, """                          style: _textStyle(fontSize: 13, color: WynColors.mutedNeutral),\n""", """                          style: _textStyle(fontSize: 12.5, color: WynColors.graphite),\n""")
replace_once(
    inbox,
    """                              fontSize: 13,\n                              fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,\n                              fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,\n                              color: isUnread ? WynColors.ink : WynColors.graphite,\n""",
    """                              fontSize: 14,\n                              fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,\n                              fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,\n                              color: isUnread ? WynColors.ink : WynColors.graphite,\n""",
)
replace_once(inbox, """      width: 6,\n      height: 6,\n      decoration: const BoxDecoration(color: WynColors.sapphire, shape: BoxShape.circle),\n""", """      width: 7,\n      height: 7,\n      decoration: const BoxDecoration(color: WynColors.ink, shape: BoxShape.circle),\n""")

# ---------------------------------------------------------------------------
# Conversation — Threads-like monochrome bubbles and profile-like identity bar.
# ---------------------------------------------------------------------------
conversation = "app/lib/features/chat/presentation/conversation_screen.dart"
replace_once(
    conversation,
    "/// sapphire-filled bubbles (mine) vs. tinted #F1EFE9 bubbles (theirs).\n",
    "/// ink-filled bubbles (mine) vs. tinted #F1EFE9 bubbles (theirs), matching\n/// the monochrome Profile/Threads direction while preserving every DM action.\n",
)
replace_once(conversation, "decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),", "decoration: const BoxDecoration(color: WynColors.online, shape: BoxShape.circle),")
replace_once(
    conversation,
    """      appBar: AppBar(\n        backgroundColor: WynColors.paper,\n        centerTitle: true,\n        leading: IconButton(\n          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),\n          onPressed: () => Navigator.of(context).pop(),\n        ),\n""",
    """      appBar: AppBar(\n        backgroundColor: WynColors.paper,\n        surfaceTintColor: WynColors.paper,\n        elevation: 0,\n        scrolledUnderElevation: 0,\n        centerTitle: true,\n        toolbarHeight: 60,\n        leading: IconButton(\n          icon: const Icon(Icons.arrow_back, size: 22, color: WynColors.ink),\n          onPressed: () => Navigator.of(context).pop(),\n        ),\n""",
)
replace_once(
    conversation,
    """              AvatarCircle(imageUrl: widget.otherAvatarUrl, fallbackText: displayName, radius: 14),\n              const SizedBox(width: WynSpacing.space2),\n""",
    """              AvatarCircle(\n                imageUrl: widget.otherAvatarUrl,\n                fallbackText: displayName,\n                radius: 16,\n                ring: false,\n              ),\n              const SizedBox(width: WynSpacing.space2),\n""",
)
replace_once(
    conversation,
    """                      style: _textStyle(fontSize: 16, fontWeight: FontWeight.w700, color: WynColors.ink),\n                    ),\n                    // WYN-139/WYN-125: null (nothing rendered at all, no\n                    // empty line reserved) for a non-developer account\n                    // -- see _buildStatusSubtitle's own doc comment.\n                    if (statusSubtitle != null) statusSubtitle,\n""",
    """                      style: _textStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: WynColors.ink),\n                    ),\n                    if (statusSubtitle != null)\n                      statusSubtitle\n                    else\n                      Text(\n                        '@${widget.otherUsername}',\n                        overflow: TextOverflow.ellipsis,\n                        style: _textStyle(fontSize: 12, color: WynColors.graphite),\n                      ),\n""",
)
replace_once(
    conversation,
    """            icon: const Icon(Icons.more_vert, color: WynColors.ink),\n""",
    """            icon: const Icon(Icons.more_horiz, color: WynColors.ink),\n""",
)
replace_once(
    conversation,
    "padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space3),",
    "padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space4),",
)
replace_once(
    conversation,
    """                  color: _canSend ? WynColors.sapphire : WynColors.hairline,\n""",
    """                  color: _canSend ? WynColors.ink : WynColors.surfaceTint,\n""",
)
replace_once(
    conversation,
    """                child: FilledButton(\n                  onPressed: _isDecidingRequest ? null : _acceptRequest,\n""",
    """                child: FilledButton(\n                  style: FilledButton.styleFrom(\n                    backgroundColor: WynColors.ink,\n                    foregroundColor: WynColors.paper,\n                  ),\n                  onPressed: _isDecidingRequest ? null : _acceptRequest,\n""",
)
replace_once(
    conversation,
    """    final bubbleColor = message.isDeleted ? WynColors.hairline : (isMine ? WynColors.sapphire : _kBubbleFill);\n""",
    """    final bubbleColor = message.isDeleted ? WynColors.hairline : (isMine ? WynColors.ink : _kBubbleFill);\n""",
)
replace_once(
    conversation,
    """                  border: const Border(left: BorderSide(color: WynColors.sapphire, width: 2)),\n""",
    """                  border: Border(\n                    left: BorderSide(\n                      color: isMine ? WynColors.paper : WynColors.graphite,\n                      width: 2,\n                    ),\n                  ),\n""",
)
replace_once(
    conversation,
    """                      ? AvatarCircle(imageUrl: otherAvatarUrl, fallbackText: otherDisplayName, radius: 15, ring: true)\n""",
    """                      ? AvatarCircle(imageUrl: otherAvatarUrl, fallbackText: otherDisplayName, radius: 15, ring: false)\n""",
)

# ---------------------------------------------------------------------------
# New Message — same strong left title and quiet person-list hierarchy.
# ---------------------------------------------------------------------------
new_message = "app/lib/features/chat/presentation/new_message_screen.dart"
replace_once(new_message, "import '../../../core/design/wyn_typography.dart';\n", "")
replace_once(
    new_message,
    """      appBar: AppBar(\n        backgroundColor: WynColors.paper,\n        centerTitle: true,\n        leading: IconButton(\n          icon: const Icon(Icons.close, size: 20, color: WynColors.ink),\n          onPressed: () => Navigator.of(context).pop(),\n        ),\n        title: Text('ข้อความใหม่', style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink)),\n""",
    """      appBar: AppBar(\n        backgroundColor: WynColors.paper,\n        surfaceTintColor: WynColors.paper,\n        elevation: 0,\n        scrolledUnderElevation: 0,\n        centerTitle: false,\n        toolbarHeight: 58,\n        titleSpacing: 0,\n        leading: IconButton(\n          icon: const Icon(Icons.close, size: 21, color: WynColors.ink),\n          onPressed: () => Navigator.of(context).pop(),\n        ),\n        title: const Text(\n          'ข้อความใหม่',\n          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: WynColors.ink),\n        ),\n""",
)
replace_once(new_message, """        height: 42,\n""", """        height: 44,\n""")
replace_once(
    new_message,
    """              color: WynColors.mutedNeutral,\n              letterSpacing: 13 * 0.14,\n""",
    """              color: WynColors.graphite,\n""",
)
replace_once(
    new_message,
    """                radius: 21,\n                ring: true,\n""",
    """                radius: 23,\n                ring: false,\n""",
)
replace_once(new_message, """                    style: _textStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WynColors.ink),\n""", """                    style: _textStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: WynColors.ink),\n""")
replace_once(new_message, """                    style: _textStyle(fontSize: 13, color: WynColors.mutedNeutral),\n""", """                    style: _textStyle(fontSize: 13.5, color: WynColors.graphite),\n""")

# ---------------------------------------------------------------------------
# Message Requests — remove the last default-Material-looking chat surface.
# ---------------------------------------------------------------------------
requests = "app/lib/features/chat/presentation/message_request_list_screen.dart"
replace_once(
    requests,
    """import '../../../core/design/wyn_spacing.dart';\nimport '../../../core/text_utils.dart';\n""",
    """import '../../../core/design/wyn_colors.dart';\nimport '../../../core/design/wyn_spacing.dart';\nimport '../../../core/text_utils.dart';\nimport '../../../core/widgets/empty_state_block.dart';\n""",
)
replace_once(
    requests,
    """    return Scaffold(\n      appBar: AppBar(title: const Text('คำขอข้อความ')),\n      body: _buildBody(),\n    );\n""",
    """    return Scaffold(\n      backgroundColor: WynColors.paper,\n      appBar: AppBar(\n        backgroundColor: WynColors.paper,\n        surfaceTintColor: WynColors.paper,\n        elevation: 0,\n        scrolledUnderElevation: 0,\n        centerTitle: false,\n        toolbarHeight: 58,\n        titleSpacing: 0,\n        leading: IconButton(\n          icon: const Icon(Icons.arrow_back, size: 22, color: WynColors.ink),\n          onPressed: () => Navigator.of(context).pop(),\n        ),\n        title: const Text(\n          'คำขอข้อความ',\n          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: WynColors.ink),\n        ),\n        bottom: const PreferredSize(\n          preferredSize: Size.fromHeight(1),\n          child: Divider(height: 1, color: WynColors.hairline),\n        ),\n      ),\n      body: _buildBody(),\n    );\n""",
)
replace_once(
    requests,
    """    if (_requests.isEmpty) {\n      return Center(\n        child: Padding(\n          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),\n          child: Column(\n            mainAxisSize: MainAxisSize.min,\n            children: [\n              Icon(\n                Icons.mail_outline,\n                size: 56,\n                color: Theme.of(context).colorScheme.outline,\n              ),\n              const SizedBox(height: WynSpacing.space4),\n              const Text('ยังไม่มีคำขอข้อความ', textAlign: TextAlign.center),\n            ],\n          ),\n        ),\n      );\n    }\n""",
    """    if (_requests.isEmpty) {\n      return const Center(\n        child: EmptyStateBlock(\n          icon: Icons.chat_bubble_outline,\n          title: 'ยังไม่มีคำขอข้อความ',\n          subtitle: 'คำขอจากคนที่ยังไม่ได้เริ่มแชทกับคุณจะอยู่ตรงนี้',\n        ),\n      );\n    }\n""",
)
replace_once(
    requests,
    """          padding: const EdgeInsets.symmetric(\n            horizontal: WynSpacing.space4,\n            vertical: WynSpacing.space2,\n          ),\n""",
    """          padding: const EdgeInsets.symmetric(\n            horizontal: WynSpacing.space4,\n            vertical: 12,\n          ),\n""",
)
replace_once(
    requests,
    """                radius: 24,\n              ),\n""",
    """                radius: 24,\n                ring: false,\n              ),\n""",
)
replace_once(
    requests,
    """                    Text(displayName, style: Theme.of(context).textTheme.titleSmall),\n                    Text(\n                      _preview,\n                      maxLines: 1,\n                      overflow: TextOverflow.ellipsis,\n                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(\n                            color: Theme.of(context).colorScheme.onSurfaceVariant,\n                          ),\n                    ),\n""",
    """                    Text(\n                      displayName,\n                      style: const TextStyle(\n                        fontSize: 15.5,\n                        fontWeight: FontWeight.w600,\n                        color: WynColors.ink,\n                      ),\n                    ),\n                    const SizedBox(height: 2),\n                    Text(\n                      _preview,\n                      maxLines: 1,\n                      overflow: TextOverflow.ellipsis,\n                      style: const TextStyle(fontSize: 14, color: WynColors.graphite),\n                    ),\n""",
)
replace_once(
    requests,
    """              Text(\n                time,\n                style: Theme.of(context).textTheme.labelSmall?.copyWith(\n                      color: Theme.of(context).colorScheme.outline,\n                    ),\n              ),\n""",
    """              Text(\n                time,\n                style: const TextStyle(fontSize: 12.5, color: WynColors.graphite),\n              ),\n""",
)

print("Chat Threads/Profile UI patch applied successfully")
