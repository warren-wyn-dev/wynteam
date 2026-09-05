// WYNOS Interaction Feedback System -- the product-facing API.
//
// This is what features call. Every method is named after something a
// user did, never after a waveform, so the rules in
// `.wyn/docs/design/ds-010-interaction-feedback.md` live in code rather
// than in reviewers' heads: if Like should stop being a light impact,
// it changes here once and every Like in the app changes with it.
//
// Adding a method is how a new action joins the system. Reaching past
// this into [WynHaptics] from a feature is not -- see
// `test/interaction_guard_test.dart`.
import 'wyn_haptic_type.dart';
import 'wyn_haptics.dart';

/// Semantic feedback for WYNOS actions.
class WynFeedback {
  WynFeedback._();

  // -------------------------------------------------------------------
  // Reversible toggles -- light
  //
  // All of these share one property: the user can undo them with the
  // same tap that made them. That is what makes light the right weight
  // -- an acknowledgement, not a commitment.
  // -------------------------------------------------------------------

  /// Like / Unlike. Fired for the state change, in both directions:
  /// unliking is as deliberate an act as liking.
  static void like() => WynHaptics.fire(WynHapticType.light);

  /// Save / Unsave (bookmark).
  static void save() => WynHaptics.fire(WynHapticType.light);

  /// Follow / Unfollow, and sending or cancelling a follow request.
  static void follow() => WynHaptics.fire(WynHapticType.light);

  /// A comment that actually reached the server. Deliberately not fired
  /// on the send *tap* -- an optimistic buzz for a comment that then
  /// fails is worse than no buzz at all.
  static void commentSent() => WynHaptics.fire(WynHapticType.light);

  /// Any other meaningful two-state control (ReDrop, poll vote, mute).
  static void toggle() => WynHaptics.fire(WynHapticType.light);

  // -------------------------------------------------------------------
  // Moving between peers -- selection
  // -------------------------------------------------------------------

  /// Switching a bottom-nav tab, a segmented control, a filter.
  ///
  /// Fire this only when the selection genuinely changed. Every
  /// navigation is emphatically NOT a haptic: a buzz on each of the
  /// dozens of pushes in a browsing session stops meaning anything and
  /// starts costing battery.
  static void selectionChanged() => WynHaptics.fire(WynHapticType.selection);

  // -------------------------------------------------------------------
  // Committed changes -- medium
  // -------------------------------------------------------------------

  /// A delete that went through. Paired with the item leaving the UI,
  /// never on its own.
  static void deleted() => WynHaptics.fire(WynHapticType.medium);

  /// Confirming something the app asked twice about, where the result
  /// is not a delete (blocking someone, leaving a Club).
  static void confirmed() => WynHaptics.fire(WynHapticType.medium);

  // -------------------------------------------------------------------
  // Outcomes -- success / error
  // -------------------------------------------------------------------

  /// Something the user waited on finished: a Drop or Pop published, a
  /// Club created, a profile saved.
  ///
  /// (The brief lists "create post" under both medium and success. It is
  /// success here: what the user is being told is *that it worked*, and
  /// publishing is the one action in WYNOS that has a real wait in front
  /// of it. Medium stays the weight for confirm/delete, where the point
  /// is the weight of the commitment rather than the outcome.)
  static void completed() => WynHaptics.fire(WynHapticType.success);

  /// An action the user asked for did not happen -- an upload that
  /// failed, a delete the server refused. Never for a form field that
  /// is merely still incomplete.
  static void failed() => WynHaptics.fire(WynHapticType.error);
}
