import 'package:flutter/material.dart';

import '../../../../../core/design/wyn_colors.dart';
import '../../../../../core/design/wyn_spacing.dart';
import '../../../../../core/design/wyn_typography.dart';

/// Screen 8 -- Finish. The one screen in this flow with no form input and
/// no progress counter (per the design spec's mock -- a pure celebratory
/// moment before Home), so it doesn't use OnboardingScaffold.
class FinishStep extends StatelessWidget {
  const FinishStep({
    super.key,
    required this.onEnter,
    this.isLoading = false,
    this.errorText,
  });

  final VoidCallback onEnter;
  final bool isLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: WynColors.sapphire,
                ),
                child: const Icon(Icons.check, size: 44, color: WynColors.paper),
              ),
              const SizedBox(height: WynSpacing.space8),
              Text(
                'พร้อมแล้ว',
                style: WynTypography.screenTitle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: WynColors.ink),
              ),
              const SizedBox(height: WynSpacing.space2),
              const Text(
                'ยินดีต้อนรับสู่ WYNOS 👋',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: WynColors.graphite),
              ),
              const Spacer(flex: 4),
              if (errorText != null) ...[
                Text(
                  errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: WynColors.errorLight),
                ),
                const SizedBox(height: WynSpacing.space4),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding:
                        const EdgeInsets.symmetric(vertical: WynSpacing.space3 + 2),
                    backgroundColor: WynColors.sapphire,
                    foregroundColor: WynColors.paper,
                    disabledBackgroundColor: WynColors.hairline,
                    disabledForegroundColor: WynColors.mutedNeutral,
                    textStyle:
                        const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: isLoading ? null : onEnter,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: WynColors.paper),
                        )
                      : const Text('เข้าสู่ WYNOS'),
                ),
              ),
              const SizedBox(height: WynSpacing.space8),
            ],
          ),
        ),
      ),
    );
  }
}
