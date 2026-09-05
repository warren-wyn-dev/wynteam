// WYNOS Interaction Feedback System -- the vocabulary.
//
// Every haptic WYNOS is allowed to fire is one of these seven. Features
// never name a platform impact directly (`lightImpact`, `selectionClick`
// ...); they name an *intent* from this enum, and [WynHaptics] decides
// what that means on the device in hand. That indirection is the whole
// point: when the mapping needs to change (a platform gains real
// notification haptics, say), it changes in exactly one file instead of
// in every feature that ever buzzed.

/// The intent behind a haptic, not the waveform.
///
/// Ordered from quietest to loudest, then the two "semantic" ones --
/// see `.wyn/docs/design/ds-010-interaction-feedback.md` for which
/// product action gets which.
enum WynHapticType {
  /// The default acknowledgement for a reversible toggle the user just
  /// flipped: Like/Unlike, Save/Unsave, Follow/Unfollow, sending a
  /// comment, picking an option that matters.
  light,

  /// A change the user would notice if it happened by accident:
  /// confirming a destructive action, a delete that went through.
  medium,

  /// Reserved. Nothing in WYNOS uses this today -- it exists so a future
  /// action that genuinely warrants it doesn't reach for [error]
  /// (which means "this failed") just to get a stronger buzz.
  heavy,

  /// Moving between peers: switching a bottom-nav tab, a segmented
  /// control, a filter. Distinctly lighter than [light] on iOS, and
  /// that difference is the point -- navigating should not feel like
  /// committing.
  selection,

  /// An action the user asked for completed: a Drop published, a
  /// profile saved.
  success,

  /// Reserved for a "careful" moment that is not yet a failure. Unused
  /// today, same reasoning as [heavy].
  warning,

  /// An action failed. The only negative signal in the set -- never
  /// fire it for a validation hint the user is still mid-way through
  /// fixing, only for something that actually did not happen.
  error,
}
