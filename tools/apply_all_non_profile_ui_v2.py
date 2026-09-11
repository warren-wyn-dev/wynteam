from pathlib import Path

source = Path('tools/apply_all_non_profile_ui.py').read_text()

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
# only imports that are provably unused after the complete transform. Profile
# and hidden Pop stay excluded from this cleanup as well.
color_import = "import 'package:wyn/core/design/wyn_colors.dart';\n"
features = Path('app/lib/features')
for path in features.rglob('*.dart'):
    if 'profile' in path.parts or 'pop' in path.parts:
        continue
    text = path.read_text()
    if color_import not in text:
        continue
    without_import = text.replace(color_import, '', 1)
    if 'WynColors.' not in without_import:
        path.write_text(without_import)
