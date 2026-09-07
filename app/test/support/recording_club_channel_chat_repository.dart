import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/club/data/club_channel_chat_repository.dart';
import 'package:wyn/features/club/data/club_channel_message.dart';

/// A ClubChannelChatRepository whose network-touching methods are
/// overridden to just record what they were called with / return canned
/// data, instead of making a real Supabase call. Mirrors
/// RecordingChatRepository -- see .wyn/learning/PATTERNS.md.
///
/// The realtime subscribe methods deliberately never call `.subscribe()`
/// on the channel they hand back (that's what attempts a real WebSocket
/// connection, which leaves a pending Timer flutter_test's
/// `_verifyInvariants` fails a test over) -- they just record the
/// callback so a test can invoke [emitMessage] directly to simulate an
/// incoming realtime event.
class RecordingClubChannelChatRepository extends ClubChannelChatRepository {
  RecordingClubChannelChatRepository({Map<String, List<ClubChannelMessage>>? messagesByChannel})
      : messagesByChannel = messagesByChannel ?? {},
        // A second, independent client just for minting fake
        // RealtimeChannel objects -- ClubChannelChatRepository's own
        // client is private to its file, unreachable from this subclass.
        _fakeChannelClient = SupabaseClient(
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

  /// Returned by [fetchMessages] for the matching channelId, newest-page
  /// only (matches RecordingClubPostRepository's identical "page 0 only"
  /// posture) -- pagination isn't the focus of any test using this yet.
  Map<String, List<ClubChannelMessage>> messagesByChannel;

  Map<String, int> unreadCounts = {};

  int sendMessageCalls = 0;
  ClubChannelMessage? sendMessageResult;
  Object? sendMessageError;
  String? lastSendMessageContent;
  String? lastSendMessageChannelId;
  String? lastSendMessageReplyToId;

  int deleteMessageCalls = 0;
  String? lastDeleteMessageId;

  int markChannelReadCalls = 0;
  String? lastMarkChannelReadChannelId;

  String? signedUrlResult;

  void Function(ClubChannelMessage message)? _channelCallback;
  void Function(int onlineCount)? _presenceCallback;
  void Function(ClubChannelMessage message)? _unreadOnlyCallback;

  @override
  Future<List<ClubChannelMessage>> fetchMessages(
    String channelId, {
    DateTime? beforeCreatedAt,
  }) async {
    if (beforeCreatedAt != null) return [];
    return messagesByChannel[channelId] ?? [];
  }

  @override
  Future<ClubChannelMessage> sendMessage({
    required String clubId,
    required String channelId,
    String? content,
    Uint8List? imageBytes,
    String? imageExtension,
    String? replyToMessageId,
  }) async {
    sendMessageCalls++;
    lastSendMessageContent = content;
    lastSendMessageChannelId = channelId;
    lastSendMessageReplyToId = replyToMessageId;
    if (sendMessageError != null) throw sendMessageError!;
    return sendMessageResult ??
        ClubChannelMessage(
          id: 'sent-$sendMessageCalls',
          channelId: channelId,
          authorId: 'me',
          authorUsername: 'me',
          createdAt: DateTime.now(),
          content: content,
          replyToMessageId: replyToMessageId,
        );
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    deleteMessageCalls++;
    lastDeleteMessageId = messageId;
  }

  @override
  Future<String?> imageSignedUrl(String path) async => signedUrlResult;

  @override
  Future<void> markChannelRead(String channelId) async {
    markChannelReadCalls++;
    lastMarkChannelReadChannelId = channelId;
  }

  @override
  Future<Map<String, int>> fetchUnreadCounts(String clubId) async => unreadCounts;

  @override
  RealtimeChannel subscribeToChannel(
    String channelId,
    void Function(ClubChannelMessage message) onInsert, {
    void Function(int onlineCount)? onPresenceChange,
  }) {
    _channelCallback = onInsert;
    _presenceCallback = onPresenceChange;
    return _fakeChannelClient.channel('test-club-channel-$channelId');
  }

  @override
  RealtimeChannel subscribeToNewMessagesOnly(
    String channelId,
    void Function(ClubChannelMessage message) onInsert,
  ) {
    _unreadOnlyCallback = onInsert;
    return _fakeChannelClient.channel('test-club-channel-unread-$channelId');
  }

  @override
  void unsubscribe(RealtimeChannel channel) {
    // No-op -- the channel was never actually subscribed (see the class
    // doc comment), so there's nothing real to tear down.
  }

  /// Test helper: simulates a new message arriving over
  /// [subscribeToChannel]'s channel.
  void emitMessage(ClubChannelMessage message) => _channelCallback?.call(message);

  /// Test helper: simulates a new message arriving over
  /// [subscribeToNewMessagesOnly]'s channel.
  void emitUnreadMessage(ClubChannelMessage message) => _unreadOnlyCallback?.call(message);

  /// Test helper: simulates a presence sync reporting [count] members
  /// currently online.
  void emitPresenceCount(int count) => _presenceCallback?.call(count);
}
