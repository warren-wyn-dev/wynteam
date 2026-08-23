import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/chat/data/chat_message.dart';
import 'package:wyn/features/chat/data/chat_repository.dart';
import 'package:wyn/features/chat/data/conversation.dart';
import 'package:wyn/features/chat/data/message_request.dart';

/// A ChatRepository whose network-touching methods are overridden to
/// just record what they were called with / return canned data,
/// instead of making a real Supabase call. Mirrors
/// RecordingAppealRepository (WYN-030) -- see .wyn/learning/PATTERNS.md.
///
/// The 2 realtime subscribe methods deliberately never call
/// `.subscribe()` on the channel they hand back (that's what attempts
/// a real WebSocket connection) -- they just record the callback so a
/// test can invoke [emitConversationMessage]/[emitMyMessage] directly
/// to simulate an incoming realtime event.
class RecordingChatRepository extends ChatRepository {
  RecordingChatRepository({this.unreadCount = 0})
      : // A second, independent client just for minting fake
        // RealtimeChannel objects (see subscribeToConversationMessages/
        // subscribeToMyMessages below) -- ChatRepository's own client is
        // private to its file, unreachable from this subclass.
        _fakeChannelClient = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        super(
          // autoRefreshToken: false -- see RecordingModerationRepository's
          // identical comment on why a default SupabaseClient's
          // auto-refresh Timer is a problem when this is constructed
          // fresh inside a `testWidgets` body rather than once in
          // `setUp`/`setUpAll`.
          SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final SupabaseClient _fakeChannelClient;

  int unreadCount;

  List<List<Conversation>> inboxPages = const [];
  Object? fetchInboxError;

  Map<String, List<ChatMessage>> messagesByConversation = const {};
  Object? fetchMessagesError;

  String getOrCreateConversationResult = 'conversation-1';
  Object? getOrCreateConversationError;

  int markConversationReadCalls = 0;
  String? lastMarkConversationReadId;

  ChatMessage? sendMessageResult;
  Object? sendMessageError;
  int sendMessageCalls = 0;
  String? lastSendMessageText;
  Uint8List? lastSendMessageImageBytes;
  String? lastSendMessageReplyToId;

  Object? deleteMessageError;
  int deleteMessageCalls = 0;
  String? lastDeleteMessageId;

  Map<String, bool> mutedConversations = const {};
  int muteCalls = 0;
  int unmuteCalls = 0;

  String? signedUrlResult;

  List<List<MessageRequest>> messageRequestPages = const [];
  Object? fetchMessageRequestsError;
  int pendingMessageRequestCount = 0;

  Object? acceptMessageRequestError;
  int acceptMessageRequestCalls = 0;
  String? lastAcceptMessageRequestId;

  Object? deleteMessageRequestError;
  int deleteMessageRequestCalls = 0;
  String? lastDeleteMessageRequestId;

  void Function(ChatMessage message)? _conversationCallback;
  void Function(ChatMessage message)? _inboxCallback;

  @override
  Future<List<Conversation>> fetchInbox({required int page}) async {
    final error = fetchInboxError;
    if (error != null) throw error;
    if (page < 0 || page >= inboxPages.length) return [];
    return inboxPages[page];
  }

  @override
  Future<int> countUnreadConversations() async => unreadCount;

  @override
  Future<String> getOrCreateConversation(String otherUserId) async {
    final error = getOrCreateConversationError;
    if (error != null) throw error;
    return getOrCreateConversationResult;
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    markConversationReadCalls++;
    lastMarkConversationReadId = conversationId;
  }

  ConversationMeta? conversationMetaResult;
  Object? fetchConversationMetaError;

  @override
  Future<ConversationMeta?> fetchConversationMeta(String conversationId) async {
    final error = fetchConversationMetaError;
    if (error != null) throw error;
    return conversationMetaResult;
  }

  @override
  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    DateTime? beforeCreatedAt,
  }) async {
    final error = fetchMessagesError;
    if (error != null) throw error;
    final all = messagesByConversation[conversationId] ?? const <ChatMessage>[];
    if (beforeCreatedAt == null) return all;
    return all.where((m) => m.createdAt.isBefore(beforeCreatedAt)).toList();
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    String? text,
    Uint8List? imageBytes,
    String? imageExtension,
    String? replyToMessageId,
  }) async {
    sendMessageCalls++;
    lastSendMessageText = text;
    lastSendMessageImageBytes = imageBytes;
    lastSendMessageReplyToId = replyToMessageId;
    final error = sendMessageError;
    if (error != null) throw error;
    return sendMessageResult ??
        ChatMessage(
          id: 'sent-$sendMessageCalls',
          conversationId: conversationId,
          senderId: 'me',
          createdAt: DateTime.now(),
          text: text,
          replyToMessageId: replyToMessageId,
        );
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    deleteMessageCalls++;
    lastDeleteMessageId = messageId;
    final error = deleteMessageError;
    if (error != null) throw error;
  }

  @override
  Future<String?> imageSignedUrl(String path) async => signedUrlResult;

  @override
  Future<bool> isConversationMuted(String conversationId) async =>
      mutedConversations[conversationId] ?? false;

  @override
  Future<void> muteConversation(String conversationId) async {
    muteCalls++;
    mutedConversations = {...mutedConversations, conversationId: true};
  }

  @override
  Future<void> unmuteConversation(String conversationId) async {
    unmuteCalls++;
    mutedConversations = {...mutedConversations, conversationId: false};
  }

  @override
  Future<List<MessageRequest>> fetchMessageRequests({required int page}) async {
    final error = fetchMessageRequestsError;
    if (error != null) throw error;
    if (page < 0 || page >= messageRequestPages.length) return [];
    return messageRequestPages[page];
  }

  @override
  Future<int> countPendingMessageRequests() async => pendingMessageRequestCount;

  @override
  Future<void> acceptMessageRequest(String conversationId) async {
    acceptMessageRequestCalls++;
    lastAcceptMessageRequestId = conversationId;
    final error = acceptMessageRequestError;
    if (error != null) throw error;
  }

  @override
  Future<void> deleteMessageRequest(String conversationId) async {
    deleteMessageRequestCalls++;
    lastDeleteMessageRequestId = conversationId;
    final error = deleteMessageRequestError;
    if (error != null) throw error;
  }

  // Deliberately never calls `.subscribe()` on the channel it returns
  // (that's what attempts a real WebSocket connection) -- `.channel()`
  // alone just registers a local topic, no network I/O. The real
  // callback is captured separately for [emitConversationMessage] to
  // invoke directly.
  @override
  RealtimeChannel subscribeToConversationMessages(
    String conversationId,
    void Function(ChatMessage message) onInsert,
  ) {
    _conversationCallback = onInsert;
    return _fakeChannelClient.channel('test-conversation-$conversationId');
  }

  @override
  RealtimeChannel subscribeToMyMessages(void Function(ChatMessage message) onInsert) {
    _inboxCallback = onInsert;
    return _fakeChannelClient.channel('test-inbox');
  }

  @override
  void unsubscribe(RealtimeChannel channel) {
    // No-op -- the channel was never actually subscribed (see the class
    // doc comment), so there's nothing real to tear down.
  }

  /// Test helper: simulates a new message arriving over
  /// [subscribeToConversationMessages]'s channel.
  void emitConversationMessage(ChatMessage message) => _conversationCallback?.call(message);

  /// Test helper: simulates a new message arriving over
  /// [subscribeToMyMessages]'s channel.
  void emitMyMessage(ChatMessage message) => _inboxCallback?.call(message);
}
