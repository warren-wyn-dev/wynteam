import 'package:flutter/foundation.dart';

/// WYN-113 (Invite-Only Access Gate): carries a validated referral code
/// from [RedeemInviteCodeScreen] across to OnboardingFlow's Birthday
/// step, where it's actually redeemed (see AuthRepository
/// .redeemReferralCode's own doc comment for why there specifically).
/// Static and in-memory, same "one-shot, app-lifecycle-scoped state"
/// shape as DeepLinkService's own `_handled` flag (deep_link_service.dart)
/// -- not threaded as a constructor parameter through every sign-in
/// screen (AuthMethodScreen, EmailAuthScreen, PhoneEntryScreen,
/// OtpVerificationScreen, OnboardingFlow) because none of those screens
/// otherwise need to know a referral code exists at all.
///
/// Known limitation, accepted for V1: this is lost if the app restarts
/// between redeeming a code and finishing the Birthday step (e.g. the
/// visitor closes the app mid-onboarding and resumes later) -- the same
/// class of gap OnboardingFlow's own `_username`/`_displayName` fields
/// already have ("Carried across steps purely for prefill... never
/// re-read from network mid-flow"). The actual gate enforcement already
/// happened before sign-in; losing this only means that one signup's
/// redemption is missed for viral-coefficient tracking, not that an
/// ungated signup occurred.
class PendingReferralCode {
  PendingReferralCode._();

  static String? _code;

  /// True once a code has been validated and is waiting to be redeemed
  /// -- read (without consuming) by AuthMethodScreen to decide whether
  /// the invite-gate prompt still needs to show.
  static bool get hasValidatedCode => _code != null;

  static void set(String code) => _code = code;

  /// Returns the pending code and clears it -- called at most once, by
  /// OnboardingFlow's Birthday step.
  static String? consume() {
    final code = _code;
    _code = null;
    return code;
  }

  @visibleForTesting
  static void resetForTest() => _code = null;
}
