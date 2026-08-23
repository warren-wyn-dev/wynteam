import 'package:supabase_flutter/supabase_flutter.dart';

import '../../report/data/report_target_type.dart';
import 'moderation_action_type.dart';
import 'moderation_report.dart';
import 'moderation_status.dart';
import 'moderation_target_summary.dart';

// Same author-embed FK-qualification pattern DropRepository/
// ClubPostRepository already use (see their own comments on why a bare
// `profiles(...)` embed is ambiguous) -- reused here rather than
// duplicated logic, just for a narrower column set (this screen only
// ever needs the author's username, never the full profile).
const _dropAuthorUsername = 'author:profiles!drops_author_id_fkey(username)';
const _dropCommentAuthorUsername =
    'author:profiles!drop_comments_author_id_fkey(username)';
const _clubPostAuthorUsername =
    'author:profiles!club_posts_author_id_fkey(username)';
const _clubPostCommentAuthorUsername =
    'author:profiles!club_post_comments_author_id_fkey(username)';

const _openStatuses = ['pending', 'reviewing'];

/// Wraps the `moderation_queue` view read, the per-target-type summary
/// lookups, and the `apply_moderation_action()`/
/// `get_my_moderation_status()` RPCs needed for WYN-029. See
/// supabase/schema.sql for the RLS/RPC this relies on.
class ModerationRepository {
  ModerationRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 20;

  /// FIFO -- oldest first (Product spec: "เรียงจากเก่าไปใหม่", no
  /// priority scoring this round).
  Future<List<ModerationReport>> fetchQueue({required int page}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('moderation_queue')
        .select('id, target_type, target_id, category, detail, status, created_at')
        .inFilter('status', _openStatuses)
        .order('created_at', ascending: true)
        .range(from, to);

    return rows.map((row) => ModerationReport.fromMap(row)).toList();
  }

  /// Re-fetches a single report by id -- used by
  /// ModerationReportDetailScreen to detect the "someone else already
  /// actioned this" race (Screen 3's own state).
  Future<ModerationReport?> fetchReport(String reportId) async {
    final row = await _client
        .from('moderation_queue')
        .select('id, target_type, target_id, category, detail, status, created_at')
        .eq('id', reportId)
        .maybeSingle();
    return row == null ? null : ModerationReport.fromMap(row);
  }

  /// Resolves [report]'s target to a short display summary. Never
  /// throws on a missing target -- that's a normal, expected outcome
  /// (see [ModerationTargetSummary]'s own doc comment), not an error.
  Future<ModerationTargetSummary> fetchTargetSummary(ModerationReport report) {
    switch (report.targetType) {
      case ReportTargetType.user:
        return _fetchUserSummary(report.targetId);
      case ReportTargetType.drop:
        return _fetchDropSummary(report.targetId);
      case ReportTargetType.dropComment:
        return _fetchDropCommentSummary(report.targetId);
      case ReportTargetType.club:
        return _fetchClubSummary(report.targetId);
      case ReportTargetType.clubPost:
        return _fetchClubPostSummary(report.targetId);
      case ReportTargetType.clubPostComment:
        return _fetchClubPostCommentSummary(report.targetId);
      case ReportTargetType.message:
        return _fetchMessageSummary(report.targetId);
    }
  }

