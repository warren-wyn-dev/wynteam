import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/auth/data/pending_referral_code.dart';
import 'package:wyn/features/auth/presentation/redeem_invite_code_screen.dart';

import 'support/recording_auth_repository.dart';

void main() {
  late RecordingAuthRepository authRepository;

  setUp(() {
    authRepository = RecordingAuthRepository();
    PendingReferralCode.resetForTest();
  });

  Widget buildScreen() => MaterialApp(
        home: RedeemInviteCodeScreen(authRepository: authRepository),
      );

  testWidgets('submitting an empty code shows a local error, never calls '
      'validateReferralCode', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.tap(find.text('ดำเนินการต่อ'));
    await tester.pump();

    expect(find.text('กรุณากรอกโค้ดเชิญ'), findsOneWidget);
    expect(authRepository.validateReferralCodeCalls, isEmpty);
  });

  testWidgets('an invalid code shows an error and does not pop',
      (tester) async {
    authRepository.validateReferralCodeResult = false;

    await tester.pumpWidget(buildScreen());
    await tester.enterText(
        find.byKey(const Key('invite_code_field')), 'BADCODE');
    await tester.tap(find.text('ดำเนินการต่อ'));
    await tester.pumpAndSettle();

    expect(find.text('โค้ดเชิญไม่ถูกต้อง'), findsOneWidget);
    expect(find.byType(RedeemInviteCodeScreen), findsOneWidget);
    expect(PendingReferralCode.hasValidatedCode, isFalse);
  });

  testWidgets(
      'a network error validating the code shows a retry-shaped error, '
      'not a false negative', (tester) async {
    authRepository.validateReferralCodeError = Exception('network error');

    await tester.pumpWidget(buildScreen());
    await tester.enterText(
        find.byKey(const Key('invite_code_field')), 'ANYCODE');
    await tester.tap(find.text('ดำเนินการต่อ'));
    await tester.pumpAndSettle();

    expect(find.text('เชื่อมต่อไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(PendingReferralCode.hasValidatedCode, isFalse);
  });

  testWidgets(
      'a valid code sets PendingReferralCode and pops true -- case as '
      'typed is sent through unchanged (the server side lower/upper-cases)',
      (tester) async {
    authRepository.validateReferralCodeResult = true;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) =>
                    RedeemInviteCodeScreen(authRepository: authRepository),
              ),
            );
            expect(result, isTrue);
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('invite_code_field')), 'GoodCode1');
    await tester.tap(find.text('ดำเนินการต่อ'));
    await tester.pumpAndSettle();

    expect(authRepository.validateReferralCodeCalls, ['GoodCode1']);
    expect(PendingReferralCode.hasValidatedCode, isTrue);
    expect(PendingReferralCode.consume(), 'GoodCode1');
  });
}
