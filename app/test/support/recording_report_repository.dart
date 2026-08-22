import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/report/data/report_category.dart';
import 'package:wyn/features/report/data/report_repository.dart';
import 'package:wyn/features/report/data/report_target_type.dart';

/// A ReportRepository whose network-touching methods are overridden to
/// just record what they were called with, instead of making a real
/// Supabase call. Mirrors RecordingDropRepository (WYN-005) -- see
/// .wyn/learning/PATTERNS.md.
class RecordingReportRepository extends ReportRepository {
  RecordingReportRepository({
    this.hasOpenReportResult = false,
    this.hasOpenReportError,
    this.submitReportError,
  }) : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [hasOpenReport] unless [hasOpenReportError] is set.
  /// Mutable (not just constructor-set) so a single instance built once
  /// in `setUpAll` -- see RecordingDropRepository's doc comment on why
  /// that matters for the underlying SupabaseClient's auto-refresh
  /// Timer -- can still be reconfigured per test.
  bool hasOpenReportResult;

  /// If set, [hasOpenReport] throws this instead of returning a result.
  Object? hasOpenReportError;

  /// If set, [submitReport] throws this instead of succeeding.
  Object? submitReportError;

  int hasOpenReportCalls = 0;
  int submitReportCalls = 0;
  ReportTargetType? lastTargetType;
  String? lastTargetId;
  ReportCategory? lastCategory;
  String? lastDetail;

  @override
  Future<bool> hasOpenReport({
    required ReportTargetType targetType,
    required String targetId,
  }) async {
    hasOpenReportCalls++;
    final error = hasOpenReportError;
    if (error != null) throw error;
    return hasOpenReportResult;
  }

  @override
  Future<void> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportCategory category,
    String? detail,
  }) async {
    submitReportCalls++;
    lastTargetType = targetType;
    lastTargetId = targetId;
    lastCategory = category;
    lastDetail = detail;
    final error = submitReportError;
    if (error != null) throw error;
  }
}
