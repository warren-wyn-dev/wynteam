import '../../report/data/report_category.dart';
import '../../report/data/report_target_type.dart';

/// One row of `public.moderation_queue` (see supabase/schema.sql,
/// WYN-029 section) -- deliberately has no `reporterId` field at all,
/// matching the view's own column list, which never includes
/// `reporter_id` (WYN-026's reporter-identity guarantee carrying
/// forward, per the design doc's Handoff item 2).
class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.category,
    this.detail,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final ReportTargetType targetType;
  final String targetId;
  final ReportCategory category;
  final String? detail;

  /// 'pending' | 'reviewing' | 'actioned' | 'dismissed'.
  final String status;
  final DateTime createdAt;

  factory ModerationReport.fromMap(Map<String, dynamic> map) => ModerationReport(
        id: map['id'] as String,
        targetType: reportTargetTypeFromWireValue(map['target_type'] as String),
        targetId: map['target_id'] as String,
        category: reportCategoryFromWireValue(map['category'] as String),
        detail: map['detail'] as String?,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
