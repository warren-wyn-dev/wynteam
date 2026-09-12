from pathlib import Path


def one(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected 1 match, found {count}")
    p.write_text(text.replace(old, new, 1))


one(
    "app/lib/core/widgets/hashtag_text.dart",
    "    final hashtagStyle = baseStyle.copyWith(\n      color: _hashtagLinkBlue,\n      fontWeight: FontWeight.w600,\n    );\n",
    "    final hashtagStyle = baseStyle.copyWith(\n      color: _hashtagLinkBlue,\n    );\n",
)

# Replace the single RichText render block with a reusable builder, then split
# compact feed captions at a hashtag line and give that boundary exactly 4px.
p = Path("app/lib/core/widgets/hashtag_text.dart")
text = p.read_text()
start = text.index("    final spans = <InlineSpan>[];\n")
end = text.index("\n    );\n  }\n}", start) + len("\n    );")
new_render = '''    Text buildRichText(String text) {
      final spans = <InlineSpan>[];
      var lastEnd = 0;
      for (final token in _findTokens(text)) {
        if (token.start < lastEnd) continue;
        if (token.start > lastEnd) {
          _appendPlainText(spans, text.substring(lastEnd, token.start), baseStyle);
        }

        final recognizer = TapGestureRecognizer()
          ..onTap = token.kind == _SpanKind.hashtag
              ? () => _openHashtagFeed(token.value)
              : () => _openMentionedProfile(token.value);
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: text.substring(token.start, token.end),
          style: token.kind == _SpanKind.hashtag ? hashtagStyle : mentionStyle,
          recognizer: recognizer,
        ));
        lastEnd = token.end;
      }
      if (lastEnd < text.length) {
        _appendPlainText(spans, text.substring(lastEnd), baseStyle);
      }

      return Text.rich(
        TextSpan(style: baseStyle, children: spans),
        maxLines: widget.maxLines,
        overflow: widget.overflow ?? TextOverflow.clip,
        textHeightBehavior: compactFeedCard
            ? const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              )
            : null,
      );
    }

    if (compactFeedCard && widget.maxLines == null) {
      final boundary = RegExp(r'\\r?\\n(?=[ \\t]*#)').firstMatch(displayText);
      if (boundary != null) {
        final caption = displayText.substring(0, boundary.start).trimRight();
        final hashtagBlock = displayText.substring(boundary.end).trimLeft();
        if (caption.isNotEmpty && hashtagBlock.isNotEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildRichText(caption),
              const SizedBox(
                key: ValueKey<String>('feed_caption_hashtag_gap'),
                height: 4,
              ),
              buildRichText(hashtagBlock),
            ],
          );
        }
      }
    }

    return buildRichText(displayText);'''
p.write_text(text[:start] + new_render + text[end:])

# Keep the 44px interaction targets, but when the action row is the final row,
# remove the extra card-bottom pad. A 24px glyph inside the 44px target leaves
# ~10px visible space to the divider, matching the approved brief.
for card in [
    "app/lib/features/home/presentation/widgets/home_drop_card.dart",
    "app/lib/features/home/presentation/widgets/home_pop_card.dart",
]:
    one(
        card,
        "          padding: const EdgeInsets.fromLTRB(\n            0,\n            WynSpacing.space3,\n            0,\n            WynSpacing.space2,\n          ),\n",
        "          padding: EdgeInsets.fromLTRB(\n            0,\n            WynSpacing.space3,\n            0,\n            item.topReply == null ? 0 : WynSpacing.space2,\n          ),\n",
    )

    p = Path(card)
    text = p.read_text()
    old_name = "                                      Flexible(\n                                        child: Text(\n                                          item.authorNameOrUsername,\n"
    new_name = "                                      Expanded(\n                                        flex: 3,\n                                        child: Text(\n                                          item.authorNameOrUsername,\n                                          maxLines: 1,\n                                          softWrap: false,\n"
    if text.count(old_name) != 1:
        raise SystemExit(f"{card}: author pattern count {text.count(old_name)}")
    text = text.replace(old_name, new_name, 1)

    old_date = "                                      Flexible(\n                                        child: Text(\n"
    new_date = "                                      Flexible(\n                                        flex: 2,\n                                        child: Text(\n"
    if text.count(old_date) != 1:
        raise SystemExit(f"{card}: date pattern count {text.count(old_date)}")
    p.write_text(text.replace(old_date, new_date, 1))

# Tests support the two-RichText compact rendering and lock the brief:
# 4px caption->hashtag gap and identical font size/weight with color-only change.
p = Path("app/test/hashtag_text_test.dart")
text = p.read_text()
a = text.index("TextSpan _spanWithText")
b = text.index("\n}\n\n/// Finds", a) + 2
helper = '''TextSpan _spanWithText(WidgetTester tester, String text) {
  TextSpan? found;
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    final rootSpan = richText.text as TextSpan;
    rootSpan.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span;
        return false;
      }
      return true;
    });
    if (found != null) break;
  }
  expect(found, isNotNull, reason: 'no span found for "$text"');
  return found!;
}'''
text = text[:a] + helper + text[b:]

old = '''    final richText = tester.widget<RichText>(find.byType(RichText).first);
    expect(
      richText.text.toPlainText(),
      'ชีวิตไม่ต้องสมบูรณ์แบบ\\n#คำคม #ชีวิตดีๆ #WYNOS',
    );
'''
new = '''    final richTexts = tester.widgetList<RichText>(find.byType(RichText)).toList();
    expect(richTexts, hasLength(2));
    expect(richTexts[0].text.toPlainText(), 'ชีวิตไม่ต้องสมบูรณ์แบบ');
    expect(richTexts[1].text.toPlainText(), '#คำคม #ชีวิตดีๆ #WYNOS');
    final gap = find.byKey(const ValueKey<String>('feed_caption_hashtag_gap'));
    expect(gap, findsOneWidget);
    expect(tester.getSize(gap).height, 4);

    final hashtagSpan = _spanWithText(tester, '#คำคม');
    expect(hashtagSpan.style?.fontSize, 17.5);
    expect(hashtagSpan.style?.fontWeight, FontWeight.w400);
    expect(hashtagSpan.style?.color, const Color(0xFF1D9BF0));
'''
if text.count(old) != 1:
    raise SystemExit("compact hashtag test pattern mismatch")
text = text.replace(old, new, 1)

old = '''    final richText = tester.widget<RichText>(find.byType(RichText).first);
    expect(richText.text.toPlainText(), 'ข้อความ\\n#WYN');
'''
new = '''    final richTexts = tester.widgetList<RichText>(find.byType(RichText)).toList();
    expect(richTexts, hasLength(2));
    expect(richTexts[0].text.toPlainText(), 'ข้อความ');
    expect(richTexts[1].text.toPlainText(), '#WYN');
'''
if text.count(old) != 1:
    raise SystemExit("trailing whitespace test pattern mismatch")
p.write_text(text.replace(old, new, 1))