  Future<ModerationTargetSummary> _fetchUserSummary(String userId) async {
    final row = await _client
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      return const ModerationTargetSummary(exists: false, label: '(บัญชีนี้ถูกลบไปแล้ว)');
    }
    final username = row['username'] as String;
    return ModerationTargetSummary(exists: true, label: '@$username', ownerUsername: username);
  }

  Future<ModerationTargetSummary> _fetchDropSummary(String dropId) async {
    final row = await _client
        .from('drops')
        .select('caption, $_dropAuthorUsername')
        .eq('id', dropId)
        .maybeSingle();
    if (row == null) {
      return const ModerationTargetSummary(exists: false, label: '(เนื้อหานี้ถูกลบไปแล้ว)');
    }
    final caption = row['caption'] as String?;
    final author = row['author'] as Map<String, dynamic>?;
    return ModerationTargetSummary(
      exists: true,
      label: (caption == null || caption.isEmpty) ? '(ไม่มีแคปชัน)' : caption,
      ownerUsername: author?['username'] as String?,
    );
  }

  Future<ModerationTargetSummary> _fetchDropCommentSummary(String commentId) async {
    final row = await _client
        .from('drop_comments')
        .select('text_content, drop_id, $_dropCommentAuthorUsername')
        .eq('id', commentId)
        .maybeSingle();
    if (row == null) {
      return const ModerationTargetSummary(exists: false, label: '(เนื้อหานี้ถูกลบไปแล้ว)');
    }
    final author = row['author'] as Map<String, dynamic>?;
    return ModerationTargetSummary(
      exists: true,
      label: row['text_content'] as String,
      ownerUsername: author?['username'] as String?,
      parentId: row['drop_id'] as String,
    );
  }

  Future<ModerationTargetSummary> _fetchClubSummary(String clubId) async {
    final row = await _client
        .from('clubs')
        .select('name')
        .eq('id', clubId)
        .maybeSingle();
    if (row == null) {
      return const ModerationTargetSummary(exists: false, label: '(Club นี้ถูกลบไปแล้ว)');
    }
    return ModerationTargetSummary(exists: true, label: row['name'] as String);
  }

  Future<ModerationTargetSummary> _fetchClubPostSummary(String postId) async {
    final row = await _client
        .from('club_posts')
        .select('content, $_clubPostAuthorUsername')
        .eq('id', postId)
        .maybeSingle();
    if (row == null) {
      return const ModerationTargetSummary(exists: false, label: '(เนื้อหานี้ถูกลบไปแล้ว)');
    }
    final content = row['content'] as String?;
    final author = row['author'] as Map<String, dynamic>?;
    return ModerationTargetSummary(
      exists: true,
      label: (content == null || content.isEmpty) ? '(โพสต์ไม่มีข้อความ)' : content,
      ownerUsername: author?['username'] as String?,
    );
  }

  Future<ModerationTargetSummary> _fetchClubPostCommentSummary(String commentId) async {
    final row = await _client
        .from('club_post_comments')
        .select('text_content, club_post_id, $_clubPostCommentAuthorUsername')
        .eq('id', commentId)
        .maybeSingle();
    if (row == null) {
      return const ModerationTargetSummary(exists: false, label: '(เนื้อหานี้ถูกลบไปแล้ว)');
    }
    final author = row['author'] as Map<String, dynamic>?;
    return ModerationTargetSummary(
      exists: true,
      label: row['text_content'] as String,
      ownerUsername: author?['username'] as String?,
      parentId: row['club_post_id'] as String,
    );
  }

  /// Uses `get_message_for_moderation()` (WYN-031) instead of a plain
  /// `.from('messages')` select -- `messages`' own SELECT policy is
  /// participant-only, and a moderator is never a conversation
  /// participant, so a direct select would always return nothing. The
  /// RPC re-checks the moderator role itself server-side rather than
  /// trusting this screen only ever calling it for moderators.
  Future<ModerationTargetSummary> _fetchMessageSummary(String messageId) async {
    final rows = await _client.rpc('get_message_for_moderation', params: {
      'p_message_id': messageId,
    }) as List<dynamic>;
    if (rows.isEmpty) {
      return const ModerationTargetSummary(exists: false, label: '(เนื้อหานี้ถูกลบไปแล้ว)');
    }
    final row = rows.first as Map<String, dynamic>;
    final deletedAt = row['deleted_at'] as String?;
    final sender = row['sender_username'] as String?;
    if (deletedAt != null) {
      return ModerationTargetSummary(
        exists: true,
        label: '(ข้อความนี้ถูกลบไปแล้ว)',
        ownerUsername: sender,
      );
    }
    final text = row['text'] as String?;
    final hasImage = row['image_url'] != null;
    final label = (text == null || text.isEmpty)
        ? (hasImage ? '📷 รูปภาพ' : '(ข้อความว่าง)')
        : text;
    return ModerationTargetSummary(exists: true, label: label, ownerUsername: sender);
  }

  /// Atomically applies one action (see supabase/schema.sql's
  /// `apply_moderation_action()` for the full atomic effect: closes the
  /// report, records the action, and performs its real-world effect).
  /// [durationDays] is required (1/3/7) for Restrict/Suspend, ignored
  /// otherwise -- validated both by ModerationActionSheet before this
  /// is ever called and again server-side.
  Future<void> applyAction({
    required String reportId,
    required ModerationActionType actionType,
    required String reason,
    int? durationDays,
  }) {
    return _client.rpc('apply_moderation_action', params: {
      'p_report_id': reportId,
      'p_action_type': actionType.wireValue,
      'p_reason': reason,
      'p_duration_days': durationDays,
    });
  }

  /// The caller's own current status -- see [ModerationStatus]'s doc
  /// comment for why this is the single call site both AuthGate and
  /// RestrictionBanner go through.
  Future<ModerationStatus> fetchMyStatus() async {
    final rows = await _client.rpc('get_my_moderation_status') as List<dynamic>;
    return ModerationStatus.fromMap(rows.first as Map<String, dynamic>);
  }
}
