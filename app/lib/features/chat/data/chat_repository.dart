import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_message.dart';
import 'conversation.dart';
import 'message_request.dart';
import 'shared_content_type.dart';
import '../../../core/storage_upload_options.dart';

/// What `ConversationScreen` needs to decide which of its 4 composer-area
/// states applies (WYN-032), plus [otherUserLastReadAt] for the last-
/// outgoing-bubble read receipt -- deliberately not the full
/// `Conversation` row, since this is fetched fresh on every open rather
/// than trusted from a possibly-stale list-row prop.
typedef ConversationMeta = ({String status, String? requestedBy, DateTime? otherUserLastReadAt});

// Hinted by column name (`reply_to_message_id`), not by the FK's
// constraint name (`messages_reply_to_message_id_fkey`). PostgREST 400s
// with PGRST200 ("Could not find a relationship between 'messages' and
// 'messages'") on the constraint-name form for this specific *self*-
// referencing relationship even though that exact constraint genuinely
// exists -- verified directly against production. Since this embed is
// part of every `_messageColumns` select, that alone made every chat
// send and fetch 400 unconditionally, reply or not.
const _replyEmbed = 'reply_to:messages!reply_to_message_id(text, image_url, deleted_at)';
const _messageColumns = 'id, conversation_id, sender_id, text, image_url, reply_to_message_id, '
    'shared_content_type, shared_content_id, deleted_at, created_at, view_once, viewed_at, $_replyEmbed';

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
        .select('status, requested_by, user_a_id, user_b_id, user_a_last_read_at, user_b_last_read_at')
        .eq('id', conversationId)
        .maybeSingle();
    if (row == null) return null;
    return (
      status: row['status'] as String,
      requestedBy: row['requested_by'] as String?,
      otherUserLastReadAt: _otherUserLastReadAt(row),
    );
  }

  /// [row] must carry `user_a_id`/`user_b_id`/`user_a_last_read_at`/
  /// `user_b_last_read_at` -- shared by [fetchConversationMeta] and the
  /// realtime UPDATE payload [subscribeToConversationMeta] delivers,
  /// which is always the plain row with no embed (same as every other
  /// `postgres_changes` payload in this repository).
  DateTime? _otherUserLastReadAt(Map<String, dynamic> row) {
    final iAmUserA = row['user_a_id'] as String == _myUserId;
    final raw = iAmUserA ? row['user_b_last_read_at'] : row['user_a_last_read_at'];
    return raw == null ? null : DateTime.parse(raw as String);
  }

  /// Subscribes to changes on [conversationId]'s own `conversations` row
  /// -- specifically so the last-outgoing-bubble read receipt in
  /// `ConversationScreen` flips from "sent" to "read" live the moment the
  /// other participant's `mark_conversation_read()` call moves their
  /// `user_a_last_read_at`/`user_b_last_read_at` column forward, instead
  /// of only catching up on next reload/pull-to-refresh. Caller must
  /// `unsubscribe()` in `dispose()`, same as
  /// [subscribeToConversationMessages].
  RealtimeChannel subscribeToConversationMeta(
    String conversationId,
    void Function(ConversationMeta meta) onUpdate,
  ) {
    final channel = _client.channel('conversation-meta-$conversationId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: conversationId),
          callback: (payload) {
            final row = payload.newRecord;
            onUpdate((
              status: row['status'] as String,
              requestedBy: row['requested_by'] as String?,
              otherUserLastReadAt: _otherUserLastReadAt(row),
            ));
          },
        )
        .subscribe();
    return channel;
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
  /// [viewOnce] (Founder feedback) only ever makes sense alongside
  /// [imageBytes] -- the composer's own toggle is only reachable once a
  /// photo is attached, so a text-only/shared-content send never passes
  /// true here.
  Future<ChatMessage> sendMessage({
    required String conversationId,
    String? text,
    Uint8List? imageBytes,
    String? imageExtension,
    String? replyToMessageId,
    SharedContentType? sharedContentType,
    String? sharedContentId,
    bool viewOnce = false,
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
          'view_once': viewOnce,
        })
        .select(_messageColumns)
        .single();
    return ChatMessage.fromMap(row);
  }

  /// The recipient's one explicit "I'm opening this now" for a View
  /// Once photo -- see `mark_view_once_viewed()`'s own doc comment in
  /// supabase/schema.sql for why this has to happen (and succeed)
  /// *before* [imageSignedUrl] is ever called for that message's path.
  Future<void> markViewOnceViewed(String messageId) {
    return _client.rpc('mark_view_once_viewed', params: {'p_message_id': messageId});
  }

  /// Called once [message]'s View Once countdown (owned entirely by the
  /// caller -- ConversationScreen's own Timer, not this repository) has
  /// elapsed: deletes the underlying storage object first, then nulls
  /// `messages.image_url` -- that order matters, since the storage
  /// DELETE policy's own check requires `image_url` to still equal the
  /// object's path (see "Participants can delete a viewed View Once
  /// photo" in supabase/schema.sql); nulling it first would make the
  /// object undeletable through that policy forever after.
  ///
  /// Storage removal is best-effort (same posture as [deleteMessage]),
  /// but the RPC call is not -- a failure there is surfaced to the
  /// caller, since it means the message's row still looks "viewed but
  /// not yet expired" and is worth a retry rather than silently
  /// swallowing.
  Future<void> expireViewOnceMessage(ChatMessage message) async {
    final path = message.imageUrl;
    if (path != null) {
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {
        // Best-effort -- see doc comment above.
      }
    }
    await _client.rpc('clear_view_once_message', params: {'p_message_id': message.id});
  }

  /// Also best-effort deletes the underlying `chat-media` storage object
  /// when [message] carried an image -- `delete_message()` itself only
  /// ever nulled `messages.image_url` (the DB reference), leaving the
  /// actual file orphaned in storage forever regardless of how many
  /// messages got "deleted" (confirmed by reading that function in
  /// supabase/schema.sql: it has never touched `storage.objects`).
  /// Takes the full [ChatMessage], not just its id, because the storage
  /// path lives in [ChatMessage.imageUrl] -- the RPC call below nulls it
  /// in the same statement that sets `deleted_at`, so there is no way to
  /// recover the path afterward.
  Future<void> deleteMessage(ChatMessage message) async {
    await _client.rpc('delete_message', params: {'p_message_id': message.id});
    final path = message.imageUrl;
    if (path != null) {
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {
        // Best-effort, deliberately: a failure here must never surface
        // as "delete failed" once the message itself (the thing the
        // user actually asked to delete) already succeeded. Worst case
        // is an orphaned file -- the same pre-existing condition this
        // change fixes going forward, not a new failure mode.
      }
    }
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
  ///
  /// [onUpdate] (Founder feedback -- View Once) is optional and, unlike
  /// [onInsert], registered on this same channel rather than a second
  /// one: so far the only UPDATE this app makes to an existing
  /// `messages` row is `mark_view_once_viewed()`/
  /// `clear_view_once_message()` flipping `viewed_at`/`image_url` --
  /// this is what lets the *sender's* own bubble flip from "sent,
  /// waiting to be opened" to "opened" live, the moment the recipient
  /// opens (or their countdown expires), without a reload.
  RealtimeChannel subscribeToConversationMessages(
    String conversationId,
    void Function(ChatMessage message) onInsert, {
    void Function(ChatMessage message)? onUpdate,
  }) {
    final channel = _client.channel('conversation-$conversationId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) => _handleRealtimeInsert(payload.newRecord, onInsert),
    );
    if (onUpdate != null) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) => onUpdate(ChatMessage.fromMap(payload.newRecord)),
      );
    }
    channel.subscribe();
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
