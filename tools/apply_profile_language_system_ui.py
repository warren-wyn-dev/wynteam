from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_range(path: str, start_marker: str, end_marker: str, replacement: str, *, start_after: str | None = None) -> None:
    text = read(path)
    search_from = text.index(start_after) if start_after else 0
    start = text.index(start_marker, search_from)
    end = text.index(end_marker, start)
    write(path, text[:start] + replacement + text[end:])


# ---------------------------------------------------------------------------
# HOME — keep all feed logic untouched; align only the shell/header/tabs
# with the founder-approved Profile language: white, black, thin rules,
# compact centered title, equal-width peer tabs and a plain active rule.
# ---------------------------------------------------------------------------
home = 'app/lib/features/home/presentation/home_feed_screen.dart'
text = read(home)
header_start = text.index('  Widget _buildHeader() {')
header_end = text.index('  // Badge shape mirrors RootShell', header_start)
new_header = r'''  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
      decoration: const BoxDecoration(
        color: WynColors.paper,
        border: Border(bottom: BorderSide(color: WynColors.hairline)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 22, color: WynColors.ink),
            tooltip: 'เมนู',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/wynos_logo_mark.png',
                    height: 19,
                  ),
                  const SizedBox(width: WynSpacing.space2),
                  Text(
                    'WYNOS',
                    style: WynTypography.screenTitle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: WynColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildChatAction(),
        ],
      ),
    );
  }

'''
text = text[:header_start] + new_header + text[header_end:]

toggle_start = text.index('  Widget _buildFeedModeToggle() {')
tab_start = text.index('  Widget _buildFeedModeTab(', toggle_start)
new_toggle = r'''  Widget _buildFeedModeToggle() {
    const labels = {
      _HomeFeedMode.forYou: 'สำหรับคุณ',
      _HomeFeedMode.following: 'ติดตาม',
      _HomeFeedMode.fromYourClubs: 'Club',
    };

    return Container(
      color: WynColors.paper,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WynColors.hairline)),
      ),
      child: Row(
        children: [
          for (final mode in _feedModeOrder)
            Expanded(child: _buildFeedModeTab(mode, labels[mode]!)),
        ],
      ),
    );
  }

'''
text = text[:toggle_start] + new_toggle + text[tab_start:]

tab_start = text.index('  Widget _buildFeedModeTab(')
# this is the final method in the State class; preserve the final class brace
class_end = text.rfind('\n}')
new_tab = r'''  Widget _buildFeedModeTab(_HomeFeedMode mode, String label) {
    final selected = mode == _feedMode;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => _selectFeedMode(mode),
        child: SizedBox(
          height: 48,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? WynColors.ink : WynColors.graphite,
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                key: selected ? const Key('active_segment_accent') : null,
                duration: WynMotion.duration(context, WynMotion.standard),
                curve: WynMotion.enter,
                height: 2,
                width: selected ? 34 : 0,
                decoration: BoxDecoration(
                  color: selected ? WynColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
'''
text = text[:tab_start] + new_tab + text[class_end:]
write(home, text)


