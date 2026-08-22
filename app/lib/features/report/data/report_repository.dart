import 'package:supabase_flutter/supabase_flutter.dart';

import 'report_category.dart';
import 'report_target_type.dart';

const _openStatuses = ['pending', 'reviewing'];

/// Wraps the `reports` table read and `submit_report()` RPC needed for
/// WYN-026 (Report). See supabase/schema.sql for the RLS policy (a
/// reporter can only ever see their own submitted reports) and the RPC
/// this relies on for validating/inserting.
class ReportRepository {
  ReportRepository(this._client);

  final SupabaseClient _client;

  /// Whether the current user already has an open (pending/reviewing)
  /// report against this exact target -- used to show "รายงานแล้ว"
  /// instead of the report form. See ReportSheet.
  Future<bool> hasOpenReport({
    required ReportTargetType targetType,
    required String targetId,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('reports')
        .select('id')
        .eq('reporter_id', userId)
        .eq('target_type', targetType.wireValue)
        .eq('target_id', targetId)
        .inFilter('status', _openStatuses)
        .limit(1);
    return rows.isNotEmpty;
  }

  /// [detail] is required by the caller (ReportSheet) when [category] is
  /// [ReportCategory.other] -- also enforced server-side by
  /// `reports_other_requires_detail`. Throws if the target doesn't
  /// exist, is the caller's own, or already has an open report from
  /// this user (submit_report() re-raises the unique-violation as a
  /// clearer message).
  Future<void> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportCategory category,
    String? detail,
  }) {
    return _client.rpc('submit_report', params: {
      'p_target_type': targetType.wireValue,
      'p_target_id': targetId,
      'p_category': category.wireValue,
      'p_detail': detail,
    });
  }
}
