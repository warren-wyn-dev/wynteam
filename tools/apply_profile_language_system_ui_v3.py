from pathlib import Path

exec(
    compile(
        Path('tools/apply_profile_language_system_ui_v2.py').read_text(),
        'tools/apply_profile_language_system_ui_v2.py',
        'exec',
    ),
    {'__name__': '__main__'},
)


def replace_all(path: str, old: str, new: str, expected: int | None = None) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if expected is not None and count != expected:
        raise RuntimeError(f'{path}: expected {expected} matches, found {count}: {old!r}')
    if count == 0:
        raise RuntimeError(f'{path}: anchor missing: {old!r}')
    p.write_text(text.replace(old, new))


# Home: Container cannot take color + decoration simultaneously. Keep the
# approved white surface in the BoxDecoration and preserve the existing menu
# icon contract used by navigation/regression tests.
home = 'app/lib/features/home/presentation/home_feed_screen.dart'
replace_all(home, 'icon: const Icon(Icons.menu_rounded, size: 22, color: WynColors.ink),',
            'icon: const Icon(Icons.menu, size: 22, color: WynColors.ink),', expected=1)
replace_all(
    home,
    """    return Container(\n      color: WynColors.paper,\n      decoration: const BoxDecoration(\n        border: Border(bottom: BorderSide(color: WynColors.hairline)),\n      ),\n""",
    """    return Container(\n      decoration: const BoxDecoration(\n        color: WynColors.paper,\n        border: Border(bottom: BorderSide(color: WynColors.hairline)),\n      ),\n""",
    expected=1,
)

# Search: retain the existing functional/test semantics (search icon, stable
# placeholder, and public tab wording) while keeping the new Profile-inspired
# pill/header/tab styling.
search = 'app/lib/features/search/presentation/search_screen.dart'
replace_all(search, 'Icons.search_rounded', 'Icons.search', expected=1)
replace_all(search, 'Icons.close_rounded', 'Icons.close', expected=1)
replace_all(search, "hintText: 'ค้นหาใน WYNOS',", "hintText: 'ค้นหา username, โพสต์, Club',", expected=1)
replace_all(search, "text: 'ผู้คน'", "text: 'User'", expected=1)

# Notifications: same Container assertion fix as Home. Keep exact legacy icon
# constants so interaction tests and accessibility semantics remain stable.
notification = 'app/lib/features/notification/presentation/notification_list_screen.dart'
replace_all(notification, 'icon: const Icon(Icons.menu_rounded, size: 22, color: WynColors.ink),',
            'icon: const Icon(Icons.menu, size: 22, color: WynColors.ink),', expected=1)
replace_all(notification, 'icon: const Icon(Icons.search_rounded, size: 21, color: WynColors.ink),',
            'icon: const Icon(Icons.search, size: 21, color: WynColors.ink),', expected=1)
replace_all(
    notification,
    """    return Container(\n      color: WynColors.paper,\n      decoration: const BoxDecoration(\n        border: Border(bottom: BorderSide(color: WynColors.hairline)),\n      ),\n""",
    """    return Container(\n      decoration: const BoxDecoration(\n        color: WynColors.paper,\n        border: Border(bottom: BorderSide(color: WynColors.hairline)),\n      ),\n""",
    expected=1,
)

# Settings: keep the grouped-card visual but stay compact enough that the
# separated logout action remains immediately reachable on small viewports.
# The version footer remains the true last ListView child, matching Beta4's
# established screen contract.
settings = 'app/lib/features/settings/presentation/settings_screen.dart'
replace_all(settings, '          const SizedBox(height: WynSpacing.space6),\n          _SettingsSection(\n            children: [\n              _SettingsRow(\n                icon: Icons.logout_rounded,',
            '          const SizedBox(height: WynSpacing.space3),\n          _SettingsSection(\n            children: [\n              _SettingsRow(\n                icon: Icons.logout_rounded,', expected=1)
replace_all(settings, '          const SizedBox(height: WynSpacing.space5),\n          _VersionFooter(',
            '          _VersionFooter(', expected=1)
replace_all(settings, '        WynSpacing.space5,\n        WynSpacing.space5,\n        WynSpacing.space5,\n        WynSpacing.space2,',
            '        WynSpacing.space4,\n        WynSpacing.space3,\n        WynSpacing.space4,\n        WynSpacing.space1,', expected=1)
replace_all(settings, '          constraints: const BoxConstraints(minHeight: 60),',
            '          constraints: const BoxConstraints(minHeight: 52),', expected=1)

# Side menu: preserve the established close icon finder/semantic contract.
menu = 'app/lib/features/root/presentation/side_menu.dart'
replace_all(menu, 'icon: const Icon(Icons.close_rounded, size: 22, color: WynColors.ink),',
            'icon: const Icon(Icons.close, size: 22, color: WynColors.ink),', expected=1)
