from pathlib import Path

exec(
    compile(
        Path('tools/apply_profile_language_system_ui_v4.py').read_text(),
        'tools/apply_profile_language_system_ui_v4.py',
        'exec',
    ),
    {'__name__': '__main__'},
)

# RootShell has used WynosFounderBottomNavigation since the founder bottom-nav
# refresh. One legacy assertion still searched for Material NavigationBar and
# therefore failed even though the selected Profile destination was correct.
# Update only that stale test contract; product navigation behavior is unchanged.
path = Path('app/test/root_shell_test.dart')
text = path.read_text()
import_anchor = "import 'package:wyn/features/root/presentation/root_shell.dart';\n"
import_line = "import 'package:wyn/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart';\n"
if import_line not in text:
    if import_anchor not in text:
        raise RuntimeError('root shell import anchor missing')
    text = text.replace(import_anchor, import_anchor + import_line, 1)
old = """    expect(\n      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,\n      4,\n    );\n"""
new = """    expect(\n      tester\n          .widget<WynosFounderBottomNavigation>(\n            find.byType(WynosFounderBottomNavigation),\n          )\n          .selectedIndex,\n      4,\n    );\n"""
if old not in text:
    raise RuntimeError('stale NavigationBar assertion anchor missing')
path.write_text(text.replace(old, new, 1))
