import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/action_sheet_row.dart';

/// 21-report-block.tsx's `MainSheet` row shape (icon, label, chevron)
/// -- now shared by every "..." action sheet in the app (Drop/Pop/Club
/// post/comment, Profile, Chat) instead of each building its own
/// `ListTile`-based menu.
void main() {
  testWidgets('renders the icon, label, and a trailing chevron',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActionSheetRow(
          icon: Icons.flag_outlined,
          label: 'รายงานโพสต์นี้',
          onTap: () {},
        ),
      ),
    ));

    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    expect(find.text('รายงานโพสต์นี้'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('tapping the row calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActionSheetRow(
          icon: Icons.block,
          label: 'บล็อกผู้ใช้นี้',
          onTap: () => tapped = true,
        ),
      ),
    ));

    await tester.tap(find.text('บล็อกผู้ใช้นี้'));
    expect(tapped, isTrue);
  });

  testWidgets('an explicit color overrides the default ink color for a '
      'destructive row', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActionSheetRow(
          icon: Icons.delete_outline,
          label: 'ลบ',
          color: Colors.red,
          onTap: () {},
        ),
      ),
    ));

    final icon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
    expect(icon.color, Colors.red);
  });

  group('ActionSheetBody', () {
    testWidgets('shows a drag handle and a divider between rows, but not '
        'after the last one', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActionSheetBody(rows: [
            ActionSheetRow(icon: Icons.flag_outlined, label: 'รายงาน', onTap: () {}),
            ActionSheetRow(icon: Icons.block, label: 'บล็อก', onTap: () {}),
          ]),
        ),
      ));

      expect(find.byType(SheetDragHandle), findsOneWidget);
      expect(find.byType(ActionSheetRow), findsNWidgets(2));
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('a single row shows no divider at all', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActionSheetBody(rows: [
            ActionSheetRow(icon: Icons.flag_outlined, label: 'รายงาน', onTap: () {}),
          ]),
        ),
      ));

      expect(find.byType(Divider), findsNothing);
    });
  });
}
