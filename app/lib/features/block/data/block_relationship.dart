/// The block relationship between the current user and some other user
/// -- matches the text values `public.block_relationship()` returns in
/// supabase/schema.sql (WYN-027). Distinguishes "I blocked them" from
/// "they blocked me" so ViewProfileScreen's Blocked persona (see
/// .wyn/docs/design/wyn-027-block-system.md, Screen 3) can pick honest
/// banner copy for each direction.
enum BlockRelationship {
  none,
  blockedByMe,
  blockedMe,
  mutual;

  static BlockRelationship fromWire(String value) => switch (value) {
        'blocked_by_me' => BlockRelationship.blockedByMe,
        'blocked_me' => BlockRelationship.blockedMe,
        'mutual' => BlockRelationship.mutual,
        _ => BlockRelationship.none,
      };

  /// True for any relationship where a block exists in either direction
  /// -- the condition every UI gate in WYN-027 actually cares about
  /// (Screen 1's "hide บล็อก item", Screen 3's "show Blocked persona").
  bool get isBlockedEitherWay => this != BlockRelationship.none;

  /// True only when *I* am the one who blocked them -- the only case
  /// where "เลิกบล็อก" (via Settings) is ever meaningful.
  bool get iBlockedThem =>
      this == BlockRelationship.blockedByMe || this == BlockRelationship.mutual;
}
