import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/push/data/push_token_repository.dart';
import 'package:wyn/features/push/presentation/push_notification_service.dart';

/// A [PushNotificationService] whose permission answers are set by the
/// test rather than by a real Firebase app.
///
/// Extends the real class (rather than reimplementing an interface),
/// same shape as every other Recording*/Fake* double in this project:
/// the deep-link switch, the token registration and the platform
/// detection all stay the production ones, and only the two methods
/// that would reach `FirebaseMessaging.instance` are overridden.
///
/// Without this there is no way to exercise [PushPermissionCard]'s four
/// states at all -- in a widget test `Firebase.apps` is always empty, so
/// the real service answers `unsupported` to everything and the card
/// renders nothing.
class FakePushNotificationService extends PushNotificationService {
  FakePushNotificationService()
      : super(PushTokenRepository(Supabase.instance.client));

  /// What [currentPermissionState] reports.
  PushPermissionState currentState = PushPermissionState.notDetermined;

  /// What [requestPermissionAndRegister] resolves to -- i.e. what the
  /// person tapped in the OS dialog.
  PushPermissionState requestResult = PushPermissionState.granted;

  /// How many times the OS prompt was reached. The assertion that
  /// matters most in these tests is that this stays 0 until an explicit
  /// user action (Beta4 §11.2).
  int requestCalls = 0;

  /// When set, [currentPermissionState] waits on this instead of
  /// answering immediately -- so a test can hold the card in its
  /// still-loading state and assert it offers nothing yet.
  Completer<void>? holdCurrentState;

  @override
  Future<PushPermissionState> currentPermissionState() async {
    final hold = holdCurrentState;
    if (hold != null) await hold.future;
    return currentState;
  }

  /// What [collectDiagnostics] reports. Null means "answer from
  /// [currentState] with nothing else set", which is what a device with
  /// no Firebase app would really produce.
  PushDiagnostics? diagnostics;

  @override
  Future<PushDiagnostics> collectDiagnostics() async {
    return diagnostics ??
        PushDiagnostics(
          firebaseReady: false,
          webPushConfigured: false,
          permission: currentState,
        );
  }

  @override
  Future<PushPermissionState> requestPermissionAndRegister() async {
    requestCalls++;
    currentState = requestResult;
    return requestResult;
  }
}
