import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/auth/data/onboarding_state.dart';
import 'package:wyn/features/auth/presentation/account_restricted_screen.dart';
import 'package:wyn/features/auth/presentation/auth_gate.dart';
import 'package:wyn/features/auth/presentation/onboarding/onboarding_flow.dart';
import 'package:wyn/features/auth/presentation/welcome_screen.dart';
import 'package:wyn/features/legal/presentation/document_acceptance_screen.dart';
import 'package:wyn/features/moderation/data/moderation_status.dart';
import 'package:wyn/features/root/presentation/root_shell.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_auth_repository.dart';
import 'support/recording_moderation_repository.dart';
import 'support/recording_platform_document_repository.dart';

User _fakeUser(String id, {bool isAnonymous = false}) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      isAnonymous: isAnonymous,
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
  //
  // RecordingPlatformDocumentRepository (WYN-046) is constructed once
  // here -- unlike RecordingModerationRepository/RecordingAuthRepository
  // below, which are built fresh per testWidgets body (each needing its
  // own independent session/status state, with autoRefreshToken: false
  // on their own SupabaseClient to avoid a leaked GoTrue Timer) -- this
  // repository holds no such per-test stream state, so it follows this
  // project's other convention instead: one SupabaseClient-wrapping
  // double built in setUpAll, its canned fields reassigned per test. See
  // .wyn/tasks/bugs/WYN-044-notification-settings-test-timer-leak-and-preference-leak.md.
  late RecordingPlatformDocumentRepository platformDocumentRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'restricted-user');
    platformDocumentRepository = RecordingPlatformDocumentRepository();
  });

  setUp(() {
    platformDocumentRepository.hasAcceptedResult = true;
    platformDocumentRepository.hasAcceptedError = null;
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
      'being signed out (session kept valid for a possible appeal), and '
      'never sees DocumentAcceptanceScreen even with incomplete '
      'acceptances (WYN-046 -- moderation check must win the ordering)',
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
    // Deliberately false -- this account would need the Acceptance Gate
    // if it weren't blocked first. Proves the moderation check really is
    // ordered *before* the document check, not just that both happen to
    // pass in the common case.
    platformDocumentRepository.hasAcceptedResult = false;

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authRepository: authRepository,
        moderationRepository: moderationRepository,
        platformDocumentRepository: platformDocumentRepository,
      ),
    ));
    await tester.pumpAndSettle();

    // No sign-out yet -- the whole point of WYN-030's reordering.
    expect(authRepository.signOutCalls, 0);
    expect(find.byType(AccountRestrictedScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(DocumentAcceptanceScreen), findsNothing);
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
    // onboardingStateResult: not completed (OnboardingFlow, not RootShell)
    // -- deliberately the lighter of the two "not blocked" outcomes: RootShell
    // mounts every Bottom Nav tab at once (IndexedStack, see
    // .wyn/company/CONTEXT.md's WYN-008 notes), which cascades into
    // real (against a fake project, failing) Supabase calls from several
    // other screens' own initState -- irrelevant noise for what this
    // test needs to prove (that the moderation gate itself let a
    // Restricted-only account through to the *next* check at all).
      )..onboardingStateResult = OnboardingState.notStarted();
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
        // hasAcceptedResult: true (setUp's default) -- this test isn't
        // about the Acceptance Gate, so it must pass through it
        // unnoticed to reach UsernameSetupScreen, same "irrelevant noise
        // for what this test needs to prove" reasoning as
        // hasUsernameResult above. Injected explicitly (rather than left
        // to AuthGate's own default) so this never makes a real network
        // call against the fake Supabase project.
        platformDocumentRepository: platformDocumentRepository,
      ),
    ));
    await tester.pumpAndSettle();

    // Restrict alone must never block login -- only Suspend/Ban do.
    expect(authRepository.signOutCalls, 0);
    expect(find.byType(AccountRestrictedScreen), findsNothing);
    expect(find.byType(DocumentAcceptanceScreen), findsNothing);
    expect(find.byType(OnboardingFlow), findsOneWidget);
  });

  // WYN-046 -- the Acceptance Gate itself: an account that is not
  // blocked but has NOT accepted the current version of the 3 mandatory
  // documents must see DocumentAcceptanceScreen instead of
  // UsernameSetupScreen/RootShell, proving the gate is positioned after
  // the moderation check (already covered above) and before the
  // username check.
  testWidgets(
      'an account with incomplete document acceptances sees '
      'DocumentAcceptanceScreen before UsernameSetupScreen/RootShell',
      (tester) async {
    final authRepository = RecordingAuthRepository(
      initialSession: _fakeSession('needs-acceptance-user'),
    )..onboardingStateResult = OnboardingState.notStarted();
    final moderationRepository = RecordingModerationRepository(
      myStatus: const ModerationStatus(
        isRestricted: false,
        isSuspended: false,
        isBanned: false,
      ),
    );
    platformDocumentRepository.hasAcceptedResult = false;

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authRepository: authRepository,
        moderationRepository: moderationRepository,
        platformDocumentRepository: platformDocumentRepository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AccountRestrictedScreen), findsNothing);
    expect(find.byType(DocumentAcceptanceScreen), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  // WYN-046 Product spec's Risks -- a transient load error checking
  // acceptance status must fail open (let the user through) rather than
  // lock the whole app out, same posture as the moderation status check.
  testWidgets(
      'a load error checking document acceptances fails open (does not '
      'block login)', (tester) async {
    final authRepository = RecordingAuthRepository(
      initialSession: _fakeSession('accept-check-error-user'),
    )..onboardingStateResult = OnboardingState.notStarted();
    final moderationRepository = RecordingModerationRepository(
      myStatus: const ModerationStatus(
        isRestricted: false,
        isSuspended: false,
        isBanned: false,
      ),
    );
    platformDocumentRepository.hasAcceptedError = Exception('network error');

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authRepository: authRepository,
        moderationRepository: moderationRepository,
        platformDocumentRepository: platformDocumentRepository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(DocumentAcceptanceScreen), findsNothing);
    expect(find.byType(OnboardingFlow), findsOneWidget);
  });

  // WYN-072 (Guest Browsing): a guest signed in via Anonymous Sign-In
  // ("เข้าชม WYNOS ได้เลย" on AuthMethodScreen) must land on RootShell
  // directly -- never OnboardingFlow -- even though
  // fetchOnboardingState would say not-completed for an account with no
  // `profiles` row at all. onboardingStateResult is deliberately left at
  // its "completed" default here and never asserted on: the whole point
  // is that AuthGate must not even reach that check for an anonymous
  // session.
  //
  // Bug fix (WYN-072-auth-gate-test-realtime-timer-leak): injects a
  // cheap keyed placeholder via rootShellBuilder instead of letting
  // AuthGate build a *real* RootShell -- a real RootShell's HomeFeedScreen
  // subscribes to a real Supabase Realtime channel (real HomeRepository,
  // no injection seam through AuthGate for it), which flutter_test's
  // automatic widget-tree teardown then disposes, scheduling a real 50s
  // RealtimeClient pending-disconnect Timer *after* the test body has
  // already returned -- there is no point in the test that could cancel
  // it, so `!timersPending` always failed at teardown even though every
  // assertion below had already passed. Actual behavior tested for the
  // real (non-anonymous) gate/guest destinations lives in
  // root_shell_guest_gate_test.dart instead, built directly against
  // RootShell with injected Recording* repositories (root_shell_test.dart's
  // own established pattern) -- this test's only job is to prove
  // *AuthGate's own branch decision*, which doesn't need RootShell's real
  // internals at all.
  testWidgets(
      'a guest (Anonymous Sign-In) skips Username Setup and lands on '
      'RootShell directly', (tester) async {
    final authRepository = RecordingAuthRepository(
      initialSession: Session(
        accessToken: 'fake-access-token',
        tokenType: 'bearer',
        user: _fakeUser('guest-user', isAnonymous: true),
      ),
    );
    final moderationRepository = RecordingModerationRepository(
      myStatus: const ModerationStatus(
        isRestricted: false,
        isSuspended: false,
        isBanned: false,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authRepository: authRepository,
        moderationRepository: moderationRepository,
        platformDocumentRepository: platformDocumentRepository,
        rootShellBuilder: (_) =>
            const SizedBox(key: Key('fake_root_shell')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingFlow), findsNothing);
    expect(find.byKey(const Key('fake_root_shell')), findsOneWidget);
    expect(find.byType(RootShell), findsNothing);
  });

  // Bug fix (2026-09-03 Beta2 review): this gate used to render only
  // `if (!snapshot.hasData) return _LoadingScreen()`, with no hasError
  // branch at all -- unlike the moderation-status and document-acceptance
  // gates above, which both fail open explicitly. A single transient
  // failure of fetchOnboardingState() therefore parked every signed-in
  // user on a spinner with nothing left in the tree to trigger a rebuild:
  // a permanent dead end for the whole app, not a slow load. Neither
  // fail-open nor fail-closed is safe here (see the branch's own comment
  // in auth_gate.dart), so it fails visibly with a retry instead.
  testWidgets(
      'a load error reading onboarding state shows a retry state instead of '
      'an indefinite spinner, and the retry really re-queries',
      (tester) async {
    final authRepository = RecordingAuthRepository(
      initialSession: _fakeSession('onboarding-check-error-user'),
    )..onboardingStateError = Exception('network error');
    final moderationRepository = RecordingModerationRepository(
      myStatus: const ModerationStatus(
        isRestricted: false,
        isSuspended: false,
        isBanned: false,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authRepository: authRepository,
        moderationRepository: moderationRepository,
        platformDocumentRepository: platformDocumentRepository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('เชื่อมต่อไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.text('ลองใหม่'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(OnboardingFlow), findsNothing);
    expect(find.byType(WelcomeScreen), findsNothing);

    // The recovery half: `future:` is re-created on every build, so the
    // retry's bare setState is a genuine re-query, not a no-op rebuild
    // of an already-failed Future. Lands on OnboardingFlow (rather than
    // RootShell) deliberately -- the completed: true path would reach
    // captureCurrentAccount and its real platform Keychain channel,
    // which is not what this test is about.
    authRepository
      ..onboardingStateError = null
      ..onboardingStateResult = OnboardingState.notStarted();

    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('เชื่อมต่อไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'), findsNothing);
    expect(find.byType(OnboardingFlow), findsOneWidget);
  });
}
