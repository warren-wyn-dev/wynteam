import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/presentation/create_club_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';

/// Regression tests for CreateClubScreen's required-field gating, per
/// .wyn/docs/design/wyn-014-club-core.md, Screen 2: "disabled จนกว่าจะ
/// กรอกครบ Name+Privacy อย่างน้อย -- Cover/Icon/Description/Category เป็น
/// optional".
void main() {
  late RecordingClubRepository clubRepo;
  late RecordingClubPostRepository clubPostRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    clubRepo = RecordingClubRepository();
    clubPostRepo = RecordingClubPostRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateClubScreen(
          clubRepository: clubRepo,
          clubPostRepository: clubPostRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder createButtonFinder() =>
      find.widgetWithText(FilledButton, 'สร้าง Club');

  testWidgets('the create button is disabled until both Name and Privacy are set',
      (tester) async {
    await pumpScreen(tester);

    expect(tester.widget<FilledButton>(createButtonFinder()).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'ชื่อ Club'), 'ชมรมถ่ายภาพ');
    await tester.pump();
    // Name alone isn't enough -- Privacy is also required.
    expect(tester.widget<FilledButton>(createButtonFinder()).onPressed, isNull);

    await tester.ensureVisible(find.text('สาธารณะ'));
    await tester.tap(find.text('สาธารณะ'));
    await tester.pump();
    expect(tester.widget<FilledButton>(createButtonFinder()).onPressed, isNotNull);
  });

  testWidgets('shows the cover-picker placeholder hint before a cover is picked', (tester) async {
    await pumpScreen(tester);

    expect(find.text('แตะเพื่อเลือกรูปปก'), findsOneWidget);
    expect(find.text('แนะนำอัตราส่วน 16:9'), findsOneWidget);
  });

  testWidgets('creating with only Name and Privacy set (Category/Description/Cover/Icon '
      'left blank) still calls createClub', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, 'ชื่อ Club'), 'ชมรมถ่ายภาพ');
    await tester.ensureVisible(find.text('ส่วนตัว'));
    await tester.tap(find.text('ส่วนตัว'));
    await tester.pump();

    await tester.ensureVisible(createButtonFinder());
    await tester.tap(createButtonFinder());
    await tester.pumpAndSettle();

    expect(clubRepo.createClubCalls, 1);
  });
}
