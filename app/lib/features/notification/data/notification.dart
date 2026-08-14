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
    required this.actorId,
    required this.actorUsername,
    this.actorDisplayName,
    this.actorAvatarUrl,
    this.dropId,
    this.popId,
    this.clubId,
    this.clubName,
    this.clubPostId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String actorId;
  final String actorUsername;
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

  final bool isRead;
  final DateTime createdAt;

  String get actorNameOrUsername => displayNameOrUsername(
        displayName: actorDisplayName,
        username: actorUsername,
      );

  factory WynNotification.fromMap(Map<String, dynamic> map) {
    final actor = map['actor'] as Map<String, dynamic>;
    final club = map['club'] as Map<String, dynamic>?;
    return WynNotification(
      id: map['id'] as String,
      type: _typeFromString(map['type'] as String),
      actorId: actor['id'] as String,
      actorUsername: actor['username'] as String? ?? '',
      actorDisplayName: actor['display_name'] as String?,
      actorAvatarUrl: actor['avatar_url'] as String?,
      dropId: map['drop_id'] as String?,
      popId: map['pop_id'] as String?,
      clubId: map['club_id'] as String?,
      clubName: club?['name'] as String?,
      clubPostId: map['club_post_id'] as String?,
      isRead: map['is_read'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
