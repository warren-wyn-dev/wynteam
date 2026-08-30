import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/block/presentation/block_dialogs.dart';

void main() {
  Widget buildTrigger(Future<void> Function(BuildContext) onPressed) => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => onPressed(context),
              child: const Text('open'),
            ),
          ),
        ),
      );

  group('confirmBlock', () {
    testWidgets('shows the username and returns true when confirmed',
        (tester) async {
      bool? result;
      await tester.pumpWidget(buildTrigger((context) async {
        result = await confirmBlock(context, username: 'namfah');
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('บล็อก @namfah?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'บล็อก'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('returns false when cancelled', (tester) async {
      bool? result;
      await tester.pumpWidget(buildTrigger((context) async {
        result = await confirmBlock(context, username: 'namfah');
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'ยกเลิก'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('confirmUnblock', () {
    testWidgets('shows the username and returns true when confirmed',
        (tester) async {
      bool? result;
      await tester.pumpWidget(buildTrigger((context) async {
        result = await confirmUnblock(context, username: 'namfah');
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('เลิกบล็อก @namfah?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'เลิกบล็อก'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('returns false when cancelled', (tester) async {
      bool? result;
      await tester.pumpWidget(buildTrigger((context) async {
        result = await confirmUnblock(context, username: 'namfah');
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
