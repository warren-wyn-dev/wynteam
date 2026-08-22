/// Fixed set of report reasons -- matches the `category` check
/// constraint on `public.reports` in supabase/schema.sql and the Product
/// spec's Requirements (Category list is defined by the Master Spec, not
/// something the UI can add to). See
/// .wyn/docs/design/wyn-026-report-system.md, Screen 1.
enum ReportCategory {
  spam,
  scam,
  harassment,
  hate,
  sexualContent,
  violence,
  privacy,
  illegalContent,
  copyright,
  other,
}

extension ReportCategoryDisplay on ReportCategory {
  /// The exact string `submit_report()` and the `reports.category`
  /// check constraint expect.
  String get wireValue => switch (this) {
        ReportCategory.spam => 'spam',
        ReportCategory.scam => 'scam',
        ReportCategory.harassment => 'harassment',
        ReportCategory.hate => 'hate',
        ReportCategory.sexualContent => 'sexual_content',
        ReportCategory.violence => 'violence',
        ReportCategory.privacy => 'privacy',
        ReportCategory.illegalContent => 'illegal_content',
        ReportCategory.copyright => 'copyright',
        ReportCategory.other => 'other',
      };

  /// Thai label with the English term kept in parentheses -- the design
  /// spec asks for this so the WYN-029 moderation queue (which reads the
  /// same category values) stays unambiguous for reviewers.
  String get label => switch (this) {
        ReportCategory.spam => 'สแปม (Spam)',
        ReportCategory.scam => 'หลอกลวง (Scam)',
        ReportCategory.harassment => 'คุกคาม/กลั่นแกล้ง (Harassment)',
        ReportCategory.hate => 'ความเกลียดชัง (Hate)',
        ReportCategory.sexualContent => 'เนื้อหาทางเพศ (Sexual Content)',
        ReportCategory.violence => 'ความรุนแรง (Violence)',
        ReportCategory.privacy => 'ละเมิดความเป็นส่วนตัว (Privacy)',
        ReportCategory.illegalContent => 'ผิดกฎหมาย (Illegal Content)',
        ReportCategory.copyright => 'ละเมิดลิขสิทธิ์ (Copyright)',
        ReportCategory.other => 'อื่น ๆ (Other)',
      };
}

/// Parses [ReportCategoryDisplay.wireValue] back into a [ReportCategory]
/// -- needed by WYN-029's Moderation Queue, which reads `category` back
/// off `moderation_queue` rows (every other report entry point only
/// ever writes it, never reads it back).
ReportCategory reportCategoryFromWireValue(String value) => switch (value) {
      'spam' => ReportCategory.spam,
      'scam' => ReportCategory.scam,
      'harassment' => ReportCategory.harassment,
      'hate' => ReportCategory.hate,
      'sexual_content' => ReportCategory.sexualContent,
      'violence' => ReportCategory.violence,
      'privacy' => ReportCategory.privacy,
      'illegal_content' => ReportCategory.illegalContent,
      'copyright' => ReportCategory.copyright,
      'other' => ReportCategory.other,
      _ => throw ArgumentError('Unknown report category: $value'),
    };
