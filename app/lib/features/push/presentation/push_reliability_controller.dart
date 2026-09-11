import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/push_env.dart';
import '../data/push_token_repository.dart';
import 'push_notification_service.dart';

/// App-process safety net for DM notification delivery.
///
/// [PushNotificationService] remains the source of truth for browser/OS push:
/// permission, token registration, token refresh and push-tap routing. This
/// controller closes two separate lifecycle gaps:
///
/// 1. A user can grant notification permission in browser/OS settings while
///    WYNOS is already mounted. Re-running the existing service on auth changes
///    and app resume makes token registration self-healing without prompting.
/// 2. A visible WYNOS tab must not depend on browser notification permission at
///    all. `public.messages` is already in Supabase Realtime and its SELECT RLS
///    limits delivery to conversation participants, so a process-wide INSERT
///    subscription can show an in-app DM banner even when this account has no
///    FCM token. Browser/OS push remains responsible for background/closed-app
///    delivery when permission is granted.
///
/// The realtime path is deliberately independent from Firebase. That matters
/// for the exact broken state this class is meant to repair: a signed-in user
/// with notification permission denied/not-yet-granted still receives an
/// in-app banner while actively using WYNOS.
class PushReliabilityController with WidgetsBindingObserver {
  PushReliabilityController._();

  static final PushReliabilityController instance = PushReliabilityController._();

  static const Duration _foregroundBannerDuration = Duration(seconds: 4);

  bool _started = false;
  Future<void>? _repairInFlight;
  SupabaseClient? _client;
  PushNotificationService? _repairService;
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _dmChannel;
  String? _dmChannelUserId;

  bool get _pushRuntimeAvailable =>
      Firebase.apps.isNotEmpty && (!kIsWeb || PushEnv.isWebPushConfigured);

  /// Starts the process-wide reliability hooks. Safe to call more than once.
  void start() {
    if (_started) return;
    _started = true;

    final client = Supabase.instance.client;
    _client = client;

    // The in-app Realtime banner must work even when Firebase/Web Push is not
    // configured or permission is unavailable. Push-token repair is optional.
    if (_pushRuntimeAvailable) {
      _repairService = PushNotificationService(PushTokenRepository(client));
    }

    WidgetsBinding.instance.addObserver(this);

    _authSubscription = client.auth.onAuthStateChange.listen((state) {
      final userId = state.session?.user.id;
      _syncDmChannel(userId);
      if (userId != null) _scheduleRegistrationRepair();
    });

    // Supabase may have restored a persisted session before start() runs.
    final restoredUserId = client.auth.currentUser?.id;
    _syncDmChannel(restoredUserId);
    if (restoredUserId != null) _scheduleRegistrationRepair();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleRegistrationRepair();
    }
  }

  /// Keeps one RLS-scoped process-wide INSERT subscription bound to the
  /// currently signed-in account. Account-switch races are guarded twice:
  /// the old channel is removed and its callback also checks that the account
  /// which created it is still the active account before showing anything.
  void _syncDmChannel(String? userId) {
    final client = _client;
    if (client == null) return;

    if (_dmChannelUserId == userId && (_dmChannel != null || userId == null)) {
      return;
    }

    final previous = _dmChannel;
    _dmChannel = null;
    _dmChannelUserId = userId;
    if (previous != null) {
      unawaited(client.removeChannel(previous));
    }

    if (userId == null) return;

    final channel = client.channel('push-reliability-dm-$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final senderId = payload.newRecord['sender_id'] as String?;
            if (senderId == null) return;
            _handleIncomingRealtimeDm(
              senderId: senderId,
              subscribedUserId: userId,
              activeUserId: client.auth.currentUser?.id,
            );
          },
        )
        .subscribe();
    _dmChannel = channel;
  }

  void _scheduleRegistrationRepair() {
    if (_repairInFlight != null) return;
    if (_client?.auth.currentUser == null) return;
    final service = _repairService;
    if (service == null) return;

    _repairInFlight = _runRegistrationRepair(service);
  }

  Future<void> _runRegistrationRepair(PushNotificationService service) async {
    try {
      // initialize() never prompts. It only adopts an already-granted
      // permission and then re-upserts the current FCM token, so this is safe
      // on every resume/auth event and repairs a missing DB row.
      await service.initialize();
    } catch (_) {
      // Best effort: push must never block sign-in/resume or surface a fatal UI
      // error. The next auth event/resume gets another chance.
    } finally {
      _repairInFlight = null;
    }
  }

  void _handleIncomingRealtimeDm({
    required String senderId,
    required String subscribedUserId,
    required String? activeUserId,
  }) {
    // Ignore the realtime echo of this user's own send. Also ignore an event
    // from an old account's channel during the tiny async account-switch
    // unsubscribe window.
    if (activeUserId != subscribedUserId || senderId == subscribedUserId) {
      return;
    }

    _showForegroundMessage(
      data: const {'type': 'new_message'},
      title: 'ข้อความใหม่',
      body: 'มีคนส่งข้อความถึงคุณ',
    );
  }

  void _showForegroundMessage({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) {
    // Keep this fix tightly scoped to DM. Other notification types keep their
    // existing in-app/badge behavior.
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

  /// Test-only entry point for the presentation path.
  @visibleForTesting
  void debugShowForegroundMessage({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) {
    _showForegroundMessage(data: data, title: title, body: body);
  }

  /// Test-only entry point for Realtime account/sender filtering.
  @visibleForTesting
  void debugHandleIncomingRealtimeDm({
    required String senderId,
    required String subscribedUserId,
    required String? activeUserId,
  }) {
    _handleIncomingRealtimeDm(
      senderId: senderId,
      subscribedUserId: subscribedUserId,
      activeUserId: activeUserId,
    );
  }

  /// This singleton intentionally lives for the whole process and therefore has
  /// no production dispose path.
  @visibleForTesting
  bool get debugHasLiveSubscriptions =>
      _authSubscription != null || _dmChannel != null;
}