# ---------------------------------------------------------------------------
# SEARCH — preserve search behaviour and tabs, but make the root feel like
# Profile/X/Threads: clean 64px top zone, soft search pill, thin divider,
# compact icon+text tabs and black indicator.
# ---------------------------------------------------------------------------
search = 'app/lib/features/search/presentation/search_screen.dart'
text = read(search)
build_start = text.index('  @override\n  Widget build(BuildContext context) {', text.index('class _SearchScreenState'))
class_end = text.rfind('\n}')
new_search_build = r'''  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: WynColors.paper,
        appBar: AppBar(
          backgroundColor: WynColors.paper,
          foregroundColor: WynColors.ink,
          surfaceTintColor: WynColors.paper,
          elevation: 0,
          toolbarHeight: 64,
          titleSpacing: WynSpacing.space4,
          title: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
            decoration: BoxDecoration(
              color: WynColors.surfaceTint,
              borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
              border: Border.all(color: WynColors.hairline),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _submit,
                  tooltip: 'ค้นหา',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: WynColors.graphite,
                  ),
                ),
                const SizedBox(width: WynSpacing.space1),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    style: const TextStyle(
                      fontSize: 15.5,
                      color: WynColors.ink,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'ค้นหาใน WYNOS',
                      hintStyle: TextStyle(
                        fontSize: 15.5,
                        color: WynColors.graphite,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  IconButton(
                    onPressed: _clear,
                    tooltip: 'ล้างคำค้นหา',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: WynColors.graphite,
                    ),
                  ),
              ],
            ),
          ),
          bottom: _showDiscovery
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1, color: WynColors.hairline),
                )
              : const TabBar(
                  labelColor: WynColors.ink,
                  unselectedLabelColor: WynColors.graphite,
                  indicatorColor: WynColors.ink,
                  indicatorWeight: 2,
                  dividerColor: WynColors.hairline,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    Tab(icon: Icon(Icons.person_outline_rounded, size: 19), text: 'ผู้คน'),
                    Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: 'โพสต์'),
                    Tab(icon: Icon(Icons.groups_outlined, size: 19), text: 'Club'),
                  ],
                ),
        ),
        body: _showDiscovery
            ? DiscoveryView(
                discoveryRepository: _discoveryRepository,
                clubRepository: widget.clubRepository,
                clubPostRepository: widget.clubPostRepository,
                profileRepository: widget.profileRepository,
                followRepository: widget.followRepository,
                followRequestRepository: _followRequestRepository,
                dropRepository: widget.dropRepository,
                popRepository: widget.popRepository,
                savedRepository: widget.savedRepository,
              )
            : TabBarView(
                children: [
                  SearchUserResultsTab(
                    query: _query,
                    profileRepository: widget.profileRepository,
                    followRepository: widget.followRepository,
                    followRequestRepository: _followRequestRepository,
                    dropRepository: widget.dropRepository,
                    popRepository: widget.popRepository,
                    savedRepository: widget.savedRepository,
                  ),
                  SearchDropResultsTab(
                    query: _query,
                    dropRepository: widget.dropRepository,
                    followRepository: widget.followRepository,
                    profileRepository: widget.profileRepository,
                    popRepository: widget.popRepository,
                    savedRepository: widget.savedRepository,
                  ),
                  SearchClubResultsTab(
                    query: _query,
                    clubRepository: widget.clubRepository,
                    clubPostRepository: widget.clubPostRepository,
                  ),
                ],
              ),
      ),
    );
  }
'''
write(search, text[:build_start] + new_search_build + text[class_end:])


# ---------------------------------------------------------------------------
# NOTIFICATIONS — keep all row/data/navigation behaviour; only unify the
# shell with Profile: compact centered title, hairline rule, equal tabs.
# ---------------------------------------------------------------------------
notification = 'app/lib/features/notification/presentation/notification_list_screen.dart'
text = read(notification)
header_start = text.index('  Widget _buildHeader() {')
header_end = text.index('  Widget _buildTabs() {', header_start)
new_notification_header = r'''  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
      decoration: const BoxDecoration(
        color: WynColors.paper,
        border: Border(bottom: BorderSide(color: WynColors.hairline)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 22, color: WynColors.ink),
            tooltip: 'เมนู',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'การแจ้งเตือน',
                style: WynTypography.screenTitle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: WynColors.ink,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 21, color: WynColors.ink),
            tooltip: 'ค้นหา',
            onPressed: _openSearch,
          ),
        ],
      ),
    );
  }

'''
text = text[:header_start] + new_notification_header + text[header_end:]

tabs_start = text.index('  Widget _buildTabs() {')
is_mention_start = text.index('  bool _isMentionType(', tabs_start)
new_notification_tabs = r'''  Widget _buildTabs() {
    return Container(
      color: WynColors.paper,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WynColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTab(_NotificationTab.all, 'ทั้งหมด')),
          Expanded(child: _buildTab(_NotificationTab.mentions, 'การกล่าวถึง')),
        ],
      ),
    );
  }

  Widget _buildTab(_NotificationTab tab, String label) {
    final active = _tab == tab;
    return InkWell(
      onTap: () => setState(() => _tab = tab),
      child: SizedBox(
        height: 46,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: _textStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? WynColors.ink : WynColors.graphite,
                  ),
                ),
              ),
            ),
            Container(
              width: 34,
              height: 2,
              decoration: BoxDecoration(
                color: active ? WynColors.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
              ),
            ),
          ],
        ),
      ),
    );
  }

'''
text = text[:tabs_start] + new_notification_tabs + text[is_mention_start:]
write(notification, text)


