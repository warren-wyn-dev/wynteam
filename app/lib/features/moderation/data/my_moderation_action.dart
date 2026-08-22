import 'moderation_action_type.dart';

/// One row from `get_my_moderation_action(p_action_id)` (see
/// supabase/schema.sql, WYN-030 section) -- deliberately excludes
/// `reviewer_id`/`report_id`, the only columns of `moderation_actions`
/// an ordinary user is never allowed to read about their own row. See
/// .wyn/docs/design/wyn-030-appeal-system.md, Screen 8.
class MyModerationAction {
  const MyModerationAction({
    required this.actionType,
    required this.reason,
    this.durationDays,
    this.expiresAt,
    required this.createdAt,
  });

  final ModerationActionType actionType;
  final String reason;
  final int? durationDays;
  final DateTime? expiresAt;
  final DateTime createdAt;

  factory MyModerationAction.fromMap(Map<String, dynamic> map) => MyModerationAction(
        actionType: moderationActionTypeFromWire(map['action_type'] as String),
        reason: map['reason'] as String,
        durationDays: map['duration_days'] as int?,
        expiresAt: map['expires_at'] == null
            ? null
            : DateTime.parse(map['expires_at'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
