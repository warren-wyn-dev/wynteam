import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/web/home_screen_platform.dart';
import 'package:wyn/features/home/presentation/widgets/add_to_home_screen_sheet.dart';

/// WYN-107, Screen 2 -- pumps AddToHomeScreenSheet directly (rather than
/// through showAddToHomeScreenSheet's modal route) so these can assert on
/// its exact, verbatim copy without a bottom-sheet's own open/close
/// animation noise.
Widget _wrap(WebPlatformKind kind) => MaterialApp(
      home: Scaffold(body: AddToHomeScreenSheet(platformKind: kind)),
    );

void main() {
  testWidgets('shows the shared title/subtitle regardless of platform',
      (tester) async {
    await tester.pumpWidget(_wrap(WebPlatformKind.iosSafari));

    expect(find.text('เพิ่ม WYNOS ไว้ที่หน้าจอหลัก'), findsOneWidget);
    expect(
      find.text('เปิดใช้งานได้เร็วเหมือนแอปจริง ไม่ต้องเปิดเบราว์เซอร์ใหม่ทุกครั้ง'),
      findsOneWidget,
    );
    expect(find.text('เข้าใจแล้ว'), findsOneWidget);
  });

  testWidgets('shows only the iOS Safari 3-step content when detected as '
      'iOS Safari', (tester) async {
    await tester.pumpWidget(_wrap(WebPlatformKind.iosSafari));

    expect(find.byIcon(Icons.ios_share), findsOneWidget);
    expect(find.byIcon(Icons.add_to_home_screen), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.textContaining('แชร์'), findsOneWidget);
    expect(find.textContaining('เพิ่มไปยังหน้าจอโฮม'), findsOneWidget);

    // No Android-only content leaks in.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.install_mobile), findsNothing);
    expect(find.textContaining('จุดสามจุด'), findsNothing);
  });

  testWidgets('shows only the Android Chrome 3-step content when detected '
      'as Android Chrome', (tester) async {
    await tester.pumpWidget(_wrap(WebPlatformKind.androidChrome));

    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.install_mobile), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.textContaining('จุดสามจุด'), findsOneWidget);
    expect(find.textContaining('ติดตั้งแอป'), findsOneWidget);

    // No iOS-only content leaks in.
    expect(find.byIcon(Icons.ios_share), findsNothing);
    expect(find.textContaining('แชร์'), findsNothing);
  });

  testWidgets('"เข้าใจแล้ว" closes the sheet, no "don\'t show again" control '
      'anywhere', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAddToHomeScreenSheet(
                context,
                platformKind: () => WebPlatformKind.iosSafari,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AddToHomeScreenSheet), findsOneWidget);

    await tester.tap(find.text('เข้าใจแล้ว'));
    await tester.pumpAndSettle();
    expect(find.byType(AddToHomeScreenSheet), findsNothing);
  });
}
