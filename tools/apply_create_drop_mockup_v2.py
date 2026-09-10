from pathlib import Path

# Apply the approved visual patch first.
exec(
    compile(
        Path('tools/apply_create_drop_mockup.py').read_text(),
        'tools/apply_create_drop_mockup.py',
        'exec',
    ),
    {'__name__': '__main__'},
)

path = Path('app/lib/features/drop/presentation/create_drop_screen.dart')
text = path.read_text()

# Keep poll controls reachable on short viewports. The editor still occupies
# the available blank area because it lives inside Expanded/scroll content;
# minLines does not need to manufacture that whitespace.
if text.count('minLines: 6,') != 1:
    raise RuntimeError('expected one composer minLines anchor')
text = text.replace('minLines: 6,', 'minLines: 2,', 1)

# Preserve the established Draft glyph contract while retaining the new
# centered header treatment from the mockup.
if text.count('Icons.edit_outlined') < 2:
    raise RuntimeError('expected draft icon anchors')
text = text.replace('Icons.edit_outlined', 'Icons.edit_note_outlined', 2)

# Slightly shorter attachment tiles keep the approved four-card panel useful
# on compact phones and when poll controls extend vertically.
needle = 'child: Ink(\n            height: 82,'
if needle not in text:
    raise RuntimeError('toolbar tile height anchor missing')
text = text.replace(needle, 'child: Ink(\n            height: 72,', 1)

path.write_text(text)
