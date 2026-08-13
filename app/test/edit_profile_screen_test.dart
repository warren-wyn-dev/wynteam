import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/data/profile_repository.dart';
import 'package:wyn/features/profile/presentation/edit_profile_screen.dart';

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
}
