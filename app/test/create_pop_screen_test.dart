import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/pop/presentation/create_pop_screen.dart';

import 'support/recording_pop_repository.dart';

void main() {
  late RecordingPopRepository repo;
  setUpAll(() {
    repo = RecordingPopRepository();
  });

  testWidgets(
      'the "แชร์" button stays disabled until a video is picked '
      '(a Pop always needs a video, mirroring how a Drop always needs an '
      'image)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreatePopScreen(popRepository: repo),
    ));

    final shareButton = find.widgetWithText(TextButton, 'แชร์');
    expect(shareButton, findsOneWidget);
    expect(tester.widget<TextButton>(shareButton).onPressed, isNull);

    // Typing a caption alone must not enable it either -- a video is
    // mandatory.
    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pump();

    expect(tester.widget<TextButton>(shareButton).onPressed, isNull);
  });

  testWidgets('shows a placeholder prompt before any video is picked',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreatePopScreen(popRepository: repo),
    ));

    expect(find.text('แตะเพื่อเลือกวิดีโอ'), findsOneWidget);
  });
}
