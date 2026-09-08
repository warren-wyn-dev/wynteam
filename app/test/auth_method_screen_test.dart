import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/auth/data/pending_referral_code.dart';
import 'package:wyn/features/auth/presentation/auth_method_screen.dart';
import 'package:wyn/features/auth/presentation/redeem_invite_code_screen.dart';

import 'support/recording_auth_repository.dart';

/// WYN-113 (Invite-Only Access Gate): AuthMethodScreen checks
/// `isInviteGateEnabled()` once on mount and, while the gate is on and
/// no code has been redeemed yet this app session, replaces the real
/// sign-in buttons (Google/Apple/Email/Phone) with a single "กรอกโค้ดเชิญ"
/// prompt -- see auth_method_screen.dart's own doc comment on why the
/// guest-browse button is deliberately NOT behind this check.
void main() {
  late RecordingAuthRepository authRepository;

  setUp(() {
    authRepository = RecordingAuthRepository();
    PendingReferralCode.resetForTest();
  });

  Widget buildScreen({bool isAddingAccount = false}) => MaterialApp(
        home: AuthMethodScreen(
          authRepository: authRepository,
          isAddingAccount: isAddingAccount,
        ),
      );

  testWidgets(
      'gate off (default): the real sign-in buttons show immediately, '
      'no redeem prompt', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
    expect(find.text('กรอกโค้ดเชิญ'), findsNothing);
  });

  testWidgets(
      'gate on, no code redeemed yet: the redeem prompt shows instead of '
      'the real sign-in buttons', (tester) async {
    authRepository.inviteGateEnabledResult = true;

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('กรอกโค้ดเชิญ'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsNothing);
    // The guest-browse button would be deliberately unaffected by the
    // gate if it were on -- moot right now since it's disabled entirely
    // (Founder, 2026-09-08). See _guestBrowsingEnabled.
    expect(find.text('เข้าชม WYNOS ได้เลย'), findsNothing);
  });

  testWidgets(
      'a transient error checking the gate fails open -- the real '
      'sign-in buttons still show, not stuck on a spinner',
      (tester) async {
    authRepository.inviteGateEnabledError = Exception('network error');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
    expect(find.text('กรอกโค้ดเชิญ'), findsNothing);
  });

  testWidgets(
      'adding a second account never checks the gate at all -- the real '
      'sign-in buttons show even though the gate is genuinely on',
      (tester) async {
    authRepository.inviteGateEnabledResult = true;

    await tester.pumpWidget(buildScreen(isAddingAccount: true));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
    expect(find.text('กรอกโค้ดเชิญ'), findsNothing);
    // isAddingAccount already hides the guest-browse button today --
    // unrelated to this gate, just confirming nothing about that
    // changed.
    expect(find.text('เข้าชม WYNOS ได้เลย'), findsNothing);
  });

  testWidgets(
      'a code already validated before this screen mounted (e.g. a deep '
      'link flow) skips the prompt even though the gate is on',
      (tester) async {
    authRepository.inviteGateEnabledResult = true;
    PendingReferralCode.set('PRESET1');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
    expect(find.text('กรอกโค้ดเชิญ'), findsNothing);
  });

  testWidgets(
      'tapping กรอกโค้ดเชิญ opens RedeemInviteCodeScreen, and a valid code '
      'reveals the real sign-in buttons on return',
      (tester) async {
    authRepository.inviteGateEnabledResult = true;
    authRepository.validateReferralCodeResult = true;

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('กรอกโค้ดเชิญ'));
    await tester.pumpAndSettle();

    expect(find.byType(RedeemInviteCodeScreen), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('invite_code_field')), 'GOODCODE');
    await tester.tap(find.text('ดำเนินการต่อ'));
    await tester.pumpAndSettle();

    expect(find.byType(RedeemInviteCodeScreen), findsNothing);
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
    expect(authRepository.validateReferralCodeCalls, ['GOODCODE']);
    expect(PendingReferralCode.hasValidatedCode, isTrue);
  });

  testWidgets(
      'backing out of RedeemInviteCodeScreen without a valid code keeps '
      'the prompt showing', (tester) async {
    authRepository.inviteGateEnabledResult = true;

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('กรอกโค้ดเชิญ'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('กรอกโค้ดเชิญ'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsNothing);
  });
}
