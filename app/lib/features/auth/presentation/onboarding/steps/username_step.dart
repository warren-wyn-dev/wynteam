import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/design/wyn_colors.dart';
import '../../../../../core/design/wyn_spacing.dart';
import '../../../../../core/widgets/labeled_field.dart';
import '../onboarding_scaffold.dart';

enum _UsernameStatus { idle, checking, available, taken, invalid }

/// Screen 4 -- Username. Same normalize/validate/debounce shape as the
/// pre-existing EditProfileScreen username field (Profile is a
/// deliberately separate feature from Auth in this codebase, so this
/// isn't shared code, just the same established pattern), plus one
/// addition this onboarding flow's spec calls for that neither prior
/// screen had: lowercasing/trimming input as the user types instead of
/// just rejecting uppercase as invalid.
class UsernameStep extends StatefulWidget {
  const UsernameStep({
    super.key,
    required this.checkAvailability,
    required this.onSubmit,
    required this.onBack,
    required this.stepIndex,
    required this.stepCount,
    this.isLoading = false,
    this.errorText,
  });

  final Future<bool> Function(String username) checkAvailability;
  final Future<void> Function(String username) onSubmit;
  final VoidCallback onBack;
  final int stepIndex;
  final int stepCount;
  final bool isLoading;
  final String? errorText;

  @override
  State<UsernameStep> createState() => _UsernameStepState();
}

class _UsernameStepState extends State<UsernameStep> {
  final _controller = TextEditingController();
  static final _usernameRegExp = RegExp(r'^[a-z0-9_]{3,20}$');
  _UsernameStatus _status = _UsernameStatus.idle;
  Timer? _debounce;

  void _onChanged(String raw) {
    _debounce?.cancel();

    // Normalize as the user types: lowercase + strip whitespace, so
    // "Worapon" or " worapon " both resolve to "worapon" instead of
    // being flagged invalid over case alone.
    final normalized = raw.trim().toLowerCase();
    if (normalized != raw) {
      _controller.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }

    if (normalized.isEmpty) {
      setState(() => _status = _UsernameStatus.idle);
      return;
    }
    if (!_usernameRegExp.hasMatch(normalized)) {
      setState(() => _status = _UsernameStatus.invalid);
      return;
    }

    setState(() => _status = _UsernameStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final available = await widget.checkAvailability(normalized);
      if (!mounted) return;
      setState(() {
        _status =
            available ? _UsernameStatus.available : _UsernameStatus.taken;
      });
    });
  }

  Future<void> _submit() async {
    await widget.onSubmit(_controller.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _status == _UsernameStatus.available && !widget.isLoading;

    return OnboardingScaffold(
      title: 'ตั้งชื่อผู้ใช้ของคุณ',
      description: 'ตัวตนหลักของคุณบน WYNOS ใช้ให้เพื่อนตามหาคุณเจอ',
      stepIndex: widget.stepIndex,
      stepCount: widget.stepCount,
      primaryLabel: 'ดำเนินการต่อ',
      isLoading: widget.isLoading,
      onBack: widget.onBack,
      errorText: widget.errorText,
      onPrimaryPressed: canSubmit ? _submit : null,
      body: LabeledField(
        key: const Key('onboarding_username_field'),
        label: 'ชื่อผู้ใช้',
        controller: _controller,
        maxLength: 20,
        prefix: '@',
        alwaysShowHelper: true,
        helper: 'ใช้ตัวอักษร a-z, 0-9 และ _ เท่านั้น (3-20 ตัวอักษร)',
        errorText: switch (_status) {
          _UsernameStatus.taken => 'ชื่อผู้ใช้นี้ถูกใช้แล้ว',
          _UsernameStatus.invalid => 'รูปแบบไม่ถูกต้อง',
          _ => null,
        },
        suffix: switch (_status) {
          _UsernameStatus.checking => const Padding(
              padding: EdgeInsets.only(left: WynSpacing.space2),
              child: SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          _UsernameStatus.available => const Padding(
              padding: EdgeInsets.only(left: WynSpacing.space2),
              child: Icon(Icons.check_circle,
                  size: 18, color: WynColors.sapphire),
            ),
          _ => null,
        },
        onChanged: _onChanged,
      ),
    );
  }
}
