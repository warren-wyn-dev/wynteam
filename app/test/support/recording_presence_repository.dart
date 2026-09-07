import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/presence/data/presence_repository.dart';

/// A PresenceRepository whose network/realtime-touching methods are
/// overridden to just record what they were called with / return canned
/// data, instead of making a real Supabase call or touching
/// [PresenceRepository]'s own process-wide static state. Mirrors
/// RecordingChatRepository (WYN-031) -- see .wyn/learning/PATTERNS.md.
///
/// Deliberately overrides every method the base class' static fields
/// back (`isUserOnline`/`addGlobalPresenceListener`/
/// `removeGlobalPresenceListener`/`startGlobalPresence`/
/// `stopGlobalPresence`) with purely instance-local state instead --
/// using the real static state here would leak "who's online" across
/// unrelated tests in the same isolate, the same class of problem
/// RecordingDeveloperAccessService.resetForTest() exists to guard
/// against for its own static cache.
class RecordingPresenceRepository extends PresenceRepository {
  RecordingPresenceRepository()
      : _fakeChannelClient = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        super(
          SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final SupabaseClient _fakeChannelClient;

  final Set<String> _onlineUserIds = {};
  final List<VoidCallback> _globalPresenceListeners = [];

  int startGlobalPresenceCalls = 0;
  int trackOnlineCalls = 0;
  int untrackOnlineCalls = 0;
  int stopGlobalPresenceCalls = 0;

  @override
  bool isUserOnline(String userId) => _onlineUserIds.contains(userId);

  /// Test helper: simulates the global presence channel syncing with
  /// [userId] now (dis)connected -- notifies every registered listener,
  /// same as the real `onPresenceSync` callback would.
  void setOnline(String userId, {required bool online}) {
    if (online) {
      _onlineUserIds.add(userId);
    } else {
      _onlineUserIds.remove(userId);
    }
    for (final listener in List<VoidCallback>.of(_globalPresenceListeners)) {
      listener();
    }
  }

  @override
  void addGlobalPresenceListener(VoidCallback listener) {
    _globalPresenceListeners.add(listener);
  }

  @override
  void removeGlobalPresenceListener(VoidCallback listener) {
    _globalPresenceListeners.remove(listener);
  }

  @override
  RealtimeChannel startGlobalPresence() {
    startGlobalPresenceCalls++;
    return _fakeChannelClient.channel('test-presence-global');
  }

  @override
  Future<void> trackOnline() async {
    trackOnlineCalls++;
  }

  @override
  Future<void> untrackOnline() async {
    untrackOnlineCalls++;
  }

  @override
  void stopGlobalPresence() {
    stopGlobalPresenceCalls++;
    _onlineUserIds.clear();
    _globalPresenceListeners.clear();
  }

  void Function()? _typingPresenceCallback;
  final Set<String> _typingUserIds = {};

  int setTypingCalls = 0;
  bool? lastSetTyping;
  int subscribeTypingChannelCalls = 0;

  @override
  RealtimeChannel subscribeTypingChannel(
    String conversationId, {
    required void Function() onPresenceChange,
  }) {
    subscribeTypingChannelCalls++;
    _typingPresenceCallback = onPresenceChange;
    return _fakeChannelClient.channel('test-typing-$conversationId');
  }

  /// Test helper: simulates the per-conversation typing channel syncing
  /// with [userId]'s own `typing` flag now set to [typing].
  void setOtherTyping(String userId, {required bool typing}) {
    if (typing) {
      _typingUserIds.add(userId);
    } else {
      _typingUserIds.remove(userId);
    }
    _typingPresenceCallback?.call();
  }

  @override
  bool isOtherTyping(RealtimeChannel channel, String otherUserId) =>
      _typingUserIds.contains(otherUserId);

  @override
  Future<void> setTyping(RealtimeChannel channel, bool typing) async {
    setTypingCalls++;
    lastSetTyping = typing;
  }

  @override
  void unsubscribeTyping(RealtimeChannel channel) {
    // No-op -- the channel was never actually subscribed (see the class
    // doc comment), so there's nothing real to tear down.
  }

  bool showOnlineStatusResult = true;
  Object? fetchShowOnlineStatusError;

  @override
  Future<bool> fetchShowOnlineStatus() async {
    final error = fetchShowOnlineStatusError;
    if (error != null) throw error;
    return showOnlineStatusResult;
  }

  int setShowOnlineStatusCalls = 0;
  bool? lastSetShowOnlineStatus;
  Object? setShowOnlineStatusError;

  @override
  Future<void> setShowOnlineStatus(bool value) async {
    setShowOnlineStatusCalls++;
    lastSetShowOnlineStatus = value;
    final error = setShowOnlineStatusError;
    if (error != null) throw error;
  }

  int touchMyPresenceCalls = 0;
  Object? touchMyPresenceError;

  @override
  Future<void> touchMyPresence() async {
    touchMyPresenceCalls++;
    final error = touchMyPresenceError;
    if (error != null) throw error;
  }

  PartnerPresence partnerPresenceResult = (showOnline: false, lastSeenAt: null);
  Object? fetchConversationPartnerPresenceError;
  int fetchConversationPartnerPresenceCalls = 0;

  @override
  Future<PartnerPresence> fetchConversationPartnerPresence(String conversationId) async {
    fetchConversationPartnerPresenceCalls++;
    final error = fetchConversationPartnerPresenceError;
    if (error != null) throw error;
    return partnerPresenceResult;
  }
}
