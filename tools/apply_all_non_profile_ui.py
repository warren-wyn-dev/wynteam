from pathlib import Path
import re

ROOT = Path('app/lib')
FEATURES = ROOT / 'features'
EXCLUDED_PARTS = {'profile', 'pop'}


def is_target(path: Path) -> bool:
    parts = set(path.parts)
    if 'presentation' not in parts:
        return False
    if 'profile' in parts or 'pop' in parts:
        return False
    return path.suffix == '.dart'


def ensure_color_import(text: str) -> str:
    if 'wyn_colors.dart' in text:
        return text
    marker = "import 'package:flutter/material.dart';\n"
    if marker in text:
        return text.replace(marker, marker + "import 'package:wyn/core/design/wyn_colors.dart';\n", 1)
    raise RuntimeError('Material import not found')


def scan_matching_paren(text: str, open_idx: int) -> int:
    depth = 0
    i = open_idx
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
        if ch in ('\"', "'"):
            if text[i:i+3] == ch * 3:
                quote = ch
                triple = True
                i += 3
            else:
                quote = ch
                i += 1
            continue
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise RuntimeError('Unbalanced call parentheses')


def top_level_named_args(body: str) -> set[str]:
    names = set()
    par = bra = cur = 0
    start = 0
    quote = None
    line_comment = False
    block_comment = 0

    def consume(segment: str):
        m = re.match(r'\s*([A-Za-z_]\w*)\s*:', segment, re.S)
        if m:
            names.add(m.group(1))

    i = 0
    while i < len(body):
        ch = body[i]
        nxt = body[i:i+2]
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
        if ch in ('\"', "'"):
            quote = ch
        elif ch == '(':
            par += 1
        elif ch == ')':
            par -= 1
        elif ch == '[':
            bra += 1
        elif ch == ']':
            bra -= 1
        elif ch == '{':
            cur += 1
        elif ch == '}':
            cur -= 1
        elif ch == ',' and par == bra == cur == 0:
            consume(body[start:i])
            start = i + 1
        i += 1
    consume(body[start:])
    return names


def inject_missing_args(text: str, token: str, desired: list[tuple[str, str]]) -> tuple[str, int]:
    changed = 0
    cursor = 0
    while True:
        idx = text.find(token, cursor)
        if idx < 0:
            break
        open_idx = idx + len(token) - 1
        close_idx = scan_matching_paren(text, open_idx)
        body = text[open_idx + 1:close_idx]
        names = top_level_named_args(body)
        missing = [(name, value) for name, value in desired if name not in names]
        if missing:
            line_start = text.rfind('\n', 0, idx) + 1
            base_indent = text[line_start:idx]
            call_indent = base_indent + '  '
            injection = ''.join(f'\n{call_indent}{name}: {value},' for name, value in missing)
            text = text[:open_idx + 1] + injection + text[open_idx + 1:]
            delta = len(injection)
            close_idx += delta
            changed += 1
        cursor = close_idx + 1
    return text, changed


SURFACE_RULES = [
    ('Scaffold(', [
        ('backgroundColor', 'WynColors.paper'),
    ]),
    ('AppBar(', [
        ('backgroundColor', 'WynColors.paper'),
        ('foregroundColor', 'WynColors.ink'),
        ('surfaceTintColor', 'WynColors.paper'),
        ('elevation', '0'),
        ('scrolledUnderElevation', '0'),
        ('centerTitle', 'true'),
    ]),
    ('TabBar(', [
        ('labelColor', 'WynColors.ink'),
        ('unselectedLabelColor', 'WynColors.graphite'),
        ('indicatorColor', 'WynColors.ink'),
        ('indicatorWeight', '2'),
        ('dividerColor', 'WynColors.hairline'),
    ]),
    ('AlertDialog(', [
        ('backgroundColor', 'WynColors.paper'),
        ('surfaceTintColor', 'WynColors.paper'),
    ]),
    ('SimpleDialog(', [
        ('backgroundColor', 'WynColors.paper'),
        ('surfaceTintColor', 'WynColors.paper'),
    ]),
    ('Card(', [
        ('color', 'WynColors.paper'),
        ('surfaceTintColor', 'WynColors.paper'),
        ('elevation', '0'),
    ]),
    ('showModalBottomSheet<', [
        ('backgroundColor', 'WynColors.paper'),
        ('useSafeArea', 'true'),
    ]),
]

# Handle non-generic showModalBottomSheet( calls separately. Keep global sheet
# changes layout-neutral: forcing a drag handle increases sheet height and can
# push actions below the tappable viewport on compact screens.
BOTTOM_SHEET_RULE = [
    ('backgroundColor', 'WynColors.paper'),
    ('useSafeArea', 'true'),
]

