import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_message.dart';
import 'conversation.dart';
import 'message_request.dart';
import 'shared_content_type.dart';
import '../../../core/storage_upload_options.dart';

/// The 2 columns `ConversationScreen` needs to decide which of its 4
/// composer-area states applies (WYN-032) -- deliberately not the full
/// `Conversation` row, since this is fetched fresh on every open
/// rather than trusted from a possibly-stale list-row prop.
typedef ConversationMeta = ({String status, String? requestedBy});

const _replyEmbed = 'reply_to:messages!messages_reply_to_message_id_fkey(text, image_url, deleted_at)';
const _messageColumns = 'id, conversation_id, sender_id, text, image_url, reply_to_message_id, '
    'shared_content_type, shared_content_id, deleted_at, created_at, $_replyEmbed';

/// Wraps `chat_inbox`, `conversations`, `messages`, `conversation_mutes`,
/// `message_requests` (WYN-032), the `chat-media` storage bucket, and
/// the RPCs WYN-031/032 need. See supabase/schema.sql's "WYN-031: 1:1
/// Chat" and "WYN-032: Message Request flow" sections for the RLS/RPC
/// this relies on.
///
/// Sending a message is a plain table insert (no RPC) -- every
/// condition (participant/not-blocked/not-posting-blocked/non-blank) is
/// already expressed as an RLS `with check` + CHECK constraint,
/// mirroring drops/club_posts. Deleting one goes through
/// `delete_message()` instead, which nulls the row's own content
/// rather than just flagging it -- see that function's comment in
/// schema.sql for why a raw UPDATE policy would be the wrong shape here.
///
/// WYN-033 (Share to Chat): a shared Drop/Profile/Club is stored on the
/// message row as just a type+id (`shared_content_type`/
/// `shared_content_id`), never denormalized -- the UI resolves it
/// through the normal DropRepository/ClubRepository/ProfileRepository
/// fetch calls at render time, so the existing RLS on those tables
/// (e.g. a blocked author's Drop already being invisible) protects a
/// shared reference automatically, with no new mechanism here.
class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 30;
  static const messagePageSize = 30;
  static const _bucket = 'chat-media';
  static const _signedUrlTtlSeconds = 3600;

  String get _myUserId => _client.auth.currentUser!.id;

  /// Sorted by `chat_inbox`'s own `conversation_created_at` as a
  /// fallback for conversations with no messages yet -- the real sort
  /// (most-recent-message-first) happens client-side via
  /// [Conversation.sortKey], since PostgREST can't order by
  /// `coalesce(last_message_at, conversation_created_at)` directly.
  Future<List<Conversation>> fetchInbox({required int page}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final rows = await _client
        .from('chat_inbox')
        .select()
        .order('conversation_created_at', ascending: false)
        .range(from, to);
    final conversations = rows.map((row) => Conversation.fromMap(row)).toList()
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return conversations;
  }

  Future<int> countUnreadConversations() async {
    final result = await _client.rpc('count_unread_conversations');
    return result as int;
  }

  /// Pending conversations someone else started that this caller
  /// hasn't decided on yet (WYN-032) -- `message_requests` already
  /// scopes to "I'm the recipient, not the requester" and excludes any
  /// blocked-either-way pair, so no extra filtering is needed here.
  Future<List<MessageRequest>> fetchMessageRequests({required int page}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final rows = await _client
        .from('message_requests')
        .select()
        .order('conversation_created_at', ascending: false)
        .range(from, to);
    return rows.map((row) => MessageRequest.fromMap(row)).toList();
  }

  Future<int> countPendingMessageRequests() async {
    return _client.from('message_requests').count(CountOption.exact);
  }

  /// The recipient accepts a Message Request -- the conversation
  /// behaves exactly like any other WYN-031 chat from this point on.
  Future<void> acceptMessageRequest(String conversationId) {
    return _client.rpc('accept_message_request', params: {
      'p_conversation_id': conversationId,
    });
  }

  /// The recipient declines a Message Request -- discards the
  /// conversation and every message in it outright (see
  /// delete_message_request()'s comment in schema.sql). The requester
  /// gets no signal that this happened.
  Future<void> deleteMessageRequest(String conversationId) {
    return _client.rpc('delete_message_request', params: {
      'p_conversation_id': conversationId,
    });
  }

  /// Starts (or resumes) a 1:1 conversation with [otherUserId] --
  /// returns the same conversation id every time for the same pair.
  Future<String> getOrCreateConversation(String otherUserId) async {
    final result = await _client.rpc('get_or_create_conversation', params: {
      'p_other_user_id': otherUserId,
    });
    return result as String;
  }

  Future<void> markConversationRead(String conversationId) {
    return _client.rpc('mark_conversation_read', params: {
      'p_conversation_id': conversationId,
    });
  }

  /// Fetched fresh by `ConversationScreen` on every open (WYN-032) --
  /// deliberately not trusted from whatever the caller's own list row
  /// happened to say, since that can be stale (e.g. accepted from a
  /// different screen, or from a notification tap that skips the list
  /// entirely).
  Future<ConversationMeta?> fetchConversationMeta(String conversationId) async {
    final row = await _client
        .from('conversations')
        .select('status, requested_by')
        .eq('id', conversationId)
        .maybeSingle();
    if (row == null) return null;
    return (status: row['status'] as String, requestedBy: row['requested_by'] as String?);
  }

  /// Newest first (matches `ConversationScreen`'s `reverse: true`
  /// list) -- [beforeMessageCreatedAt] pages further into the past,
  /// same "cursor on the sort column, not offset" shape
  /// `AppealRepository`/`ModerationRepository` use `page`/`range` for,
  /// chosen here instead because new messages keep arriving at the
  /// *front* of this list while the user scrolls toward the back, and
  /// a page-number offset would double-count/skip rows as that happens.
  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    DateTime? beforeCreatedAt,
  }) async {
    var query = _client.from('messages').select(_messageColumns).eq('conversation_id', conversationId);
    if (beforeCreatedAt != null) {
      query = query.lt('created_at', beforeCreatedAt.toIso8601String());
    }
    final rows = await query.order('created_at', ascending: false).limit(messagePageSize);
    return rows.map((row) => ChatMessage.fromMap(row)).toList();
  }

  /// Uploads [imageBytes] to `chat-media` (if given) then inserts the
  /// message row directly -- see the class doc comment for why this
  /// has no RPC. [text] and [imageBytes] can't both be null (the
  /// caller's own composer already disables the send button for that
  /// case; the `messages_not_blank_unless_deleted` CHECK constraint is
  /// the real boundary).
  /// Returns the inserted row (with its real id/created_at) so the
  /// caller can show it immediately without waiting on the realtime
  /// echo of its own send -- see ConversationScreen's send handler for
  /// why this matters (realtime is only relied on for the *other*
  /// side's messages, with an id-dedupe as a second line of defense).
  /// [sharedContentType]/[sharedContentId] (WYN-033) let [text] serve
  /// as an optional caption alongside a shared Drop/Profile/Club card
  /// -- deliberately not denormalizing the shared content itself here;
  /// see the class doc comment.
  Future<ChatMessage> sendMessage({
    required String conversationId,
    String? text,
    Uint8List? imageBytes,
    String? imageExtension,
    String? replyToMessageId,
    SharedContentType? sharedContentType,
    String? sharedContentId,
  }) async {
    String? imagePath;
    if (imageBytes != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      imagePath = '$conversationId/$_myUserId-$timestamp.${imageExtension ?? 'jpg'}';
      await _client.storage.from(_bucket).uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: immutableUploadFileOptions,
          );
    }

    final row = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': _myUserId,
          'text': (text == null || text.trim().isEmpty) ? null : text.trim(),
          'image_url': imagePath,
          'reply_to_message_id': replyToMessageId,
          'shared_content_type': sharedContentType?.wireValue,
          'shared_content_id': sharedContentId,
        })
        .select(_messageColumns)
        .single();
    return ChatMessage.fromMap(row);
  }

  Future<void> deleteMessage(String messageId) {
    return _client.rpc('delete_message', params: {'p_message_id': messageId});
  }

  Future<ChatMessage?> fetchMessage(String messageId) async {
    final row = await _client
        .from('messages')
        .select(_messageColumns)
        .eq('id', messageId)
        .maybeSingle();
    return row == null ? null : ChatMessage.fromMap(row);
  }

  /// A fresh signed URL for one chat-media path -- null on failure
  /// (matches ClubPostRepository/AppealRepository's identical posture:
  /// a broken thumbnail is better than a broken screen).
  Future<String?> imageSignedUrl(String path) async {
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, _signedUrlTtlSeconds);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isConversationMuted(String conversationId) async {
    final row = await _client
        .from('conversation_mutes')
        .select('conversation_id')
        .eq('conversation_id', conversationId)
        .eq('user_id', _myUserId)
        .maybeSingle();
    return row != null;
  }

  Future<void> muteConversation(String conversationId) {
    return _client.from('conversation_mutes').insert({
      'conversation_id': conversationId,
      'user_id': _myUserId,
    });
  }

  Future<void> unmuteConversation(String conversationId) {
    return _client
        .from('conversation_mutes')
        .delete()
        .eq('conversation_id', conversationId)
        .eq('user_id', _myUserId);
  }

  /// Subscribes to every new message in [conversationId] --
  /// `ConversationScreen`'s realtime feed. Caller must
  /// `_client.removeChannel(channel)` in `dispose()`; leaving a
  /// channel subscribed after the screen is gone leaks a socket
  /// listener and can double-deliver events to a later subscription.
  RealtimeChannel subscribeToConversationMessages(
    String conversationId,
    void Function(ChatMessage message) onInsert,
  ) {
    final channel = _client.channel('conversation-$conversationId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) => _handleRealtimeInsert(payload.newRecord, onInsert),
        )
        .subscribe();
    return channel;
  }

  /// A `postgres_changes` payload is always the raw row -- never the
  /// `reply_to` embed `fetchMessages()`'s own select does -- so a
  /// realtime-delivered reply is re-fetched once (by id) to pick up
  /// its quote preview before the caller ever sees it, instead of
  /// showing a reply bubble with no quote for a moment.
  Future<void> _handleRealtimeInsert(
    Map<String, dynamic> rawRow,
    void Function(ChatMessage message) onInsert,
  ) async {
    if (rawRow['reply_to_message_id'] == null) {
      onInsert(ChatMessage.fromMap(rawRow));
      return;
    }
    final full = await fetchMessage(rawRow['id'] as String);
    onInsert(full ?? ChatMessage.fromMap(rawRow));
  }

  /// Subscribes to every new message across *all* of this user's
  /// conversations -- `ChatInboxScreen`'s realtime feed. Deliberately
  /// no `conversation_id` filter: `messages`' own participant-only
  /// SELECT policy already scopes `postgres_changes` delivery to rows
  /// this caller may see, the same way it scopes a plain `select`.
  RealtimeChannel subscribeToMyMessages(void Function(ChatMessage message) onInsert) {
    final channel = _client.channel('chat-inbox-$_myUserId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) => _handleRealtimeInsert(payload.newRecord, onInsert),
        )
        .subscribe();
    return channel;
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
