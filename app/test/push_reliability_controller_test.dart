import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/navigation/app_navigator.dart';
import 'package:wyn/features/push/presentation/push_reliability_controller.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
  }

  testWidgets('foreground new_message shows an in-app notification banner',
      (tester) async {
    await pumpApp(tester);

    PushReliabilityController.instance.debugShowForegroundMessage(
      data: const {
        'type': 'new_message',
        'conversation_id': 'conversation-1',
      },
      title: 'Alice',
      body: 'ส่งข้อความถึงคุณ',
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('ส่งข้อความถึงคุณ'), findsOneWidget);
  });

  testWidgets('foreground non-DM push keeps existing behavior with no banner',
      (tester) async {
    await pumpApp(tester);

    PushReliabilityController.instance.debugShowForegroundMessage(
      data: const {'type': 'like_drop'},
      title: 'Alice',
      body: 'ถูกใจโพสต์ของคุณ',
    );
    await tester.pump();

    expect(find.text('Alice'), findsNothing);
    expect(find.text('ถูกใจโพสต์ของคุณ'), findsNothing);
  });

  testWidgets('foreground DM falls back to safe copy when FCM text is absent',
      (tester) async {
    await pumpApp(tester);

    PushReliabilityController.instance.debugShowForegroundMessage(
      data: const {'type': 'new_message'},
    );
    await tester.pump();

    expect(find.text('ข้อความใหม่'), findsOneWidget);
    expect(find.text('มีคนส่งข้อความถึงคุณ'), findsOneWidget);
  });
}
