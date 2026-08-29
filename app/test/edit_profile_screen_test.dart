import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/core/design/wyn_colors.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/data/profile_repository.dart';
import 'package:wyn/features/profile/presentation/edit_profile_screen.dart';

import 'support/recording_profile_repository.dart';

/// Every text field lives inside a private `_ProfileField` now
/// (06-edit-profile.tsx's label-above/hairline-underline layout, not a
/// Material `InputDecoration` box), so its label text is a sibling of
/// the `TextField`, not a descendant of it -- `find.widgetWithText
/// (TextField, ...)` can no longer find these. Each field carries its
/// own `Key` instead; these helpers keep every test call site short.
Finder _field(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(TextField),
    );

final _usernameField = _field('username_field');
final _displayNameField = _field('display_name_field');
final _bioField = _field('bio_field');

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
  });

  // 06-edit-profile.tsx: the helper text + live character counter only
  // reveal once the field is focused (an animated show/hide), not
  // permanently visible the way Material's own InputDecoration counter
  // was -- so this now taps into the field first.
  testWidgets(
      'bio counter shows the pre-filled length once the field is focused',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditProfileScreen(
        profileRepository: profileRepository,
        profile: profile,
      ),
    ));

    expect(find.text('9/160'), findsNothing);
    await tester.tap(_bioField);
    await tester.pump();

    expect(find.text('9/160'), findsOneWidget);
  });

  testWidgets('bio counter updates as the user types', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditProfileScreen(
        profileRepository: profileRepository,
        profile: profile,
      ),
    ));

    await tester.tap(_bioField);
    await tester.enterText(_bioField, 'a' * 20);
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

    await tester.tap(_bioField);
    await tester.enterText(_bioField, 'a' * 150);
    await tester.pump();

    final counter = tester.widget<Text>(find.text('150/160'));
    expect(counter.style?.color, WynColors.errorLight);
  });

  testWidgets('"บันทึก" starts disabled and enables once something '
      'actually changes (06-edit-profile.tsx)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditProfileScreen(
        profileRepository: profileRepository,
        profile: profile,
      ),
    ));

    final saveButton = find.widgetWithText(FilledButton, 'บันทึก');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.enterText(_bioField, 'bio ใหม่');
    await tester.pump();

    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
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

      expect(_usernameField, findsOneWidget);
      expect(find.text('namfah'), findsOneWidget);
    });

    testWidgets(
        'typing back the exact same username never triggers an '
        'availability check, and "บันทึก" stays disabled (no real change)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(
          profileRepository: recordingRepo,
          profile: profile,
        ),
      ));

      await tester.enterText(_usernameField, 'namfah');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ชื่อผู้ใช้นี้ถูกใช้แล้ว'), findsNothing);
      final saveButton = find.widgetWithText(FilledButton, 'บันทึก');
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    });

    testWidgets('an invalid format (too short) shows an error and '
        'disables "บันทึก"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(
          profileRepository: recordingRepo,
          profile: profile,
        ),
      ));

      await tester.enterText(_usernameField, 'ab');
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

      await tester.enterText(_usernameField, 'wynos');
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

      await tester.enterText(_usernameField, 'wynos');
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

      await tester.enterText(_usernameField, 'wynos');
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
      await tester.pumpAndSettle();

      expect(recordingRepo.updateUsernameArgs, ['wynos']);
      expect(recordingRepo.updateProfileArgs, hasLength(1));
    });

    testWidgets(
        'saving after changing only the display name never calls '
        'updateUsername', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(
          profileRepository: recordingRepo,
          profile: profile,
        ),
      ));

      await tester.enterText(_displayNameField, 'ชื่อใหม่');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
      await tester.pumpAndSettle();

      expect(recordingRepo.updateUsernameArgs, isEmpty);
      expect(recordingRepo.updateProfileArgs, hasLength(1));
    });
  });
}
