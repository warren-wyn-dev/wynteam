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

  testWidgets('foreground non-DM event keeps existing behavior with no banner',
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

  testWidgets('incoming realtime DM shows safe in-app copy without FCM text',
      (tester) async {
    await pumpApp(tester);

    PushReliabilityController.instance.debugHandleIncomingRealtimeDm(
      senderId: 'sender-user',
      subscribedUserId: 'receiver-user',
      activeUserId: 'receiver-user',
    );
    await tester.pump();

    expect(find.text('ข้อความใหม่'), findsOneWidget);
    expect(find.text('มีคนส่งข้อความถึงคุณ'), findsOneWidget);
  });

  testWidgets('realtime echo of own sent message does not show a banner',
      (tester) async {
    await pumpApp(tester);

    PushReliabilityController.instance.debugHandleIncomingRealtimeDm(
      senderId: 'receiver-user',
      subscribedUserId: 'receiver-user',
      activeUserId: 'receiver-user',
    );
    await tester.pump();

    expect(find.text('ข้อความใหม่'), findsNothing);
    expect(find.text('มีคนส่งข้อความถึงคุณ'), findsNothing);
  });

  testWidgets('stale account realtime event is ignored after account switch',
      (tester) async {
    await pumpApp(tester);

    PushReliabilityController.instance.debugHandleIncomingRealtimeDm(
      senderId: 'other-user',
      subscribedUserId: 'old-account',
      activeUserId: 'new-account',
    );
    await tester.pump();

    expect(find.text('ข้อความใหม่'), findsNothing);
    expect(find.text('มีคนส่งข้อความถึงคุณ'), findsNothing);
  });
}
