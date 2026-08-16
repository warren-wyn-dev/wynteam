import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/auth/presentation/seller_auth_gate.dart';
import 'package:zoky_seller/features/auth/presentation/seller_sign_in_screen.dart';
import 'package:zoky_seller/features/auth/presentation/username_setup_screen.dart';
import 'package:zoky_seller/features/shell/presentation/seller_home_shell.dart';
import 'package:zoky_seller/features/store/data/store.dart';
import 'package:zoky_seller/features/store/presentation/create_store_screen.dart';

import 'support/fake_session.dart';
import 'support/recording_seller_auth_repository.dart';
import 'support/recording_seller_notification_repository.dart';
import 'support/recording_seller_repository.dart';

final _store = Store(
  id: 'store-1',
  ownerId: 'u1',
  name: 'ร้านทดสอบ',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  // Constructed in setUp(), never inline inside a testWidgets callback --
  // each Recording*Repository wraps a real (throwaway) SupabaseClient,
  // whose GoTrueClient starts an auto-refresh Timer.periodic at
  // construction time. Building it inline inside testWidgets creates
  // that Timer *after* the test's fake-async zone is already
  // established, which flutter_test's binding then flags as "A Timer
  // is still pending even after the widget tree was disposed" when the
  // test ends. See .wyn/learning/PATTERNS.md / MISTAKES.md (ZOKY-002).
  late RecordingSellerAuthRepository signedOutAuth;
  late RecordingSellerAuthRepository noUsernameAuth;
  late RecordingSellerAuthRepository onboardedAuth;
  late RecordingSellerRepository noStoreRepo;
  late RecordingSellerRepository withStoreRepo;
  late RecordingSellerNotificationRepository notificationRepo;

  setUp(() {
    signedOutAuth = RecordingSellerAuthRepository(session: null);
    noUsernameAuth = RecordingSellerAuthRepository(
      session: fakeSession(),
      hasUsernameResult: false,
    );
    onboardedAuth = RecordingSellerAuthRepository(session: fakeSession());
    noStoreRepo = RecordingSellerRepository(myStore: null);
    withStoreRepo = RecordingSellerRepository(myStore: _store);
    notificationRepo = RecordingSellerNotificationRepository();
  });

  testWidgets('signed out shows SellerSignInScreen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerAuthGate(
        authRepository: signedOutAuth,
        sellerRepository: noStoreRepo,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SellerSignInScreen), findsOneWidget);
  });

  testWidgets(
      'signed in without a profiles row shows UsernameSetupScreen even '
      'when a store already exists', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerAuthGate(
        authRepository: noUsernameAuth,
        sellerRepository: withStoreRepo,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(UsernameSetupScreen), findsOneWidget);
    expect(find.byType(CreateStoreScreen), findsNothing);
    expect(find.byType(SellerHomeShell), findsNothing);
  });

  testWidgets(
      'onboarded seller without a store sees CreateStoreScreen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerAuthGate(
        authRepository: onboardedAuth,
        sellerRepository: noStoreRepo,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CreateStoreScreen), findsOneWidget);
    expect(find.byType(SellerHomeShell), findsNothing);
  });

  testWidgets('onboarded seller with a store goes straight to SellerHomeShell',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerAuthGate(
        authRepository: onboardedAuth,
        sellerRepository: withStoreRepo,
        notificationRepository: notificationRepo,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SellerHomeShell), findsOneWidget);
    expect(find.byType(CreateStoreScreen), findsNothing);
    // 1 seller -> 1 store: SellerHomeShell must receive the exact store
    // SellerAuthGate resolved, not re-fetch/guess.
    final shell = tester.widget<SellerHomeShell>(find.byType(SellerHomeShell));
    expect(shell.store.id, 'store-1');
  });
}
