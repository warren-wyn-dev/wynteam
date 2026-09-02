import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/auth/data/onboarding_state.dart';
import 'package:wyn/features/auth/presentation/onboarding/onboarding_flow.dart';
import 'package:wyn/features/auth/presentation/onboarding/steps/birthday_step.dart';
import 'package:wyn/features/auth/presentation/onboarding/steps/display_name_step.dart';
import 'package:wyn/features/auth/presentation/onboarding/steps/finish_step.dart';
import 'package:wyn/features/auth/presentation/onboarding/steps/password_step.dart';
import 'package:wyn/features/auth/presentation/onboarding/steps/profile_optional_step.dart';
import 'package:wyn/features/auth/presentation/onboarding/steps/username_step.dart';
import 'package:wyn/features/profile/data/profile_repository.dart';

import 'support/recording_auth_repository.dart';

User _fakeUser({
  Map<String, dynamic> userMetadata = const {},
  Map<String, dynamic> appMetadata = const {},
}) =>
    User(
      id: 'user-1',
      appMetadata: appMetadata,
      userMetadata: userMetadata,
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );

// Same "SupabaseClient() only stores config, makes no network calls until
// a method is invoked" reasoning as email_auth_screen_test.dart -- lets
// ProfileOptionalStep's uploadAvatar callback exist without ever touching
// Supabase.instance (which nothing in this file initializes).
ProfileRepository _fakeProfileRepository() =>
    ProfileRepository(SupabaseClient('https://example.supabase.co', 'test-key'));

Future<void> _fillBirthday(
  WidgetTester tester, {
  required String day,
  required String month,
  required String year,
}) async {
  await tester.enterText(find.byKey(const Key('birthday_dd_field')), day);
  await tester.enterText(find.byKey(const Key('birthday_mm_field')), month);
  await tester.enterText(find.byKey(const Key('birthday_yyyy_field')), year);
  await tester.pump();
}

String _pad(int n) => n.toString().padLeft(2, '0');

