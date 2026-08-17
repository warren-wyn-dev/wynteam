import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/edit_profile_screen.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_cover_avatar.dart';

import 'support/fake_image_picker_platform.dart';
import 'support/recording_auth_repository.dart';
import 'support/recording_profile_repository.dart';

void main() {
  const profile = Profile(
    id: 'u1',
    username: 'namfah',
    displayName: 'น้ำฝน',
    bio: 'สวัสดีค่ะ',
  );

  Finder usernameField() => find.widgetWithText(TextField, 'ชื่อผู้ใช้');
  Finder websiteField() => find.widgetWithText(TextField, 'เว็บไซต์');
  Finder saveButton() => find.widgetWithText(FilledButton, 'บันทึก');

  Widget buildScreen({
    required RecordingProfileRepository profileRepository,
    required RecordingAuthRepository authRepository,
    Profile screenProfile = profile,
  }) =>
      MaterialApp(
        home: EditProfileScreen(
          profileRepository: profileRepository,
          authRepository: authRepository,
          profile: screenProfile,
        ),
      );

  testWidgets('pre-fills display name, bio, and username from the existing profile',
      (tester) async {
    await tester.pumpWidget(buildScreen(
      profileRepository: RecordingProfileRepository(profile: profile),
      authRepository: RecordingAuthRepository(),
    ));

    expect(find.text('น้ำฝน'), findsOneWidget);
    expect(find.text('สวัสดีค่ะ'), findsOneWidget);
    expect(find.text('namfah'), findsOneWidget);
    expect(find.text('9/160'), findsOneWidget);
  });

  testWidgets('bio counter updates as the user types', (tester) async {
    await tester.pumpWidget(buildScreen(
      profileRepository: RecordingProfileRepository(profile: profile),
      authRepository: RecordingAuthRepository(),
    ));

    await tester.enterText(find.widgetWithText(TextFormField, 'Bio'), 'a' * 20);
    await tester.pump();

    expect(find.text('20/160'), findsOneWidget);
  });

  testWidgets('bio counter turns error-colored near the character limit',
      (tester) async {
    await tester.pumpWidget(buildScreen(
      profileRepository: RecordingProfileRepository(profile: profile),
      authRepository: RecordingAuthRepository(),
    ));

    final bioField = find.widgetWithText(TextField, 'Bio');
    await tester.enterText(bioField, 'a' * 150);
    await tester.pump();

    final field = tester.widget<TextField>(bioField);
    final theme = Theme.of(tester.element(bioField));
    expect(field.decoration?.counterStyle?.color, theme.colorScheme.error);
  });

  group('Website field (WYN-024 R2)', () {
    testWidgets('accepts a URL with no scheme, and rejects garbage input',
        (tester) async {
      await tester.pumpWidget(buildScreen(
        profileRepository: RecordingProfileRepository(profile: profile),
        authRepository: RecordingAuthRepository(),
      ));

      await tester.enterText(websiteField(), 'not a url');
      // The header (WYN-024 R1's cover+avatar) plus every field added by
      // WYN-024 makes this form taller than the 800x600 default test
      // surface -- ensureVisible() scrolls the SingleChildScrollView so
      // the tap actually lands, instead of silently missing (see
      // create_club_screen_test.dart for the same pattern on another tall
      // form).
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(find.text('ลิงก์เว็บไซต์รูปแบบไม่ถูกต้อง'), findsOneWidget);
    });

    testWidgets('an empty website is valid (the field is optional)',
        (tester) async {
      final profileRepo = RecordingProfileRepository(profile: profile);
      await tester.pumpWidget(buildScreen(
        profileRepository: profileRepo,
        authRepository: RecordingAuthRepository(),
      ));

      // Leave the website field untouched (empty) and save.
      // The header (WYN-024 R1's cover+avatar) plus every field added by
      // WYN-024 makes this form taller than the 800x600 default test
      // surface -- ensureVisible() scrolls the SingleChildScrollView so
      // the tap actually lands, instead of silently missing (see
      // create_club_screen_test.dart for the same pattern on another tall
      // form).
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(find.text('ลิงก์เว็บไซต์รูปแบบไม่ถูกต้อง'), findsNothing);
      expect(profileRepo.updateProfileCalls, 1);
    });

    testWidgets('saving normalizes a schemeless URL to https:// before writing',
        (tester) async {
      final profileRepo = RecordingProfileRepository(profile: profile);
      Profile? popped;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<Profile>(
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      profileRepository: profileRepo,
                      authRepository: RecordingAuthRepository(),
                      profile: profile,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(websiteField(), 'namfah.dev');
      // The header (WYN-024 R1's cover+avatar) plus every field added by
      // WYN-024 makes this form taller than the 800x600 default test
      // surface -- ensureVisible() scrolls the SingleChildScrollView so
      // the tap actually lands, instead of silently missing (see
      // create_club_screen_test.dart for the same pattern on another tall
      // form).
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(popped?.website, 'https://namfah.dev');
    });
  });

  group('Username self-exclusion (WYN-024 R3 -- the design spec\'s most '
      'important regression test)', () {
    testWidgets(
        'saving without touching the username succeeds, even though '
        'isUsernameAvailable would (correctly, per its own contract) '
        'report the user\'s own current username as taken', (tester) async {
      final profileRepo = RecordingProfileRepository(profile: profile);
      // Simulates the real AuthRepository.isUsernameAvailable's lack of
      // self-exclusion: the profile's own current username is "taken" by
      // its own row, exactly like `.eq('username', 'namfah')` would find
      // a match for the signed-in user themself.
      final authRepo = RecordingAuthRepository(takenUsernames: {profile.username});

      await tester.pumpWidget(buildScreen(
        profileRepository: profileRepo,
        authRepository: authRepo,
      ));

      // Re-type the exact same pre-filled username -- the scenario a
      // missing short-circuit would mis-handle.
      await tester.enterText(usernameField(), profile.username);
      await tester.pump(const Duration(milliseconds: 500));

      // The header (WYN-024 R1's cover+avatar) plus every field added by
      // WYN-024 makes this form taller than the 800x600 default test
      // surface -- ensureVisible() scrolls the SingleChildScrollView so
      // the tap actually lands, instead of silently missing (see
      // create_club_screen_test.dart for the same pattern on another tall
      // form).
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(authRepo.isUsernameAvailableCalls, 0);
      expect(authRepo.setUsernameCalls, 0);
      expect(find.text('ชื่อผู้ใช้นี้ถูกใช้แล้ว'), findsNothing);
      expect(profileRepo.updateProfileCalls, 1);
    });

    testWidgets('changing the username to a genuinely available one still '
        'checks availability and succeeds', (tester) async {
      final profileRepo = RecordingProfileRepository(profile: profile);
      final authRepo = RecordingAuthRepository();
      Profile? popped;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<Profile>(
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      profileRepository: profileRepo,
                      authRepository: authRepo,
                      profile: profile,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(usernameField(), 'newname');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // The header (WYN-024 R1's cover+avatar) plus every field added by
      // WYN-024 makes this form taller than the 800x600 default test
      // surface -- ensureVisible() scrolls the SingleChildScrollView so
      // the tap actually lands, instead of silently missing (see
      // create_club_screen_test.dart for the same pattern on another tall
      // form).
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(authRepo.isUsernameAvailableCalls, 1);
      expect(authRepo.setUsernameArgs, ['newname']);
      expect(popped?.username, 'newname');
    });

    testWidgets('changing the username to one genuinely taken by someone '
        'else still blocks saving (no regression vs. onboarding)',
        (tester) async {
      final profileRepo = RecordingProfileRepository(profile: profile);
      final authRepo = RecordingAuthRepository(takenUsernames: {'someoneelse'});

      await tester.pumpWidget(buildScreen(
        profileRepository: profileRepo,
        authRepository: authRepo,
      ));

      await tester.enterText(usernameField(), 'someoneelse');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ชื่อผู้ใช้นี้ถูกใช้แล้ว'), findsOneWidget);

      // The header (WYN-024 R1's cover+avatar) plus every field added by
      // WYN-024 makes this form taller than the 800x600 default test
      // surface -- ensureVisible() scrolls the SingleChildScrollView so
      // the tap actually lands, instead of silently missing (see
      // create_club_screen_test.dart for the same pattern on another tall
      // form).
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(profileRepo.updateProfileCalls, 0);
    });

    testWidgets(
        'fail-fast ordering: a username taken at submit time blocks '
        'updateProfile from running at all -- no partial save', (tester) async {
      final profileRepo = RecordingProfileRepository(profile: profile);
      final authRepo = RecordingAuthRepository(takenUsernames: {'someoneelse'});

      await tester.pumpWidget(buildScreen(
        profileRepository: profileRepo,
        authRepository: authRepo,
      ));

      await tester.enterText(usernameField(), 'someoneelse');
      // Save before the debounce settles, forcing setUsername's own
      // re-check (the "race condition guard") to be what actually blocks
      // this -- not the debounce's status alone.
      // The header (WYN-024 R1's cover+avatar) plus every field added by
      // WYN-024 makes this form taller than the 800x600 default test
      // surface -- ensureVisible() scrolls the SingleChildScrollView so
      // the tap actually lands, instead of silently missing (see
      // create_club_screen_test.dart for the same pattern on another tall
      // form).
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(authRepo.setUsernameCalls, 1);
      expect(profileRepo.updateProfileCalls, 0);
      expect(profileRepo.uploadAvatarCalls, 0);
      expect(profileRepo.uploadCoverCalls, 0);

      // The debounce Timer from enterText() above is still pending at
      // this point (save happened before its 400ms elapsed) -- let it
      // fire so it doesn't leak past this test as a "Timer still
      // pending" failure.
      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  group('Cover + Avatar picker (WYN-024 R1)', () {
    setUp(() {
      ImagePickerPlatform.instance =
          FakeImagePickerPlatform(Uint8List.fromList(List.filled(8, 1)));
    });

    testWidgets('tapping the cover opens the same bottom sheet as the avatar',
        (tester) async {
      await tester.pumpWidget(buildScreen(
        profileRepository: RecordingProfileRepository(profile: profile),
        authRepository: RecordingAuthRepository(),
      ));

      await tester.tap(find.byKey(const Key('profile-cover-tap-target')));
      await tester.pumpAndSettle();

      expect(find.text('ถ่ายรูปใหม่'), findsOneWidget);
      expect(find.text('เลือกจากคลังภาพ'), findsOneWidget);
    });

    testWidgets(
        'picking a new cover photo previews it, and saving uploads it via '
        'ProfileRepository.uploadCover', (tester) async {
      final profileRepo = RecordingProfileRepository(profile: profile);

      await tester.pumpWidget(buildScreen(
        profileRepository: profileRepo,
        authRepository: RecordingAuthRepository(),
      ));

      await tester.tap(find.byKey(const Key('profile-cover-tap-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เลือกจากคลังภาพ'));
      await tester.pumpAndSettle();
      // The fake picker hands back placeholder bytes that aren't a real
      // image, so MemoryImage's async decode throws -- harmless here
      // since this test only cares that the picked bytes were wired into
      // an Image.memory, not that they render successfully. Same
      // takeException() posture drop_feed_screen_test.dart uses for
      // Image.network. See .wyn/learning/PATTERNS.md.
      tester.takeException();

      expect(find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
          findsOneWidget);

      // The header (WYN-024 R1's cover+avatar) plus every field added by
      // WYN-024 makes this form taller than the 800x600 default test
      // surface -- ensureVisible() scrolls the SingleChildScrollView so
      // the tap actually lands, instead of silently missing (see
      // create_club_screen_test.dart for the same pattern on another tall
      // form).
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(profileRepo.uploadCoverCalls, 1);
      expect(profileRepo.uploadAvatarCalls, 0);
      expect(profileRepo.updateProfileCalls, 1);
    });

    testWidgets(
        'picking a new avatar photo (not the cover) uploads it via '
        'ProfileRepository.uploadAvatar, and not uploadCover', (tester) async {
      final profileRepo = RecordingProfileRepository(profile: profile);

      await tester.pumpWidget(buildScreen(
        profileRepository: profileRepo,
        authRepository: RecordingAuthRepository(),
      ));

      await tester.tap(find.byKey(const Key('profile-avatar-tap-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เลือกจากคลังภาพ'));
      await tester.pumpAndSettle();
      // See the cover test above's identical comment -- the fake picker's
      // placeholder bytes aren't a real image, so the async decode throws
      // harmlessly.
      tester.takeException();

      // The header (WYN-024 R1's cover+avatar) plus every field added by
      // WYN-024 makes this form taller than the 800x600 default test
      // surface -- ensureVisible() scrolls the SingleChildScrollView so
      // the tap actually lands, instead of silently missing (see
      // create_club_screen_test.dart for the same pattern on another tall
      // form).
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(profileRepo.uploadAvatarCalls, 1);
      expect(profileRepo.uploadCoverCalls, 0);
    });

    testWidgets('renders the existing cover_url via ProfileCoverAvatar when '
        'nothing new has been picked', (tester) async {
      const withCover = Profile(
        id: 'u1',
        username: 'namfah',
        coverUrl: 'https://example.supabase.co/avatars/u1/cover.jpg',
      );

      await tester.pumpWidget(buildScreen(
        profileRepository: RecordingProfileRepository(profile: withCover),
        authRepository: RecordingAuthRepository(),
        screenProfile: withCover,
      ));
      // This test environment has no real network -- Image.network's
      // async fetch of coverUrl throws, harmlessly, since this test only
      // asserts the URL/callbacks were wired into ProfileCoverAvatar, not
      // that the image renders. Same posture as the tests above.
      tester.takeException();

      final coverAvatar = tester.widget<ProfileCoverAvatar>(
        find.byType(ProfileCoverAvatar),
      );
      expect(coverAvatar.coverUrl, withCover.coverUrl);
      expect(coverAvatar.onTapCover, isNotNull);
      expect(coverAvatar.onTapAvatar, isNotNull);
    });
  });
}
