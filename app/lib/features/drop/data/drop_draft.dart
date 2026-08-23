/// A saved-but-unpublished Drop (WYN-036) -- see supabase/schema.sql's
/// `drop_drafts` table. Entirely separate from [Drop]: a Draft never
/// appears in `home_feed`/Search/Notifications/Reports, and unlike a
/// published Drop is explicitly allowed to be incomplete (e.g. a Poll
/// draft with only 1 option filled in).
class DropDraft {
  const DropDraft({
    required this.id,
    this.imageUrl,
    this.caption,
    this.pollOptions,
    this.pollDurationDays,
    required this.updatedAt,
  });

  final String id;

  /// Set only for an image-mode draft.
  final String? imageUrl;

  /// Doubles as the caption (image mode) or the poll question (poll
  /// mode), same reuse [Drop.caption] already relies on.
  final String? caption;

  /// Set only for a poll-mode draft. May contain empty strings for a
  /// still-unfilled option -- a Draft is allowed to be incomplete,
  /// unlike a published Poll's [Drop.pollOptions].
  final List<String>? pollOptions;
  final int? pollDurationDays;
  final DateTime updatedAt;

  bool get isPoll => pollOptions != null;

  factory DropDraft.fromMap(Map<String, dynamic> map) => DropDraft(
        id: map['id'] as String,
        imageUrl: map['image_url'] as String?,
        caption: map['caption'] as String?,
        pollOptions: (map['poll_options'] as List<dynamic>?)?.cast<String>(),
        pollDurationDays: map['poll_duration_days'] as int?,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
