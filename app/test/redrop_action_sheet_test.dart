import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/design/wyn_colors.dart';
import 'package:wyn/core/design/wyn_spacing.dart';
import 'package:wyn/core/widgets/action_sheet_row.dart';
import 'package:wyn/features/drop/presentation/widgets/redrop_action_sheet.dart';

/// Beta4 §6 -- the ReDrop / Quote sheet.
///
/// The rule being guarded here is "ห้ามใช้ Emoji เป็น Icon จริง ให้ใช้
/// Icon/SVG System ของ WYNOS". These two rows are the entry point to
/// the most consequential action a feed card exposes, and they were the
/// only two in the product that the icon system's rules could not reach
/// -- an emoji paints in the platform's own colours, sits on the text
/// baseline, sizes off the font, and has no pressed/active/disabled
/// rendering to give.
///
/// The sheet is tested directly (rather than only through the two
/// screens that open it) because it is now one shared function; the
/// screens' own tests cover that each still reaches it.
void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    required bool isRedropped,
    VoidCallback? onToggleRedrop,
    VoidCallback? onQuoteRedrop,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showRedropSheet(
                context,
                isRedropped: isRedropped,
                onToggleRedrop: onToggleRedrop ?? () {},
                onQuoteRedrop: onQuoteRedrop ?? () {},
              ),
              child: const Text('เปิด'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers exactly two rows, built from the shared action sheet',
      (tester) async {
    await openSheet(tester, isRedropped: false);

    expect(find.byType(ActionSheetBody), findsOneWidget);
    expect(find.byType(ActionSheetRow), findsNWidgets(2));
    expect(find.text('รีโพสต์'), findsOneWidget);
    expect(find.text('อ้างอิง'), findsOneWidget);
  });

  testWidgets('uses real icons, never emoji', (tester) async {
    await openSheet(tester, isRedropped: false);

    expect(find.byIcon(Icons.repeat), findsOneWidget);
    expect(find.byIcon(Icons.format_quote), findsOneWidget);
    expect(find.textContaining('🔄'), findsNothing);
    expect(find.textContaining('💬'), findsNothing);
  });

  testWidgets(
      'both icons share one size and colour -- the same 18px ink every '
      'other action row in the app uses', (tester) async {
    await openSheet(tester, isRedropped: false);

    for (final icon in [Icons.repeat, Icons.format_quote]) {
      final widget = tester.widget<Icon>(find.byIcon(icon));
      expect(widget.size, 18, reason: '$icon size');
      expect(widget.color, WynColors.ink, reason: '$icon colour');
    }
  });

  testWidgets(
      'the ReDrop row keeps its icon in the undo state -- only the label '
      'changes', (tester) async {
    // The pre-Beta4 version showed '🔄' on the ReDrop label and nothing
    // at all on "ยกเลิกรีโพสต์", so the row visibly changed shape
    // depending on the viewer's own ReDrop state.
    await openSheet(tester, isRedropped: true);

    expect(find.text('ยกเลิกรีโพสต์'), findsOneWidget);
    expect(find.text('รีโพสต์'), findsNothing);
    expect(find.byIcon(Icons.repeat), findsOneWidget);
    expect(find.byType(ActionSheetRow), findsNWidgets(2));
  });

  testWidgets('each row has a real tap target, not a text-sized one',
      (tester) async {
    await openSheet(tester, isRedropped: false);

    for (final key in [
      const Key('redrop_sheet_toggle_row'),
      const Key('redrop_sheet_quote_row'),
    ]) {
      expect(
        tester.getSize(find.byKey(key)).height,
        greaterThanOrEqualTo(WynSpacing.touchTargetMin),
        reason: '$key height',
      );
    }
  });

  testWidgets('tapping a row dismisses the sheet and then runs its action',
      (tester) async {
    var toggled = 0;
    var quoted = 0;
    await openSheet(
      tester,
      isRedropped: false,
      onToggleRedrop: () => toggled++,
      onQuoteRedrop: () => quoted++,
    );

    await tester.tap(find.text('รีโพสต์'));
    await tester.pumpAndSettle();

    expect(toggled, 1);
    expect(quoted, 0);
    // Dismissed first, so the action never runs behind a sheet still on
    // screen (QuoteRedropScreen in particular is pushed by its row).
    expect(find.byType(ActionSheetBody), findsNothing);
  });

  testWidgets('the quote row runs the quote action', (tester) async {
    var toggled = 0;
    var quoted = 0;
    await openSheet(
      tester,
      isRedropped: false,
      onToggleRedrop: () => toggled++,
      onQuoteRedrop: () => quoted++,
    );

    await tester.tap(find.text('อ้างอิง'));
    await tester.pumpAndSettle();

    expect(quoted, 1);
    expect(toggled, 0);
  });
}
