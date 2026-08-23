/// What kind of thing a report (WYN-026) points at. Matches the
/// `target_type` check constraint on `public.reports` in
/// supabase/schema.sql. `message` (WYN-031) is the first target type
/// with a real entry point added after WYN-026 itself shipped.
enum ReportTargetType {
  user,
  drop,
  dropComment,
  club,
  clubPost,
  clubPostComment,
  message,
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
        ReportTargetType.message => 'message',
      };

  /// Thai label for the Moderation Queue's row/detail screens (WYN-029,
  /// Screen 2 -- "Category · Target type"). No other screen displays a
  /// target type on its own (every other report entry point already
  /// knows what it's reporting), so this is new with WYN-029.
  String get label => switch (this) {
        ReportTargetType.user => 'ผู้ใช้',
        ReportTargetType.drop => 'โพสต์ Drop',
        ReportTargetType.dropComment => 'คอมเมนต์ Drop',
        ReportTargetType.club => 'Club',
        ReportTargetType.clubPost => 'โพสต์ Club',
        ReportTargetType.clubPostComment => 'คอมเมนต์โพสต์ Club',
        ReportTargetType.message => 'ข้อความ',
      };
}

/// Parses the wire value back into a [ReportTargetType] -- needed by
/// WYN-029's Moderation Queue, which reads `target_type` back off
/// `moderation_queue` rows (every other report entry point only ever
/// writes [ReportTargetTypeWire.wireValue], never reads it back).
ReportTargetType reportTargetTypeFromWireValue(String value) =>
    switch (value) {
      'user' => ReportTargetType.user,
      'drop' => ReportTargetType.drop,
      'drop_comment' => ReportTargetType.dropComment,
      'club' => ReportTargetType.club,
      'club_post' => ReportTargetType.clubPost,
      'club_post_comment' => ReportTargetType.clubPostComment,
      'message' => ReportTargetType.message,
      _ => throw ArgumentError('Unknown report target type: $value'),
    };
