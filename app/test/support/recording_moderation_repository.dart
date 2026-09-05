import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/moderation/data/moderation_action_type.dart';
import 'package:wyn/features/moderation/data/moderation_report.dart';
import 'package:wyn/features/moderation/data/moderation_repository.dart';
import 'package:wyn/features/moderation/data/moderation_status.dart';
import 'package:wyn/features/moderation/data/moderation_target_summary.dart';

/// A ModerationRepository whose network-touching methods are overridden
/// to just record what they were called with / return canned data,
/// instead of making a real Supabase call. Mirrors
/// RecordingReportRepository (WYN-026) -- see .wyn/learning/PATTERNS.md.
class RecordingModerationRepository extends ModerationRepository {
  RecordingModerationRepository({
    this.myStatus = const ModerationStatus(
      isRestricted: false,
      isSuspended: false,
      isBanned: false,
    ),
    this.myStatusError,
    this.queuePages = const [],
    this.fetchQueueError,
    this.targetSummaries = const {},
    this.applyActionError,
  }) : super(
          // autoRefreshToken: false -- see
          // RecordingAuthRepository's identical comment on why a
          // default SupabaseClient's auto-refresh Timer is a problem
          // when this is constructed fresh inside a `testWidgets` body
          // (as auth_gate_test.dart does) rather than once in
          // `setUpAll`.
          SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  /// Returned by [fetchMyStatus] unless [myStatusError] is set.
  ModerationStatus myStatus;
  Object? myStatusError;

  /// One entry per page index -- fetchQueue(page: n) returns
  /// queuePages[n], or an empty list once past the end.
  List<List<ModerationReport>> queuePages;
  Object? fetchQueueError;

  /// Keyed by [ModerationReport.id] -- fetchTargetSummary looks the
  /// report's own id up here.
  Map<String, ModerationTargetSummary> targetSummaries;

  Object? applyActionError;
  int applyActionCalls = 0;
  String? lastReportId;
  ModerationActionType? lastActionType;
  String? lastReason;
  int? lastDurationDays;

  int fetchMyStatusCalls = 0;

  @override
  Future<ModerationStatus> fetchMyStatus() async {
    fetchMyStatusCalls++;
    final error = myStatusError;
    if (error != null) throw error;
    return myStatus;
  }

  @override
  Future<List<ModerationReport>> fetchQueue({required int page}) async {
    final error = fetchQueueError;
    if (error != null) throw error;
    if (page < 0 || page >= queuePages.length) return [];
    return queuePages[page];
  }

  @override
  Future<ModerationReport?> fetchReport(String reportId) async {
    for (final page in queuePages) {
      for (final report in page) {
        if (report.id == reportId) return report;
      }
    }
    return null;
  }

  @override
  Future<ModerationTargetSummary> fetchTargetSummary(ModerationReport report) async {
    return targetSummaries[report.id] ??
        const ModerationTargetSummary(exists: true, label: 'summary');
  }

  @override
  Future<void> applyAction({
    required String reportId,
    required ModerationActionType actionType,
    required String reason,
    int? durationDays,
  }) async {
    applyActionCalls++;
    lastReportId = reportId;
    lastActionType = actionType;
    lastReason = reason;
    lastDurationDays = durationDays;
    final error = applyActionError;
    if (error != null) throw error;
  }
}
