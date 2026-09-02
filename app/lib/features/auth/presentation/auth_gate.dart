import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../legal/data/platform_document_repository.dart';
import '../../legal/presentation/document_acceptance_screen.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../moderation/data/appeal_status.dart';
import '../../moderation/data/moderation_repository.dart';
import '../../moderation/data/moderation_status.dart';
import '../../moderation/presentation/appeal_form_screen.dart';
import '../../push/data/push_token_repository.dart';
import '../../push/presentation/push_notification_service.dart';
import '../../root/presentation/root_shell.dart';
import '../data/auth_repository.dart';
import '../data/onboarding_state.dart';
import 'account_restricted_screen.dart';
import 'onboarding/onboarding_flow.dart';
import 'welcome_screen.dart';

/// Decides which screen to show based on auth + onboarding state:
/// signed out -> Welcome, signed in but Suspended/Banned -> Account
/// Restricted (WYN-029, checked *before* the onboarding check below --
/// see the design doc's Screen 6), signed in but missing acceptance of
/// a current mandatory platform document -> Document Acceptance
/// (WYN-046, checked *after* the moderation check above and *before*
/// the onboarding check below -- applies uniformly to brand-new and
/// existing users alike, per that task's Product spec), signed in but
/// onboarding not yet complete -> OnboardingFlow (First Login /
/// Account Onboarding: Birthday -> Username -> Display Name ->
/// Password -> Profile Optional -> Finish, resumable -- see
/// .wyn/docs/design/wyn-002-authentication-onboarding.md and
/// AuthRepository.fetchOnboardingState), fully onboarded -> RootShell
/// (the Home/Drop/Pop/Profile Bottom Nav from "WYN V0.1 — CORE APP
/// FEATURE PROMPT", see .wyn/company/DECISIONS.md 2026-08-14 —
/// replaces the old single-screen FeedScreen from WYN-004).
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authRepository,
    this.moderationRepository,
    this.appealRepository,
    this.platformDocumentRepository,
    this.rootShellBuilder,
  });

  // All optional -- default to real Supabase-backed instances (see
  // _AuthGateState's late finals below), same "existing call sites
  // don't need to thread one through" shape as every other optional
  // repository param in this app. Tests inject Recording* fakes here
  // instead of touching Supabase.instance/a real GoTrue backend --
  // WYN-029, needed specifically to exercise the sign-out race this
  // screen's own comments describe without a live Supabase project.
  final AuthRepository? authRepository;
  final ModerationRepository? moderationRepository;

  // Same shape again -- WYN-030's appeal entry point on
  // AccountRestrictedScreen.
  final AppealRepository? appealRepository;

  // Same shape again -- WYN-046's Acceptance Gate.
  final PlatformDocumentRepository? platformDocumentRepository;

  // Bug fix (WYN-072-auth-gate-test-realtime-timer-leak): unlike the
  // repositories above, RootShell itself was hardcoded (`const
  // RootShell()`), so a test exercising the "guest reaches RootShell"
  // branch always got the *real* RootShell -- all-default,
  // Supabase.instance-backed repositories, including a real
  // HomeRepository whose HomeFeedScreen subscribes to a real Realtime
  // channel. flutter_test's automatic widget-tree teardown at test end
  // then calls HomeFeedScreen.dispose() -> unsubscribe(), which schedules
  // a real 50s RealtimeClient pending-disconnect Timer *after* the test
  // body has already returned control to the framework -- there is no
  // point in the test where that Timer could be cancelled or flushed, so
  // `!timersPending` always fails. Injectable the same way as every
  // other dependency above so a test can swap in a cheap placeholder
  // (e.g. a keyed SizedBox) instead of a real RootShell, without needing
  // to touch AuthGate's own decision logic at all.
  final Widget Function()? rootShellBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository(Supabase.instance.client);
  late final ModerationRepository _moderationRepository =
      widget.moderationRepository ?? ModerationRepository(Supabase.instance.client);
  late final AppealRepository _appealRepository =
      widget.appealRepository ?? AppealRepository(Supabase.instance.client);
  late final Widget Function() _buildRootShell =
      widget.rootShellBuilder ?? () => const RootShell();
  late final PlatformDocumentRepository _platformDocumentRepository =
      widget.platformDocumentRepository ??
          PlatformDocumentRepository(Supabase.instance.client);
  late final StreamSubscription<AuthState> _authSubscription;

  // Set exactly once per sign-in (by the auth listener below, or by
  // initState if a session already exists at cold start) -- read by
  // build()'s FutureBuilder, never recreated on every rebuild, same
  // "cache the Future, don't refetch on every build" convention every
  // other screen's `_loadFuture` field already follows.
  Future<ModerationStatus>? _moderationStatusFuture;

  // Guards _handleBlockedLogin from being kicked off more than once per
  // detected block -- build() can run many times while its one async
  // gap (see _handleBlockedLogin) is still in flight.
  bool _isHandlingBlockedLogin = false;

  // THE TRAP (see .wyn/docs/design/wyn-029-moderation-queue.md, Screen
  // 6): once this is non-null, build() must render AccountRestrictedScreen
  // unconditionally, checked *before* looking at the auth stream's
  // session at all. If build() instead derived "blocked" from session
  // state directly, the StreamBuilder below would flash straight to
  // WelcomeScreen the instant a rebuild saw session == null -- the auth
  // listener's own `popUntil(isFirst)` doesn't save this, because that
  // only pops routes *pushed on top of* AuthGate, not AuthGate's own
  // build() output.
  //
  // WYN-030: the session is deliberately still valid while this is
  // non-null (see _handleBlockedLogin's doc comment) -- signOut() only
  // happens in _leaveBlockedScreen, in the *same* setState call that
  // clears this field, so the session-null flash to WelcomeScreen lands
  // exactly when the user actually leaves, not before.
  _BlockedLoginInfo? _blockedInfo;

  @override
  void initState() {
    super.initState();
    // Every other screen in the app (auth flow screens, ViewProfileScreen,
    // CreateDropScreen, DropDetailScreen, ...) is pushed with
    // Navigator.push on top of this route. Whenever the session actually
    // starts or ends -- from the OTP screen, an OAuth deep-link callback,
    // or a logout button buried in a pushed screen like
    // ViewProfileScreen -- pop back to this route so the user sees what
    // AuthGate now renders (OnboardingFlow/RootShell on sign-in,
    // WelcomeScreen on sign-out) instead of staying stuck on the screen
    // that triggered the change. See .wyn/learning/MISTAKES.md.
    _authSubscription = _authRepository.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        _moderationStatusFuture = _moderationRepository.fetchMyStatus();
      }
      final isRelevant = state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.signedOut;
      if (isRelevant && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    if (_authRepository.currentSession != null) {
      _moderationStatusFuture = _moderationRepository.fetchMyStatus();
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  /// Records the block locally so build() can render
  /// AccountRestrictedScreen without ever racing an auth-state event.
  ///
  /// WYN-030: unlike before, this no longer signs the session out. The
  /// session (JWT) is deliberately left valid while AccountRestrictedScreen
  /// is showing, so submit_appeal() -- an authenticated RPC -- can still
  /// succeed for a Suspended/Banned user. This is *not* a change to the
  /// auth/RLS security boundary: Suspend/Ban only ever blocked INSERT at
  /// the RLS layer (supabase/schema.sql), never READ, so a valid token
  /// held a little longer doesn't expose anything a signed-in-but-blocked
  /// user couldn't already reach before this feature existed. The actual
  /// sign-out is deferred to _leaveBlockedScreen, fired only when the user
  /// taps "ตกลง" (see build() below). See
  /// .wyn/docs/design/wyn-030-appeal-system.md, Screen 3.
  Future<void> _handleBlockedLogin(ModerationStatus status) async {
    // One async gap so this setState doesn't run synchronously inside
    // build() itself (this is fired unawaited from the FutureBuilder
    // below) -- there's no longer a signOut() call here to provide that
    // gap for free.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    setState(() {
      _blockedInfo = _BlockedLoginInfo(
        isBanned: status.isBanned,
        reason: status.isBanned ? status.banReason : status.suspendReason,
        expiresAt: status.isBanned ? null : status.suspendExpiresAt,
        actionId: status.isBanned ? status.banActionId : status.suspendActionId,
        appealStatus:
            status.isBanned ? status.banAppealStatus : status.suspendAppealStatus,
      );
      _isHandlingBlockedLogin = false;
    });
  }

  /// The actual sign-out, deferred from _handleBlockedLogin above --
  /// fired when the user taps "ตกลง" on AccountRestrictedScreen, whether
  /// or not they appealed first. Best-effort push-token deregistration
  /// first, same posture as ViewProfileScreen._signOut.
  Future<void> _leaveBlockedScreen() async {
    try {
      await PushNotificationService(PushTokenRepository(Supabase.instance.client))
          .unregisterCurrentDevice();
    } catch (_) {
      // Intentionally silent -- see ViewProfileScreen._signOut.
    }
    await _authRepository.signOut();
    if (!mounted) return;
    setState(() => _blockedInfo = null);
  }

  /// Opens AppealFormScreen for the currently-blocked action. On a
  /// successful submit, flips the local appealStatus to `pending` in
  /// place -- no need to re-fetch ModerationStatus, since a successful
  /// submit_appeal() call is exactly what that status would now show.
  Future<void> _openAppealFromBlocked() async {
    final info = _blockedInfo;
    if (info == null || info.actionId == null) return;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppealFormScreen(
          appealRepository: _appealRepository,
          actionId: info.actionId!,
          actionLabel: info.isBanned ? 'ระงับถาวร (Ban)' : 'ระงับชั่วคราว (Suspend)',
        ),
      ),
    );
    if (submitted == true && mounted) {
      setState(() {
        _blockedInfo = _BlockedLoginInfo(
          isBanned: info.isBanned,
          reason: info.reason,
          expiresAt: info.expiresAt,
          actionId: info.actionId,
          appealStatus: AppealStatus.pending,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockedInfo = _blockedInfo;
    if (blockedInfo != null) {
      return AccountRestrictedScreen(
        isBanned: blockedInfo.isBanned,
        reason: blockedInfo.reason,
        expiresAt: blockedInfo.expiresAt,
        onAcknowledge: _leaveBlockedScreen,
        actionId: blockedInfo.actionId,
        appealStatus: blockedInfo.appealStatus,
        onAppeal: blockedInfo.actionId == null ? null : _openAppealFromBlocked,
      );
    }

    return StreamBuilder<AuthState>(
      stream: _authRepository.authStateChanges,
      builder: (context, snapshot) {
        final session = _authRepository.currentSession;

        if (session == null) {
          return WelcomeScreen(authRepository: _authRepository);
        }

        return FutureBuilder<ModerationStatus>(
          future: _moderationStatusFuture,
          builder: (context, statusSnapshot) {
            // Fails open on a transient load error -- a network hiccup
            // checking moderation status must never itself become a way
            // to lock every user out of the app; the RLS-level
            // enforcement (supabase/schema.sql) still applies regardless
            // of what this screen shows.
            final status = statusSnapshot.data;
            if (status == null && !statusSnapshot.hasError) {
              return const _LoadingScreen();
            }

            if (status != null && status.blocksLogin) {
              if (!_isHandlingBlockedLogin) {
                _isHandlingBlockedLogin = true;
                unawaited(_handleBlockedLogin(status));
              }
              return const _LoadingScreen();
            }

            return FutureBuilder<bool>(
              future: _platformDocumentRepository.hasAcceptedMandatoryDocuments(),
              builder: (context, acceptanceSnapshot) {
                // Fails open on a transient load error -- same "never lock
                // the whole app out over a network hiccup" reasoning as the
                // moderation status check above. Product's Risks explicitly
                // chose fail-open over fail-closed for this gate too: there
                // are no real production users yet for a stricter posture
                // to meaningfully protect, and RLS still enforces the real
                // acceptance requirement independent of what this screen
                // shows (WYN-046 Product spec).
                final hasAccepted = acceptanceSnapshot.data;
                if (hasAccepted == null && !acceptanceSnapshot.hasError) {
                  return const _LoadingScreen();
                }

                if (hasAccepted == false) {
                  return DocumentAcceptanceScreen(
                    platformDocumentRepository: _platformDocumentRepository,
                    // Same "rendered as AuthGate's own route, re-run the
                    // FutureBuilder above on rebuild" reasoning as
                    // UsernameSetupScreen.onUsernameSet below -- this
                    // FutureBuilder's `future` is re-created fresh on every
                    // build (not cached in a field), so a bare setState here
                    // re-queries hasAcceptedMandatoryDocuments() and moves
                    // on once it now returns true.
                    onAccepted: () => setState(() {}),
                  );
                }

                // WYN-072 (Guest Browsing): a guest (Anonymous Sign-In,
                // see AuthMethodScreen's "เข้าชม WYNOS ได้เลย") skips
                // Username Setup entirely and lands straight on Home --
                // asking a guest to pick a username first would defeat
                // the point of "browse without logging in". A guest's
                // `profiles` row is never created at all (not just
                // missing a username); every screen that would normally
                // read it is gated behind requireRealAccount() (see
                // guest_gate.dart) before the guest can reach it, and
                // RootShell's own eager IndexedStack build of
                // ViewProfileScreen for the guest's own (nonexistent)
                // profile already fails open into that screen's own
                // error state rather than crashing (its own
                // snapshot.hasError branch) -- confirmed by reading
                // view_profile_screen.dart, not assumed.
                if (session.user.isAnonymous) {
                  return _buildRootShell();
                }

                return FutureBuilder<OnboardingState>(
                  future: _authRepository.fetchOnboardingState(session.user),
                  builder: (context, onboardingSnapshot) {
                    if (!onboardingSnapshot.hasData) {
                      return const _LoadingScreen();
                    }
                    final onboardingState = onboardingSnapshot.data!;
                    if (onboardingState.completed) {
                      return _buildRootShell();
                    }
                    return OnboardingFlow(
                      authRepository: _authRepository,
                      user: session.user,
                      initialState: onboardingState,
                      // Completing onboarding is a Postgres write, not a
                      // Supabase auth event, so nothing else tells this
                      // widget to re-check and switch to RootShell --
                      // rebuilding here re-runs the fetchOnboardingState()
                      // FutureBuilder above, which then returns RootShell
                      // as AuthGate's own child (keeping this State, and
                      // its auth-state subscription, alive for logout to
                      // keep working). Same shape as the old
                      // UsernameSetupScreen.onUsernameSet under WYN-002.
                      onCompleted: () => setState(() {}),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _BlockedLoginInfo {
  const _BlockedLoginInfo({
    required this.isBanned,
    required this.reason,
    required this.expiresAt,
    required this.actionId,
    required this.appealStatus,
  });

  final bool isBanned;
  final String? reason;
  final DateTime? expiresAt;
  final String? actionId;
  final AppealStatus appealStatus;
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
