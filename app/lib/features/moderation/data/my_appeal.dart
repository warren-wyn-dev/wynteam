import 'appeal_status.dart';

/// The current user's own view of an appeal they submitted -- one row
/// from `appeals`, queried with a column list that deliberately never
/// includes `reviewer_id` (RLS is row-level, not column-level: the
/// appellant's own SELECT policy lets them see their own row in full,
/// so the *query* itself is the only thing standing between them and
/// the reviewer's identity -- see .wyn/docs/design/
/// wyn-030-appeal-system.md, Screen 8, and MyAppealRepository.fetchMyAppeal).
class MyAppeal {
  const MyAppeal({
    required this.reason,
    this.evidencePaths,
    required this.status,
    this.decisionReason,
    required this.createdAt,
  });

  final String reason;
  final List<String>? evidencePaths;
  final AppealStatus status;
  final String? decisionReason;
  final DateTime createdAt;

  factory MyAppeal.fromMap(Map<String, dynamic> map) => MyAppeal(
        reason: map['reason'] as String,
        evidencePaths: (map['evidence_paths'] as List<dynamic>?)?.cast<String>(),
        status: AppealStatus.fromWire(map['status'] as String),
        decisionReason: map['decision_reason'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
