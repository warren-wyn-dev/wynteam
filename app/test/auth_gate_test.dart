import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/auth/presentation/account_restricted_screen.dart';
import 'package:wyn/features/auth/presentation/auth_gate.dart';
import 'package:wyn/features/auth/presentation/username_setup_screen.dart';
import 'package:wyn/features/auth/presentation/welcome_screen.dart';
import 'package:wyn/features/moderation/data/moderation_status.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_auth_repository.dart';
import 'support/recording_moderation_repository.dart';

User _fakeUser(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );

Session _fakeSession(String userId) => Session(
      accessToken: 'fake-access-token',
      tokenType: 'bearer',
      user: _fakeUser(userId),
    );

void main() {
  // RootShell (the "not blocked, logs in normally" path in the third
  // test below) reaches into Supabase.instance.client directly for its
  // own internal repositories -- independent of RecordingAuthRepository,
  // which never touches Supabase.instance at all.
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'restricted-user');
  });

  // WYN-029/WYN-030 -- Screen 6's own explicit "kับดัก" warning: a
  // Suspended/Banned account must see AccountRestrictedScreen and it
  // must STAY shown, not flash back to WelcomeScreen. WYN-030 changed
  // *how* this holds: AuthGate no longer signs the session out the
  // moment it detects the block (so submit_appeal() -- an authenticated
  // RPC -- can still succeed while this screen is up); signOut() only
  // fires when the user taps "ตกลง" (see the next test). This test now
  // proves the session is deliberately left alone while the screen is
  // showing, not that a sign-out survived.
  testWidgets(
      'a Suspended account signing in sees AccountRestrictedScreen without '
      'being signed out (session kept valid for a possible appeal)',
      (tester) async {
    final authRepository = RecordingAuthRepository(
      initialSession: _fakeSession('suspended-user'),
    );
    final moderationRepository = RecordingModerationRepository(
      myStatus: ModerationStatus(
        isRestricted: false,
        isSuspended: true,
        suspendReason: 'สแปม',
        suspendExpiresAt: DateTime.now().add(const Duration(days: 3)),
        isBanned: false,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authRepository: authRepository,
        moderationRepository: moderationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    // No sign-out yet -- the whole point of WYN-030's reordering.
    expect(authRepository.signOutCalls, 0);
    expect(find.byType(AccountRestrictedScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.text('บัญชีของคุณถูกระงับชั่วคราว'), findsOneWidget);

    // Pump extra frames -- AccountRestrictedScreen must still be the
    // only thing on screen, and still no sign-out, purely from the
    // passage of time/rebuilds with nothing tapped.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(authRepository.signOutCalls, 0);
    expect(find.byType(AccountRestrictedScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('tapping ตกลง on AccountRestrictedScreen returns to WelcomeScreen',
      (tester) async {
    final authRepository = RecordingAuthRepository(
      initialSession: _fakeSession('banned-user'),
    );
    final moderationRepository = RecordingModerationRepository(
      myStatus: const ModerationStatus(
        isRestricted: false,
        isSuspended: false,
        isBanned: true,
        banReason: 'ละเมิดกฎ',
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authRepository: authRepository,
        moderationRepository: moderationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('บัญชีของคุณถูกระงับถาวร'), findsOneWidget);
    // WYN-030: no sign-out yet -- it's deferred until "ตกลง" below.
    expect(authRepository.signOutCalls, 0);

    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    // "ตกลง" is what actually triggers the sign-out now.
    expect(authRepository.signOutCalls, 1);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(AccountRestrictedScreen), findsNothing);
  });

  testWidgets('a Restricted-only account (not Suspended/Banned) logs in normally',
      (tester) async {
    final authRepository = RecordingAuthRepository(
      initialSession: _fakeSession('restricted-user'),
    // hasUsernameResult: false (UsernameSetupScreen, not RootShell) --
    // deliberately the lighter of the two "not blocked" outcomes: RootShell
    // mounts every Bottom Nav tab at once (IndexedStack, see
    // .wyn/company/CONTEXT.md's WYN-008 notes), which cascades into
    // real (against a fake project, failing) Supabase calls from several
    // other screens' own initState -- irrelevant noise for what this
    // test needs to prove (that the moderation gate itself let a
    // Restricted-only account through to the *next* check at all).
      )..hasUsernameResult = false;
    final moderationRepository = RecordingModerationRepository(
      myStatus: ModerationStatus(
        isRestricted: true,
        restrictReason: 'สแปม',
        restrictExpiresAt: DateTime.now().add(const Duration(days: 1)),
        isSuspended: false,
        isBanned: false,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authRepository: authRepository,
        moderationRepository: moderationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    // Restrict alone must never block login -- only Suspend/Ban do.
    expect(authRepository.signOutCalls, 0);
    expect(find.byType(AccountRestrictedScreen), findsNothing);
    expect(find.byType(UsernameSetupScreen), findsOneWidget);
  });
}
