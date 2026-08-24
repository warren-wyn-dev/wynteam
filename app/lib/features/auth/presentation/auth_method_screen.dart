import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import 'email_auth_screen.dart';
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
              // Any email + any number of accounts (Founder, 2026-08-24)
              // -- not tied to a single Google identity like the button
              // above, so a tester can sign up with whatever address
              // they want. See email_auth_screen.dart's own doc comment.
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EmailAuthScreen(
                              authRepository: widget.authRepository,
                            ),
                          ),
                        ),
                child: const Text('เข้าสู่ระบบด้วยอีเมล'),
              ),
              // Apple Sign-In and Phone/SMS OTP temporarily removed from
              // this screen (Founder, 2026-08-24) -- Apple needs an Apple
              // Developer account tied to iOS distribution, and Phone OTP
              // needs a paid SMS provider (Twilio et al., per WYN-002's
              // own deployment checklist) -- neither is set up yet.
              // AuthRepository.signInWithApple()/sendPhoneOtp() and
              // PhoneEntryScreen/OtpVerificationScreen are untouched, so
              // re-adding either button back here is the only step
              // needed once that provider is actually configured.
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
