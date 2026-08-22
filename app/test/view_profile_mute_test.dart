import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/block/data/block_relationship.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_block_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_mute_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_report_repository.dart';
import 'support/recording_saved_repository.dart';

/// Now that ViewProfileScreen's report/block/mute repositories are
/// injectable (fixed alongside WYN-028 -- see the WYN-027 QA finding in
/// .wyn/company/DECISIONS.md), this exercises the More menu integration
/// that was previously untestable because those three were hardcoded to
/// a real (fake-session, no real backend) SupabaseClient.
void main() {
  const otherProfile = Profile(id: 'someone-else', username: 'namfah');

  late RecordingProfileRepository profileRepo;
  late RecordingFollowRepository followRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;
  late RecordingReportRepository reportRepo;
  late RecordingBlockRepository blockRepo;
  late RecordingMuteRepository muteRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    profileRepo = RecordingProfileRepository(profile: otherProfile);
    followRepo = RecordingFollowRepository();
    dropRepo = RecordingDropRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();
    reportRepo = RecordingReportRepository();
    blockRepo = RecordingBlockRepository();
    muteRepo = RecordingMuteRepository();
  });

  setUp(() {
    blockRepo.blockRelationshipResult = BlockRelationship.none;
    muteRepo.isMutedResult = false;
    muteRepo.muteUserError = null;
    muteRepo.unmuteUserError = null;
    muteRepo.muteUserCalls = 0;
    muteRepo.unmuteUserCalls = 0;
    muteRepo.lastMutedUserId = null;
    muteRepo.lastUnmutedUserId = null;
  });

  Widget buildProfile() => MaterialApp(
        home: ViewProfileScreen(
          profileRepository: profileRepo,
          followRepository: followRepo,
          dropRepository: dropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          reportRepository: reportRepo,
          blockRepository: blockRepo,
          muteRepository: muteRepo,
          userId: 'someone-else',
        ),
      );

  testWidgets(
      'shows "ปิดเสียง" between รายงาน and บล็อก when not muted and not blocked',
      (tester) async {
    await tester.pumpWidget(buildProfile());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    final items = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    final titles = items
        .map((tile) => (tile.title as Text).data)
        .toList(growable: false);
    expect(titles, ['รายงาน', 'ปิดเสียง', 'บล็อก']);
  });

  testWidgets('tapping ปิดเสียง calls muteUser and shows a confirmation '
      'SnackBar, with no confirm dialog', (tester) async {
    await tester.pumpWidget(buildProfile());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ปิดเสียง'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(muteRepo.muteUserCalls, 1);
    expect(muteRepo.lastMutedUserId, 'someone-else');
    expect(find.text('ปิดเสียง @namfah แล้ว'), findsOneWidget);
  });

  testWidgets('shows "เปิดเสียง" once already muted, and tapping it unmutes',
      (tester) async {
    muteRepo.isMutedResult = true;
    await tester.pumpWidget(buildProfile());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('เปิดเสียง'), findsOneWidget);
    expect(find.text('ปิดเสียง'), findsNothing);

    await tester.tap(find.text('เปิดเสียง'));
    await tester.pumpAndSettle();

    expect(muteRepo.unmuteUserCalls, 1);
    expect(find.text('เปิดเสียง @namfah แล้ว'), findsOneWidget);
  });

  testWidgets('does not show ปิดเสียง/เปิดเสียง at all when a block '
      'relationship already exists', (tester) async {
    blockRepo.blockRelationshipResult = BlockRelationship.blockedByMe;
    await tester.pumpWidget(buildProfile());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('ปิดเสียง'), findsNothing);
    expect(find.text('เปิดเสียง'), findsNothing);
    expect(find.text('รายงาน'), findsOneWidget);
    expect(find.text('บล็อก'), findsNothing);
  });

  testWidgets('a failed mute reverts the toggle and shows an error SnackBar',
      (tester) async {
    muteRepo.muteUserError = Exception('network down');
    await tester.pumpWidget(buildProfile());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ปิดเสียง'));
    await tester.pumpAndSettle();

    expect(find.text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);

    // Reverted -- opening the menu again should still offer ปิดเสียง.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('ปิดเสียง'), findsOneWidget);
  });
}
