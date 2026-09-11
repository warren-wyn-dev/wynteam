from pathlib import Path

source = Path('tools/apply_all_non_profile_ui.py').read_text()

# Drop Detail is a behavior-heavy surface with a custom action bar, comment
# composer, view metrics, and ReDrop affordance. The global constructor-level
# transformer is intentionally presentation-only. Keep this bespoke,
# Founder-approved surface on its current implementation while the generic pass
# harmonizes the remaining presentation tree.
exclude_marker = "EXCLUDED_PARTS = {'profile', 'pop'}\n\n"
if exclude_marker not in source:
    raise RuntimeError('Transformer shape changed: exclusion marker not found')
source = source.replace(
    exclude_marker,
    exclude_marker
    + "EXCLUDED_PATHS = {\n"
    + "    'app/lib/features/drop/presentation/drop_detail_screen.dart',\n"
    + "}\n\n",
    1,
)

target_marker = "def is_target(path: Path) -> bool:\n    parts = set(path.parts)\n"
if target_marker not in source:
    raise RuntimeError('Transformer shape changed: is_target marker not found')
source = source.replace(
    target_marker,
    target_marker
    + "    if path.as_posix() in EXCLUDED_PATHS:\n"
    + "        return False\n",
    1,
)

audit_marker = "    '- Hidden and intentionally not resurfaced: `app/lib/features/pop/**`\\n\\n'\n"
if audit_marker not in source:
    raise RuntimeError('Transformer shape changed: audit marker not found')
source = source.replace(
    audit_marker,
    "    '- Hidden and intentionally not resurfaced: `app/lib/features/pop/**`\\n'\n"
    "    '- Behavior-sensitive Founder-final surface audited and intentionally preserved unchanged: `app/lib/features/drop/presentation/drop_detail_screen.dart`\\n\\n'\n",
    1,
)

# The base transformer intentionally works at source-text level, so make every
# constructor lookup lexical and identifier-boundary aware before executing it.
# This prevents tokens such as `Card(`, `AppBar(`, and `Scaffold(` from
# accidentally matching custom widgets like HomeDropCard, SliverAppBar, or
# OnboardingScaffold, and it ignores examples inside comments/string literals.
helper = r'''
def find_code_token(text: str, token: str, start: int = 0) -> int:
    i = max(0, start)
    quote = None
    triple = False
    line_comment = False
    block_comment = 0
    while i < len(text):
        ch = text[i]
        nxt = text[i:i+2]
        if line_comment:
            if ch == '\n':
                line_comment = False
            i += 1
            continue
        if block_comment:
            if nxt == '/*':
                block_comment += 1
                i += 2
                continue
            if nxt == '*/':
                block_comment -= 1
                i += 2
                continue
            i += 1
            continue
        if quote is not None:
            if triple:
                if text[i:i+3] == quote * 3:
                    quote = None
                    triple = False
                    i += 3
                    continue
                i += 1
                continue
            if ch == '\\':
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if nxt == '//':
            line_comment = True
            i += 2
            continue
        if nxt == '/*':
            block_comment = 1
            i += 2
            continue
        if ch in ('"', "'"):
            if text[i:i+3] == ch * 3:
                quote = ch
                triple = True
                i += 3
            else:
                quote = ch
                i += 1
            continue
        if text.startswith(token, i):
            prev = text[i-1] if i > 0 else ''
            if not (prev.isalnum() or prev in '_$'):
                return i
        i += 1
    return -1

# Regression probes for the exact false-positive family that broke the first
# one-shot run. These execute before any repository file is modified.
assert find_code_token('return Scaffold(body: body);', 'Scaffold(') >= 0
assert find_code_token('return OnboardingScaffold(body: body);', 'Scaffold(') == -1
assert find_code_token('return HomeDropCard(drop: drop);', 'Card(') == -1
assert find_code_token('return SliverAppBar(title: title);', 'AppBar(') == -1
assert find_code_token('// Scaffold(fake)\nreturn Scaffold(body: body);', 'Scaffold(') > 0
assert find_code_token('final sample = "Card(fake)";\nCard(child: child);', 'Card(') > 0
'''

needle = '\ndef inject_missing_args(text: str, token: str, desired: list[tuple[str, str]]) -> tuple[str, int]:\n'
if needle not in source:
    raise RuntimeError('Transformer shape changed: inject_missing_args marker not found')
source = source.replace(needle, helper + needle, 1)

replacements = {
    'idx = text.find(token, cursor)': 'idx = find_code_token(text, token, cursor)',
    "gi = text.find('showModalBottomSheet<', search)": "gi = find_code_token(text, 'showModalBottomSheet<', search)",
    "uses_surface = any(token in text for token, _ in SURFACE_RULES) or 'showModalBottomSheet(' in text": "uses_surface = any(find_code_token(text, token) >= 0 for token, _ in SURFACE_RULES) or find_code_token(text, 'showModalBottomSheet(') >= 0",
    'if token not in text:\n            continue': 'if find_code_token(text, token) < 0:\n            continue',
    "base_indent = text[line_start:idx]\n            call_indent = base_indent + '  '": "line_prefix = text[line_start:idx]\n            base_indent = re.match(r'[ \\t]*', line_prefix).group(0)\n            call_indent = base_indent + '  '",
    "indent = text[line_start:gi] + '  '": "line_prefix = text[line_start:gi]\n                    base_indent = re.match(r'[ \\t]*', line_prefix).group(0)\n                    indent = base_indent + '  '",
}
for old, new in replacements.items():
    if old not in source:
        raise RuntimeError(f'Transformer shape changed: expected snippet not found: {old}')
    source = source.replace(old, new)

