import 'package:flutter/material.dart';

import '../data/seller_auth_repository.dart';
import 'phone_entry_screen.dart';
import '../../../core/design/wyn_spacing.dart';

/// Sign-in for sellers who already have a WYN account. Combines what
/// `app/`'s `WelcomeScreen` + `AuthMethodScreen` do as two separate
/// screens into one, since this app has no "sign up" flow to explain
/// first -- anyone opening it is a WYN user who came here on purpose to
/// register a store. See .wyn/docs/design/seller-001-foundation.md,
/// Screen: SellerSignInScreen.
class SellerSignInScreen extends StatefulWidget {
  const SellerSignInScreen({super.key, required this.authRepository});

  final SellerAuthRepository authRepository;

  @override
  State<SellerSignInScreen> createState() => _SellerSignInScreenState();
}

class _SellerSignInScreenState extends State<SellerSignInScreen> {
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Text(
                'ZOKY Sellers by WYN',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: WynSpacing.space3),
              Text(
                'เข้าสู่ระบบด้วยบัญชี WYN ของคุณเพื่อเริ่มขายของบน ZOKY',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(flex: 2),
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
                child: const Text('เข้าสู่ระบบด้วยเบอร์โทร'),
              ),
              const SizedBox(height: WynSpacing.space3),
              // Temporary Internal Testing bypass (2026-08-16, see
              // .wyn/company/DECISIONS.md) -- mirrors app/'s WelcomeScreen.
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => _handle(widget.authRepository.signInAnonymously),
                child: const Text('ทดลองใช้โดยไม่ต้องเข้าสู่ระบบ'),
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
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
