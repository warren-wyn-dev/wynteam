import 'appeal_status.dart';

/// The current caller's moderation status -- one row from
/// `get_my_moderation_status()` (see supabase/schema.sql, WYN-029
/// section, extended by WYN-030). The single source both `AuthGate`'s
/// login gate (Screen 6) and `RestrictionBanner` (Screen 7) read, so
/// the two can never disagree about what
/// "currently restricted/suspended/banned" means. Auto-expiry is
/// already applied server-side (the RPC only reports an active
/// Restrict/Suspend when `expires_at > now()`, and now also
/// `overturned_at is null` -- WYN-030), so nothing here needs its own
/// expiry/overturn math beyond formatting the date for display.
class ModerationStatus {
  const ModerationStatus({
    required this.isRestricted,
    this.restrictReason,
    this.restrictExpiresAt,
    this.restrictActionId,
    this.restrictAppealStatus = AppealStatus.none,
    required this.isSuspended,
    this.suspendReason,
    this.suspendExpiresAt,
    this.suspendActionId,
    this.suspendAppealStatus = AppealStatus.none,
    required this.isBanned,
    this.banReason,
    this.banActionId,
    this.banAppealStatus = AppealStatus.none,
  });

  final bool isRestricted;
  final String? restrictReason;
  final DateTime? restrictExpiresAt;
  final String? restrictActionId;
  final AppealStatus restrictAppealStatus;

  final bool isSuspended;
  final String? suspendReason;
  final DateTime? suspendExpiresAt;
  final String? suspendActionId;
  final AppealStatus suspendAppealStatus;

  final bool isBanned;
  final String? banReason;
  final String? banActionId;
  final AppealStatus banAppealStatus;

  /// Suspend and Ban both block login (Screen 6) -- Ban takes
  /// precedence in the UI when (implausibly) both are somehow active at
  /// once, since it's the more severe, permanent state.
  bool get blocksLogin => isBanned || isSuspended;

  factory ModerationStatus.fromMap(Map<String, dynamic> map) => ModerationStatus(
        isRestricted: map['is_restricted'] as bool,
        restrictReason: map['restrict_reason'] as String?,
        restrictExpiresAt: map['restrict_expires_at'] == null
            ? null
            : DateTime.parse(map['restrict_expires_at'] as String),
        restrictActionId: map['restrict_action_id'] as String?,
        restrictAppealStatus: map['restrict_appeal_status'] == null
            ? AppealStatus.none
            : AppealStatus.fromWire(map['restrict_appeal_status'] as String),
        isSuspended: map['is_suspended'] as bool,
        suspendReason: map['suspend_reason'] as String?,
        suspendExpiresAt: map['suspend_expires_at'] == null
            ? null
            : DateTime.parse(map['suspend_expires_at'] as String),
        suspendActionId: map['suspend_action_id'] as String?,
        suspendAppealStatus: map['suspend_appeal_status'] == null
            ? AppealStatus.none
            : AppealStatus.fromWire(map['suspend_appeal_status'] as String),
        isBanned: map['is_banned'] as bool,
        banReason: map['ban_reason'] as String?,
        banActionId: map['ban_action_id'] as String?,
        banAppealStatus: map['ban_appeal_status'] == null
            ? AppealStatus.none
            : AppealStatus.fromWire(map['ban_appeal_status'] as String),
      );
}
