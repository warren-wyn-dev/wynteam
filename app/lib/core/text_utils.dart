/// Converts an empty text field to `null`. Used for optional fields backed
/// by a DB constraint that requires either NULL or a non-empty value (e.g.
/// profiles_display_name_length, posts_text_content_length in
/// supabase/schema.sql), where sending '' would violate the constraint.
/// See .wyn/learning/MISTAKES.md for the bug this fixed in WYN-003.
String? normalizeOptionalText(String value) => value.isEmpty ? null : value;

/// The display name to show for a user: their display name if set, else
/// "@username" as a fallback. Shared by Profile, Post, and Comment so the
/// three don't drift.
String displayNameOrUsername({
  required String? displayName,
  required String username,
}) =>
    (displayName != null && displayName.isNotEmpty)
        ? displayName
        : '@$username';
