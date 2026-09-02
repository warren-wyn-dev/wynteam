import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wyn_typography.dart';

/// Shared chrome for every First Login / Account Onboarding step (Birthday,
/// Username, Display Name, Password, Profile Optional, Finish) -- Back,
/// Title, short description, the step's own input, a progress indicator,
/// and a primary CTA pinned above the keyboard. See the design spec's
/// Screen 15 example layout.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.body,
    required this.stepIndex,
    required this.stepCount,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.isLoading = false,
    this.onBack,
    this.errorText,
    this.footer,
  });

  final String title;
  final String description;
  final Widget body;

  /// 1-based -- shown as "$stepIndex of $stepCount".
  final int stepIndex;
  final int stepCount;

  final String primaryLabel;

  /// Null disables the primary CTA (e.g. input not yet valid).
  final VoidCallback? onPrimaryPressed;
  final bool isLoading;

  /// Null hides the back chevron entirely (Birthday, the first step, has
  /// nothing local to go back to).
  final VoidCallback? onBack;
  final String? errorText;

  /// Optional extra content under the CTA (e.g. Profile Optional's "Skip"
  /// link).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                WynSpacing.space2,
                WynSpacing.space2,
                WynSpacing.space5,
                0,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: WynSpacing.touchTargetRecommended,
                    height: WynSpacing.touchTargetRecommended,
                    child: onBack == null
                        ? null
                        : IconButton(
                            key: const Key('onboarding_back_button'),
                            icon: const Icon(Icons.chevron_left,
                                size: 24, color: WynColors.ink),
                            onPressed: isLoading ? null : onBack,
                          ),
                  ),
                  const Spacer(),
                  Text(
                    '$stepIndex of $stepCount',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: WynColors.faint,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: WynSpacing.space6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: WynSpacing.space4),
                    Text(
                      title,
                      style: WynTypography.screenTitle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: WynColors.ink,
                      ),
                    ),
                    const SizedBox(height: WynSpacing.space2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: WynColors.graphite,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: WynSpacing.space8),
                    body,
                    if (errorText != null) ...[
                      const SizedBox(height: WynSpacing.space4),
                      Text(
                        errorText!,
                        style:
                            const TextStyle(fontSize: 13, color: WynColors.errorLight),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                WynSpacing.space6,
                WynSpacing.space4,
                WynSpacing.space6,
                WynSpacing.space6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          vertical: WynSpacing.space3 + 2),
                      backgroundColor: WynColors.sapphire,
                      foregroundColor: WynColors.paper,
                      disabledBackgroundColor: WynColors.hairline,
                      disabledForegroundColor: WynColors.mutedNeutral,
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    onPressed: isLoading ? null : onPrimaryPressed,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: WynColors.paper),
                          )
                        : Text(primaryLabel),
                  ),
                  if (footer != null) footer!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fade + slide transition shared by every step change inside
/// OnboardingFlow -- fast and subtle per the design spec's Motion section,
/// reusing Flutter's own transition primitives rather than a new
/// animation framework (this app has no dedicated motion system to reuse
/// -- see core/design/, which only defines static tokens).
Widget onboardingStepTransition(Widget child, Animation<double> animation) {
  final offsetAnimation = Tween<Offset>(
    begin: const Offset(0.04, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(position: offsetAnimation, child: child),
  );
}
