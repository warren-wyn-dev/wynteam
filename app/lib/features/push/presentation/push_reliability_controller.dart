import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/push_env.dart';
import '../../../core/text_utils.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/active_conversation_tracker.dart';
import '../../chat/presentation/conversation_screen.dart';
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

  static final PushReliabilityController instance =
      PushReliabilityController._();

  static const Duration _foregroundBannerDuration = Duration(seconds: 4);

  bool _started = false;
  Future<void>? _repairInFlight;
  SupabaseClient? _client;
  PushNotificationService? _repairService;
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _dmChannel;
  String? _dmChannelUserId;
  OverlayEntry? _foregroundOverlayEntry;
  Timer? _foregroundOverlayTimer;

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

    if (client.auth.currentUser?.id != subscribedUserId ||
        senderId == subscribedUserId) {
      return;
    }

    final conversationId = record['conversation_id'] as String?;
    if (conversationId != null &&
        ActiveConversationTracker.currentConversationId == conversationId) {
      return;
    }

    final preview = _dmPreview(record);
    final sender = await _senderPresentation(senderId);

    if (client.auth.currentUser?.id != subscribedUserId) return;
    if (conversationId != null &&
        ActiveConversationTracker.currentConversationId == conversationId) {
      return;
    }

    _showForegroundMessage(
      data: const {'type': 'new_message'},
      title: sender.name,
      body: preview,
      onTap: conversationId == null || sender.username.isEmpty
          ? null
          : () => _openRealtimeConversation(
                conversationId: conversationId,
                senderId: senderId,
                sender: sender,
              ),
    );
  }

  Future<_DmSenderPresentation> _senderPresentation(String senderId) async {
    final client = _client;
    if (client == null) {
      return const _DmSenderPresentation(name: 'ข้อความใหม่');
    }

    try {
      final profile = await client
          .from('profiles')
          .select('username, display_name, avatar_url')
          .eq('id', senderId)
          .maybeSingle();
      if (profile == null) {
        return const _DmSenderPresentation(name: 'ข้อความใหม่');
      }

      final username = (profile['username'] as String?)?.trim() ?? '';
      final displayName = (profile['display_name'] as String?)?.trim();
      final resolvedName = displayNameOrUsername(
        displayName: displayName,
        username: username,
      ).trim();
      return _DmSenderPresentation(
        name: resolvedName.isEmpty ? 'ข้อความใหม่' : resolvedName,
        username: username,
        displayName: displayName,
        avatarUrl: profile['avatar_url'] as String?,
      );
    } catch (_) {
      return const _DmSenderPresentation(name: 'ข้อความใหม่');
    }
  }

  void _openRealtimeConversation({
    required String conversationId,
    required String senderId,
    required _DmSenderPresentation sender,
  }) {
    final client = _client;
    final navigator = appNavigatorKey.currentState;
    if (client == null || navigator == null || sender.username.isEmpty) return;
    if (ActiveConversationTracker.currentConversationId == conversationId) {
      return;
    }

    _dismissForegroundMessage();
    unawaited(
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            chatRepository: ChatRepository(client),
            conversationId: conversationId,
            otherUserId: senderId,
            otherUsername: sender.username,
            otherDisplayName: sender.displayName,
            otherAvatarUrl: sender.avatarUrl,
          ),
        ),
      ),
    );
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
    VoidCallback? onTap,
  }) {
    if (data['type'] != 'new_message') return;

    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _dismissForegroundMessage();
    final safeTitle = title?.trim();
    final safeBody = body?.trim();
    final resolvedTitle =
        safeTitle == null || safeTitle.isEmpty ? 'ข้อความใหม่' : safeTitle;
    final resolvedBody =
        safeBody == null || safeBody.isEmpty ? 'ส่งข้อความถึงคุณ' : safeBody;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                key: const Key('foreground_dm_banner'),
                color: colors.surface,
                elevation: 8,
                shadowColor: colors.shadow.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap == null
                      ? null
                      : () {
                          _dismissForegroundMessage();
                          onTap();
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_rounded,
                            size: 20,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resolvedTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                resolvedBody,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _foregroundOverlayEntry = entry;
    overlay.insert(entry);
    _foregroundOverlayTimer = Timer(
      _foregroundBannerDuration,
      _dismissForegroundMessage,
    );
  }

  void _dismissForegroundMessage() {
    _foregroundOverlayTimer?.cancel();
    _foregroundOverlayTimer = null;
    final entry = _foregroundOverlayEntry;
    _foregroundOverlayEntry = null;
    if (entry?.mounted ?? false) {
      entry!.remove();
    }
  }

  @visibleForTesting
  void debugShowForegroundMessage({
    required Map<String, dynamic> data,
    String? title,
    String? body,
    VoidCallback? onTap,
  }) {
    _showForegroundMessage(
      data: data,
      title: title,
      body: body,
      onTap: onTap,
    );
  }

  @visibleForTesting
  void debugPresentIncomingRealtimeDm({
    required String senderId,
    required String subscribedUserId,
    required String? activeUserId,
    required String senderName,
    String? conversationId,
    String? text,
    String? imageUrl,
    bool viewOnce = false,
    String? sharedContentType,
    VoidCallback? onTap,
  }) {
    if (activeUserId != subscribedUserId || senderId == subscribedUserId) {
      return;
    }
    if (conversationId != null &&
        ActiveConversationTracker.currentConversationId == conversationId) {
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
      onTap: onTap,
    );
  }

  @visibleForTesting
  void debugDismissForegroundMessage() => _dismissForegroundMessage();

  /// Test-only pure preview helper.
  @visibleForTesting
  String debugDmPreview(Map<String, dynamic> record) => _dmPreview(record);

  /// This singleton intentionally lives for the whole process and therefore has
  /// no production dispose path.
  @visibleForTesting
  bool get debugHasLiveSubscriptions =>
      _authSubscription != null || _dmChannel != null;
}

class _DmSenderPresentation {
  const _DmSenderPresentation({
    required this.name,
    this.username = '',
    this.displayName,
    this.avatarUrl,
  });

  final String name;
  final String username;
  final String? displayName;
  final String? avatarUrl;
}
