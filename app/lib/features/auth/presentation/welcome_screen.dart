import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import 'auth_method_screen.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';

/// Screen 1 — Welcome.
/// See .wyn/docs/design/wyn-002-authentication-onboarding.md
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 19-onboarding.tsx: the one wordmark moment in the
                  // whole app that outranks every other screen's own --
                  // this is the very first thing a brand-new person
                  // sees, so it carries its own explicit size/weight/
                  // tracking via WynTypography.screenTitle rather than
                  // the plain Theme.textTheme every other bit of text on
                  // this form-heavy flow correctly uses as-is.
                  Text(
                    'WYN',
                    style: WynTypography.screenTitle(
                      fontSize: 34,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 34 * 0.03,
                      color: WynColors.ink,
                    ),
                  ),
                  const SizedBox(width: WynSpacing.space2),
                  // Beta label (Founder, 2026-08-24) -- flags this build
                  // as pre-launch/testing to anyone who opens the app
                  // before real (lawyer-reviewed) platform documents
                  // replace the WYN-046 placeholder content -- see
                  // .wyn/company/APPROVALS.md's entry on that gap.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WynSpacing.space2,
                      vertical: WynSpacing.space1,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius:
                          BorderRadius.circular(WynSpacing.radiusFull),
                    ),
                    child: Text(
                      'BETA',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: WynSpacing.space3),
              Text(
                'เชื่อมต่อ แสดงตัวตน และสร้างชุมชนของคุณเอง',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      color: WynColors.graphite,
                    ),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AuthMethodScreen(
                        authRepository: authRepository,
                      ),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: WynSpacing.space4),
                    child: Text('เริ่มต้นใช้งาน'),
                  ),
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
