import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/presentation/create_drop_screen.dart';

import 'support/recording_drop_repository.dart';

void main() {
  late RecordingDropRepository repo;
  setUpAll(() {
    repo = RecordingDropRepository();
  });

  testWidgets(
      'the "แชร์" button stays disabled until an image is picked '
      '(a Drop always needs a photo, unlike WYN-004 posts)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateDropScreen(dropRepository: repo),
    ));

    final shareButton = find.widgetWithText(TextButton, 'แชร์');
    expect(shareButton, findsOneWidget);
    expect(tester.widget<TextButton>(shareButton).onPressed, isNull);

    // Typing a caption alone must not enable it either -- an image is
    // mandatory, not just one of two options like WYN-004's text/image.
    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pump();

    expect(tester.widget<TextButton>(shareButton).onPressed, isNull);
  });

  testWidgets('shows a placeholder prompt before any image is picked',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateDropScreen(dropRepository: repo),
    ));

    expect(find.text('แตะเพื่อเลือกรูป'), findsOneWidget);
  });
}
