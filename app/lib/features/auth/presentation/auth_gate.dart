import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../root/presentation/root_shell.dart';
import '../data/auth_repository.dart';
import 'username_setup_screen.dart';
import 'welcome_screen.dart';

/// Decides which screen to show based on auth + onboarding state:
/// signed out -> Welcome, signed in without a username -> Username Setup,
/// fully onboarded -> RootShell (the Home/Drop/Pop/Profile Bottom Nav
/// from "WYN V0.1 — CORE APP FEATURE PROMPT", see
/// .wyn/company/DECISIONS.md 2026-08-14 — replaces the old single-screen
/// FeedScreen from WYN-004).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final _authRepository = AuthRepository(Supabase.instance.client);
  late final StreamSubscription<AuthState> _authSubscription;

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
      final isRelevant = state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.signedOut;
      if (isRelevant && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authRepository.authStateChanges,
      builder: (context, snapshot) {
        final session = _authRepository.currentSession;

        if (session == null) {
          return WelcomeScreen(authRepository: _authRepository);
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
  }
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
