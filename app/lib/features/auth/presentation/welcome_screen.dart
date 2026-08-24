import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import 'auth_method_screen.dart';
import '../../../core/design/wyn_spacing.dart';

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
              Text(
                'WYN',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: WynSpacing.space3),
              Text(
                'เชื่อมต่อ แสดงตัวตน และสร้างชุมชนของคุณเอง',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
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
