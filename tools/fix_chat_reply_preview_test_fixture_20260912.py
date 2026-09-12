from pathlib import Path

p = Path('app/test/conversation_screen_test.dart')
text = p.read_text()
old = "          replyPreviewText: 'ข้อความต้นฉบับที่อยู่ไกลมาก',\n"
new = "          replyPreviewText: 'ตัวอย่างข้อความอ้างอิง',\n"
assert text.count(old) == 1, f'expected one fixture match, found {text.count(old)}'
p.write_text(text.replace(old, new, 1))
print('reply preview scroll fixture aligned')
