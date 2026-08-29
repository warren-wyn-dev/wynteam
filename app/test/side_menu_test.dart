import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/presentation/my_clubs_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_saved_tab.dart';
import 'package:wyn/features/root/presentation/side_menu.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

/// 10-side-menu.tsx -- the ☰ drawer, wired up from NotificationListScreen
/// (see notification_list_screen_test.dart's own "opens the side menu
/// drawer" test for that half). Real destinations only, no placeholders
/// -- see side_menu.dart's own doc comment for why "บันทึกไว้" reuses
/// ViewProfileScreen's existing `_openSaved` destination rather than a
/// new Bookmarks screen (design-reference's 15-bookmarks.tsx isn't built
/// yet).
void main() {
  late RecordingProfileRepository profileRepo;
  late RecordingFollowRepository followRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;
  late RecordingClubRepository clubRepo;
  late RecordingClubPostRepository clubPostRepo;

  setUp(() {
    profileRepo = RecordingProfileRepository(
      profile: const Profile(
        id: 'u1',
        username: 'warren',
        displayName: 'WARREN',
      ),
    );
    followRepo = RecordingFollowRepository()
      ..followerCount = 4
      ..followingCount = 1;
    dropRepo = RecordingDropRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();
    clubRepo = RecordingClubRepository();
    clubPostRepo = RecordingClubPostRepository();
  });

  Widget buildDrawer() => MaterialApp(
        home: Scaffold(
          drawer: SideMenu(
            profileRepository: profileRepo,
            followRepository: followRepo,
            dropRepository: dropRepo,
            popRepository: popRepo,
            savedRepository: savedRepo,
            clubRepository: clubRepo,
            clubPostRepository: clubPostRepo,
          ),
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.pumpWidget(buildDrawer());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  setUpAll(initFakeSupabaseSession);

  testWidgets(
      'shows the real display name, handle, and real follower/following '
      'counts -- no placeholder zeros or hardcoded verified badge',
      (tester) async {
    await openDrawer(tester);

    expect(find.text('WARREN'), findsOneWidget);
    expect(find.text('@warren'), findsOneWidget);
    expect(find.textContaining('4'), findsOneWidget);
    expect(find.textContaining('ผู้ติดตาม'), findsOneWidget);
    expect(find.textContaining('1'), findsOneWidget);
    expect(find.textContaining('กำลังติดตาม'), findsOneWidget);
    // No real "verified" field anywhere in the Profile model -- must not
    // be hardcoded true for anyone.
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('tapping the identity block opens the viewer\'s own profile',
      (tester) async {
    await openDrawer(tester);

    await tester.tap(find.text('WARREN'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
  });

  testWidgets('tapping "โปรไฟล์" opens the viewer\'s own profile',
      (tester) async {
    await openDrawer(tester);

    await tester.tap(find.text('โปรไฟล์'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
  });

  testWidgets('tapping "Club ของฉัน" opens MyClubsScreen', (tester) async {
    await openDrawer(tester);

    await tester.tap(find.text('Club ของฉัน'));
    await tester.pumpAndSettle();

    expect(find.byType(MyClubsScreen), findsOneWidget);
  });

  testWidgets('tapping "บันทึกไว้" opens the same Saved screen Profile\'s '
      'own icon-row button does', (tester) async {
    await openDrawer(tester);

    await tester.tap(find.text('บันทึกไว้'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileSavedTab), findsOneWidget);
    expect(find.text('บันทึก'), findsOneWidget);
  });

  testWidgets('the close button closes the drawer', (tester) async {
    await openDrawer(tester);
    expect(find.byType(SideMenu), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(SideMenu), findsNothing);
  });

  testWidgets('no overflow at a real drawer width with realistic counts',
      (tester) async {
    followRepo
      ..followerCount = 12345
      ..followingCount = 6789;
    await openDrawer(tester);

    expect(tester.takeException(), isNull);
  });
}
