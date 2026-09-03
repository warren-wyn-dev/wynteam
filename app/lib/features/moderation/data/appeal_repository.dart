import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'appeal.dart';
import 'my_appeal.dart';
import 'my_moderation_action.dart';
import '../../../core/storage_upload_options.dart';

/// Wraps `appeals`, the `appeal-evidence` storage bucket, and the
/// `submit_appeal()`/`decide_appeal()`/`get_my_moderation_action()`
/// RPCs needed for WYN-030 (Appeal). See supabase/schema.sql for the
/// RLS/RPC this relies on.
///
/// **Column-list discipline is the actual privacy boundary here, not
/// RLS alone**: `appeals`' SELECT policy lets an appellant see their
/// own row in full (including `reviewer_id`), so [fetchMyAppeal] must
/// never select that column -- RLS is row-level, not column-level, the
/// same lesson this project has had to relearn twice already (WYN-027,
/// WYN-029). Only [fetchPendingAppeals]/[fetchAppeal] (moderator-only
/// call sites, gated by the screens that call them) select it.
class AppealRepository {
  AppealRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 20;
  static const _bucket = 'appeal-evidence';
  static const _signedUrlTtlSeconds = 3600;

  Future<MyModerationAction> fetchMyModerationAction(String actionId) async {
    final rows = await _client.rpc('get_my_moderation_action', params: {
      'p_action_id': actionId,
    }) as List<dynamic>;
    return MyModerationAction.fromMap(rows.first as Map<String, dynamic>);
  }

  /// Null if this action hasn't been appealed yet.
  Future<MyAppeal?> fetchMyAppeal(String actionId) async {
    final row = await _client
        .from('appeals')
        .select('reason, evidence_paths, status, decision_reason, created_at')
        .eq('moderation_action_id', actionId)
        .maybeSingle();
    return row == null ? null : MyAppeal.fromMap(row);
  }

  /// Uploads [evidenceImages] (if any) to the private `appeal-evidence`
  /// bucket under this user's own folder, then calls `submit_appeal()`.
  Future<void> submitAppeal({
    required String actionId,
    required String reason,
    List<Uint8List>? evidenceImages,
    List<String>? evidenceExtensions,
  }) async {
    final userId = _client.auth.currentUser!.id;

    List<String>? evidencePaths;
    if (evidenceImages != null && evidenceImages.isNotEmpty) {
      evidencePaths = [];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < evidenceImages.length; i++) {
        final extension = evidenceExtensions![i];
        final path = '$userId/$timestamp-$i.$extension';
        await _client.storage.from(_bucket).uploadBinary(
              path,
              evidenceImages[i],
              fileOptions: immutableUploadFileOptions,
            );
        evidencePaths.add(path);
      }
    }

    await _client.rpc('submit_appeal', params: {
      'p_action_id': actionId,
      'p_reason': reason,
      'p_evidence_paths': evidencePaths,
    });
  }

  /// A fresh signed URL for one evidence image path -- null on failure
  /// (matches ClubPostRepository._signedUrl's own posture: a broken
  /// thumbnail is better than a broken screen).
  Future<String?> evidenceSignedUrl(String path) async {
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, _signedUrlTtlSeconds);
    } catch (_) {
      return null;
    }
  }

  /// FIFO -- oldest first, same convention as
  /// ModerationRepository.fetchQueue.
  Future<List<Appeal>> fetchPendingAppeals({required int page}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('appeals')
        .select(
          'id, moderation_action_id, reason, evidence_paths, status, decision_reason, created_at, '
          'moderation_action:moderation_actions(action_type, reason, created_at, report_id, target_user_id, '
          'reviewer:profiles!moderation_actions_reviewer_id_fkey(username)), '
          'appellant:profiles!appeals_appellant_id_fkey(username, display_name)',
        )
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .range(from, to);

    return rows.map((row) => Appeal.fromMap(row)).toList();
  }

  /// Re-fetches a single appeal by id -- used by AppealDetailScreen to
  /// detect the "someone else already decided this" race.
  Future<Appeal?> fetchAppeal(String appealId) async {
    final row = await _client
        .from('appeals')
        .select(
          'id, moderation_action_id, reason, evidence_paths, status, decision_reason, created_at, '
          'moderation_action:moderation_actions(action_type, reason, created_at, report_id, target_user_id, '
          'reviewer:profiles!moderation_actions_reviewer_id_fkey(username)), '
          'appellant:profiles!appeals_appellant_id_fkey(username, display_name)',
        )
        .eq('id', appealId)
        .maybeSingle();
    return row == null ? null : Appeal.fromMap(row);
  }

  Future<void> decideAppeal({
    required String appealId,
    required bool approve,
    String? decisionReason,
  }) {
    return _client.rpc('decide_appeal', params: {
      'p_appeal_id': appealId,
      'p_approve': approve,
      'p_decision_reason': decisionReason,
    });
  }
}
