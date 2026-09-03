import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop_draft.dart';
import 'package:wyn/features/drop/presentation/create_drop_screen.dart';
import 'package:wyn/features/drop/presentation/widgets/draft_grid_tile.dart';
import 'package:wyn/features/drop/presentation/widgets/draft_list.dart';

import 'support/recording_drop_repository.dart';
import 'support/recording_profile_repository.dart';

DropDraft _draft({String id = 'd1'}) => DropDraft(
      id: id,
      caption: 'ยังคิดไม่ออก',
      pollOptions: const ['A', 'B'],
      updatedAt: DateTime(2026, 1, 1),
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // Constructed in setUpAll, not inline per-test -- constructing a
  // RecordingDropRepository/RecordingProfileRepository inside a testWidgets
  // body attributes GoTrue's auto-refresh Timer.periodic to that test's
  // FakeAsync zone, causing a "Timer is still pending" failure. See
  // .wyn/learning/PATTERNS.md.
  late RecordingDropRepository emptyRepo;
  late RecordingProfileRepository emptyProfileRepo;
  late RecordingDropRepository listRepo;
  late RecordingProfileRepository listProfileRepo;
  late RecordingDropRepository errorRepo;
  late RecordingProfileRepository errorProfileRepo;
  late RecordingDropRepository tapRepo;
  late RecordingProfileRepository tapProfileRepo;
  late RecordingDropRepository deleteRepo;
  late RecordingProfileRepository deleteProfileRepo;

  setUpAll(() {
    emptyRepo = RecordingDropRepository();
    emptyProfileRepo = RecordingProfileRepository();
    listRepo = RecordingDropRepository()
      ..draftsToReturn = [_draft(id: 'd1'), _draft(id: 'd2')];
    listProfileRepo = RecordingProfileRepository();
    errorRepo = RecordingDropRepository()..fetchDraftsError = Exception('boom');
    errorProfileRepo = RecordingProfileRepository();
    tapRepo = RecordingDropRepository()..draftsToReturn = [_draft()];
    tapProfileRepo = RecordingProfileRepository();
    deleteRepo = RecordingDropRepository()
      ..draftsToReturn = [_draft(id: 'd1'), _draft(id: 'd2')];
    deleteProfileRepo = RecordingProfileRepository();
  });

  testWidgets('shows a loading spinner, then the empty state when there '
      'are no drafts', (tester) async {
    await tester.pumpWidget(_wrap(DraftList(
      dropRepository: emptyRepo,
      profileRepository: emptyProfileRepo,
    )));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.textContaining('ยังไม่มีร่าง'), findsOneWidget);
  });

  testWidgets('shows every draft returned by fetchDrafts', (tester) async {
    await tester.pumpWidget(_wrap(DraftList(
      dropRepository: listRepo,
      profileRepository: listProfileRepo,
    )));
    await tester.pumpAndSettle();

    expect(listRepo.fetchDraftsCalls, 1);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('a fetch failure shows an error with a retry button',
      (tester) async {
    await tester.pumpWidget(_wrap(DraftList(
      dropRepository: errorRepo,
      profileRepository: errorProfileRepo,
    )));
    await tester.pumpAndSettle();

    expect(find.text('โหลดร่างไม่สำเร็จ'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'ลองใหม่'), findsOneWidget);
  });

  testWidgets('tapping a draft opens CreateDropScreen prefilled with it',
      (tester) async {
    await tester.pumpWidget(_wrap(DraftList(
      dropRepository: tapRepo,
      profileRepository: tapProfileRepo,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DraftGridTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(CreateDropScreen), findsOneWidget);
    // The poll question/options carried over from the draft.
    expect(find.text('ยังคิดไม่ออก'), findsOneWidget);
  });

  testWidgets('deleting a draft removes it from the grid and calls '
      'deleteDraft', (tester) async {
    await tester.pumpWidget(_wrap(DraftList(
      dropRepository: deleteRepo,
      profileRepository: deleteProfileRepo,
    )));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(DraftGridTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ลบ'));
    await tester.pumpAndSettle();

    expect(deleteRepo.deleteDraftCalls, ['d1']);
  });
}
