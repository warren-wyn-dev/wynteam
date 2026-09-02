import 'package:flutter/material.dart';

import '../../../../../core/design/wyn_colors.dart';
import '../../../../../core/design/wyn_spacing.dart';
import '../../../../../core/widgets/labeled_field.dart';
import '../onboarding_scaffold.dart';

enum _Strength { weak, medium, strong }

_Strength _strengthOf(String password) {
  var score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password)) {
    score++;
  }
  if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) score++;
  if (score <= 1) return _Strength.weak;
  if (score <= 3) return _Strength.medium;
  return _Strength.strong;
}

/// Screen 6 -- WYNOS Password. Sets a real password credential on the
/// caller's existing Supabase Auth user (see
/// AuthRepository.setPassword) -- never logged, never sent anywhere but
/// Supabase's own Auth API, never stored/hashed by this app itself.
class PasswordStep extends StatefulWidget {
  const PasswordStep({
    super.key,
    required this.onSubmit,
    required this.onBack,
    required this.stepIndex,
    required this.stepCount,
    this.isLoading = false,
    this.errorText,
  });

  final Future<void> Function(String password) onSubmit;
  final VoidCallback onBack;
  final int stepIndex;
  final int stepCount;
  final bool isLoading;
  final String? errorText;

  @override
  State<PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends State<PasswordStep> {
  // Mirrors the Supabase project's own password_min_length setting (6) --
  // same reasoning as EmailAuthScreen's identical constant.
  static const _minLength = 6;

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool get _isLongEnough => _passwordController.text.length >= _minLength;
  bool get _confirmTyped => _confirmController.text.isNotEmpty;
  bool get _matches => _passwordController.text == _confirmController.text;

  bool get _canSubmit =>
      _isLongEnough && _confirmTyped && _matches && !widget.isLoading;

  String? get _confirmError {
    if (!_confirmTyped || _matches) return null;
    return 'รหัสผ่านไม่ตรงกัน';
  }

  Future<void> _submit() async {
    await widget.onSubmit(_passwordController.text);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Widget _strengthIndicator() {
    if (_passwordController.text.isEmpty) return const SizedBox.shrink();
    final strength = _strengthOf(_passwordController.text);
    final (label, color, fraction) = switch (strength) {
      _Strength.weak => ('รหัสผ่านอ่อน', WynColors.errorLight, 1 / 3),
      _Strength.medium => ('รหัสผ่านปานกลาง', WynColors.warningLight, 2 / 3),
      _Strength.strong => ('รหัสผ่านแข็งแรง', WynColors.successLight, 1.0),
    };
    return Padding(
      padding: const EdgeInsets.only(
          top: WynSpacing.space2, bottom: WynSpacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: WynColors.hairline,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: WynSpacing.space1),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _visibilityToggle(bool obscured, VoidCallback onTap) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 18,
        color: WynColors.graphite,
      ),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'ตั้งรหัสผ่าน WYNOS',
      description:
          'ใช้เข้าสู่ระบบ WYNOS ได้โดยตรง เผื่อไว้ในกรณีที่ไม่ได้เข้าผ่าน Google',
      stepIndex: widget.stepIndex,
      stepCount: widget.stepCount,
      primaryLabel: 'ดำเนินการต่อ',
      isLoading: widget.isLoading,
      onBack: widget.onBack,
      errorText: widget.errorText,
      onPrimaryPressed: _canSubmit ? _submit : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            key: const Key('onboarding_password_field'),
            label: 'รหัสผ่าน',
            controller: _passwordController,
            maxLength: 72,
            helper: 'อย่างน้อย $_minLength ตัวอักษร',
            alwaysShowHelper: true,
            obscureText: _obscurePassword,
            suffix: _visibilityToggle(
              _obscurePassword,
              () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            onChanged: (_) => setState(() {}),
          ),
          _strengthIndicator(),
          LabeledField(
            key: const Key('onboarding_confirm_password_field'),
            label: 'ยืนยันรหัสผ่าน',
            controller: _confirmController,
            maxLength: 72,
            helper: 'พิมพ์รหัสผ่านอีกครั้งให้ตรงกัน',
            alwaysShowHelper: true,
            obscureText: _obscureConfirm,
            errorText: _confirmError,
            suffix: _visibilityToggle(
              _obscureConfirm,
              () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
