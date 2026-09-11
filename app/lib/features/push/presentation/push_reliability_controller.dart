import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/push_env.dart';
import '../data/push_token_repository.dart';
import 'push_notification_service.dart';

/// App-process safety net for push delivery.
///
/// [PushNotificationService] remains the source of truth for permission,
/// token registration, token refresh and push-tap routing. This controller
/// only closes two lifecycle gaps that are easy to hit on web/PWA:
///
/// 1. A user can grant notification permission in browser/OS settings while
///    WYNOS is already mounted. RootShell's one-time initialize call has
///    already happened by then, so no token is registered until a full app
///    restart. Re-running the existing service on auth changes and app resume
///    makes registration self-healing without prompting for permission.
/// 2. FCM deliberately does not display a system notification while the app
///    is in the foreground. The existing foreground listener refreshes the
///    unread badge only, so an incoming DM can otherwise be completely silent.
///    This controller shows a lightweight in-app banner for `new_message`.
///
/// It is process-wide and intentionally started once from `main.dart` after
/// Firebase initialization. No polling and no database/schema changes.
class PushReliabilityController with WidgetsBindingObserver {
  PushReliabilityController._();

  static final PushReliabilityController instance = PushReliabilityController._();

  static const Duration _foregroundBannerDuration = Duration(seconds: 4);

  bool _started = false;
  Future<void>? _repairInFlight;
  PushNotificationService? _repairService;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  bool get _pushRuntimeAvailable =>
      Firebase.apps.isNotEmpty && (!kIsWeb || PushEnv.isWebPushConfigured);

  /// Starts the process-wide reliability hooks. Safe to call more than once.
  void start() {
    if (_started) return;
    _started = true;

    if (!_pushRuntimeAvailable) return;

    final client = Supabase.instance.client;
    _repairService = PushNotificationService(PushTokenRepository(client));

    WidgetsBinding.instance.addObserver(this);

    _authSubscription = client.auth.onAuthStateChange.listen((state) {
      if (state.session?.user != null) _scheduleRegistrationRepair();
    });

    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Supabase may have restored a persisted session before start() runs.
    // Repair that account too instead of waiting for the next auth event.
    _scheduleRegistrationRepair();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleRegistrationRepair();
    }
  }

  void _scheduleRegistrationRepair() {
    if (_repairInFlight != null) return;
    if (Supabase.instance.client.auth.currentUser == null) return;
    final service = _repairService;
    if (service == null) return;

    _repairInFlight = _runRegistrationRepair(service);
  }

  Future<void> _runRegistrationRepair(PushNotificationService service) async {
    try {
      // initialize() never prompts. It only adopts an already-granted
      // permission and then re-upserts the current FCM token, so this is
      // safe on every resume/auth event and repairs a missing DB row.
      await service.initialize();
    } catch (_) {
      // Best effort: push must never block sign-in/resume or surface a
      // fatal UI error. The next auth event/resume gets another chance.
    } finally {
      _repairInFlight = null;
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showForegroundMessage(
      data: message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }

  void _showForegroundMessage({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) {
    // Keep this fix tightly scoped to the reported DM gap. Other foreground
    // notification types keep their existing in-app/badge behavior.
    if (data['type'] != 'new_message') return;

    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final safeTitle = title?.trim();
    final safeBody = body?.trim();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: _foregroundBannerDuration,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              safeTitle == null || safeTitle.isEmpty ? 'ข้อความใหม่' : safeTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              safeBody == null || safeBody.isEmpty
                  ? 'มีคนส่งข้อความถึงคุณ'
                  : safeBody,
            ),
          ],
        ),
      ),
    );
  }

  /// Test-only entry point for the foreground presentation path. Production
  /// reaches the same private method from FirebaseMessaging.onMessage.
  @visibleForTesting
  void debugShowForegroundMessage({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) {
    _showForegroundMessage(data: data, title: title, body: body);
  }

  /// Keeps analyzer from treating the subscriptions as accidental dead state;
  /// this singleton intentionally lives for the whole process and therefore has
  /// no production dispose path.
  @visibleForTesting
  bool get debugHasLiveSubscriptions =>
      _authSubscription != null || _foregroundSubscription != null;
}
