import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/push_env.dart';
import '../../../core/text_utils.dart';
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
/// The foreground banner resolves the sender's profile and uses the exact
/// message row delivered by Realtime, so it can say who sent the DM and what
/// they sent without routing the DM through the general notification center.
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
            final record = Map<String, dynamic>.from(payload.newRecord);
            final senderId = record['sender_id'] as String?;
            if (senderId == null) return;
            unawaited(
              _handleIncomingRealtimeDm(
                record: record,
                senderId: senderId,
                subscribedUserId: userId,
              ),
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

  Future<void> _handleIncomingRealtimeDm({
    required Map<String, dynamic> record,
    required String senderId,
    required String subscribedUserId,
  }) async {
    final client = _client;
    if (client == null) return;

    // Ignore the realtime echo of this user's own send. Also ignore an event
    // from an old account's channel during the tiny async account-switch
    // unsubscribe window.
    if (client.auth.currentUser?.id != subscribedUserId ||
        senderId == subscribedUserId) {
      return;
    }

    final preview = _dmPreview(record);
    final senderName = await _senderName(senderId);

    // The profile lookup above is asynchronous. Re-check the account after it
    // completes so a fast account switch cannot surface the old account's DM.
    if (client.auth.currentUser?.id != subscribedUserId) return;

    _showForegroundMessage(
      data: const {'type': 'new_message'},
      title: senderName,
      body: preview,
    );
  }

  Future<String> _senderName(String senderId) async {
    final client = _client;
    if (client == null) return 'ข้อความใหม่';

    try {
      final profile = await client
          .from('profiles')
          .select('username, display_name')
          .eq('id', senderId)
          .maybeSingle();
      if (profile == null) return 'ข้อความใหม่';

      final username = profile['username'] as String?;
      if (username == null || username.isEmpty) return 'ข้อความใหม่';
      return displayNameOrUsername(
        displayName: profile['display_name'] as String?,
        username: username,
      );
    } catch (_) {
      // A failed profile lookup must never suppress the actual DM alert.
      return 'ข้อความใหม่';
    }
  }

  String _dmPreview(Map<String, dynamic> record) {
    final text = (record['text'] as String?)?.trim();
    if (text != null && text.isNotEmpty) return text;

    if (record['image_url'] != null) {
      return record['view_once'] == true
          ? 'ส่งรูปภาพแบบดูครั้งเดียว'
          : 'ส่งรูปภาพ';
    }

    switch (record['shared_content_type'] as String?) {
      case 'drop':
        return 'แชร์โพสต์กับคุณ';
      case 'profile':
        return 'แชร์โปรไฟล์กับคุณ';
      case 'club':
        return 'แชร์ Club กับคุณ';
      default:
        return 'ส่งข้อความถึงคุณ';
    }
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
                  ? 'ส่งข้อความถึงคุณ'
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

  /// Test-only entry point for Realtime presentation/filtering without a real
  /// Supabase profile lookup.
  @visibleForTesting
  void debugPresentIncomingRealtimeDm({
    required String senderId,
    required String subscribedUserId,
    required String? activeUserId,
    required String senderName,
    String? text,
    String? imageUrl,
    bool viewOnce = false,
    String? sharedContentType,
  }) {
    if (activeUserId != subscribedUserId || senderId == subscribedUserId) {
      return;
    }

    _showForegroundMessage(
      data: const {'type': 'new_message'},
      title: senderName,
      body: _dmPreview({
        'text': text,
        'image_url': imageUrl,
        'view_once': viewOnce,
        'shared_content_type': sharedContentType,
      }),
    );
  }

  /// Test-only pure preview helper.
  @visibleForTesting
  String debugDmPreview(Map<String, dynamic> record) => _dmPreview(record);

  /// This singleton intentionally lives for the whole process and therefore has
  /// no production dispose path.
  @visibleForTesting
  bool get debugHasLiveSubscriptions =>
      _authSubscription != null || _dmChannel != null;
}