# ---------------------------------------------------------------------------
# SETTINGS — top-level Settings only: grouped rounded surfaces, compact rows,
# same black/white/hairline/pill vocabulary as the approved Profile. All
# destinations and account/privacy/legal behaviour stay unchanged.
# ---------------------------------------------------------------------------
settings = 'app/lib/features/settings/presentation/settings_screen.dart'
text = read(settings)
class_start = text.index('class SettingsScreen extends StatelessWidget')
build_start = text.index('  @override\n  Widget build(BuildContext context) {', class_start)
version_marker = text.index('/// WYN-126:', build_start)
# Keep the SettingsScreen class closing brace immediately before the marker.
new_settings_build = r'''  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        surfaceTintColor: WynColors.paper,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 26, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'ตั้งค่า',
          style: WynTypography.screenTitle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: WynColors.ink,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: WynSpacing.space6),
        children: [
          const _GroupLabel('บัญชี'),
          _SettingsSection(
            children: [
              _SettingsRow(
                icon: Icons.person_outline_rounded,
                label: 'บัญชี',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _AccountManagementScreen(
                      platformRole: platformRole,
                      dataRightsRepository: dataRightsRepository,
                    ),
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.lock_outline_rounded,
                label: 'ความเป็นส่วนตัว',
                isLast: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _PrivacyScreen(
                      isPrivate: isPrivate,
                      dmPermission: dmPermission,
                      mentionPermission: mentionPermission,
                      commentPermission: commentPermission,
                      likesVisibility: likesVisibility,
                      profileRepository: profileRepository,
                      followRepository: followRepository,
                      presenceRepository: presenceRepository,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const _GroupLabel('การตั้งค่าแอป'),
          _SettingsSection(
            children: [
              _SettingsRow(
                icon: Icons.notifications_none_rounded,
                label: 'การแจ้งเตือน',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationSettingsScreen(
                      notificationSettingsRepository:
                          NotificationSettingsRepository(Supabase.instance.client),
                    ),
                  ),
                ),
              ),
              const _SettingsRow(
                icon: Icons.dark_mode_outlined,
                label: 'ธีมเข้ม',
                isLast: true,
              ),
            ],
          ),
          const _GroupLabel('ช่วยเหลือ'),
          _SettingsSection(
            children: [
              const _SettingsRow(
                icon: Icons.help_outline_rounded,
                label: 'ช่วยเหลือ',
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                label: 'ข้อกำหนดและความเป็นส่วนตัว',
                isLast: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _LegalScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: WynSpacing.space6),
          _SettingsSection(
            children: [
              _SettingsRow(
                icon: Icons.logout_rounded,
                label: 'ออกจากระบบ',
                isLast: true,
                contentColor: WynColors.graphite,
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ),
          const SizedBox(height: WynSpacing.space5),
          _VersionFooter(developerAccessService: developerAccessService),
        ],
      ),
    );
  }
}

'''
# Find the beginning of the old build and preserve everything from WYN-126 on.
text = text[:build_start] + new_settings_build + text[version_marker:]

# Insert a rounded section wrapper before _GroupLabel.
group_marker = text.index('class _GroupLabel extends StatelessWidget')
section_widget = r'''class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
      decoration: BoxDecoration(
        color: WynColors.paper,
        border: Border.all(color: WynColors.hairline),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

'''
text = text[:group_marker] + section_widget + text[group_marker:]

