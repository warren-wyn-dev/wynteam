/// Which step of the First Login / Account Onboarding flow (Birthday ->
/// Username -> Display Name -> Password -> Profile Optional) a signed-in,
/// not-yet-onboarded user should resume at. Order matches
/// `.wyn/docs/design/wyn-002-authentication-onboarding.md`'s successor
/// flow: WELCOME -> GOOGLE AUTH -> BIRTHDAY -> USERNAME -> DISPLAY NAME ->
/// PASSWORD -> PROFILE OPTIONAL -> FINISH -> HOME.
enum OnboardingStep { birthday, username, displayName, password, profileOptional }

/// A signed-in user's onboarding progress, read in one query by
/// [AuthRepository.fetchOnboardingState] so AuthGate/OnboardingFlow never
/// have to guess which step to show. Closing the app mid-onboarding and
/// reopening it re-derives [resumeStep] from whatever has actually been
/// saved so far -- no separate "current step" column to keep in sync, and
/// no way for it to drift from the real data.
class OnboardingState {
  const OnboardingState({
    required this.hasDateOfBirth,
    required this.username,
    required this.displayName,
    required this.hasPassword,
    required this.completed,
  });

  /// A brand-new sign-in (no `profiles` row yet, no `profile_private` row
  /// yet) reads as every field unset -- resumeStep correctly starts at
  /// [OnboardingStep.birthday].
  factory OnboardingState.notStarted() => const OnboardingState(
        hasDateOfBirth: false,
        username: null,
        displayName: null,
        hasPassword: false,
        completed: false,
      );

  final bool hasDateOfBirth;
  final String? username;
  final String? displayName;

  /// True once the account has a password credential -- either it signed
  /// up with email+password directly (already has one), or it completed
  /// the onboarding Password step for a Google-only account. Never re-asks
  /// for a password once either is true.
  final bool hasPassword;

  final bool completed;

  /// Where a not-yet-onboarded user should resume. Only meaningful when
  /// [completed] is false -- AuthGate checks that first and renders
  /// RootShell directly once it's true, never consulting this.
  OnboardingStep get resumeStep {
    if (!hasDateOfBirth) return OnboardingStep.birthday;
    if (username == null) return OnboardingStep.username;
    if (displayName == null) return OnboardingStep.displayName;
    if (!hasPassword) return OnboardingStep.password;
    return OnboardingStep.profileOptional;
  }
}
