import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import 'phone_entry_screen.dart';
import '../../../core/design/wyn_spacing.dart';

/// Screen 2 — Auth Method Selection.
/// See .wyn/docs/design/wyn-002-authentication-onboarding.md
class AuthMethodScreen extends StatefulWidget {
  const AuthMethodScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<AuthMethodScreen> createState() => _AuthMethodScreenState();
}

class _AuthMethodScreenState extends State<AuthMethodScreen> {
  // Temporarily hidden -- Phone/OTP sign-in is a real, supported auth
  // method (approved by Founder, 2026-08-13) but the Supabase project's
  // phone provider isn't enabled and no SMS provider (Twilio) is
  // configured yet, so tapping through to PhoneEntryScreen and sending
  // an OTP always fails server-side. Flip back to true once Twilio is
  // set up -- see .wyn/company/DECISIONS.md, 2026-08-24 ("Phone Login
  // ซ่อนชั่วคราว").
  static const _phoneLoginEnabled = false;

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handle(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'เข้าสู่ระบบไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: WynSpacing.space6),
              Text(
                'เข้าสู่ระบบ WYN',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: WynSpacing.space8),
              FilledButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _handle(widget.authRepository.signInWithGoogle),
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('เข้าสู่ระบบด้วย Google'),
              ),
              const SizedBox(height: WynSpacing.space3),
              FilledButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _handle(widget.authRepository.signInWithApple),
                icon: const Icon(Icons.apple),
                label: const Text('เข้าสู่ระบบด้วย Apple'),
              ),
              if (_phoneLoginEnabled) ...[
                const SizedBox(height: WynSpacing.space3),
                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PhoneEntryScreen(
                                authRepository: widget.authRepository,
                              ),
                            ),
                          ),
                  child: const Text('ใช้เบอร์โทรศัพท์แทน'),
                ),
              ],
              if (_isLoading) ...[
                const SizedBox(height: WynSpacing.space6),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: WynSpacing.space4),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
