from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected exactly one match, found {count}: {old[:120]!r}")
    write(path, text.replace(old, new, 1))


def replace_between(path: str, start: str, end: str, replacement: str) -> None:
    text = read(path)
    i = text.find(start)
    if i < 0:
        raise RuntimeError(f"{path}: start marker missing: {start!r}")
    j = text.find(end, i + len(start))
    if j < 0:
        raise RuntimeError(f"{path}: end marker missing: {end!r}")
    write(path, text[:i] + replacement + text[j:])


# ---------------------------------------------------------------------------
# WYN-141 Founder-approved system refresh.
# Scope: system presentation + top-level navigation surfaces.
# The Profile screen itself is deliberately untouched.
# ---------------------------------------------------------------------------

write(
    "app/lib/core/design/wyn_theme.dart",
    r'''// WYN Design System — assembled ThemeData.
//
// WYN-141 system refresh: the Founder approved a cleaner X/Threads-like
// presentation while keeping WYNOS data, routes and behavior unchanged.
// This file is the broad visual layer: every screen gets the same app bars,
// controls, fields, sheets, dialogs, tabs and list density without copying
// styling into feature code. The Profile screen keeps its own explicit
// Founder-approved composition/styles and is not redesigned by this pass.
import 'package:flutter/material.dart';

import 'wyn_colors.dart';
import 'wyn_spacing.dart';
import 'wyn_typography.dart';

class WynTheme {
  WynTheme._();

  static const List<String> fontFamilyFallback = ['WYNThaiLooped'];

  static final CardThemeData _lightCardTheme = CardThemeData(
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: WynColors.hairline),
    ),
  );

  static final CardThemeData _darkCardTheme = CardThemeData(
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      side: const BorderSide(color: WynColors.borderStrongDark),
    ),
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: WynColors.socialLightScheme,
    scaffoldBackgroundColor: WynColors.paper,
    fontFamilyFallback: fontFamilyFallback,
    textTheme: WynTypography.textTheme,
    cardTheme: _lightCardTheme,
    dividerTheme: const DividerThemeData(
      color: WynColors.hairline,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: WynColors.paper,
      foregroundColor: WynColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 60,
      titleTextStyle: TextStyle(
        color: WynColors.ink,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      iconTheme: IconThemeData(color: WynColors.ink, size: 24),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: WynColors.ink,
        foregroundColor: WynColors.paper,
        disabledBackgroundColor: WynColors.surfaceTint,
        disabledForegroundColor: WynColors.faint,
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        foregroundColor: WynColors.ink,
        side: const BorderSide(color: WynColors.hairline),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: WynColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        foregroundColor: WynColors.ink,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: WynColors.surfaceTint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: WynColors.graphite, fontSize: 16),
      labelStyle: const TextStyle(color: WynColors.graphite, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: WynColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: WynColors.sapphire, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: WynColors.errorLight),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: WynColors.errorLight, width: 1.5),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: WynColors.ink,
      textColor: WynColors.ink,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 12,
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: WynColors.ink,
      dividerColor: WynColors.hairline,
      labelColor: WynColors.ink,
      unselectedLabelColor: WynColors.graphite,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      indicatorSize: TabBarIndicatorSize.label,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: WynColors.paper,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: WynColors.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        side: BorderSide(color: WynColors.hairline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: WynColors.ink,
      contentTextStyle: const TextStyle(color: WynColors.paper, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: WynColors.paper,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: WynColors.paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: WynColors.sapphire,
      linearTrackColor: WynColors.surfaceTint,
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: WynColors.socialDarkScheme,
    fontFamilyFallback: fontFamilyFallback,
    textTheme: WynTypography.textTheme,
    cardTheme: _darkCardTheme,
  );
}
''',
)

# Keep the Founder Profile metrics unchanged; only root navigation values move.
replace_once(
    "app/lib/core/design/wynos_founder_metrics.dart",
    "  static const double bottomNavContentHeight = 72;\n  static const double createActionDiameter = 56;\n",
    "  static const double bottomNavContentHeight = 64;\n  static const double createActionDiameter = 48;\n",
)

write(
    "app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart",
    r'''import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wynos_founder_metrics.dart';

/// WYN-141 approved mobile navigation: icon-first, quiet, five equal slots.
/// The middle item stays a create action (never a selected page).
class WynosFounderBottomNavigation extends StatelessWidget {
  const WynosFounderBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.createAction,
    required this.notificationIcon,
    required this.selectedNotificationIcon,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget createAction;
  final Widget notificationIcon;
  final Widget selectedNotificationIcon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WynColors.paper,
        border: Border(top: BorderSide(color: WynColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: WynosFounderMetrics.bottomNavContentHeight,
          child: Row(
            children: [
              Expanded(
                child: _Destination(
                  label: 'หน้าหลัก',
                  selected: selectedIndex == 0,
                  icon: selectedIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                  onTap: () => onDestinationSelected(0),
                ),
              ),
              Expanded(
                child: _Destination(
                  label: 'ค้นหา',
                  selected: selectedIndex == 1,
                  icon: Icons.search_rounded,
                  onTap: () => onDestinationSelected(1),
                ),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'สร้างโพสต์ใหม่',
                  child: InkResponse(
                    onTap: () => onDestinationSelected(2),
                    radius: 32,
                    child: Center(child: createAction),
                  ),
                ),
              ),
              Expanded(
                child: _DestinationWidget(
                  label: 'การแจ้งเตือน',
                  selected: selectedIndex == 3,
                  icon: selectedIndex == 3 ? selectedNotificationIcon : notificationIcon,
                  onTap: () => onDestinationSelected(3),
                ),
              ),
              Expanded(
                child: _Destination(
                  label: 'โปรไฟล์',
                  selected: selectedIndex == 4,
                  icon: selectedIndex == 4
                      ? Icons.person_rounded
                      : Icons.person_outline_rounded,
                  onTap: () => onDestinationSelected(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DestinationWidget(
      label: label,
      selected: selected,
      icon: Icon(icon, size: 26),
      onTap: onTap,
    );
  }
}

class _DestinationWidget extends StatelessWidget {
  const _DestinationWidget({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? WynColors.ink : WynColors.graphite;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Center(
          child: IconTheme(
            data: IconThemeData(color: color, size: 26),
            child: icon,
          ),
        ),
      ),
    );
  }
}
''',
)

