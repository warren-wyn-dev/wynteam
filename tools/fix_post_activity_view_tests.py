from pathlib import Path

path = Path('app/test/drop_detail_screen_test.dart')
text = path.read_text()

old_six = """      final activityEntry = find.text('ดูกิจกรรม');
      await tester.ensureVisible(activityEntry);
      await tester.pumpAndSettle();
      await tester.tap(activityEntry);
      await tester.pumpAndSettle();
      expect(find.text('การเข้าชม'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);"""
new_hidden = """      final activityEntry = find.text('ดูกิจกรรม');
      await tester.ensureVisible(activityEntry);
      await tester.pumpAndSettle();
      await tester.tap(activityEntry);
      await tester.pumpAndSettle();
      expect(find.text('การเข้าชม'), findsNothing);"""
if text.count(old_six) != 2:
    raise SystemExit(f'expected two old view-count activity assertions, found {text.count(old_six)}')
text = text.replace(old_six, new_hidden)

old_43 = """      final activityEntry = find.text('ดูกิจกรรม');
      await tester.ensureVisible(activityEntry);
      await tester.pumpAndSettle();
      await tester.tap(activityEntry);
      await tester.pumpAndSettle();
      expect(find.text('การเข้าชม'), findsOneWidget);
      expect(find.text('43'), findsOneWidget);"""
if old_43 not in text:
    raise SystemExit('old 43-view activity assertion not found')
text = text.replace(old_43, new_hidden, 1)

old_title = """    testWidgets(
        'the view count has a Semantics label -- a gap the Pop equivalent '
        '(HomePopCard) has always had, deliberately not repeated here '
        '(Design spec, Accessibility)', (tester) async {"""
new_title = """    testWidgets(
        'view recording stays active while post activity omits views',
        (tester) async {"""
if old_title not in text:
    raise SystemExit('old view semantics test title not found')
text = text.replace(old_title, new_title, 1)

old_comment_1 = """      // The optimistic view-count bump is visible immediately, before
      // the (fake, network-less) RPC call resolves. Lives in the stat
      // line now (\"6 การเข้าชม\"), not a bare number -- see
      // DropDetailScreen._buildStatLine.
"""
text = text.replace(
    old_comment_1,
    "      // View recording remains behavioral state; post activity intentionally omits views.\n",
    1,
)
old_comment_2 = """      // Optimistically bumped the same as any other viewer -- 5 -> 6
      // (stat line, see DropDetailScreen._buildStatLine).
"""
text = text.replace(
    old_comment_2,
    "      // The author's own View is still recorded, but it is not an activity tab.\n",
    1,
)

comment_start = text.find('      // WYN-038 QA fix:')
if comment_start == -1:
    raise SystemExit('old view semantics comment start not found')
activity_start = text.find("      final activityEntry = find.text('ดูกิจกรรม');", comment_start)
if activity_start == -1:
    raise SystemExit('activity assertion after view semantics comment not found')
text = (
    text[:comment_start]
    + "      // Activity is intentionally limited to Likes and ReDrops; Views stay analytics-only.\n"
    + text[activity_start:]
)

path.write_text(text)
