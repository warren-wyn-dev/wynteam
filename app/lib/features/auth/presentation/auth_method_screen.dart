import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import 'email_auth_screen.dart';
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

  // WYN-072: paused for the same reason -- Sign in with Apple requires
  // an Apple Developer Program membership to actually work (Apple OAuth
  // provider config, capability entitlement), and Founder confirmed
  // (2026-08-30) that hasn't been purchased yet ("แพงจ่ายไม่ไหว"). The
  // button was reachable and tappable but every tap failed silently
  // server-side -- worse than not offering it at all. Flip back to true
  // once the Apple Developer Program is set up -- signInWithApple()
  // itself is untouched in AuthRepository, ready to go.
  static const _appleLoginEnabled = false;

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
                'เข้าสู่ระบบ WYNOS',
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
              if (_appleLoginEnabled) ...[
                const SizedBox(height: WynSpacing.space3),
                FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _handle(widget.authRepository.signInWithApple),
                  icon: const Icon(Icons.apple),
                  label: const Text('เข้าสู่ระบบด้วย Apple'),
                ),
              ],
              const SizedBox(height: WynSpacing.space3),
              // Any email + any number of accounts (Founder, 2026-08-24)
              // -- not tied to a single Google/Apple identity, so a
              // tester can sign up with whatever address they want. See
              // email_auth_screen.dart's own doc comment.
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
              // WYN-072 (Guest Browsing): a lighter, secondary path --
              // graphite text on a plain TextButton, not paired visually
              // with Google/อีเมล above as an equal CTA -- deliberately
              // not "ข้าม" (skip), since this isn't skipping a step in
              // the same flow, it's a separate path that goes straight
              // to Home. Uses signInAnonymously() (approved 2026-08-16
              // for internal testing, never wired into UI until now) --
              // the RLS on every core table requires an `authenticated`
              // session to read anything at all, so there is no way to
              // browse with literally no session; anonymous sign-in is
              // the one already-approved mechanism that satisfies that
              // without touching RLS/Auth architecture.
              const SizedBox(height: WynSpacing.space6),
              Center(
                child: Semantics(
                  label: 'เข้าชม WYNOS โดยไม่ต้องเข้าสู่ระบบ',
                  button: true,
                  child: TextButton(
                    // Graphite/onSurfaceVariant, not the theme's primary
                    // color -- a deliberately lighter-weight CTA than
                    // Google/อีเมล above, per the design spec's own "ทาง
                    // เลือกที่เบา กว่า" note. Semantic token (not a
                    // hardcoded WynColors.graphite) so it still adapts
                    // correctly in dark mode, same convention every other
                    // screen in this app already follows.
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => _handle(
                              () => widget.authRepository.signInAnonymously(),
                            ),
                    child: const Text('เข้าชม WYNOS ได้เลย'),
                  ),
                ),
              ),
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
