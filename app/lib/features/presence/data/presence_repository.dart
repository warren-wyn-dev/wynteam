import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [PresenceRepository.fetchConversationPartnerPresence]'s own return
/// shape -- see that method's own doc comment. `showOnline` already
/// bakes in the reciprocal privacy check (`get_conversation_partner_presence()`
/// itself enforces it -- see supabase/schema.sql's WYN-139 section), so
/// a caller never needs to re-derive it from anything else.
typedef PartnerPresence = ({bool showOnline, DateTime? lastSeenAt});

/// WYN-139: DM Presence -- Typing Indicator + Online/Offline + Last Seen.
///
/// Wraps `public.user_presence` (deliberately a table separate from
/// `profiles` -- that table's own SELECT policy is `using (true)`, so a
/// `last_seen_at`/`show_online_status` column living there directly
/// would leak to every authenticated user with no reciprocal check at
/// all; see supabase/schema.sql's WYN-139 section for the full
/// reasoning) plus 2 realtime Presence channels that never touch
/// Postgres at all -- "online" is a live-socket-only concept, not
/// something a DB query can ever answer (see the design doc's own
/// "Presence Channel Design" section):
///
/// 1. A single **global** channel (topic [globalPresenceTopic], keyed by
///    this user's own id) for "who's online right now" -- started once
///    per app session by `RootShell` (gated by Staged Rollout), never
///    per-conversation. [isUserOnline] answers "is user X online" for
///    *any* caller (e.g. `ConversationScreen`) by reading a
///    process-wide cache kept in sync by whichever instance actually
///    owns that channel, rather than requiring every caller to hold a
///    reference to the exact same `RealtimeChannel` object.
/// 2. A **per-conversation** typing channel (opened/closed with whatever
///    `ConversationScreen` is open, mirroring
///    `ClubChannelChatRepository.subscribeToChannel`'s identical
///    per-screen scope for Club) -- has no privacy gate at all
///    (Requirement: "Typing Indicator ไม่มี privacy toggle แยก").
class PresenceRepository {
  PresenceRepository(this._client);

  final SupabaseClient _client;

  String get _myUserId => _client.auth.currentUser!.id;

  static const globalPresenceTopic = 'presence-online-global';

  // Process-wide, not per-instance -- mirrors DeveloperAccessService's
  // own static-cache shape (see that class's doc comment). Kept in sync
  // by [startGlobalPresence]'s own `onPresenceSync` callback; read by
  // [isUserOnline] regardless of which instance/screen is asking.
  static final Set<String> _onlineUserIds = {};
  static RealtimeChannel? _globalChannel;
  static final List<VoidCallback> _globalPresenceListeners = [];

  /// True once [startGlobalPresence] has synced at least one presence
  /// state showing [userId] as currently connected. Always `false`
  /// before the very first sync, and always `false` for every user if
  /// [startGlobalPresence] was never called at all (e.g. a
  /// non-developer account, per the Staged Rollout gate -- see
  /// `RootShell`'s own doc comment).
  bool isUserOnline(String userId) => _onlineUserIds.contains(userId);

  /// Fires (with no payload -- callers just re-read [isUserOnline]
  /// themselves) every time the global channel's presence state changes.
  /// `ConversationScreen` registers one of these so its AppBar subtitle
  /// re-renders live when the other participant's online status flips,
  /// without needing its own reference to the global channel object.
  /// Caller must [removeGlobalPresenceListener] in `dispose()`.
  void addGlobalPresenceListener(VoidCallback listener) {
    _globalPresenceListeners.add(listener);
  }

  void removeGlobalPresenceListener(VoidCallback listener) {
    _globalPresenceListeners.remove(listener);
  }

