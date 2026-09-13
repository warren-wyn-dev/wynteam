import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../data/auth_repository.dart';
import '../data/pending_referral_code.dart';

/// WYN-113 (Invite-Only Access Gate): shown from AuthMethodScreen in
/// place of the real sign-in buttons while the Founder has the gate
/// turned on and this visitor hasn't redeemed a code yet this app
/// session. On a valid code, stores it via [PendingReferralCode] (not
/// redeemed here -- see that class's own doc comment for why the
/// actual redemption happens later, in OnboardingFlow) and pops `true`;
/// AuthMethodScreen then reveals its normal Google/Apple/Email/Phone
/// buttons. Popping without a valid code (back button) returns `null`/
/// `false`, and AuthMethodScreen keeps showing this prompt.
///
/// Deliberately does not gate "เข้าชม WYNOS ได้เลย" (guest browsing,
/// WYN-072) at all -- that button lives on AuthMethodScreen itself and
/// is never affected by anything on this screen; the invite gate's own
/// Goal ("ควบคุมอัตราการไหลเข้าของผู้ใช้ใหม่") is about real accounts, not
/// disposable guest sessions that never get a `profiles` row.
class RedeemInviteCodeScreen extends StatefulWidget {
  const RedeemInviteCodeScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<RedeemInviteCodeScreen> createState() => _RedeemInviteCodeScreenState();
}

class _RedeemInviteCodeScreenState extends State<RedeemInviteCodeScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _errorText = 'กรุณากรอกโค้ดเชิญ');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    bool isValid;
    try {
      isValid = await widget.authRepository.validateReferralCode(code);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = 'เชื่อมต่อไม่สำเร็จ ลองใหม่อีกครั้ง';
      });
      return;
    }
    if (!mounted) return;
    if (!isValid) {
      setState(() {
        _isLoading = false;
        _errorText = 'โค้ดเชิญไม่ถูกต้อง';
      });
      return;
    }
    PendingReferralCode.set(code);
    Navigator.of(context).pop(true);
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
              BrowserSystemText(
                'กรอกโค้ดเชิญ',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: WynSpacing.space3),
              BrowserSystemText(
                'ตอนนี้ WYNOS เปิดให้เข้าใช้งานเฉพาะผู้ที่มีโค้ดเชิญจากเพื่อนเท่านั้น',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: WynSpacing.space8),
              BrowserSystemTextField(
                key: const Key('invite_code_field'),
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                decoration:
                    const InputDecoration(label: BrowserSystemText('โค้ดเชิญ')),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
                onSubmitted: (_) => _isLoading ? null : _submit(),
              ),
              const SizedBox(height: WynSpacing.space6),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const BrowserSystemText('ดำเนินการต่อ'),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: WynSpacing.space4),
                BrowserSystemText(
                  _errorText!,
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
