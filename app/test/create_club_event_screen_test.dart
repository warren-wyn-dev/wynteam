import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club_event.dart';
import 'package:wyn/features/club/presentation/create_club_event_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_event_repository.dart';

/// Regression tests for WYN-118's create/edit Event form.
void main() {
  late RecordingClubEventRepository repo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'owner-1');
  });

  setUp(() {
    repo = RecordingClubEventRepository();
  });

  Widget buildScreen({ClubEvent? existingEvent}) => MaterialApp(
        home: CreateClubEventScreen(
          clubEventRepository: repo,
          clubId: 'club-1',
          existingEvent: existingEvent,
        ),
      );

  testWidgets('"สร้างกิจกรรม" stays disabled until title and location are filled',
      (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.widgetWithText(TextField, 'ชื่อกิจกรรม'), 'Photo Walk');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    // Default location type is offline -- its field is labeled "ที่อยู่".
    await tester.enterText(find.widgetWithText(TextField, 'ที่อยู่'), 'Lumphini Park');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('creating an event calls createEvent with the entered fields',
      (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.widgetWithText(TextField, 'ชื่อกิจกรรม'), 'Photo Walk');
    await tester.enterText(find.widgetWithText(TextField, 'ที่อยู่'), 'Lumphini Park');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'สร้างกิจกรรม'));
    await tester.pumpAndSettle();

    expect(repo.createEventCalls, 1);
  });

  testWidgets('switching location type to ออนไลน์ relabels the field to "ลิงก์"',
      (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.widgetWithText(TextField, 'ที่อยู่'), findsOneWidget);

    await tester.tap(find.text('ออนไลน์'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'ลิงก์'), findsOneWidget);
  });

  testWidgets('editing an existing event pre-fills the form and calls '
      'updateEvent, not createEvent', (tester) async {
    final existing = ClubEvent(
      id: 'event-1',
      clubId: 'club-1',
      creatorId: 'owner-1',
      creatorUsername: 'owner',
      title: 'Photo Walk',
      description: 'Bring your camera',
      startsAt: DateTime.now().add(const Duration(days: 3)),
      locationType: ClubEventLocationType.offline,
      location: 'Lumphini Park',
      createdAt: DateTime.now(),
      goingCount: 0,
      maybeCount: 0,
      notGoingCount: 0,
    );
    await tester.pumpWidget(buildScreen(existingEvent: existing));

    expect(find.text('แก้ไขกิจกรรม'), findsOneWidget);
    expect(find.text('Photo Walk'), findsOneWidget);
    expect(find.text('Bring your camera'), findsOneWidget);
    expect(find.text('Lumphini Park'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(repo.updateEventCalls, 1);
    expect(repo.createEventCalls, 0);
  });

  testWidgets('a failed save shows an error message', (tester) async {
    repo.createEventError = Exception('network error');
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.widgetWithText(TextField, 'ชื่อกิจกรรม'), 'Photo Walk');
    await tester.enterText(find.widgetWithText(TextField, 'ที่อยู่'), 'Lumphini Park');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'สร้างกิจกรรม'));
    await tester.pumpAndSettle();

    expect(find.text('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
  });
}
