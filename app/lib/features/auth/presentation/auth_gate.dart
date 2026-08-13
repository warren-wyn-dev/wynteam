import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/presentation/home_screen.dart';
import '../data/auth_repository.dart';
import 'username_setup_screen.dart';
import 'welcome_screen.dart';

/// Decides which screen to show based on auth + onboarding state:
/// signed out -> Welcome, signed in without a username -> Username Setup,
/// fully onboarded -> Home. See .wyn/tasks/bugs/WYN-002-*.md.
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
    // WelcomeScreen/AuthMethodScreen/PhoneEntryScreen/OtpVerificationScreen
    // are pushed with Navigator.push on top of this route. When sign-in
    // actually completes -- from the OTP screen, or from an OAuth
    // deep-link callback that resolves after AuthMethodScreen started it --
    // pop back to this route so the user sees what AuthGate now renders
    // (UsernameSetupScreen or HomeScreen) instead of staying stuck on the
    // screen that started the sign-in.
    _authSubscription = _authRepository.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn && mounted) {
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
              return const HomeScreen();
            }
            return UsernameSetupScreen(
              authRepository: _authRepository,
              userId: session.user.id,
              // A saved username is a Postgres write, not a Supabase auth
              // event, so nothing else tells this widget to re-check and
              // switch to HomeScreen -- rebuilding here re-runs the
              // hasUsername() FutureBuilder above, which then returns
              // HomeScreen as AuthGate's own child (keeping this State,
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
