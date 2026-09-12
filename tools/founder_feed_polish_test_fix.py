from pathlib import Path

p = Path('app/test/hashtag_text_test.dart')
text = p.read_text()
old = "style: TextStyle(fontSize: 17.5, height: 1.32),"
new = "style: TextStyle(\n              fontSize: 17.5,\n              height: 1.32,\n              fontWeight: FontWeight.w400,\n            ),"
count = text.count(old)
if count != 2:
    raise SystemExit(f'expected two compact feed test styles, found {count}')
p.write_text(text.replace(old, new))