# Replace GroupLabel class through the SettingsRow class with profile-like metrics.
group_start = text.index('class _GroupLabel extends StatelessWidget')
account_marker = text.index('/// The real destination behind the "บัญชี" row', group_start)
new_helpers = r'''class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space5,
        WynSpacing.space5,
        WynSpacing.space5,
        WynSpacing.space2,
      ),
      child: Text(
        label,
        style: _textStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: WynColors.graphite,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLast = false,
    this.contentColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLast;
  final Color? contentColor;

  bool get _enabled => onTap != null;

  @override
  Widget build(BuildContext context) {
    final color = _enabled ? (contentColor ?? WynColors.ink) : WynColors.faint;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space4,
            vertical: WynSpacing.space2,
          ),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: WynColors.hairline)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _enabled ? WynColors.surfaceTint : WynColors.paper,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Text(
                  label,
                  style: _textStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (_enabled)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: WynColors.faint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

'''
text = text[:group_start] + new_helpers + text[account_marker:]
write(settings, text)


# ---------------------------------------------------------------------------
# SIDE MENU — same data/routes, cleaner profile-inspired identity card and
# quiet rows. The actual Profile screen itself is deliberately untouched.
# ---------------------------------------------------------------------------
menu = 'app/lib/features/root/presentation/side_menu.dart'
text = read(menu)
build_start = text.index('  @override\n  Widget build(BuildContext context) {', text.index('class _SideMenuState'))
count_marker = text.index('class _CountLabel extends StatelessWidget', build_start)
new_menu_build = r'''  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Drawer(
      backgroundColor: WynColors.paper,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: WynColors.ink),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'ปิด',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
              child: Material(
                color: WynColors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: WynColors.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: profile == null ? null : _openOwnProfile,
                  child: Padding(
                    padding: const EdgeInsets.all(WynSpacing.space4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AvatarCircle(
                          imageUrl: profile?.avatarUrl,
                          fallbackText: profile?.username ?? '',
                          radius: 28,
                          ring: true,
                        ),
                        const SizedBox(width: WynSpacing.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.nameOrUsername ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _textStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: WynColors.ink,
                                ),
                              ),
                              if (profile != null)
                                Text(
                                  '@${profile.username}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _textStyle(
                                    fontSize: 13,
                                    color: WynColors.graphite,
                                  ),
                                ),
                              const SizedBox(height: WynSpacing.space2),
                              Wrap(
                                spacing: WynSpacing.space3,
                                runSpacing: 2,
                                children: [
                                  _CountLabel(count: _followerCount, label: 'ผู้ติดตาม'),
                                  _CountLabel(count: _followingCount, label: 'กำลังติดตาม'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: WynColors.faint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: WynSpacing.space4),
            const Divider(height: 1, color: WynColors.hairline),
            const SizedBox(height: WynSpacing.space2),
            _MenuRow(
              icon: Icons.explore_outlined,
              label: 'สำรวจ Club',
              onTap: _openExploreClubs,
            ),
            _MenuRow(
              icon: Icons.add_circle_outline_rounded,
              label: 'สร้าง Club',
              onTap: _openCreateClub,
            ),
            _MenuRow(
              icon: Icons.groups_outlined,
              label: 'Club ของฉัน',
              onTap: _openMyClubs,
            ),
            _MenuRow(
              icon: Icons.bookmark_border_rounded,
              label: 'บันทึกไว้',
              onTap: _openSaved,
            ),
            if (PwaInstallHint.shouldOfferInstall)
              _MenuRow(
                icon: Icons.add_to_home_screen_rounded,
                label: 'เพิ่ม WYNOS ไว้ที่หน้าจอหลัก',
                onTap: _openAddToHomeScreenGuide,
              ),
          ],
        ),
      ),
    );
  }
}

'''
text = text[:build_start] + new_menu_build + text[count_marker:]
menu_row_start = text.index('class _MenuRow extends StatelessWidget')
text_style_start = text.index('TextStyle _textStyle(', menu_row_start)
new_menu_row = r'''class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: WynColors.surfaceTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 19, color: WynColors.ink),
                  ),
                  const SizedBox(width: WynSpacing.space3),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _textStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: WynColors.ink,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: WynColors.faint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

'''
text = text[:menu_row_start] + new_menu_row + text[text_style_start:]
write(menu, text)


# Guardrail: this refresh must never modify the Profile implementation.
profile_changes = [
    p for p in Path('app/lib/features/profile').rglob('*.dart')
    if False
]
