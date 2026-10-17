import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/adaptive/adaptive.dart';
import 'package:zoky_app/core/adaptive/zoky_icons.dart';

import 'support/pump_zoky.dart';

/// Runs [body] with defaultTargetPlatform overridden, always restoring it
/// before the test ends (the framework checks it is unset afterwards).
Future<void> onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Widget _launcher(void Function(BuildContext) onPressed) {
  return Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () => onPressed(context),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  group('iOS (Cupertino)', () {
    testWidgets('isCupertino and adaptive icons', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        late BuildContext captured;
        await pumpZokyWidget(
          tester,
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        );
        expect(isCupertino(captured), isTrue);
        expect(ZokyIcons.back(captured), CupertinoIcons.back);
        expect(ZokyIcons.share(captured), CupertinoIcons.share);
        expect(ZokyIcons.more(captured), CupertinoIcons.ellipsis);
      });
    });

    testWidgets('alert dialog is CupertinoAlertDialog', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        String? result;
        await pumpZokyWidget(
          tester,
          _launcher((context) async {
            result = await showZokyAlertDialog<String>(
              context: context,
              title: 'ล้างตะกร้า?',
              message: 'เมนูในตะกร้าจะถูกลบทั้งหมด',
              actions: const [
                ZokyDialogAction(label: 'ยกเลิก', value: 'cancel'),
                ZokyDialogAction(
                  label: 'ล้างตะกร้า',
                  value: 'clear',
                  isDestructive: true,
                ),
              ],
            );
          }),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        final destructive = tester.widget<CupertinoDialogAction>(
          find.widgetWithText(CupertinoDialogAction, 'ล้างตะกร้า'),
        );
        expect(destructive.isDestructiveAction, isTrue);
        await tester.tap(find.text('ล้างตะกร้า'));
        await tester.pumpAndSettle();
        expect(result, 'clear');
      });
    });

    testWidgets('action sheet is CupertinoActionSheet with cancel', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pumpZokyWidget(
          tester,
          _launcher((context) {
            showZokyActionSheet<int>(
              context: context,
              title: 'เลือกที่อยู่',
              actions: const [
                ZokySheetAction(label: 'บ้าน', value: 1),
                ZokySheetAction(label: 'ที่ทำงาน', value: 2),
              ],
            );
          }),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoActionSheet), findsOneWidget);
        expect(find.text('ยกเลิก'), findsOneWidget);
        expect(find.byType(ListTile), findsNothing);
      });
    });

    testWidgets('date picker is a CupertinoDatePicker wheel', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pumpZokyWidget(
          tester,
          _launcher((context) {
            showZokyDatePicker(
              context: context,
              initialDate: DateTime(2026, 10, 17),
              firstDate: DateTime(2026, 10, 1),
              lastDate: DateTime(2026, 12, 31),
            );
          }),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoDatePicker), findsOneWidget);
        expect(find.byType(DatePickerDialog), findsNothing);
        expect(find.text('เสร็จ'), findsOneWidget);
      });
    });

    testWidgets('switch is CupertinoSwitch', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pumpZokyWidget(
          tester,
          ZokySwitch(value: true, onChanged: (_) {}),
        );
        expect(find.byType(CupertinoSwitch), findsOneWidget);
        expect(find.byType(Switch), findsNothing);
      });
    });
  });

  group('Android (Material)', () {
    testWidgets('isCupertino and adaptive icons', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        late BuildContext captured;
        await pumpZokyWidget(
          tester,
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        );
        expect(isCupertino(captured), isFalse);
        expect(ZokyIcons.back(captured), Icons.arrow_back);
        expect(ZokyIcons.share(captured), Icons.share);
        expect(ZokyIcons.more(captured), Icons.more_vert);
      });
    });

    testWidgets('alert dialog is M3 AlertDialog', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        String? result;
        await pumpZokyWidget(
          tester,
          _launcher((context) async {
            result = await showZokyAlertDialog<String>(
              context: context,
              title: 'ล้างตะกร้า?',
              actions: const [
                ZokyDialogAction(label: 'ยกเลิก', value: 'cancel'),
                ZokyDialogAction(
                  label: 'ล้างตะกร้า',
                  value: 'clear',
                  isDestructive: true,
                ),
              ],
            );
          }),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(CupertinoAlertDialog), findsNothing);
        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();
        expect(result, 'cancel');
      });
    });

    testWidgets('action sheet is a modal bottom sheet of ListTiles', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.android, () async {
        int? result;
        await pumpZokyWidget(
          tester,
          _launcher((context) async {
            result = await showZokyActionSheet<int>(
              context: context,
              title: 'เลือกที่อยู่',
              actions: const [
                ZokySheetAction(label: 'บ้าน', value: 1),
                ZokySheetAction(label: 'ที่ทำงาน', value: 2),
              ],
            );
          }),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byType(ListTile), findsNWidgets(2));
        expect(find.byType(CupertinoActionSheet), findsNothing);
        await tester.tap(find.text('ที่ทำงาน'));
        await tester.pumpAndSettle();
        expect(result, 2);
      });
    });

    testWidgets('date picker is the Material calendar dialog', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        await pumpZokyWidget(
          tester,
          _launcher((context) {
            showZokyDatePicker(
              context: context,
              initialDate: DateTime(2026, 10, 17),
              firstDate: DateTime(2026, 10, 1),
              lastDate: DateTime(2026, 12, 31),
            );
          }),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        expect(find.byType(CupertinoDatePicker), findsNothing);
      });
    });

    testWidgets('switch is M3 Switch with primary track', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        await pumpZokyWidget(
          tester,
          ZokySwitch(value: true, onChanged: (_) {}),
        );
        expect(find.byType(Switch), findsOneWidget);
        expect(find.byType(CupertinoSwitch), findsNothing);
      });
    });
  });
}
