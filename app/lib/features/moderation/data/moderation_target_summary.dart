/// A short, best-effort description of a report's target for the
/// Moderation Queue's list row (Screen 2) and detail link card
/// (Screen 3) -- resolved separately from [ModerationReport] itself,
/// since it depends on the target's own table (`profiles`/`drops`/
/// `drop_comments`/`clubs`/`club_posts`/`club_post_comments`/
/// `messages`), each with a different shape, and can legitimately be
/// "gone" if the content was deleted (by its own author, or by an
/// earlier Remove Content action on a different report against the
/// same content) before a moderator got to review it. `messages`
/// (WYN-031) is a partial exception -- a soft-deleted message still
/// [exists] as a row (see `delete_message()`, which nulls content
/// rather than removing the row), so its [label] communicates the
/// deletion directly instead of via [exists] the way every hard-delete
/// target type does.
class ModerationTargetSummary {
  const ModerationTargetSummary({
    required this.exists,
    required this.label,
    this.ownerUsername,
    this.parentId,
  });

  /// False when the target row no longer exists.
  final bool exists;

  /// Short display text -- "@username" (user), a caption/text excerpt
  /// (drop/drop_comment/club_post/club_post_comment), a Club name
  /// (club/club_post), or "(เนื้อหานี้ถูกลบไปแล้ว)"/"(บัญชีนี้ถูกลบไปแล้ว)"
  /// when [exists] is false.
  final String label;

  /// The content's author's username -- set for every target type
  /// except `user` (where the target *is* the account) and only when
  /// [exists] is true. Used by Screen 3's link card label ("โพสต์ Drop
  /// ของ @username").
  final String? ownerUsername;

  /// For `drop_comment`/`club_post_comment` only: the parent Drop/Club
  /// Post's own id, needed to open *that* screen (comments have no
  /// standalone detail screen in this app, same as
  /// NotificationListScreen never opens one).
  final String? parentId;
}