# Regression probe for the indentation bug that previously generated lines such
# as `return   backgroundColor:`. The transformed source runs this before the
# repository-wide pass and therefore fails fast if named-argument insertion is
# ever broken again.
probe_marker = '\n\nSURFACE_RULES = [\n'
probe = r"""

_probe = '''    return Scaffold(
      body: const SizedBox(),
    );'''
_probe, _probe_count = inject_missing_args(
    _probe,
    'Scaffold(',
    [('backgroundColor', 'WynColors.paper')],
)
_probe_idx = find_code_token(_probe, 'Scaffold(')
_probe_open = _probe_idx + len('Scaffold(') - 1
_probe_close = scan_matching_paren(_probe, _probe_open)
_probe_names = top_level_named_args(_probe[_probe_open + 1:_probe_close])
assert _probe_count == 1
assert 'backgroundColor' in _probe_names
assert 'return   backgroundColor' not in _probe
"""
if probe_marker not in source:
    raise RuntimeError('Transformer shape changed: SURFACE_RULES marker not found')
source = source.replace(probe_marker, probe + probe_marker, 1)

# Keep the base script's post-transform audit enabled now that lookups and
# insertion indentation are safe; dart format and flutter analyze remain
# independent syntax gates.
exec(compile(source, 'tools/apply_all_non_profile_ui.py', 'exec'), {'__name__': '__main__'})

# The base pass may inspect a file that already has every desired argument and
# therefore add the shared color import without ultimately needing it. Remove
# only imports that are provably unused after the complete transform. Profile,
# hidden Pop, and the Founder-final Drop Detail exclusion stay untouched.
color_import = "import 'package:wyn/core/design/wyn_colors.dart';\n"
features = Path('app/lib/features')
for path in features.rglob('*.dart'):
    if 'profile' in path.parts or 'pop' in path.parts:
        continue
    if path.as_posix() == 'app/lib/features/drop/presentation/drop_detail_screen.dart':
        continue
    text = path.read_text()
    if color_import not in text:
        continue
    without_import = text.replace(color_import, '', 1)
    if 'WynColors.' not in without_import:
        path.write_text(without_import)

# WYN-141 Founder Final intentionally superseded the older Post Detail TSX
# contract: the plain-language _buildStatLine was removed, engagement counts
# moved into the focused action bar, detailed metrics moved behind the
# "ดูกิจกรรม" row, and the visible action/composer icons became rounded.
# The product source already implements that approved contract. Keep regression
# coverage strict by updating the stale assertions to test the new UI rather
# than restoring obsolete visuals or skipping the behavior tests.
test_path = Path('app/test/drop_detail_screen_test.dart')
test_text = test_path.read_text()

def replace_exact(old: str, new: str, expected: int = 1) -> None:
    global test_text
    actual = test_text.count(old)
    if actual != expected:
        raise RuntimeError(
            f'Drop Detail test contract changed: expected {expected} occurrence(s) of {old!r}, found {actual}'
        )
    test_text = test_text.replace(old, new)

replace_exact(
    "expect(find.text('3 ถูกใจ'), findsOneWidget);",
    "expect(\n      find.bySemanticsLabel(RegExp('ถูกใจ 3 คน กดเพื่อถูกใจ')),\n      findsOneWidget,\n    );",
)
replace_exact(
    "expect(find.text('4 ถูกใจ'), findsOneWidget);",
    "expect(\n      find.bySemanticsLabel(RegExp('ถูกใจแล้ว 4 คน กดเพื่อเลิกถูกใจ')),\n      findsOneWidget,\n    );",
)
replace_exact(
    "await tester.tap(find.byIcon(Icons.send));",
    "await tester.tap(find.byIcon(Icons.send_rounded));",
)
replace_exact(
    "await tester.tap(find.byIcon(Icons.close));",
    "await tester.tap(find.byIcon(Icons.close_rounded));",
)

old_view_assert = "expect(find.text('6 การเข้าชม'), findsOneWidget);"
new_view_assert = """final activityEntry = find.text('ดูกิจกรรม');
      await tester.ensureVisible(activityEntry);
      await tester.pumpAndSettle();
      await tester.tap(activityEntry);
      await tester.pumpAndSettle();
      expect(find.text('การเข้าชม'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);"""
replace_exact(old_view_assert, new_view_assert, expected=2)

old_semantics_assert = """expect(
        find.bySemanticsLabel(RegExp('เข้าชมแล้ว 43 ครั้ง')),
        findsOneWidget,
      );"""
new_semantics_assert = """final activityEntry = find.text('ดูกิจกรรม');
      await tester.ensureVisible(activityEntry);
      await tester.pumpAndSettle();
      await tester.tap(activityEntry);
      await tester.pumpAndSettle();
      expect(find.text('การเข้าชม'), findsOneWidget);
      expect(find.text('43'), findsOneWidget);"""
replace_exact(old_semantics_assert, new_semantics_assert)

# Both audience tests must look for the actual Founder-final ReDrop glyph.
# Updating both is important: otherwise the hidden-state test would pass for
# the wrong reason simply because it searched for the retired square icon.
replace_exact('find.byIcon(Icons.repeat)', 'find.byIcon(Icons.repeat_rounded)', expected=2)

test_path.write_text(test_text)
