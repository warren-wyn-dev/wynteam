from pathlib import Path

path = Path('app/test/qa_round2_ui_regression_test.dart')
text = path.read_text()
old = """    'QA-R2-21 WYN-107: the compact Home card opens its content column at '\n    'x=80 on a 390 screen and the photo row still bleeds to the edge',"""
new = """    'QA-R2-21 WYN-107: the approved compact Home card opens its content '\n    'column at x=68 on a 390 screen and the photo row still bleeds to the edge',"""
if text.count(old) != 1:
    raise SystemExit(f'expected one QA-R2-21 title, found {text.count(old)}')
text = text.replace(old, new, 1)
old_expect = '      expect(row.left, closeTo(80.0, 0.5));'
new_expect = '      expect(row.left, closeTo(68.0, 0.5));'
if text.count(old_expect) != 1:
    raise SystemExit(f'expected one x=80 assertion, found {text.count(old_expect)}')
text = text.replace(old_expect, new_expect, 1)
path.write_text(text)
