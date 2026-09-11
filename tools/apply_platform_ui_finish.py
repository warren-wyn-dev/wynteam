#!/usr/bin/env python3
"""Final manual presentation pass for the non-Profile WYNOS UI.

This complements apply_all_non_profile_ui_v2.py with interaction-aware changes
that should not be done by the broad token transformer:
- tab labels never ellipsize on real phone widths;
- Notifications uses the shared 60px header, 52px equal-width tabs and 680px rail;
- Chat Inbox uses the same shared pushed-screen header/tabs/rail contract.

Presentation only. No repository, route, state, or business rules are changed.
Profile is intentionally never read or written by this script.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match in {path}, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def regex_once(path: Path, pattern: str, repl: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    new_text, count = re.subn(pattern, repl, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 regex match in {path}, found {count}")
    path.write_text(new_text, encoding="utf-8")


# 1) Shared tabs: large-platform tab bars do not truncate their labels. Keep
# equal-width navigation, but scale down only when the viewport/text scale
# genuinely requires it. The Text itself has no ellipsis, so semantics and
# visual copy stay complete.
chrome = ROOT / "app/lib/core/widgets/wynos_social_chrome.dart"
replace_once(
    chrome,
    """                  child: Text(\n                    item.label,\n                    maxLines: 1,\n                    overflow: TextOverflow.ellipsis,\n                    style: TextStyle(\n                      fontSize: 14,\n                      fontWeight:\n                          selected ? FontWeight.w700 : FontWeight.w500,\n                      color: selected ? WynColors.ink : WynColors.graphite,\n                    ),\n                  ),""",
    """                  child: FittedBox(\n                    fit: BoxFit.scaleDown,\n                    child: Text(\n                      item.label,\n                      maxLines: 1,\n                      softWrap: false,\n                      style: TextStyle(\n                        fontSize: 14,\n                        fontWeight:\n                            selected ? FontWeight.w700 : FontWeight.w500,\n                        color:\n                            selected ? WynColors.ink : WynColors.graphite,\n                      ),\n                    ),\n                  ),""",
    "shared social tab no-ellipsis contract",
)

# 2) Notifications: same header/tabs/content rail as Home/Search. Behavior,
# pagination, filtering, unread snapshot, drawer and navigation stay untouched.
notifications = ROOT / "app/lib/features/notification/presentation/notification_list_screen.dart"
replace_once(
    notifications,
    "import '../../../core/design/wyn_typography.dart';\n",
    "",
    "notifications dead typography import",
)
replace_once(
    notifications,
    "import '../../../core/widgets/empty_state_block.dart';\n",
    "import '../../../core/widgets/empty_state_block.dart';\nimport '../../../core/widgets/wynos_social_chrome.dart';\n",
    "notifications shared chrome import",
)
replace_once(
    notifications,
    """      body: SafeArea(\n        child: Column(\n          children: [\n            _buildHeader(),""",
    """      body: SafeArea(\n        child: WynosContentRail(\n          child: Column(\n            children: [\n              _buildHeader(),""",
    "notifications content rail open",
)
replace_once(
    notifications,
    """            Expanded(child: _buildBody()),\n          ],\n        ),\n      ),""",
    """              Expanded(child: _buildBody()),\n            ],\n          ),\n        ),\n      ),""",
    "notifications content rail close",
)
regex_once(
    notifications,
    r"  // 02-notifications\.tsx header:.*?\n  bool _isMentionType",
    """  // Shared top-level social chrome: presentation-only replacement for\n  // the previous one-off 60px row. Fixed action slots keep the title centered.\n  Widget _buildHeader() {\n    return WynosSocialHeader(\n      title: 'การแจ้งเตือน',\n      leading: WynosHeaderAction(\n        icon: Icons.menu,\n        tooltip: 'เมนู',\n        onPressed: () => _scaffoldKey.currentState?.openDrawer(),\n      ),\n      trailing: WynosHeaderAction(\n        icon: Icons.search,\n        tooltip: 'ค้นหา',\n        onPressed: _openSearch,\n      ),\n    );\n  }\n\n  Widget _buildTabs() {\n    return WynosSocialTabs<_NotificationTab>(\n      items: const [\n        WynosSocialTabItem(value: _NotificationTab.all, label: 'ทั้งหมด'),\n        WynosSocialTabItem(\n          value: _NotificationTab.mentions,\n          label: 'การกล่าวถึง',\n        ),\n      ],\n      selected: _tab,\n      onSelected: (tab) => setState(() => _tab = tab),\n    );\n  }\n\n  bool _isMentionType""",
    "notifications shared header and 52px tabs",
)

# 3) Chat Inbox: same pushed-screen header, 52px equal-width tabs and content
# rail. All lockdown/request/realtime/paging logic remains exactly where it was.
chat = ROOT / "app/lib/features/chat/presentation/chat_inbox_screen.dart"
replace_once(
    chat,
    "import '../../../core/design/wyn_typography.dart';\n",
    "",
    "chat dead typography import",
)
replace_once(
    chat,
    "import '../../../core/widgets/empty_state_block.dart';\n",
    "import '../../../core/widgets/empty_state_block.dart';\nimport '../../../core/widgets/wynos_social_chrome.dart';\n",
    "chat shared chrome import",
)
regex_once(
    chat,
    r"  @override\n  Widget build\(BuildContext context\) \{\n    return Scaffold\(.*?\n  Widget _buildRequestsBanner\(\) \{",
    """  @override\n  Widget build(BuildContext context) {\n    return Scaffold(\n      backgroundColor: WynColors.paper,\n      body: SafeArea(\n        child: WynosContentRail(\n          child: Column(\n            children: [\n              WynosSocialHeader(\n                title: 'ข้อความ',\n                leading: WynosBackButton(\n                  onPressed: () => Navigator.of(context).maybePop(),\n                ),\n                trailing: WynosHeaderAction(\n                  icon: Icons.edit_outlined,\n                  tooltip: 'เขียนข้อความใหม่',\n                  onPressed: _openNewMessage,\n                ),\n              ),\n              Expanded(\n                child: _isLocked\n                    ? const Center(\n                        child: EmptyStateBlock(\n                          icon: Icons.lock_clock_outlined,\n                          title: 'ระบบแชทปิดปรับปรุงชั่วคราว',\n                          subtitle: 'จะเปิดให้ใช้งานได้เร็ว ๆ นี้',\n                        ),\n                      )\n                    : Column(\n                        children: [\n                          if (_pendingRequestCount > 0)\n                            _buildRequestsBanner(),\n                          _buildTabs(),\n                          Expanded(child: _buildBody()),\n                        ],\n                      ),\n              ),\n            ],\n          ),\n        ),\n      ),\n    );\n  }\n\n  Widget _buildTabs() {\n    return WynosSocialTabs<int>(\n      items: const [\n        WynosSocialTabItem(value: 0, label: 'ทั้งหมด'),\n        WynosSocialTabItem(value: 1, label: 'ยังไม่อ่าน'),\n      ],\n      selected: _selectedTab,\n      onSelected: (index) => setState(() => _selectedTab = index),\n    );\n  }\n\n  Widget _buildRequestsBanner() {""",
    "chat shared header, rail and 52px tabs",
)

print("Applied final platform UI pass: shared tabs + Notifications + Chat Inbox")