void main() {
  late RecordingAuthRepository authRepository;

  setUp(() {
    authRepository = RecordingAuthRepository();
  });

  Widget buildFlow(
    OnboardingState state, {
    User? user,
    VoidCallback? onCompleted,
  }) =>
      MaterialApp(
        home: OnboardingFlow(
          authRepository: authRepository,
          user: user ?? _fakeUser(),
          initialState: state,
          onCompleted: onCompleted ?? () {},
          profileRepository: _fakeProfileRepository(),
        ),
      );

  testWidgets('a brand-new user starts at Birthday (New User flow, step 1)',
      (tester) async {
    await tester.pumpWidget(buildFlow(OnboardingState.notStarted()));
    expect(find.byType(BirthdayStep), findsOneWidget);
  });

  group('Birthday', () {
    testWidgets('rejects a future date', (tester) async {
      await tester.pumpWidget(buildFlow(OnboardingState.notStarted()));

      final future = DateTime.now().add(const Duration(days: 2));
      await _fillBirthday(
        tester,
        day: _pad(future.day),
        month: _pad(future.month),
        year: future.year.toString(),
      );
      await tester.tap(find.text('ดำเนินการต่อ'));
      await tester.pump();

      expect(find.text('วันเกิดต้องไม่ใช่วันที่ในอนาคต'), findsOneWidget);
      expect(authRepository.setDateOfBirthCalls, isEmpty);
      expect(find.byType(BirthdayStep), findsOneWidget);
    });

    testWidgets('rejects an under-13 date (age restriction)', (tester) async {
      await tester.pumpWidget(buildFlow(OnboardingState.notStarted()));

      final now = DateTime.now();
      final tooYoung = DateTime(now.year - 5, now.month, now.day);
      await _fillBirthday(
        tester,
        day: _pad(tooYoung.day),
        month: _pad(tooYoung.month),
        year: tooYoung.year.toString(),
      );
      await tester.tap(find.text('ดำเนินการต่อ'));
      await tester.pump();

      expect(find.textContaining('อายุอย่างน้อย'), findsOneWidget);
      expect(authRepository.setDateOfBirthCalls, isEmpty);
    });

    testWidgets('rejects an invalid calendar date', (tester) async {
      await tester.pumpWidget(buildFlow(OnboardingState.notStarted()));

      await _fillBirthday(tester, day: '31', month: '02', year: '2000');
      await tester.tap(find.text('ดำเนินการต่อ'));
      await tester.pump();

      expect(find.text('กรุณากรอกวันเกิดให้ถูกต้อง'), findsOneWidget);
      expect(authRepository.setDateOfBirthCalls, isEmpty);
    });

    testWidgets('accepts a valid date and advances to Username', (tester) async {
      await tester.pumpWidget(buildFlow(OnboardingState.notStarted()));

      await _fillBirthday(tester, day: '15', month: '06', year: '2000');
      await tester.tap(find.text('ดำเนินการต่อ'));
      await tester.pumpAndSettle();

      expect(authRepository.setDateOfBirthCalls, hasLength(1));
      expect(authRepository.setDateOfBirthCalls.single,
          DateTime(2000, 6, 15));
      expect(find.byType(UsernameStep), findsOneWidget);
    });
  });

  group('Username', () {
    OnboardingState afterBirthday() => const OnboardingState(
          hasDateOfBirth: true,
          username: null,
          displayName: null,
          hasPassword: false,
          completed: false,
        );

    testWidgets('flags a taken username and does not submit', (tester) async {
      await tester.pumpWidget(buildFlow(afterBirthday()));
      authRepository.usernameAvailableResult = false;

      await tester.enterText(
          find.byKey(const Key('onboarding_username_field')), 'taken');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ชื่อผู้ใช้นี้ถูกใช้แล้ว'), findsOneWidget);
      final button =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'ดำเนินการต่อ'));
      expect(button.onPressed, isNull);
    });

    testWidgets('flags an invalid format', (tester) async {
      await tester.pumpWidget(buildFlow(afterBirthday()));

      await tester.enterText(
          find.byKey(const Key('onboarding_username_field')), 'a');
      await tester.pump();

      expect(find.text('รูปแบบไม่ถูกต้อง'), findsOneWidget);
    });

    testWidgets('normalizes to lowercase and submits once available',
        (tester) async {
      await tester.pumpWidget(buildFlow(afterBirthday()));

      await tester.enterText(
          find.byKey(const Key('onboarding_username_field')), 'Worapon');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ชื่อผู้ใช้นี้ถูกใช้แล้ว'), findsNothing);
      await tester.tap(find.text('ดำเนินการต่อ'));
      await tester.pumpAndSettle();

      expect(authRepository.setUsernameCalls, ['worapon']);
      expect(find.byType(DisplayNameStep), findsOneWidget);
    });

    testWidgets('Back returns to Birthday', (tester) async {
      await tester.pumpWidget(buildFlow(afterBirthday()));
      await tester.tap(find.byKey(const Key('onboarding_back_button')));
      await tester.pumpAndSettle();
      expect(find.byType(BirthdayStep), findsOneWidget);
    });
  });

  testWidgets(
      'Display Name pre-fills from the Google account name and can be edited',
      (tester) async {
    const state = OnboardingState(
      hasDateOfBirth: true,
      username: 'worapon',
      displayName: null,
      hasPassword: false,
      completed: false,
    );
    await tester.pumpWidget(
      buildFlow(state, user: _fakeUser(userMetadata: {'full_name': 'Worapon P'})),
    );

    expect(find.text('Worapon P'), findsOneWidget);

    await tester.tap(find.text('ดำเนินการต่อ'));
    await tester.pumpAndSettle();

    expect(authRepository.setDisplayNameCalls, ['Worapon P']);
    expect(find.byType(PasswordStep), findsOneWidget);
  });

  group('Password', () {
    const stateNeedingPassword = OnboardingState(
      hasDateOfBirth: true,
      username: 'worapon',
      displayName: 'Worapon',
      hasPassword: false,
      completed: false,
    );

    testWidgets('is skipped entirely when the account already has a password',
        (tester) async {
      const state = OnboardingState(
        hasDateOfBirth: true,
        username: 'worapon',
        displayName: 'Worapon',
        hasPassword: true,
        completed: false,
      );
      await tester.pumpWidget(buildFlow(state));

      expect(find.byType(PasswordStep), findsNothing);
      expect(find.byType(ProfileOptionalStep), findsOneWidget);
    });

    testWidgets('Continue stays disabled until length and match are both satisfied',
        (tester) async {
      await tester.pumpWidget(buildFlow(stateNeedingPassword));

      await tester.enterText(
          find.byKey(const Key('onboarding_password_field')), '123');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'ดำเนินการต่อ'))
            .onPressed,
        isNull,
        reason: 'too short',
      );

      await tester.enterText(
          find.byKey(const Key('onboarding_password_field')), 'abcdef12');
      await tester.enterText(
          find.byKey(const Key('onboarding_confirm_password_field')), 'abcdef13');
      await tester.pump();
      expect(find.text('รหัสผ่านไม่ตรงกัน'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'ดำเนินการต่อ'))
            .onPressed,
        isNull,
        reason: 'mismatched',
      );

      await tester.enterText(
          find.byKey(const Key('onboarding_confirm_password_field')), 'abcdef12');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'ดำเนินการต่อ'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('submits and advances to Profile Optional', (tester) async {
      await tester.pumpWidget(buildFlow(stateNeedingPassword));

      await tester.enterText(
          find.byKey(const Key('onboarding_password_field')), 'abcdef12');
      await tester.enterText(
          find.byKey(const Key('onboarding_confirm_password_field')), 'abcdef12');
      await tester.pump();
      await tester.tap(find.text('ดำเนินการต่อ'));
      await tester.pumpAndSettle();

      expect(authRepository.setPasswordCalls, ['abcdef12']);
      expect(find.byType(ProfileOptionalStep), findsOneWidget);
    });
  });

  group('Profile Optional / Finish', () {
    const stateBeforeProfile = OnboardingState(
      hasDateOfBirth: true,
      username: 'worapon',
      displayName: 'Worapon',
      hasPassword: true,
      completed: false,
    );

    testWidgets('Skip never blocks -- reaches Finish without a bio', (tester) async {
      await tester.pumpWidget(buildFlow(stateBeforeProfile));

      await tester.tap(find.text('ข้ามขั้นตอนนี้'));
      await tester.pumpAndSettle();

      expect(authRepository.saveOptionalProfileCalls, 1);
      expect(authRepository.lastSavedBio, isNull);
      expect(find.byType(FinishStep), findsOneWidget);
    });

    testWidgets('Continue saves a typed bio', (tester) async {
      await tester.pumpWidget(buildFlow(stateBeforeProfile));

      await tester.enterText(
          find.byKey(const Key('onboarding_bio_field')), 'Hello WYNOS');
      await tester.tap(find.text('ต่อไป'));
      await tester.pumpAndSettle();

      expect(authRepository.saveOptionalProfileCalls, 1);
      expect(authRepository.lastSavedBio, 'Hello WYNOS');
      expect(find.byType(FinishStep), findsOneWidget);
    });

    testWidgets(
        'entering WYNOS on Finish completes onboarding and fires onCompleted',
        (tester) async {
      var completed = false;
      await tester.pumpWidget(
        buildFlow(stateBeforeProfile, onCompleted: () => completed = true),
      );

      await tester.tap(find.text('ข้ามขั้นตอนนี้'));
      await tester.pumpAndSettle();
      expect(find.byType(FinishStep), findsOneWidget);

      await tester.tap(find.text('เข้าสู่ WYNOS'));
      await tester.pump();

      expect(authRepository.completeOnboardingCalls, 1);
      expect(completed, isTrue);
    });
  });

  testWidgets(
      'Interrupted Onboarding: resumes at Display Name when Birthday/Username '
      'are already saved but Display Name is not', (tester) async {
    const state = OnboardingState(
      hasDateOfBirth: true,
      username: 'worapon',
      displayName: null,
      hasPassword: false,
      completed: false,
    );
    await tester.pumpWidget(buildFlow(state));

    expect(find.byType(BirthdayStep), findsNothing);
    expect(find.byType(UsernameStep), findsNothing);
    expect(find.byType(DisplayNameStep), findsOneWidget);
  });
}
