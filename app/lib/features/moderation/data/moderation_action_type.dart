/// The 6 actions a moderator/admin can take on a report (WYN-029),
/// matching the `moderation_actions.action_type` check constraint in
/// supabase/schema.sql and Master Spec section 25's Workflow. Ordered
/// here from least to most severe -- `ModerationReportDetailScreen`
/// (Screen 3) renders its action buttons in exactly this order.
enum ModerationActionType {
  noAction,
  warning,
  removeContent,
  restrict,
  suspend,
  ban,
}

extension ModerationActionTypeWire on ModerationActionType {
  /// The exact string `apply_moderation_action()` and the
  /// `moderation_actions.action_type` check constraint expect.
  String get wireValue => switch (this) {
        ModerationActionType.noAction => 'no_action',
        ModerationActionType.warning => 'warning',
        ModerationActionType.removeContent => 'remove_content',
        ModerationActionType.restrict => 'restrict',
        ModerationActionType.suspend => 'suspend',
        ModerationActionType.ban => 'ban',
      };

  /// Thai label -- used both as the Detail screen's button text and
  /// (via [confirmSheetTitle]) the Action sheet's header.
  String get label => switch (this) {
        ModerationActionType.noAction => 'ไม่ดำเนินการ (No Action)',
        ModerationActionType.warning => 'คำเตือน (Warning)',
        ModerationActionType.removeContent => 'ลบเนื้อหา (Remove Content)',
        ModerationActionType.restrict => 'จำกัดสิทธิ์ (Restrict)',
        ModerationActionType.suspend => 'ระงับชั่วคราว (Suspend)',
        ModerationActionType.ban => 'แบนถาวร (Ban)',
      };

  String get confirmSheetTitle => 'ยืนยัน: $label';

  /// Only Restrict/Suspend need a duration picker in
  /// ModerationActionSheet (Screen 4) -- Ban is permanent, the other 3
  /// have no time dimension at all.
  bool get needsDuration =>
      this == ModerationActionType.restrict || this == ModerationActionType.suspend;

  /// Helper text under the reason field, changes per action (Screen 4)
  /// -- No Action's reason is an internal-only note, every other
  /// action's reason is shown directly to the affected user.
  String get reasonHelperText => this == ModerationActionType.noAction
      ? 'ปิดเคสนี้โดยไม่มีผลต่อผู้ใช้ เหตุผลนี้เก็บเป็นบันทึกภายในเท่านั้น'
      : 'ผู้ใช้จะเห็นข้อความนี้โดยตรง เขียนให้ผู้ใช้เข้าใจได้';
}
