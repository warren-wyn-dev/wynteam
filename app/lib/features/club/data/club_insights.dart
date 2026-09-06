/// WYN-117 (Club Owner Insights) -- one row from `public.club_insights()`
/// (see supabase/schema.sql), a single aggregate RPC computed entirely
/// at the DB layer, mirroring the Admin Dashboard's own
/// `admin_dashboard_metrics()` pattern (WYN-050/077) rather than
/// pulling raw rows to the client and summing them here.
class ClubInsights {
  const ClubInsights({
    required this.newMembers,
    required this.newPosts,
    required this.likesAndComments,
    required this.activeMembers,
  });

  /// Approved members whose `club_members.created_at` falls in the
  /// selected window. A brand-new Club's own owner counts here if the
  /// Club itself was created within the window -- that's correct data,
  /// not a bug (see the Design doc's own note).
  final int newMembers;

  final int newPosts;

  /// One combined total (not two separate numbers), matching the
  /// Product spec's own wording ("จำนวน Like/Comment รวม").
  final int likesAndComments;

  /// Distinct members who posted, liked, or commented at least once in
  /// the window -- counts by the action's own `created_at`, regardless
  /// of the actor's role or how long ago they joined.
  final int activeMembers;

  // Postgres `bigint` columns come back over PostgREST as a JSON number
  // decoded to Dart's `num`, not always directly castable `as int` --
  // same `(value as num).toInt()` convention
  // ClubPostRepository._fetchPollStates already uses for
  // get_club_poll_results()'s own bigint columns.
  factory ClubInsights.fromMap(Map<String, dynamic> map) => ClubInsights(
        newMembers: (map['new_members'] as num).toInt(),
        newPosts: (map['new_posts'] as num).toInt(),
        likesAndComments: (map['likes_and_comments'] as num).toInt(),
        activeMembers: (map['active_members'] as num).toInt(),
      );
}
