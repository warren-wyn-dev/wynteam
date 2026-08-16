import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../notification/data/seller_notification_repository.dart';
import '../../push/presentation/push_notification_service.dart';
import '../../shell/presentation/seller_home_shell.dart';
import '../../store/data/seller_repository.dart';
import '../../store/presentation/create_store_screen.dart';
import '../data/seller_auth_repository.dart';
import 'seller_sign_in_screen.dart';
import 'username_setup_screen.dart';

/// Decides which screen to show based on auth + onboarding + store
/// state. Mirrors `app/lib/features/auth/presentation/auth_gate.dart`
/// (WYN Social's `AuthGate`) exactly for the auth/onboarding part, plus
/// one extra layer that checks whether the signed-in user already
/// registered a store:
///
///   1. signed out                         -> SellerSignInScreen
///   2. signed in, no `profiles` row yet    -> UsernameSetupScreen
///   3. onboarded, no `stores` row yet      -> CreateStoreScreen
///   4. onboarded + has a store             -> SellerHomeShell
///
/// See .wyn/docs/design/seller-001-foundation.md, Screen:
/// SellerAuthGate.
///
/// [authRepository]/[sellerRepository] are optional constructor
/// injection points (defaulting to wrapping `Supabase.instance.client`,
/// same as production use) purely so this widget's branching can be
/// exercised in a widget test with a `RecordingSellerAuthRepository`/
/// `RecordingSellerRepository` -- `app/`'s `AuthGate` couldn't be
/// tested this way (see .wyn/learning/MISTAKES.md, WYN-002) because it
/// always constructs its own `AuthRepository` internally; this is a
/// small, scoped improvement that only affects this new app.
class SellerAuthGate extends StatefulWidget {
  const SellerAuthGate({
    super.key,
    SellerAuthRepository? authRepository,
    SellerRepository? sellerRepository,
    SellerNotificationRepository? notificationRepository,
    PushNotificationService? pushNotificationService,
  })  : _authRepository = authRepository,
        _sellerRepository = sellerRepository,
        _notificationRepository = notificationRepository,
        _pushNotificationService = pushNotificationService;

  final SellerAuthRepository? _authRepository;
  final SellerRepository? _sellerRepository;

  /// Threaded straight through to `SellerHomeShell` -- same optional
  /// constructor-injection point, for the same reason (see that
  /// widget's own doc comment).
  final SellerNotificationRepository? _notificationRepository;

  /// Same reasoning, threaded straight through (WYN-016).
  final PushNotificationService? _pushNotificationService;

  @override
  State<SellerAuthGate> createState() => _SellerAuthGateState();
}

class _SellerAuthGateState extends State<SellerAuthGate> {
  late final SellerAuthRepository _authRepository =
      widget._authRepository ?? SellerAuthRepository(Supabase.instance.client);
  late final SellerRepository _sellerRepository =
      widget._sellerRepository ?? SellerRepository(Supabase.instance.client);
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Same reasoning as AuthGate: every other screen in this app is
    // pushed with Navigator.push on top of this route. Whenever the
    // session actually starts or ends, pop back to this route so the
    // user sees what SellerAuthGate now renders instead of staying
    // stuck on the screen that triggered the change. See
    // .wyn/learning/MISTAKES.md.
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
          return SellerSignInScreen(authRepository: _authRepository);
        }

        return FutureBuilder<bool>(
          future: _authRepository.hasUsername(session.user.id),
          builder: (context, usernameSnapshot) {
            if (!usernameSnapshot.hasData) {
              return const _LoadingScreen();
            }
            if (usernameSnapshot.data != true) {
              return UsernameSetupScreen(
                authRepository: _authRepository,
                userId: session.user.id,
                // A saved username is a Postgres write, not a Supabase
                // auth event, so nothing else tells this widget to
                // re-check -- rebuilding here re-runs the
                // hasUsername() FutureBuilder above (see AuthGate's
                // identical comment for why this keeps this State,
                // and its auth-state subscription, alive).
                onUsernameSet: () => setState(() {}),
              );
            }

            return FutureBuilder(
              future: _sellerRepository.fetchMyStore(),
              builder: (context, storeSnapshot) {
                // Store? legitimately resolves to null (no store yet)
                // -- checking connectionState instead of hasData here
                // is deliberate, since AsyncSnapshot.hasData is just
                // "data != null" and would spin forever for a seller
                // who genuinely has no store (same bug class fixed in
                // ZOKY-001's StoreScreen -- see .wyn/company/
                // CONTEXT.md, ZOKY-001 entry).
                if (storeSnapshot.connectionState != ConnectionState.done) {
                  return const _LoadingScreen();
                }

                final store = storeSnapshot.data;
                if (store == null) {
                  return CreateStoreScreen(
                    sellerRepository: _sellerRepository,
                    onStoreCreated: () => setState(() {}),
                  );
                }

                return SellerHomeShell(
                  store: store,
                  sellerRepository: _sellerRepository,
                  notificationRepository: widget._notificationRepository,
                  pushNotificationService: widget._pushNotificationService,
                );
              },
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
