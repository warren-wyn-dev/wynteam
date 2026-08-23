import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/presentation/edit_drop_caption_screen.dart';

import 'support/recording_drop_repository.dart';

void main() {
  // Constructed in setUpAll, not inline per-test -- see
  // .wyn/learning/PATTERNS.md (GoTrue auto-refresh Timer leak).
  late RecordingDropRepository repo;
  late RecordingDropRepository saveTestRepo;
  late RecordingDropRepository failTestRepo;

  setUpAll(() {
    repo = RecordingDropRepository();
    saveTestRepo = RecordingDropRepository();
    failTestRepo = RecordingDropRepository()
      ..editDropError = Exception('network error');
  });

  Widget buildScreen(RecordingDropRepository dropRepository, {String? initialCaption}) =>
      MaterialApp(
        home: EditDropCaptionScreen(
          dropRepository: dropRepository,
          dropId: 'd1',
          initialCaption: initialCaption,
        ),
      );

  testWidgets('"บันทึก" starts disabled when the caption has not changed',
      (tester) async {
    await tester.pumpWidget(buildScreen(repo, initialCaption: 'เดิม'));

    final saveButton = find.widgetWithText(TextButton, 'บันทึก');
    expect(tester.widget<TextButton>(saveButton).onPressed, isNull);
  });

  testWidgets('editing the text enables "บันทึก"', (tester) async {
    await tester.pumpWidget(buildScreen(repo, initialCaption: 'เดิม'));

    await tester.enterText(find.byType(TextField), 'ใหม่');
    await tester.pump();

    final saveButton = find.widgetWithText(TextButton, 'บันทึก');
    expect(tester.widget<TextButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets(
      '"บันทึก" calls editDrop with the new caption and pops with it',
      (tester) async {
    String? popResult;
    // Needs a real route to pop back to -- same fix as
    // QuoteRedropScreenTest's buildScreen/openScreen.
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                popResult = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => EditDropCaptionScreen(
                      dropRepository: saveTestRepo,
                      dropId: 'd1',
                      initialCaption: 'เดิม',
                    ),
                  ),
                );
              },
              child: const Text('เปิด'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'แคปชันใหม่');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(saveTestRepo.editDropArgs, hasLength(1));
    expect(saveTestRepo.editDropArgs.single['dropId'], 'd1');
    expect(saveTestRepo.editDropArgs.single['caption'], 'แคปชันใหม่');
    expect(find.byType(EditDropCaptionScreen), findsNothing);
    expect(popResult, 'แคปชันใหม่');
  });

  testWidgets('a failed save shows an error and stays on screen',
      (tester) async {
    await tester.pumpWidget(buildScreen(failTestRepo, initialCaption: 'เดิม'));

    await tester.enterText(find.byType(TextField), 'ใหม่');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(find.text('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.byType(EditDropCaptionScreen), findsOneWidget);
  });

  // WYN-037 QA: a Poll's question (drops.caption) must never be
  // savable empty -- unlike an image-mode Drop's optional caption, an
  // empty question would leave live options/votes with nothing
  // explaining what they're about. Found during independent QA:
  // _canSave originally only compared against the *previous* text, so
  // clearing a Poll's question entirely (new text == '') still
  // counted as "changed" and enabled "บันทึก".
  testWidgets(
      'isPollQuestion: true -- "บันทึก" stays disabled when the new '
      'text is empty, even though it differs from the original',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditDropCaptionScreen(
        dropRepository: repo,
        dropId: 'd1',
        initialCaption: 'กินอะไรดี?',
        isPollQuestion: true,
      ),
    ));

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    final saveButton = find.widgetWithText(TextButton, 'บันทึก');
    expect(tester.widget<TextButton>(saveButton).onPressed, isNull);
  });

  testWidgets(
      'isPollQuestion: true -- "บันทึก" enables normally for a '
      'non-empty replacement question', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditDropCaptionScreen(
        dropRepository: repo,
        dropId: 'd1',
        initialCaption: 'กินอะไรดี?',
        isPollQuestion: true,
      ),
    ));

    await tester.enterText(find.byType(TextField), 'ไปเที่ยวไหนดี?');
    await tester.pump();

    final saveButton = find.widgetWithText(TextButton, 'บันทึก');
    expect(tester.widget<TextButton>(saveButton).onPressed, isNotNull);
  });
}
