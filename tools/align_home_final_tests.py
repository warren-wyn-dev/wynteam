from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_exact(text: str, old: str, new: str, label: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise RuntimeError(f"{label}: expected {expected} matches, got {count}")
    return text.replace(old, new)


home = ROOT / "app/lib/features/home/presentation/home_feed_screen.dart"
text = home.read_text()
text = replace_exact(
    text,
    "                child: Container(\n                  width: 9,\n                  height: 9,",
    "                child: Container(\n                  key: const Key('home_chat_unread_dot'),\n                  width: 9,\n                  height: 9,",
    "unread-dot key",
)
text = replace_exact(
    text,
    "      child: InkWell(\n        onTap: () => _selectFeedMode(mode),",
    "      child: InkWell(\n        key: Key('home_feed_mode_${mode.name}'),\n        onTap: () => _selectFeedMode(mode),",
    "feed-tab key",
)
home.write_text(text)


test_path = ROOT / "app/test/home_feed_screen_test.dart"
test = test_path.read_text()
test = replace_exact(
    test,
    "expect(find.byIcon(Icons.menu), findsOneWidget);\n    await tester.tap(find.byIcon(Icons.menu));",
    "expect(find.byIcon(Icons.menu_rounded), findsOneWidget);\n    await tester.tap(find.byIcon(Icons.menu_rounded));",
    "hamburger icon expectation",
)
test = replace_exact(
    test,
    "expect(find.text('2'), findsOneWidget);",
    "expect(find.byKey(const Key('home_chat_unread_dot')), findsOneWidget);",
    "chat unread visible expectations",
    expected=2,
)
test = replace_exact(
    test,
    "expect(find.text('2'), findsNothing);",
    "expect(find.byKey(const Key('home_chat_unread_dot')), findsNothing);",
    "chat unread cleared expectations",
    expected=2,
)

start_marker = "    for (final width in [360.0, 375.0, 390.0, 414.0, 430.0]) {"
next_group = "  group(\'\"ติดตาม\" (Following) feed mode (WYN-024)\', () {"
start = test.find(start_marker)
end = test.find(next_group, start)
if start < 0 or end < 0:
    raise RuntimeError(f"tab-width regression block not found: start={start}, end={end}")

replacement = r'''    for (final width in [360.0, 375.0, 390.0, 414.0, 430.0]) {
      testWidgets(
          'the approved three-column Home tabs stay fully legible at '
          '${width}px', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildHome(
          mixedFeedHomeRepository,
          dropRepository: sharedDropRepository,
          popRepository: sharedPopRepository,
        ));
        await tester.pumpAndSettle();
        tester.takeException();

        const tabs = <String, String>{
          'forYou': 'สำหรับคุณ',
          'following': 'ติดตาม',
          'fromYourClubs': 'Club',
        };

        for (final entry in tabs.entries) {
          final tabFinder = find.byKey(Key('home_feed_mode_${entry.key}'));
          expect(tabFinder, findsOneWidget);
          final labelFinder = find.descendant(
            of: tabFinder,
            matching: find.text(entry.value),
          );
          expect(labelFinder, findsOneWidget);

          await tester.tap(tabFinder);
          await tester.pumpAndSettle();
          final exception = tester.takeException();
          if (exception != null && exception is! NetworkImageLoadException) {
            fail('Unexpected exception at ${width}px: $exception');
          }

          final renderParagraph =
              tester.renderObject(labelFinder) as RenderParagraph;
          expect(
            renderParagraph.didExceedMaxLines,
            isFalse,
            reason: '"${entry.value}" must remain fully legible at '
                '${width}px in the fixed three-column Home tab row',
          );
        }

        // The final black underline tracks exactly one active segment.
        expect(find.byKey(const Key('active_segment_accent')), findsOneWidget);
      });
    }
  });

'''

test = test[:start] + replacement + test[end:]
test_path.write_text(test)
print("Aligned Home final UI tests with approved visual behavior.")
