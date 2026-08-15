import 'dart:async';

import 'package:flutter/material.dart';

import '../data/seller_auth_repository.dart';
import 'widgets/otp_box_input.dart';

/// OTP Verification. Ported verbatim (no logic changes) from
/// `app/lib/features/auth/presentation/otp_verification_screen.dart` --
/// see .wyn/tasks/backlog/SELLER-001-foundation.md and
/// .wyn/docs/design/seller-001-foundation.md.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.authRepository,
    required this.phone,
  });

  final SellerAuthRepository authRepository;
  final String phone;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpBoxKey = GlobalKey<OtpBoxInputState>();
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _resendTimer;
  int _secondsRemaining = 30;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _secondsRemaining = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _verify(String otp) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepository.verifyPhoneOtp(
        phone: widget.phone,
        otp: otp,
      );
      // A successful verification fires a Supabase "signedIn" auth
      // event; SellerAuthGate listens for that and pops back to
      // itself, so no manual navigation is needed here.
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'รหัส OTP ไม่ถูกต้องหรือหมดอายุ');
      _otpBoxKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    await widget.authRepository.sendPhoneOtp(widget.phone);
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ยืนยันรหัส OTP')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'กรอกรหัส 6 หลักที่ส่งไปยัง ${widget.phone}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OtpBoxInput(key: _otpBoxKey, onCompleted: _verify),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _errorMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _secondsRemaining == 0 ? _resend : null,
                  child: Text(
                    _secondsRemaining == 0
                        ? 'ส่งรหัสอีกครั้ง'
                        : 'ส่งรหัสอีกครั้งใน $_secondsRemaining วินาที',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