# Home: left-aligned brand, chat + compact account/menu action on the right.
home = "app/lib/features/home/presentation/home_feed_screen.dart"
replace_between(
    home,
    "  Widget _buildHeader() {\n",
    "  // Badge shape mirrors RootShell._buildNotificationsIcon exactly",
    r'''  Widget _buildHeader() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
      decoration: const BoxDecoration(
        color: WynColors.paper,
        border: Border(bottom: BorderSide(color: WynColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Image.asset('assets/images/wynos_logo_mark.png', height: 20),
                const SizedBox(width: WynSpacing.space2),
                Text(
                  'WYNOS',
                  style: WynTypography.screenTitle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          _buildChatAction(),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 25),
            tooltip: 'เมนู',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ],
      ),
    );
  }

''',
)
replace_once(
    home,
    "                    decoration: const BoxDecoration(\n                      gradient: WynColors.rainbowAccent,\n                      borderRadius: BorderRadius.all(\n                          Radius.circular(WynSpacing.radiusFull)),\n                    ),\n",
    "                    decoration: const BoxDecoration(\n                      color: WynColors.ink,\n                      borderRadius: BorderRadius.all(\n                          Radius.circular(WynSpacing.radiusFull)),\n                    ),\n",
)

# Search: taller quiet search field + text-first result tabs.
search = "app/lib/features/search/presentation/search_screen.dart"
replace_once(search, "            height: 42,\n", "            height: 46,\n")
replace_once(
    search,
    "                    child: const Icon(Icons.search,\n                        size: 16, color: WynColors.mutedNeutral),\n",
    "                    child: const Icon(Icons.search_rounded,\n                        size: 20, color: WynColors.graphite),\n",
)
replace_once(
    search,
    "              : const TabBar(\n                  tabs: [\n                    Tab(icon: Icon(Icons.person_outline), text: 'User'),\n                    Tab(icon: Icon(Icons.grid_view_outlined), text: 'โพสต์'),\n                    Tab(icon: Icon(Icons.groups_outlined), text: 'Club'),\n                  ],\n                ),\n",
    "              : const TabBar(\n                  indicatorColor: WynColors.ink,\n                  indicatorSize: TabBarIndicatorSize.label,\n                  dividerColor: WynColors.hairline,\n                  labelColor: WynColors.ink,\n                  unselectedLabelColor: WynColors.graphite,\n                  tabs: [\n                    Tab(text: 'ผู้คน'),\n                    Tab(text: 'โพสต์'),\n                    Tab(text: 'Club'),\n                  ],\n                ),\n",
)

# Deployment remains explicit: normal pushes do not deploy. A merge commit
# containing [deploy-web] is an intentional production release signal.
deploy = ".github/workflows/deploy-web.yml"
replace_once(
    deploy,
    "on:\n  workflow_dispatch: {}\n\njobs:\n  deploy:\n",
    "on:\n  workflow_dispatch: {}\n  push:\n    branches: [main]\n\njobs:\n  deploy:\n    if: github.event_name == 'workflow_dispatch' || contains(github.event.head_commit.message, '[deploy-web]')\n",
)

# Record the new, explicit Founder approval without changing the release number.
task = ".wyn/tasks/active/WYN-141-frontend-ux-ui-system.md"
text = read(task)
marker = "## Founder whole-system visual approval — 2026-09-11"
if marker not in text:
    text += r'''

## Founder whole-system visual approval — 2026-09-11

Founder reviewed the generated whole-system WYNOS mockup and approved implementation with the instruction to publish the redesign across the website while keeping the existing Profile screen unchanged. This approval supersedes conflicting older presentation details for non-Profile surfaces only. Product behavior, routes, permissions, backend contracts and the Beta4 version label remain unchanged.

Implementation strategy for this pass: apply a shared component theme (app bars, buttons, inputs, list rows, tabs, dialogs, sheets, cards and feedback surfaces) so every existing screen adopts the same language, then tune the custom root navigation, Home header/feed tabs and Search surface that do not inherit enough from Material component theming. The Profile screen's custom Founder-approved composition is not modified.
'''
    write(task, text)

print("WYN-141 approved system UI codemod applied")
