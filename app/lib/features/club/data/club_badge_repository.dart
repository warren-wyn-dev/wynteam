import 'package:supabase_flutter/supabase_flutter.dart';

import 'club_member_badge.dart';

/// WYN-129 -- reads/writes `club_member_badges` and nothing else.
///
/// Deliberately its **own** repository, not a method group tacked onto
/// `ClubRepository`: badges are a purely cosmetic, Club-scoped identity
/// layer with **zero** effect on permissions (Product spec Requirement 2
/// / Risks: "ห้ามมีการเช็ค permission จากป้ายเด็ดขาด ... ต้องแยกจาก
/// `club_role()` โดยสิ้นเชิง"). Keeping every badge read/write confined
/// to this one small file makes that isolation trivial for AI QA &
/// Security (or anyone) to verify by inspection: nothing in this file
/// calls `club_role()` to *grant* anything, and nothing that calls
/// `club_role()` to gate a real action (ClubRepository,
/// ClubPostRepository, every RLS policy in supabase/schema.sql that
/// protects a mutation) ever queries `club_member_badges`. Do not merge
/// this into `ClubRepository` later without re-reading this comment.
class ClubBadgeRepository {
  ClubBadgeRepository(this._client);

  final SupabaseClient _client;

  /// Every badge in [clubId], keyed by member user id -- one query per
  /// screen load (Members tab / Posts tab / Post detail), mirroring how
  /// ClubPostRepository batches likes/saves per page rather than one
  /// query per row.
  Future<Map<String, ClubMemberBadge>> fetchBadges(String clubId) async {
    final rows =
        await _client.from('club_member_badges').select().eq('club_id', clubId);
    return {
      for (final row in rows)
        row['user_id'] as String: ClubMemberBadge.fromMap(row),
    };
  }

  /// Sets (or replaces) [userId]'s single badge in [clubId] -- RLS
  /// (`club_member_badges` insert/update policies) restricts this to
  /// that Club's own Owner/Admin, and only while [userId] is currently
  /// an approved member of the same Club.
  Future<void> setBadge({
    required String clubId,
    required String userId,
    required String label,
    required ClubBadgeColor color,
  }) async {
    final myId = _client.auth.currentUser!.id;
    await _client.from('club_member_badges').upsert(
      {
        'club_id': clubId,
        'user_id': userId,
        'label': label.trim(),
        'color_key': color.wireValue,
        'created_by': myId,
      },
      onConflict: 'club_id,user_id',
    );
  }

  Future<void> removeBadge({required String clubId, required String userId}) {
    return _client
        .from('club_member_badges')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', userId);
  }
}
