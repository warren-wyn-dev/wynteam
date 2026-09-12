from pathlib import Path

p = Path('app/test/hashtag_text_test.dart')
text = p.read_text()
old = """    final hashtagSpan = _spanWithText(tester, '#คำคม');
    expect(hashtagSpan.style?.fontSize, 17.5);
    expect(hashtagSpan.style?.fontWeight, FontWeight.w400);
    expect(hashtagSpan.style?.color, const Color(0xFF1D9BF0));
"""
new = """    final hashtagSpan = _spanWithText(tester, '#คำคม');
    final captionRoot = richTexts[0].text as TextSpan;
    expect(hashtagSpan.style?.fontSize, captionRoot.style?.fontSize);
    expect(hashtagSpan.style?.fontWeight, captionRoot.style?.fontWeight);
    expect(hashtagSpan.style?.color, const Color(0xFF1D9BF0));
"""
if text.count(old) != 1:
    raise SystemExit(f'expected one typography assertion block, found {text.count(old)}')
p.write_text(text.replace(old, new, 1))
