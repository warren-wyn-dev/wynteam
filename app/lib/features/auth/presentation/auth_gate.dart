import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/presentation/home_screen.dart';
import '../data/auth_repository.dart';
import 'username_setup_screen.dart';
import 'welcome_screen.dart';

/// Decides which screen to show based on auth + onboarding state:
/// signed out -> Welcome, signed in without a username -> Username Setup,
/// fully onboarded -> Home. See .wyn/tasks/active/WYN-002-*.md.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final _authRepository = AuthRepository(Supabase.instance.client);

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
