import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/presentation/create_club_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';

/// LabeledField's own label is a sibling of its TextField, not a
/// descendant -- see edit_profile_screen_test.dart's identical
/// `_field` helper and comment for why `find.widgetWithText(TextField,
/// ...)` no longer works here.
Finder _clubNameField() => find.descendant(
      of: find.byKey(const Key('club_name_field')),
      matching: find.byType(TextField),
    );

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

    await tester.enterText(_clubNameField(), 'ชมรมถ่ายภาพ');
    await tester.pump();
    // Name alone isn't enough -- Privacy is also required.
    expect(tester.widget<FilledButton>(createButtonFinder()).onPressed, isNull);

    await tester.ensureVisible(find.text('สาธารณะ'));
    await tester.tap(find.text('สาธารณะ'));
    await tester.pump();
    expect(tester.widget<FilledButton>(createButtonFinder()).onPressed, isNotNull);
  });

  testWidgets('Beta4 §8.1: offers exactly one Club image picker, labelled '
      '"รูป Club" -- no separate cover and icon', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const Key('club_image_picker')), findsOneWidget);
    expect(find.text('รูป Club'), findsOneWidget);
    // The old copy promised a 16:9 *cover*; this image is the Club's
    // identity and is rendered as a circle on most surfaces.
    expect(find.text('แตะเพื่อเลือกรูปปก'), findsNothing);
    expect(find.text('แนะนำอัตราส่วน 16:9'), findsNothing);
    expect(find.textContaining('ไอคอน'), findsNothing);
  });

  testWidgets('Beta4 §8.2: the form asks for the name before the image, '
      'and ends with a review summary above the create button',
      (tester) async {
    await pumpScreen(tester);

    // Name field comes first -- the screen used to open with a
    // full-bleed image picker, asking for a photo of a thing that had
    // no name yet.
    final nameY = tester.getTopLeft(_clubNameField()).dy;
    final imageY =
        tester.getTopLeft(find.byKey(const Key('club_image_picker'))).dy;
    expect(nameY, lessThan(imageY));

    // The review summary appears only once the required answers exist.
    expect(find.byKey(const Key('club_review_summary')), findsNothing);

    await tester.enterText(_clubNameField(), 'ชมรมถ่ายภาพ');
    await tester.ensureVisible(find.text('สาธารณะ'));
    await tester.tap(find.text('สาธารณะ'));
    await tester.pumpAndSettle();

    final summary = find.byKey(const Key('club_review_summary'));
    expect(summary, findsOneWidget);
    await tester.ensureVisible(summary);
    expect(find.text('ตรวจสอบข้อมูล'), findsOneWidget);
    // Says what is about to be created, including that no image was
    // chosen -- so "I forgot the picture" is catchable before the tap.
    expect(find.text('ยังไม่ได้เลือกรูป Club'), findsOneWidget);
    expect(
      tester.getTopLeft(summary).dy,
      lessThan(tester.getTopLeft(createButtonFinder()).dy),
    );
  });

  testWidgets('creating with only Name and Privacy set (Category/Description/Image '
      'left blank) still calls createClub, with no image bytes', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(_clubNameField(), 'ชมรมถ่ายภาพ');
    await tester.ensureVisible(find.text('ส่วนตัว'));
    await tester.tap(find.text('ส่วนตัว'));
    await tester.pump();

    await tester.ensureVisible(createButtonFinder());
    await tester.tap(createButtonFinder());
    await tester.pumpAndSettle();

    expect(clubRepo.createClubCalls, 1);
    // Beta4 §8.1: one image parameter, and it is genuinely optional.
    expect(clubRepo.lastCreateImageBytes, isNull);
    expect(clubRepo.lastCreateImageExtension, isNull);
  });
}
