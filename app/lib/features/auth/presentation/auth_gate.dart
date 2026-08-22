import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../moderation/data/moderation_repository.dart';
import '../../moderation/data/moderation_status.dart';
import '../../push/data/push_token_repository.dart';
import '../../push/presentation/push_notification_service.dart';
import '../../root/presentation/root_shell.dart';
import '../data/auth_repository.dart';
import 'account_restricted_screen.dart';
import 'username_setup_screen.dart';
import 'welcome_screen.dart';

/// Decides which screen to show based on auth + onboarding state:
/// signed out -> Welcome, signed in but Suspended/Banned -> Account
/// Restricted (WYN-029, checked *before* the username check below --
/// see the design doc's Screen 6), signed in without a username ->
/// Username Setup, fully onboarded -> RootShell (the Home/Drop/Pop/
/// Profile Bottom Nav from "WYN V0.1 — CORE APP FEATURE PROMPT", see
/// .wyn/company/DECISIONS.md 2026-08-14 — replaces the old single-screen
/// FeedScreen from WYN-004).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authRepository, this.moderationRepository});

  // Both optional -- default to real Supabase-backed instances (see
  // _AuthGateState's late finals below), same "existing call sites
  // don't need to thread one through" shape as every other optional
  // repository param in this app. Tests inject Recording* fakes here
  // instead of touching Supabase.instance/a real GoTrue backend --
  // WYN-029, needed specifically to exercise the sign-out race this
  // screen's own comments describe without a live Supabase project.
  final AuthRepository? authRepository;
  final ModerationRepository? moderationRepository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository(Supabase.instance.client);
  late final ModerationRepository _moderationRepository =
      widget.moderationRepository ?? ModerationRepository(Supabase.instance.client);
  late final StreamSubscription<AuthState> _authSubscription;

  // Set exactly once per sign-in (by the auth listener below, or by
  // initState if a session already exists at cold start) -- read by
  // build()'s FutureBuilder, never recreated on every rebuild, same
  // "cache the Future, don't refetch on every build" convention every
  // other screen's `_loadFuture` field already follows.
  Future<ModerationStatus>? _moderationStatusFuture;

  // Guards _handleBlockedLogin from being kicked off more than once per
  // detected block -- build() can run many times while its one async
  // sign-out is still in flight.
  bool _isHandlingBlockedLogin = false;

  // THE TRAP (see .wyn/docs/design/wyn-029-moderation-queue.md, Screen
  // 6): once this is non-null, build() must render AccountRestrictedScreen
  // unconditionally, checked *before* looking at the auth stream's
  // session at all. If build() instead derived "blocked" from session
  // state directly, the moment _handleBlockedLogin's signOut() call
  // completes, the StreamBuilder below rebuilds with session == null and
  // would flash straight to WelcomeScreen -- the auth listener's own
  // `popUntil(isFirst)` doesn't save this, because that only pops routes
  // *pushed on top of* AuthGate, not AuthGate's own build() output. This
  // field is local State, set with setState only after signOut()
  // actually finishes, and cleared only when the user taps "ตกลง".
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
    // AuthGate now renders (UsernameSetupScreen/RootShell on sign-in,
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

  /// Signs the blocked session out for real (best-effort push-token
  /// deregistration first, same posture as ViewProfileScreen._signOut),
  /// then -- only once that's actually finished -- records the block
  /// locally so build() can render AccountRestrictedScreen without ever
  /// racing the sign-out's own auth-state event.
  Future<void> _handleBlockedLogin(ModerationStatus status) async {
    try {
      await PushNotificationService(PushTokenRepository(Supabase.instance.client))
          .unregisterCurrentDevice();
    } catch (_) {
      // Intentionally silent -- see ViewProfileScreen._signOut.
    }
    await _authRepository.signOut();
    if (!mounted) return;
    setState(() {
      _blockedInfo = _BlockedLoginInfo(
        isBanned: status.isBanned,
        reason: status.isBanned ? status.banReason : status.suspendReason,
        expiresAt: status.isBanned ? null : status.suspendExpiresAt,
      );
      _isHandlingBlockedLogin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final blockedInfo = _blockedInfo;
    if (blockedInfo != null) {
      return AccountRestrictedScreen(
        isBanned: blockedInfo.isBanned,
        reason: blockedInfo.reason,
        expiresAt: blockedInfo.expiresAt,
        onAcknowledge: () => setState(() => _blockedInfo = null),
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
              future: _authRepository.hasUsername(session.user.id),
              builder: (context, usernameSnapshot) {
                if (!usernameSnapshot.hasData) {
                  return const _LoadingScreen();
                }
                if (usernameSnapshot.data == true) {
                  return const RootShell();
                }
                return UsernameSetupScreen(
                  authRepository: _authRepository,
                  userId: session.user.id,
                  // A saved username is a Postgres write, not a Supabase auth
                  // event, so nothing else tells this widget to re-check and
                  // switch to RootShell -- rebuilding here re-runs the
                  // hasUsername() FutureBuilder above, which then returns
                  // RootShell as AuthGate's own child (keeping this State,
                  // and its auth-state subscription, alive for logout to
                  // keep working).
                  onUsernameSet: () => setState(() {}),
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
  });

  final bool isBanned;
  final String? reason;
  final DateTime? expiresAt;
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
