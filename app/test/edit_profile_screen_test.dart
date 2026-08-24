import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/data/profile_repository.dart';
import 'package:wyn/features/profile/presentation/edit_profile_screen.dart';

import 'support/recording_profile_repository.dart';

void main() {
  // SupabaseClient() only stores config here -- no network call happens
  // until a method is invoked, so it's safe to construct in a widget test.
  // None of the cases below tap "บันทึก", so no network call is made.
  final profileRepository =
      ProfileRepository(SupabaseClient('https://example.supabase.co', 'test-key'));

  const profile = Profile(
    id: 'u1',
    username: 'namfah',
    displayName: 'น้ำฝน',
    bio: 'สวัสดีค่ะ',
  );

  // One shared instance across the username group's tests below (not
  // constructed inline per testWidgets, and not inside a group() body --
  // must sit at this same top level as `profileRepository` above) --
  // same "avoid a leaked GoTrue auto-refresh timer, avoid constructing a
  // SupabaseClient outside an established test zone" discipline as every
  // other RecordingXRepository in this project's test suite
  // (.wyn/learning/PATTERNS.md).
  final recordingRepo = RecordingProfileRepository(profile: profile);

  testWidgets('pre-fills display name and bio from the existing profile',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditProfileScreen(
        profileRepository: profileRepository,
        profile: profile,
      ),
    ));

    expect(find.text('น้ำฝน'), findsOneWidget);
    expect(find.text('สวัสดีค่ะ'), findsOneWidget);
    expect(find.text('9/160'), findsOneWidget);
  });

  testWidgets('bio counter updates as the user types', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditProfileScreen(
        profileRepository: profileRepository,
        profile: profile,
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Bio'), 'a' * 20);
    await tester.pump();

    expect(find.text('20/160'), findsOneWidget);
  });

  testWidgets('bio counter turns error-colored near the character limit',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditProfileScreen(
        profileRepository: profileRepository,
        profile: profile,
      ),
    ));

    final bioField = find.widgetWithText(TextField, 'Bio');
    await tester.enterText(bioField, 'a' * 150);
    await tester.pump();

    final field = tester.widget<TextField>(bioField);
    final theme = Theme.of(tester.element(bioField));
    expect(field.decoration?.counterStyle?.color, theme.colorScheme.error);
  });

  group('editable @username (WYNOS V1.0.0 Beta requirement 5)', () {
    setUp(() {
      recordingRepo.takenUsernames = {};
      recordingRepo.updateProfileArgs.clear();
      recordingRepo.updateUsernameArgs.clear();
    });

    testWidgets('pre-fills the username field with the current @username',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(
          profileRepository: recordingRepo,
          profile: profile,
        ),
      ));

      expect(find.widgetWithText(TextField, 'ชื่อผู้ใช้'), findsOneWidget);
      expect(find.text('namfah'), findsOneWidget);
    });

    testWidgets(
        'typing back the exact same username never triggers an '
        'availability check and keeps "บันทึก" enabled', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(
          profileRepository: recordingRepo,
          profile: profile,
        ),
      ));

      final usernameField = find.widgetWithText(TextField, 'ชื่อผู้ใช้');
      await tester.enterText(usernameField, 'namfah');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ชื่อผู้ใช้นี้ถูกใช้แล้ว'), findsNothing);
      final saveButton = find.widgetWithText(FilledButton, 'บันทึก');
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    });

    testWidgets('an invalid format (too short) shows an error and '
        'disables "บันทึก"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(
          profileRepository: recordingRepo,
          profile: profile,
        ),
      ));

      await tester.enterText(
          find.widgetWithText(TextField, 'ชื่อผู้ใช้'), 'ab');
      await tester.pump();

      expect(find.text('รูปแบบไม่ถูกต้อง'), findsOneWidget);
      final saveButton = find.widgetWithText(FilledButton, 'บันทึก');
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    });

    testWidgets('a new, available username shows a check icon after the '
        'debounce', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(
          profileRepository: recordingRepo,
          profile: profile,
        ),
      ));

      await tester.enterText(
          find.widgetWithText(TextField, 'ชื่อผู้ใช้'), 'wynos');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      final saveButton = find.widgetWithText(FilledButton, 'บันทึก');
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    });

    testWidgets('a taken username shows an error and disables "บันทึก"',
        (tester) async {
      recordingRepo.takenUsernames = {'wynos'};
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(
          profileRepository: recordingRepo,
          profile: profile,
        ),
      ));

      await tester.enterText(
          find.widgetWithText(TextField, 'ชื่อผู้ใช้'), 'wynos');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ชื่อผู้ใช้นี้ถูกใช้แล้ว'), findsOneWidget);
      final saveButton = find.widgetWithText(FilledButton, 'บันทึก');
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    });

    testWidgets(
        'saving with a changed, available username calls updateUsername '
        'and pops with the new username', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(
          profileRepository: recordingRepo,
          profile: profile,
        ),
      ));

      await tester.enterText(
          find.widgetWithText(TextField, 'ชื่อผู้ใช้'), 'wynos');
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
      await tester.pumpAndSettle();

      expect(recordingRepo.updateUsernameArgs, ['wynos']);
      expect(recordingRepo.updateProfileArgs, hasLength(1));
    });

    testWidgets('saving without touching the username never calls '
        'updateUsername', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(
          profileRepository: recordingRepo,
          profile: profile,
        ),
      ));

      await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
      await tester.pumpAndSettle();

      expect(recordingRepo.updateUsernameArgs, isEmpty);
      expect(recordingRepo.updateProfileArgs, hasLength(1));
    });
  });
}
