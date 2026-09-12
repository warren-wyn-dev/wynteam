from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


card = Path('app/lib/features/home/presentation/widgets/home_drop_card.dart')
text = card.read_text()

text = replace_once(
    text,
    """          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space4),""",
    """          padding: const EdgeInsets.fromLTRB(
            0,
            WynSpacing.space2,
            0,
            WynSpacing.space4,
          ),""",
    'card top padding',
)

start_marker = """                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.authorNameOrUsername,"""
end_marker = """                                    ],
                                  ),
                                ),
                              ),
                              // WYNOSHomeSpec.md 4.6:"""
start = text.find(start_marker)
if start == -1:
    raise SystemExit('author/time block start not found')
end = text.find(end_marker, start)
if end == -1:
    raise SystemExit('author/time block end not found')

replacement = """                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.authorNameOrUsername,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (item.authorIsVerified) ...[
                                        const SizedBox(width: WynSpacing.space1),
                                        const VerifiedBadge(),
                                      ],
                                      const SizedBox(width: WynSpacing.space2),
                                      Flexible(
                                        child: Text(
                                          item.location != null
                                              ? '${relativeTimeLabel(item.createdAt, now: DateTime.now())} · 📍 ${item.location}'
                                              : relativeTimeLabel(
                                                  item.createdAt,
                                                  now: DateTime.now(),
                                                ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // WYNOSHomeSpec.md 4.6:"""
text = text[:start] + replacement + text[end + len(end_marker):]

text = replace_once(
    text,
    """                                icon: const Icon(Icons.more_vert),""",
    """                                icon: const Icon(Icons.more_horiz),""",
    'horizontal more icon',
)

text = replace_once(
    text,
    """                                  height: WynSpacing.touchTargetMin,""",
    """                                  height: homeCardAvatarDiameter,""",
    'compact header action height',
)

text = replace_once(
    text,
    """                              WynSpacing.space2,
                              homeCardEdgeInset,
                              WynSpacing.space3,""",
    """                              WynSpacing.space1,
                              homeCardEdgeInset,
                              WynSpacing.space3,""",
    'caption top spacing',
)

# Keep the comment accurate after compacting the header.
text = text.replace(
    """                              // WYN-107: pinned to a 44x44 box so the
                              // header row is the height of the name
                              // block plus its own tap target, rather
                              // than IconButton's default 48 -- which,
                              // now that the avatar is a column of its
                              // own beside this row, would push the
                              // name off the avatar's own top line.
                              // Still >= the 44 minimum DS-001 6 sets.""",
    """                              // Compact header: keep the More action
                              // aligned to the 40px avatar so media/caption
                              // can begin closer to the author row. The button
                              // stays 44px wide for a forgiving horizontal
                              // target while its visual row is 40px tall.""",
)

card.write_text(text.rstrip() + '\n')


test = Path('app/test/home_drop_card_overflow_test.dart')
t = test.read_text()
t = replace_once(
    t,
    """HomeFeedItem _item({int likeCount = 0, int commentCount = 0}) => HomeFeedItem(""",
    """HomeFeedItem _item({
  int likeCount = 0,
  int commentCount = 0,
  DateTime? createdAt,
}) =>
    HomeFeedItem(""",
    'test item signature',
)
t = replace_once(
    t,
    """      createdAt: DateTime.now(),""",
    """      createdAt: createdAt ?? DateTime.now(),""",
    'test createdAt injection',
)

insert = r'''

  testWidgets(
      'post header keeps relative time beside the author and uses horizontal more',
      (tester) async {
    final createdAt = DateTime.now().subtract(const Duration(days: 3));
    await _pump(tester, card(_item(createdAt: createdAt)), width: 390);
    await tester.pump();

    final author = find.text('namfah');
    final time = find.text('3 วันที่แล้ว');
    expect(author, findsOneWidget);
    expect(time, findsOneWidget);

    final authorCenter = tester.getCenter(author);
    final timeCenter = tester.getCenter(time);
    expect((authorCenter.dy - timeCenter.dy).abs(), lessThan(3));

    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(tester.takeException(), isNull);
  });
'''
close = t.rfind('\n}')
if close == -1:
    raise SystemExit('test main closing brace not found')
if 'post header keeps relative time beside the author' not in t:
    t = t[:close] + insert + t[close:]

test.write_text(t.rstrip() + '\n')
