import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club_event.dart';
import 'package:wyn/features/club/presentation/widgets/club_events_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_event_repository.dart';

/// Regression tests for WYN-118's Events tab -- upcoming/past sections,
/// RSVP taps, and the staff-only create FAB/edit-delete menu. See
/// club_page_test.dart for the tab-visibility gating tests (approved
/// member vs non-member) on `ClubPage` itself.
void main() {
  final future = DateTime.now().add(const Duration(days: 7));
  final past = DateTime.now().subtract(const Duration(days: 7));

  ClubEvent upcomingEvent({RsvpStatus? myRsvpStatus}) => ClubEvent(
        id: 'event-upcoming',
        clubId: 'club-1',
        creatorId: 'owner-1',
        creatorUsername: 'owner',
        title: 'Photo Walk',
        startsAt: future,
        locationType: ClubEventLocationType.offline,
        location: 'Lumphini Park',
        createdAt: DateTime.now(),
        myRsvpStatus: myRsvpStatus,
        goingCount: 2,
        maybeCount: 1,
        notGoingCount: 0,
      );

  ClubEvent pastEvent() => ClubEvent(
        id: 'event-past',
        clubId: 'club-1',
        creatorId: 'owner-1',
        creatorUsername: 'owner',
        title: 'Old Meetup',
        startsAt: past,
        locationType: ClubEventLocationType.online,
        location: 'https://meet.example.com',
        createdAt: DateTime.now(),
        goingCount: 3,
        maybeCount: 0,
        notGoingCount: 1,
      );

  // Built in setUp(), never inline inside testWidgets -- a fresh
  // RecordingClubEventRepository constructs a SupabaseClient whose
  // GoTrue auto-refresh timer would otherwise be attributed to that
  // one test's FakeAsync zone (.wyn/learning/PATTERNS.md).
  late RecordingClubEventRepository repo;
  late RecordingClubEventRepository emptyRepo;
  late RecordingClubEventRepository withBothRepo;
  late RecordingClubEventRepository pastOnlyRepo;
  late RecordingClubEventRepository withAttendeesRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'viewer');
  });

  setUp(() {
    repo = RecordingClubEventRepository(upcomingEvents: [upcomingEvent()]);
    emptyRepo = RecordingClubEventRepository();
    withBothRepo = RecordingClubEventRepository(
      upcomingEvents: [upcomingEvent()],
      pastEvents: [pastEvent()],
    );
    pastOnlyRepo = RecordingClubEventRepository(pastEvents: [pastEvent()]);
    withAttendeesRepo = RecordingClubEventRepository(
      upcomingEvents: [upcomingEvent()],
      attendees: const [
        ClubEventAttendee(userId: 'u1', username: 'namfah'),
      ],
    );
  });

  Future<void> pumpTab(
    WidgetTester tester,
    RecordingClubEventRepository r, {
    bool canManage = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClubEventsTab(
          clubEventRepository: r,
          clubId: 'club-1',
          canManage: canManage,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty state when there are no events at all',
      (tester) async {
    await pumpTab(tester, emptyRepo);

    expect(find.text('ยังไม่มีกิจกรรมใน Club นี้'), findsOneWidget);
  });

  testWidgets(
      'shows upcoming events under "กำลังจะถึง" and past events under '
      '"ที่ผ่านมาแล้ว"', (tester) async {
    await pumpTab(tester, withBothRepo);

    expect(find.text('กำลังจะถึง'), findsOneWidget);
    expect(find.text('Photo Walk'), findsOneWidget);
    expect(find.text('ที่ผ่านมาแล้ว'), findsOneWidget);
    expect(find.text('Old Meetup'), findsOneWidget);
  });

  testWidgets('a past event shows no RSVP buttons', (tester) async {
    await pumpTab(tester, pastOnlyRepo);

    expect(find.text('ไปแน่นอน'), findsNothing);
  });

  testWidgets('tapping "ไปแน่นอน" calls setRsvp and optimistically updates',
      (tester) async {
    await pumpTab(tester, repo);

    await tester.tap(find.text('ไปแน่นอน'));
    await tester.pump();

    // Optimistic: was 2 going, now 3 (the viewer's own new RSVP).
    expect(find.text('3 ไป'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(repo.setRsvpArgs, [('event-upcoming', RsvpStatus.going)]);
  });

  testWidgets('a failed RSVP reverts the optimistic update', (tester) async {
    repo.setRsvpError = Exception('network error');
    await pumpTab(tester, repo);

    await tester.tap(find.text('ไปแน่นอน'));
    await tester.pumpAndSettle();

    expect(find.text('2 ไป'), findsOneWidget);
  });

  testWidgets('tapping the "X ไป" summary opens the attendee sheet',
      (tester) async {
    await pumpTab(tester, withAttendeesRepo);

    await tester.tap(find.text('2 ไป'));
    await tester.pumpAndSettle();

    expect(find.text('คนที่ไป (2)'), findsOneWidget);
    expect(find.text('@namfah'), findsOneWidget);
  });

  testWidgets('the create FAB only shows when canManage is true',
      (tester) async {
    await pumpTab(tester, repo, canManage: false);
    expect(find.byType(FloatingActionButton), findsNothing);

    await pumpTab(tester, repo, canManage: true);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('a staff member sees an edit/delete menu on the card, a '
      'plain member does not', (tester) async {
    await pumpTab(tester, repo, canManage: false);
    expect(find.byIcon(Icons.more_vert), findsNothing);

    await pumpTab(tester, repo, canManage: true);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('deleting an event calls deleteEvent after confirming',
      (tester) async {
    await pumpTab(tester, repo, canManage: true);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบกิจกรรม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();

    expect(repo.deleteEventCalls, 1);
    expect(repo.deleteEventIdArgs, ['event-upcoming']);
  });
}
