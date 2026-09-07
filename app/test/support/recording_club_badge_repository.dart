import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/club/data/club_badge_repository.dart';
import 'package:wyn/features/club/data/club_member_badge.dart';

/// A ClubBadgeRepository whose network-touching methods are overridden to
/// just record what they were called with / return canned data, instead
/// of making a real Supabase call. Mirrors RecordingClubRepository -- see
/// .wyn/learning/PATTERNS.md.
class RecordingClubBadgeRepository extends ClubBadgeRepository {
  RecordingClubBadgeRepository({Map<String, ClubMemberBadge>? badges})
      : badges = badges ?? {},
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Backing map for [fetchBadges], keyed by user id -- mutated in place
  /// by [setBadge]/[removeBadge] so a test can assert the round trip.
  Map<String, ClubMemberBadge> badges;

  int setBadgeCalls = 0;
  int removeBadgeCalls = 0;
  final List<String> removeBadgeUserIdArgs = [];

  @override
  Future<Map<String, ClubMemberBadge>> fetchBadges(String clubId) async =>
      Map.of(badges);

  @override
  Future<void> setBadge({
    required String clubId,
    required String userId,
    required String label,
    required ClubBadgeColor color,
  }) async {
    setBadgeCalls++;
    badges = {
      ...badges,
      userId: ClubMemberBadge(
        clubId: clubId,
        userId: userId,
        label: label,
        colorKey: color,
        createdBy: 'me',
        createdAt: DateTime.now(),
      ),
    };
  }

  @override
  Future<void> removeBadge({required String clubId, required String userId}) async {
    removeBadgeCalls++;
    removeBadgeUserIdArgs.add(userId);
    badges = {...badges}..remove(userId);
  }
}
