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
}
for old, new in replacements.items():
    if old not in source:
        raise RuntimeError(f'Transformer shape changed: expected snippet not found: {old}')
    source = source.replace(old, new)

# Keep the base script's post-transform audit enabled now that lookups are
# lexical-safe; dart format and flutter analyze remain independent syntax gates.
exec(compile(source, 'tools/apply_all_non_profile_ui.py', 'exec'), {'__name__': '__main__'})
