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

  testWidgets('foreground DM shows sender and exact text', (tester) async {
    await pumpApp(tester);
    PushReliabilityController.instance.debugPresentIncomingRealtimeDm(
      senderId: 'sender-user',
      subscribedUserId: 'receiver-user',
      activeUserId: 'receiver-user',
      senderName: 'Alice',
      text: 'ไปกินข้าวไหม',
    );
    await tester.pump();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('ไปกินข้าวไหม'), findsOneWidget);
  });

  testWidgets('foreground image DM shows image preview', (tester) async {
    await pumpApp(tester);
    PushReliabilityController.instance.debugPresentIncomingRealtimeDm(
      senderId: 'sender-user',
      subscribedUserId: 'receiver-user',
      activeUserId: 'receiver-user',
      senderName: 'Alice',
      imageUrl: 'image',
    );
    await tester.pump();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('ส่งรูปภาพ'), findsOneWidget);
  });

  testWidgets('foreground non-DM event shows no DM banner', (tester) async {
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

  testWidgets('own realtime message does not show a banner', (tester) async {
    await pumpApp(tester);
    PushReliabilityController.instance.debugPresentIncomingRealtimeDm(
      senderId: 'receiver-user',
      subscribedUserId: 'receiver-user',
      activeUserId: 'receiver-user',
      senderName: 'Me',
      text: 'own message',
    );
    await tester.pump();
    expect(find.text('Me'), findsNothing);
    expect(find.text('own message'), findsNothing);
  });

  testWidgets('stale account realtime event is ignored', (tester) async {
    await pumpApp(tester);
    PushReliabilityController.instance.debugPresentIncomingRealtimeDm(
      senderId: 'other-user',
      subscribedUserId: 'old-account',
      activeUserId: 'new-account',
      senderName: 'Old sender',
      text: 'stale message',
    );
    await tester.pump();
    expect(find.text('Old sender'), findsNothing);
    expect(find.text('stale message'), findsNothing);
  });

  test('DM preview prefers text and has attachment fallbacks', () {
    final controller = PushReliabilityController.instance;
    expect(
      controller.debugDmPreview({'text': '  สวัสดี  ', 'image_url': 'image'}),
      'สวัสดี',
    );
    expect(
      controller.debugDmPreview({
        'text': null,
        'image_url': 'image',
        'view_once': true,
      }),
      'ส่งรูปภาพแบบดูครั้งเดียว',
    );
    expect(
      controller.debugDmPreview({
        'text': null,
        'image_url': null,
        'shared_content_type': 'profile',
      }),
      'แชร์โปรไฟล์กับคุณ',
    );
  });
}
