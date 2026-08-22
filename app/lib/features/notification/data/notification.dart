import '../../../core/text_utils.dart';

enum NotificationType {
  likeDrop,
  likePop,
  commentDrop,
  commentPop,
  follow,
  clubJoinRequest,
  clubJoinApproved,
  clubPostLike,
  clubPostComment,
  // ZOKY-005 R1 (2026-08-16): 4 new order notification types -- see
  // supabase/schema.sql's ZOKY-005 R1 section.
  newOrder,
  orderShipped,
  orderCancelled,
  orderRefunded,
  // WYN-021: fired by drop_mentions/club_post_mentions inserts.
  mentionDrop,
  mentionClubPost,
  // WYN-029: inserted by apply_moderation_action() for Warning/Remove
  // Content only -- see supabase/schema.sql. actor_id is deliberately
  // NULL for both (WYN-029 fix, see
  // .wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md) -- the
  // reviewer's real identity is only ever recorded, client-unreachable,
  // in moderation_actions.reviewer_id. NotificationListScreen also never
  // renders an actor for these types (see its own comment on why), as
  // defense-in-depth on top of the data-layer guarantee.
  moderationWarning,
  moderationContentRemoved,
}

NotificationType _typeFromString(String value) {
  switch (value) {
    case 'like_drop':
      return NotificationType.likeDrop;
    case 'like_pop':
      return NotificationType.likePop;
    case 'comment_drop':
      return NotificationType.commentDrop;
    case 'comment_pop':
      return NotificationType.commentPop;
    case 'follow':
      return NotificationType.follow;
    case 'club_join_request':
      return NotificationType.clubJoinRequest;
    case 'club_join_approved':
      return NotificationType.clubJoinApproved;
    case 'club_post_like':
      return NotificationType.clubPostLike;
    case 'club_post_comment':
      return NotificationType.clubPostComment;
    case 'new_order':
      return NotificationType.newOrder;
    case 'order_shipped':
      return NotificationType.orderShipped;
    case 'order_cancelled':
      return NotificationType.orderCancelled;
    case 'order_refunded':
      return NotificationType.orderRefunded;
    case 'mention_drop':
      return NotificationType.mentionDrop;
    case 'mention_club_post':
      return NotificationType.mentionClubPost;
    case 'moderation_warning':
      return NotificationType.moderationWarning;
    case 'moderation_content_removed':
      return NotificationType.moderationContentRemoved;
    default:
      throw ArgumentError('Unknown notification type: $value');
  }
}

/// One row of `public.notifications` (see supabase/schema.sql, WYN-012
/// section, extended by WYN-015), joined with the actor's profile info
/// and (for Club types) the club's name. The referenced content itself
/// ([dropId]/[popId]/[clubPostId]) is only an id here, not a full
/// Drop/Pop/ClubPost -- NotificationListScreen fetches the full object
/// on tap (DropRepository.fetchById/PopRepository.fetchById/
/// ClubPostRepository.fetchById) rather than joining it into every row
/// of a paginated list that never displays the content directly (see
/// .wyn/docs/design/wyn-012-notification.md, Screen 2).
class WynNotification {
  const WynNotification({
    required this.id,
    required this.type,
    this.actorId,
    this.actorUsername,
    this.actorDisplayName,
    this.actorAvatarUrl,
    this.dropId,
    this.popId,
    this.clubId,
    this.clubName,
    this.clubPostId,
    this.orderId,
    this.orderStoreName,
    this.reason,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final NotificationType type;

  /// Null only for [NotificationType.moderationWarning]/
  /// [NotificationType.moderationContentRemoved] (WYN-029 fix) -- every
  /// other notification type always has a real actor. See the enum's own
  /// doc comment for why these two are the exception.
  final String? actorId;
  final String? actorUsername;
  final String? actorDisplayName;
  final String? actorAvatarUrl;

  /// Set only when [type] is [NotificationType.likeDrop] or
  /// [NotificationType.commentDrop].
  final String? dropId;

  /// Set only when [type] is [NotificationType.likePop] or
  /// [NotificationType.commentPop].
  final String? popId;

  /// Set for every Club notification type (all four) -- see
  /// supabase/schema.sql's notify_club_post_like/notify_club_post_comment
  /// comments for why club_id is denormalized onto post-based types too.
  final String? clubId;
  final String? clubName;

  /// Set only when [type] is [NotificationType.clubPostLike] or
  /// [NotificationType.clubPostComment].
  final String? clubPostId;

  /// Set for every ZOKY-005 R1 order notification type (all four).
  final String? orderId;

  /// Denormalized the same way [clubName] is -- fetched through a
  /// nested `order:orders(store:stores(name))` embed rather than
  /// stored directly on the notification row, since the store's name
  /// can change after the notification is created (unlike `orders.
  /// total`, which is a deliberate point-in-time snapshot -- see
  /// supabase/schema.sql's create_orders() comment). Only set for
  /// order notification types.
  final String? orderStoreName;

  /// Set only for [NotificationType.moderationWarning]/
  /// [NotificationType.moderationContentRemoved] -- the moderator's
  /// reason text, denormalized directly onto this row rather than
  /// joined from `moderation_actions` (ordinary users have no SELECT
  /// policy on that table at all, see supabase/schema.sql -- this
  /// notification row is the only place the target ever sees it).
  final String? reason;

  final bool isRead;
  final DateTime createdAt;

  /// Empty for the same null-actor case [actorId] documents (WYN-029
  /// fix) -- callers that unconditionally read this for every
  /// notification type (e.g. `_messageFor`) must not crash, even though
  /// the two moderation types never actually display the result.
  String get actorNameOrUsername => actorUsername == null
      ? ''
      : displayNameOrUsername(
          displayName: actorDisplayName,
          username: actorUsername!,
        );

  factory WynNotification.fromMap(Map<String, dynamic> map) {
    // Null only for moderation_warning/moderation_content_removed
    // (WYN-029 fix) -- actor_id itself is null on those rows, so
    // PostgREST's embedded-resource syntax degrades to a null `actor`
    // key instead of a populated object. Every other notification type
    // always has a real actor here.
    final actor = map['actor'] as Map<String, dynamic>?;
    final club = map['club'] as Map<String, dynamic>?;
    final order = map['order'] as Map<String, dynamic>?;
    final orderStore = order?['store'] as Map<String, dynamic>?;
    return WynNotification(
      id: map['id'] as String,
      type: _typeFromString(map['type'] as String),
      actorId: actor?['id'] as String?,
      actorUsername: actor?['username'] as String?,
      actorDisplayName: actor?['display_name'] as String?,
      actorAvatarUrl: actor?['avatar_url'] as String?,
      dropId: map['drop_id'] as String?,
      popId: map['pop_id'] as String?,
      clubId: map['club_id'] as String?,
      clubName: club?['name'] as String?,
      clubPostId: map['club_post_id'] as String?,
      orderId: map['order_id'] as String?,
      orderStoreName: orderStore?['name'] as String?,
      reason: map['reason'] as String?,
      isRead: map['is_read'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
