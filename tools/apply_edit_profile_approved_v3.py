from pathlib import Path

# Apply the approved source/database patch first.
exec(
    compile(
        Path('tools/apply_edit_profile_approved_v2.py').read_text(),
        'tools/apply_edit_profile_approved_v2.py',
        'exec',
    ),
    {'__name__': '__main__'},
)

# The approved layout is taller than the old screen, so the bio field is
# below a 600px widget-test viewport. Scroll it into view before tapping;
# this preserves the focus-only counter behaviour the tests are asserting.
test_path = Path('app/test/edit_profile_screen_test.dart')
text = test_path.read_text()
needle = '    await tester.tap(_bioField);'
replacement = (
    '    await tester.ensureVisible(_bioField);\n'
    '    await tester.pumpAndSettle();\n'
    '    await tester.tap(_bioField);'
)
if needle not in text:
    raise RuntimeError('bio tap test anchor missing')
text = text.replace(needle, replacement)
test_path.write_text(text)