  /// Opens the single app-wide "who's online" channel and starts
  /// tracking this user's own presence on it -- idempotent (returns the
  /// existing channel if already started), since `RootShell.initState`
  /// and a subsequent resume-from-background could both reach here.
  /// Caller (`RootShell`) owns the lifecycle: [trackOnline]/[untrackOnline]
  /// on resume/pause, [stopGlobalPresence] in `dispose()`/sign-out.
  RealtimeChannel startGlobalPresence() {
    final existing = _globalChannel;
    if (existing != null) return existing;
    final channel = _client.channel(
      globalPresenceTopic,
      opts: RealtimeChannelConfig(key: _myUserId),
    );
    channel.onPresenceSync((_) {
      _onlineUserIds
        ..clear()
        ..addAll(channel.presenceState().map((state) => state.key));
      for (final listener in List<VoidCallback>.of(_globalPresenceListeners)) {
        listener();
      }
    });
    channel.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await channel.track({'online_at': DateTime.now().toIso8601String()});
      }
    });
    _globalChannel = channel;
    return channel;
  }

  /// `AppLifecycleState.resumed` -- re-track (the channel itself, once
  /// [startGlobalPresence] opened it, stays subscribed for the app's
  /// whole session; only the tracked presence entry toggles here).
  Future<void> trackOnline() async {
    final channel = _globalChannel;
    if (channel == null) return;
    await channel.track({'online_at': DateTime.now().toIso8601String()});
  }

  /// `AppLifecycleState.paused`/`detached` -- best-effort, same posture
  /// as every other lifecycle hook in this app (see `RootShell`'s own
  /// call site): a killed-outright app misses this, which is the known
  /// "last seen can lag reality" limitation the design doc's own Edge
  /// Cases section already accepts.
  Future<void> untrackOnline() async {
    final channel = _globalChannel;
    if (channel == null) return;
    await channel.untrack();
  }

  /// Tears the global channel down entirely -- only ever called when
  /// this user's own session for this app process is ending (sign-out,
  /// account switch via `RootShell`'s own dispose -- see WYN-125's
  /// "the account switcher tears the whole shell down" note elsewhere
  /// in this codebase), not on every screen navigation.
  void stopGlobalPresence() {
    final channel = _globalChannel;
    if (channel != null) _client.removeChannel(channel);
    _globalChannel = null;
    _onlineUserIds.clear();
    _globalPresenceListeners.clear();
  }

  /// WYN-139 -- per-conversation typing channel, opened/closed with
  /// `ConversationScreen` itself (mirrors
  /// `ClubChannelChatRepository.subscribeToChannel`'s identical
  /// per-screen scope). [onPresenceChange] fires on every sync; the
  /// caller re-derives whether the *other* participant is typing via
  /// [isOtherTyping] rather than this method handing back a bool
  /// directly, since presence state can carry more than one flag in the
  /// future without this signature needing to change.
  RealtimeChannel subscribeTypingChannel(
    String conversationId, {
    required void Function() onPresenceChange,
  }) {
    final channel = _client.channel(
      'conversation-typing-$conversationId',
      opts: RealtimeChannelConfig(key: _myUserId),
    );
    channel.onPresenceSync((_) => onPresenceChange());
    channel.subscribe();
    return channel;
  }

  /// Reads [channel]'s own synced presence state for [otherUserId] --
  /// `true` only if that key has at least one tracked presence entry
  /// whose payload carries `typing: true`. Never throws/crashes if
  /// [otherUserId] hasn't tracked anything yet (not present in the
  /// state at all) -- that's the ordinary "not typing" case, not an
  /// error.
  bool isOtherTyping(RealtimeChannel channel, String otherUserId) {
    for (final state in channel.presenceState()) {
      if (state.key != otherUserId) continue;
      return state.presences.any((presence) => presence.payload['typing'] == true);
    }
    return false;
  }

  /// Broadcasts this user's own typing state on [channel] -- the
  /// caller (`ConversationScreen`) already debounces so this is called
  /// only on an actual `false`->`true`/`true`->`false` transition, not
  /// on every keystroke (Requirement: "debounce เพื่อไม่ spam event ทุก
  /// ตัวอักษร").
  Future<void> setTyping(RealtimeChannel channel, bool typing) {
    return channel.track({'typing': typing});
  }

  void unsubscribeTyping(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  /// This user's own current [user_presence.show_online_status] --
  /// `true` (the schema column's own default) for a brand new account
  /// that has never had a `user_presence` row written at all yet, same
  /// "no row yet == the default" posture `notification_settings`-backed
  /// reads already follow elsewhere in this app.
  Future<bool> fetchShowOnlineStatus() async {
    final row = await _client
        .from('user_presence')
        .select('show_online_status')
        .eq('user_id', _myUserId)
        .maybeSingle();
    return row == null ? true : row['show_online_status'] as bool;
  }

  /// Plain upsert through `user_presence`'s own RLS (no RPC needed --
  /// this only ever targets the caller's own row, same as the design
  /// doc's own "เปลี่ยนค่า show_online_status ของตัวเอง" section
  /// describes).
  Future<void> setShowOnlineStatus(bool value) {
    return _client.from('user_presence').upsert({
      'user_id': _myUserId,
      'show_online_status': value,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Persists this user's own `last_seen_at` -- called on
  /// `AppLifecycleState.paused`/`detached` (see [untrackOnline]'s own
  /// call site in `RootShell`). `touch_my_presence()` itself upserts, so
  /// this works identically for a brand new account with no
  /// `user_presence` row yet.
  Future<void> touchMyPresence() {
    return _client.rpc('touch_my_presence');
  }

  /// The *other* participant's presence, as seen through
  /// `get_conversation_partner_presence()`'s own reciprocal check --
  /// `showOnline: false` (with `lastSeenAt` always null alongside it)
  /// whenever either participant has turned their own visibility off,
  /// regardless of what the other participant's real
  /// `show_online_status`/`last_seen_at` actually are. See that RPC's
  /// own doc comment in supabase/schema.sql for the exact logic --
  /// deliberately not re-implemented client-side, so there is exactly
  /// one place this privacy rule can ever be wrong.
  Future<PartnerPresence> fetchConversationPartnerPresence(String conversationId) async {
    final rows = await _client.rpc('get_conversation_partner_presence', params: {
      'p_conversation_id': conversationId,
    }) as List<dynamic>;
    if (rows.isEmpty) return (showOnline: false, lastSeenAt: null);
    final row = rows.first as Map<String, dynamic>;
    return (
      showOnline: row['show_online'] as bool? ?? false,
      lastSeenAt: row['last_seen_at'] == null ? null : DateTime.parse(row['last_seen_at'] as String),
    );
  }
}
