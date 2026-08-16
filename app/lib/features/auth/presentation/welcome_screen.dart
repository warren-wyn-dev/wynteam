import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import 'auth_method_screen.dart';
import '../../../core/design/wyn_spacing.dart';

/// Screen 1 — Welcome.
/// See .wyn/docs/design/wyn-002-authentication-onboarding.md
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _guestLoading = false;

  Future<void> _continueAsGuest() async {
    setState(() => _guestLoading = true);
    try {
      await widget.authRepository.signInAnonymously();
      // AuthGate's own auth-state listener pops back to this route and
      // rebuilds on sign-in -- no manual navigation needed here, same as
      // every other sign-in path (Google/Apple/Phone) in this screen's
      // sibling AuthMethodScreen.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เข้าใช้งานแบบไม่ล็อกอินไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _guestLoading = false);
    }
  }

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
                        authRepository: widget.authRepository,
                      ),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: WynSpacing.space4),
                    child: Text('เริ่มต้นใช้งาน'),
                  ),
                ),
              ),
              const SizedBox(height: WynSpacing.space3),
              // Temporary Internal Testing bypass (2026-08-16, see
              // .wyn/company/DECISIONS.md) -- lets the team use the app
              // without Google/Apple OAuth or SMS OTP set up yet. Does
              // not replace or hide the real sign-in path above.
              TextButton(
                onPressed: _guestLoading ? null : _continueAsGuest,
                child: _guestLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ทดลองใช้โดยไม่ต้องเข้าสู่ระบบ'),
              ),
              const SizedBox(height: WynSpacing.space8),
            ],
          ),
        ),
      ),
    );
  }
}
