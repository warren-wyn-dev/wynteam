import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/auth_repository.dart';

/// Screen 4 — OTP Verification.
/// See .wyn/docs/design/wyn-002-authentication-onboarding.md
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.authRepository,
    required this.phone,
  });

  final AuthRepository authRepository;
  final String phone;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
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
    if (otp.length != 6) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepository.verifyPhoneOtp(
        phone: widget.phone,
        otp: otp,
      );
      // AuthGate listens to authStateChanges and navigates automatically
      // once verification succeeds — no manual navigation needed here.
    } catch (_) {
      setState(() {
        _errorMessage = 'รหัส OTP ไม่ถูกต้องหรือหมดอายุ';
        _otpController.clear();
      });
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
    _otpController.dispose();
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
              Text('กรอกรหัส 6 หลักที่ส่งไปยัง ${widget.phone}'),
              const SizedBox(height: 24),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  errorText: _errorMessage,
                ),
                onChanged: _verify,
              ),
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