files = sorted(p for p in FEATURES.rglob('*.dart') if is_target(p))
screens = sorted(p for p in files if p.name.endswith('_screen.dart'))
changed_files = []
reviewed_files = []
rule_counts = {token: 0 for token, _ in SURFACE_RULES}
rule_counts['showModalBottomSheet('] = 0

for path in files:
    original = path.read_text()
    text = original
    uses_surface = any(token in text for token, _ in SURFACE_RULES) or 'showModalBottomSheet(' in text
    if uses_surface:
        text = ensure_color_import(text)

    for token, desired in SURFACE_RULES:
        if token not in text:
            continue
        if token == 'showModalBottomSheet<':
            search = 0
            while True:
                gi = text.find('showModalBottomSheet<', search)
                if gi < 0:
                    break
                oi = text.find('>(', gi)
                if oi < 0:
                    raise RuntimeError(f'{path}: malformed generic bottom sheet call')
                open_idx = oi + 1
                close_idx = scan_matching_paren(text, open_idx)
                body = text[open_idx + 1:close_idx]
                names = top_level_named_args(body)
                missing = [(n, v) for n, v in desired if n not in names]
                if missing:
                    line_start = text.rfind('\n', 0, gi) + 1
                    indent = text[line_start:gi] + '  '
                    injection = ''.join(f'\n{indent}{n}: {v},' for n, v in missing)
                    text = text[:open_idx + 1] + injection + text[open_idx + 1:]
                    close_idx += len(injection)
                    rule_counts[token] += 1
                search = close_idx + 1
            continue
        text, count = inject_missing_args(text, token, desired)
        rule_counts[token] += count

    text, count = inject_missing_args(text, 'showModalBottomSheet(', BOTTOM_SHEET_RULE)
    rule_counts['showModalBottomSheet('] += count

    if text != original:
        path.write_text(text)
        changed_files.append(path)
    else:
        reviewed_files.append(path)

violations = []
for path in screens:
    text = path.read_text()
    for token, required in [
        ('Scaffold(', {'backgroundColor'}),
        ('AppBar(', {'backgroundColor', 'foregroundColor', 'surfaceTintColor', 'elevation', 'scrolledUnderElevation', 'centerTitle'}),
    ]:
        cursor = 0
        while True:
            idx = text.find(token, cursor)
            if idx < 0:
                break
            oi = idx + len(token) - 1
            ci = scan_matching_paren(text, oi)
            names = top_level_named_args(text[oi + 1:ci])
            missing = sorted(required - names)
            if missing:
                violations.append(f'{path}: {token[:-1]} missing {missing}')
            cursor = ci + 1

if violations:
    raise RuntimeError('Non-profile UI audit failed:\n' + '\n'.join(violations))

for protected in [FEATURES / 'profile', FEATURES / 'pop']:
    if not protected.exists():
        raise RuntimeError(f'Protected feature path missing: {protected}')

report = Path('.wyn/docs/qa/non-profile-system-ui-audit.md')
report.parent.mkdir(parents=True, exist_ok=True)
report.write_text(
    '# Non-profile system UI audit\n\n'
    'This generated audit belongs to the approved all-pages UX/UI pass.\n\n'
    f'- Presentation Dart files reviewed: {len(files)}\n'
    f'- Route-level `*_screen.dart` files reviewed: {len(screens)}\n'
    f'- Files changed by the system pass: {len(changed_files)}\n'
    f'- Files already compliant / no chrome primitive: {len(reviewed_files)}\n'
    '- Protected and intentionally untouched: `app/lib/features/profile/**`\n'
    '- Hidden and intentionally not resurfaced: `app/lib/features/pop/**`\n\n'
    '## Chrome rules\n\n'
    '- White/paper page surfaces unless a screen already owns an explicit special surface.\n'
    '- Ink foreground, zero-elevation app bars, no Material tint drift.\n'
    '- Ink/graphite/hairline tab language shared with the approved Profile.\n'
    '- Flat cards and quiet paper dialogs.\n'
    '- Safe-area paper bottom sheets without globally forcing extra vertical chrome.\n\n'
    '## Changed files\n\n' +
    ''.join(f'- `{p.as_posix()}`\n' for p in changed_files) +
    '\n## Reviewed without source changes\n\n' +
    ''.join(f'- `{p.as_posix()}`\n' for p in reviewed_files) +
    '\n## Rule applications\n\n' +
    ''.join(f'- `{k}`: {v}\n' for k, v in rule_counts.items())
)

print(f'Reviewed {len(files)} presentation files / {len(screens)} screens')
print(f'Changed {len(changed_files)} files')
for p in changed_files:
    print(p)