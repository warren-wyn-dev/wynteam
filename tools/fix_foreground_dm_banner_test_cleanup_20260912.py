from pathlib import Path

p = Path('app/test/push_reliability_controller_test.dart')
text = p.read_text(encoding='utf-8')

old = """    expect(
      tester.getTopLeft(find.byKey(const Key('foreground_dm_banner'))).dy,
      lessThan(80),
    );
  });
"""
new = """    expect(
      tester.getTopLeft(find.byKey(const Key('foreground_dm_banner'))).dy,
      lessThan(80),
    );
    PushReliabilityController.instance.debugDismissForegroundMessage();
    await tester.pump();
  });
"""
if new not in text:
    if old not in text:
        raise SystemExit('missing first banner cleanup anchor')
    text = text.replace(old, new, 1)

old = """    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('ส่งรูปภาพ'), findsOneWidget);
  });
"""
new = """    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('ส่งรูปภาพ'), findsOneWidget);
    PushReliabilityController.instance.debugDismissForegroundMessage();
    await tester.pump();
  });
"""
if new not in text:
    if old not in text:
        raise SystemExit('missing image banner cleanup anchor')
    text = text.replace(old, new, 1)

p.write_text(text, encoding='utf-8')
print('foreground DM timer cleanup applied')
