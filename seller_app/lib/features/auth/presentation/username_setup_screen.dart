import 'dart:async';

import 'package:flutter/material.dart';

import '../data/seller_auth_repository.dart';
import '../../../core/design/wyn_spacing.dart';

enum _UsernameStatus { idle, checking, available, taken, invalid }

/// Username Setup (onboarding). Ported verbatim (no logic changes) from
/// `app/lib/features/auth/presentation/username_setup_screen.dart` --
/// reused here since a seller might open this app before ever using WYN
/// Social, and both apps share the same `profiles` table. See
/// .wyn/tasks/backlog/SELLER-001-foundation.md and
/// .wyn/docs/design/seller-001-foundation.md.
class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({
    super.key,
    required this.authRepository,
    required this.userId,
    required this.onUsernameSet,
  });

  final SellerAuthRepository authRepository;
  final String userId;

  /// Called after a username is successfully saved. SellerAuthGate owns
  /// what happens next (re-checking hasUsername and rendering the next
  /// step as its own child) -- this screen must not navigate on its
  /// own, since it is rendered *as* SellerAuthGate's route rather than
  /// pushed on top of it. See .wyn/learning/PATTERNS.md,
  /// "Callback-to-parent-rebuild".
  final VoidCallback onUsernameSet;

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _controller = TextEditingController();
  final _usernameRegExp = RegExp(r'^[a-z0-9_]{3,20}$');
  _UsernameStatus _status = _UsernameStatus.idle;
  Timer? _debounce;
  bool _isSubmitting = false;

  void _onChanged(String value) {
    _debounce?.cancel();

    if (!_usernameRegExp.hasMatch(value)) {
      setState(() => _status = _UsernameStatus.invalid);
      return;
    }

    setState(() => _status = _UsernameStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final available =
          await widget.authRepository.isUsernameAvailable(value);
      if (!mounted) return;
      setState(() {
        _status =
            available ? _UsernameStatus.available : _UsernameStatus.taken;
      });
    });
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.authRepository
          .setUsername(widget.userId, _controller.text);
      widget.onUsernameSet();
    } on UsernameTakenException {
      setState(() => _status = _UsernameStatus.taken);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _status == _UsernameStatus.available && !_isSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งชื่อผู้ใช้')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WynSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  prefixText: '@',
                  labelText: 'ชื่อผู้ใช้',
                  helperText:
                      'ใช้ตัวอักษร a-z, 0-9 และ _ เท่านั้น (3-20 ตัวอักษร)',
                  errorText: switch (_status) {
                    _UsernameStatus.taken => 'ชื่อผู้ใช้นี้ถูกใช้แล้ว',
                    _UsernameStatus.invalid => 'รูปแบบไม่ถูกต้อง',
                    _ => null,
                  },
                  suffixIcon: switch (_status) {
                    _UsernameStatus.checking => const Padding(
                        padding: EdgeInsets.all(WynSpacing.space3),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    _UsernameStatus.available =>
                      const Icon(Icons.check_circle, color: Colors.green),
                    _ => null,
                  },
                ),
                onChanged: _onChanged,
              ),
              const SizedBox(height: WynSpacing.space6),
              FilledButton(
                onPressed: canSubmit ? _submit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('เสร็จสิ้น'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
