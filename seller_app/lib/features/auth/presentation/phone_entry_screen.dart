import 'package:flutter/material.dart';

import '../data/seller_auth_repository.dart';
import 'otp_verification_screen.dart';
import '../../../core/design/wyn_spacing.dart';

/// Phone Number Entry. Ported verbatim (no logic changes) from
/// `app/lib/features/auth/presentation/phone_entry_screen.dart` -- see
/// .wyn/tasks/backlog/SELLER-001-foundation.md and
/// .wyn/docs/design/seller-001-foundation.md.
class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key, required this.authRepository});

  final SellerAuthRepository authRepository;

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  static final _thaiPhoneRegExp = RegExp(r'^\+66[0-9]{9}$');

  String get _normalizedPhone {
    final raw = _phoneController.text.trim();
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('0')) return '+66${raw.substring(1)}';
    return '+66$raw';
  }

  bool get _isValid => _thaiPhoneRegExp.hasMatch(_normalizedPhone);

  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepository.sendPhoneOtp(_normalizedPhone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            authRepository: widget.authRepository,
            phone: _normalizedPhone,
          ),
        ),
      );
    } catch (_) {
      setState(() => _errorMessage = 'ส่งรหัส OTP ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('หมายเลขโทรศัพท์')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WynSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'หมายเลขโทรศัพท์',
                  prefixText: '+66 ',
                  errorText: _errorMessage,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: WynSpacing.space6),
              FilledButton(
                onPressed: (_isValid && !_isLoading) ? _sendOtp : null,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ส่งรหัส OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
