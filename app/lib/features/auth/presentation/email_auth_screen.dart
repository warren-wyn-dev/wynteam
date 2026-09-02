import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../analytics/data/analytics_repository.dart';
import '../data/auth_repository.dart';
import '../../../core/design/wyn_spacing.dart';

/// Screen — Email + Password sign-up/sign-in. Not part of WYN-002's
/// original 5-screen flow -- added alongside it (Founder, 2026-08-24)
/// so a tester can sign in with any email address and as many accounts
/// as they want, without needing a Google account or a phone number
/// with SMS OTP configured. See auth_repository.dart's
/// signUpWithEmail/signInWithEmail doc comments.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Starts in sign-up mode -- a tester reaching this screen for the
  // first time almost always wants a new account, not to log back into
  // one they haven't created yet.
  bool _isSignUp = true;
  bool _isLoading = false;
  String? _errorMessage;

  static final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _isEmailValid => _emailRegExp.hasMatch(_emailController.text.trim());

  // Mirrors the Supabase project's own password_min_length setting (6) --
  // matching it here means the client rejects a too-short password
  // before ever hitting the network, instead of round-tripping to find
  // out.
  bool get _isPasswordValid => _passwordController.text.length >= 6;

  bool get _canSubmit => _isEmailValid && _isPasswordValid && !_isLoading;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    try {
      if (_isSignUp) {
        await widget.authRepository.signUpWithEmail(email, password);
        // WYN-077: only the sign-up branch counts as "started" a new
        // account -- see AnalyticsRepository's doc comment for why
        // Google/Apple OAuth isn't instrumented the same way this round.
        unawaited(
          AnalyticsRepository(Supabase.instance.client).logSignupStarted(
            source: AnalyticsRepository.currentWebSource(),
          ),
        );
      } else {
        await widget.authRepository.signInWithEmail(email, password);
      }
      // AuthGate's own auth-state listener pops back to it and rebuilds
      // on sign-in -- no manual navigation needed here, same as every
      // other sign-in path (Google/Apple/Phone) in this screen's
      // siblings.
    } on EmailAlreadyRegisteredException {
      setState(() {
        _errorMessage = 'อีเมลนี้มีบัญชีอยู่แล้ว ลองเข้าสู่ระบบแทน';
        _isSignUp = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = _isSignUp
            ? 'สมัครสมาชิกไม่สำเร็จ ลองใหม่อีกครั้ง'
            : 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WynSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'อีเมล'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: WynSpacing.space4),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่าน',
                  helperText: 'อย่างน้อย 6 ตัวอักษร',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _canSubmit ? _submit() : null,
              ),
              const SizedBox(height: WynSpacing.space6),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isSignUp ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ'),
              ),
              const SizedBox(height: WynSpacing.space3),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _errorMessage = null;
                        }),
                child: Text(
                  _isSignUp
                      ? 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'
                      : 'ยังไม่มีบัญชี? สมัครสมาชิก',
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: WynSpacing.space2),
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
