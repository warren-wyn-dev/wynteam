import 'appeal_status.dart';
import 'moderation_action_type.dart';

/// The moderator/admin-side view of an appeal -- includes fields
/// (original action's `reviewer_id`/reason, appellant's username) that
/// are only ever selected in a moderator-context query, never in the
/// appellant-facing one ([MyAppeal]/AppealRepository.fetchMyAppeal).
/// See .wyn/docs/design/wyn-030-appeal-system.md, Screen 6.
class Appeal {
  const Appeal({
    required this.id,
    required this.moderationActionId,
    required this.reason,
    this.evidencePaths,
    required this.status,
    this.decisionReason,
    required this.createdAt,
    required this.actionType,
    required this.actionReason,
    required this.actionCreatedAt,
    required this.actionReportId,
    required this.actionTargetUserId,
    this.actionReviewerUsername,
    this.appellantUsername,
    this.appellantDisplayName,
  });

  final String id;
  final String moderationActionId;
  final String reason;
  final List<String>? evidencePaths;
  final AppealStatus status;
  final String? decisionReason;
  final DateTime createdAt;

  /// The moderation_actions row this appeal is about -- reviewer_id is
  /// intentionally resolved to a *username* here (via a profile join),
  /// never the raw id, so this can only ever be used for display, not
  /// as a value threaded back through anything the appellant could see.
  final ModerationActionType actionType;
  final String actionReason;
  final DateTime actionCreatedAt;
  final String actionReportId;
  final String actionTargetUserId;
  final String? actionReviewerUsername;

  final String? appellantUsername;
  final String? appellantDisplayName;

  factory Appeal.fromMap(Map<String, dynamic> map) {
    final action = map['moderation_action'] as Map<String, dynamic>;
    final reviewer = action['reviewer'] as Map<String, dynamic>?;
    final appellant = map['appellant'] as Map<String, dynamic>?;
    return Appeal(
      id: map['id'] as String,
      moderationActionId: map['moderation_action_id'] as String,
      reason: map['reason'] as String,
      evidencePaths: (map['evidence_paths'] as List<dynamic>?)?.cast<String>(),
      status: AppealStatus.fromWire(map['status'] as String),
      decisionReason: map['decision_reason'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      actionType: moderationActionTypeFromWire(action['action_type'] as String),
      actionReason: action['reason'] as String,
      actionCreatedAt: DateTime.parse(action['created_at'] as String),
      actionReportId: action['report_id'] as String,
      actionTargetUserId: action['target_user_id'] as String,
      actionReviewerUsername: reviewer?['username'] as String?,
      appellantUsername: appellant?['username'] as String?,
      appellantDisplayName: appellant?['display_name'] as String?,
    );
  }
}
