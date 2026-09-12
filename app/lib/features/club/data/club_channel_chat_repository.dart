import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage_upload_options.dart';
import 'club_channel_message.dart';

// Hinted by column name, not by the FK's constraint name -- mirrors
// ChatRepository._replyEmbed's identical reasoning: PostgREST 400s on
// the constraint-name form for this exact shape of self-referencing
// relationship.
const _replyEmbed =
    'reply_to:club_channel_messages!reply_to_message_id(content, image_url)';
const _authorSelect =
    'author:profiles!club_channel_messages_author_id_fkey(username, display_name, avatar_url)';
const _messageColumns =
    'id, channel_id, author_id, content, image_url, reply_to_message_id, created_at, $_authorSelect, $_replyEmbed';

/// Wraps `club_channel_messages`/`club_channel_message_reads` (WYN-128)
/// -- the Club Group Chat's own tables, entirely separate from
/// `conversations`/`messages` (WYN-031). See supabase/schema.sql's
/// "WYN-128: Club Group Chat" section for the RLS this relies on.
///
/// Sending a message is a plain table insert (no RPC), same reasoning
/// ChatRepository/ClubPostRepository give for their own sends: every
/// condition is already an RLS `with check`. Deleting one is a plain
/// hard DELETE (not delete_message()'s soft null-out) -- mirrors
/// club_posts, since there's no View-Once/shared-content state here
/// that a hard delete could leave dangling.
class ClubChannelChatRepository {
  ClubChannelChatRepository(this._client);

  final SupabaseClient _client;

  static const messagePageSize = 30;
  static const _bucket = 'club-media';
  static const _signedUrlTtlSeconds = 3600;

  String get _myUserId => _client.auth.currentUser!.id;

  /// Newest first (matches the chat screen's `reverse: true` list) --
  /// mirrors ChatRepository.fetchMessages' identical cursor-on-
  /// created_at pagination shape.
  Future<List<ClubChannelMessage>> fetchMessages(
    String channelId, {
    DateTime? beforeCreatedAt,
  }) async {
    var query = _client
        .from('club_channel_messages')
        .select(_messageColumns)
        .eq('channel_id', channelId);
    if (beforeCreatedAt != null) {
      query = query.lt('created_at', beforeCreatedAt.toIso8601String());
    }
    final rows = await query
        .order('created_at', ascending: false)
        .limit(messagePageSize);
    return rows.map((row) => ClubChannelMessage.fromMap(row)).toList();
  }

  Future<ClubChannelMessage?> fetchMessage(String messageId) async {
    final row = await _client
        .from('club_channel_messages')
        .select(_messageColumns)
        .eq('id', messageId)
        .maybeSingle();
    return row == null ? null : ClubChannelMessage.fromMap(row);
  }

  /// [imageBytes]/[imageExtension] upload to the *existing* `club-media`
  /// bucket at `{clubId}/chat/{channelId}/{userId}-{timestamp}.ext` --
  /// see the migration's own comment for why this path shape is already
  /// covered by WYN-014's existing storage policies with no new bucket
  /// or policy needed.
  Future<ClubChannelMessage> sendMessage({
    required String clubId,
    required String channelId,
    String? content,
    Uint8List? imageBytes,
    String? imageExtension,
    String? replyToMessageId,
  }) async {
    String? imagePath;
    if (imageBytes != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      imagePath =
          '$clubId/chat/$channelId/$_myUserId-$timestamp.${imageExtension ?? 'jpg'}';
      await _client.storage.from(_bucket).uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: immutableUploadFileOptions,
          );
    }

    final row = await _client
        .from('club_channel_messages')
        .insert({
          'channel_id': channelId,
          'author_id': _myUserId,
          'content': (content == null || content.trim().isEmpty)
              ? null
              : content.trim(),
          'image_url': imagePath,
          'reply_to_message_id': replyToMessageId,
        })
        .select(_messageColumns)
        .single();
    return ClubChannelMessage.fromMap(row);
  }

  /// RLS restricts this to the message's own author or that Club's
  /// staff (owner/admin/moderator) -- see supabase/schema.sql.
  Future<void> deleteMessage(String messageId) {
    return _client.from('club_channel_messages').delete().eq('id', messageId);
  }

  Future<String?> imageSignedUrl(String path) async {
    try {
      return await _client.storage
          .from(_bucket)
          .createSignedUrl(path, _signedUrlTtlSeconds);
    } catch (_) {
      return null;
    }
  }

  Future<void> markChannelRead(String channelId) {
    return _client
        .rpc('mark_club_channel_read', params: {'p_channel_id': channelId});
  }

  /// Every channel's unread count in [clubId], keyed by channel id --
  /// batched in one RPC call the same way ClubRepository.fetchChannels
  /// batches every channel's name.
  Future<Map<String, int>> fetchUnreadCounts(String clubId) async {
    final rows = await _client.rpc('get_unread_channel_counts',
        params: {'p_club_id': clubId}) as List<dynamic>;
    return {
      for (final row in rows)
        (row as Map<String, dynamic>)['channel_id'] as String:
            (row['unread_count'] as num).toInt(),
    };
  }

  /// A `postgres_changes` payload is always the raw row -- never the
  /// `reply_to`/`author` embeds `fetchMessages()`'s own select does --
  /// so a realtime-delivered message is re-fetched once (by id) before
  /// the caller ever sees it, same reasoning as
  /// ChatRepository._handleRealtimeInsert.
  Future<void> _handleRealtimeInsert(
    Map<String, dynamic> rawRow,
    void Function(ClubChannelMessage message) onInsert,
  ) async {
    final full = await fetchMessage(rawRow['id'] as String);
    if (full != null) onInsert(full);
  }

  /// Subscribes to every new message in [channelId], and (when
  /// [onPresenceChange] is given) tracks this user's presence on the
  /// same realtime channel so [onPresenceChange] can report a live count
  /// of distinct members currently viewing it -- Design's Components:
  /// "หัวห้องโชว์จำนวนสมาชิกออนไลน์". Caller must `unsubscribe()` in
  /// `dispose()`, same as ChatRepository.subscribeToConversationMessages.
  RealtimeChannel subscribeToChannel(
    String channelId,
    void Function(ClubChannelMessage message) onInsert, {
    void Function(int onlineCount)? onPresenceChange,
  }) {
    final channel = _client.channel(
      'club-channel-$channelId',
      opts: RealtimeChannelConfig(key: _myUserId),
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'club_channel_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'channel_id',
        value: channelId,
      ),
      callback: (payload) => _handleRealtimeInsert(payload.newRecord, onInsert),
    );
    if (onPresenceChange != null) {
      channel.onPresenceSync(
          (_) => onPresenceChange(channel.presenceState().length));
    }
    channel.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed &&
          onPresenceChange != null) {
        await channel.track({'online_at': DateTime.now().toIso8601String()});
      }
    });
    return channel;
  }

  /// A lighter-weight subscription than [subscribeToChannel] -- no
  /// presence tracking, used only to keep a channel's unread badge live
  /// while its chat screen isn't open (see ClubPostsTab's own doc
  /// comment on why this is a second, separate channel subscription
  /// rather than reusing one).
  RealtimeChannel subscribeToNewMessagesOnly(
    String channelId,
    void Function(ClubChannelMessage message) onInsert,
  ) {
    final channel = _client.channel('club-channel-unread-$channelId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'club_channel_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: channelId,
          ),
          callback: (payload) =>
              _handleRealtimeInsert(payload.newRecord, onInsert),
        )
        .subscribe();
    return channel;
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
