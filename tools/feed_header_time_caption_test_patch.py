from pathlib import Path

p = Path('app/test/home_drop_card_overflow_test.dart')
s = p.read_text()

old = """  testWidgets(\n    'Home feed caption removes visual translation so no phantom gap remains',\n    (tester) async {\n      await _pump(tester, card(_item()), width: 390, asHomeFeed: true);\n      await tester.pump();\n\n      final caption = find.byType(HashtagText);\n      expect(caption, findsOneWidget);\n      expect(\n        find.descendant(of: caption, matching: find.byType(Transform)),\n        findsNothing,\n      );\n      expect(tester.takeException(), isNull);\n    },\n  );\n"""
new = """  testWidgets(\n    'Home feed caption moves 3px closer without moving its layout slot',\n    (tester) async {\n      await _pump(tester, card(_item()), width: 390, asHomeFeed: true);\n      await tester.pump();\n\n      final caption = find.byType(HashtagText);\n      expect(caption, findsOneWidget);\n      final transformFinder = find.ancestor(\n        of: caption,\n        matching: find.byType(Transform),\n      );\n      expect(transformFinder, findsOneWidget);\n      final transform = tester.widget<Transform>(transformFinder);\n      expect(transform.transform.storage[13], -3);\n      expect(tester.takeException(), isNull);\n    },\n  );\n"""
if s.count(old) != 1:
    raise SystemExit('home transform test mismatch')
s = s.replace(old, new, 1)

old = """  testWidgets(\n    'reused HomeDropCard outside Home also has no caption translation',\n    (tester) async {\n      await _pump(tester, card(_item()), width: 390);\n      await tester.pump();\n\n      final caption = find.byType(HashtagText);\n      expect(caption, findsOneWidget);\n      expect(\n        find.descendant(of: caption, matching: find.byType(Transform)),\n        findsNothing,\n      );\n      expect(tester.takeException(), isNull);\n    },\n  );\n"""
new = """  testWidgets(\n    'reused HomeDropCard keeps the same 3px caption nudge',\n    (tester) async {\n      await _pump(tester, card(_item()), width: 390);\n      await tester.pump();\n\n      final caption = find.byType(HashtagText);\n      expect(caption, findsOneWidget);\n      final transformFinder = find.ancestor(\n        of: caption,\n        matching: find.byType(Transform),\n      );\n      expect(transformFinder, findsOneWidget);\n      final transform = tester.widget<Transform>(transformFinder);\n      expect(transform.transform.storage[13], -3);\n      expect(tester.takeException(), isNull);\n    },\n  );\n"""
if s.count(old) != 1:
    raise SystemExit('reused transform test mismatch')
s = s.replace(old, new, 1)

p.write_text(s)
