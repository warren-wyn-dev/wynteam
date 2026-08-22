/// What kind of thing a report (WYN-026) points at. Matches the
/// `target_type` check constraint on `public.reports` in
/// supabase/schema.sql. `message` has no UI entry point yet -- it's
/// reserved for WYN Chat (WYN-031/032, Phase 2) and `submit_report()`
/// rejects it server-side until that table exists.
enum ReportTargetType {
  user,
  drop,
  dropComment,
  club,
  clubPost,
  clubPostComment,
}

extension ReportTargetTypeWire on ReportTargetType {
  /// The exact string `submit_report()` and the `reports.target_type`
  /// check constraint expect.
  String get wireValue => switch (this) {
        ReportTargetType.user => 'user',
        ReportTargetType.drop => 'drop',
        ReportTargetType.dropComment => 'drop_comment',
        ReportTargetType.club => 'club',
        ReportTargetType.clubPost => 'club_post',
        ReportTargetType.clubPostComment => 'club_post_comment',
      };
}
