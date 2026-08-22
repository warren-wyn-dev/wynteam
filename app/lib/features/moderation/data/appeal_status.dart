/// The appeal status for one moderation action, as returned by
/// `get_my_moderation_status()`'s `*_appeal_status` columns and
/// `appeals.status` (see supabase/schema.sql, WYN-030 section).
/// `approved` is included for completeness ([AppealStatus.fromWire])
/// but is not a reachable state for `RestrictionBanner`/
/// `AccountRestrictedScreen` -- see
/// .wyn/docs/design/wyn-030-appeal-system.md, Screen 2.
enum AppealStatus {
  none,
  pending,
  approved,
  rejected;

  static AppealStatus fromWire(String value) => switch (value) {
        'pending' => AppealStatus.pending,
        'approved' => AppealStatus.approved,
        'rejected' => AppealStatus.rejected,
        _ => AppealStatus.none,
      };
}
