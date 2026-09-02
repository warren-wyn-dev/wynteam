import 'package:flutter/material.dart';

import '../../../../../core/widgets/labeled_field.dart';
import '../onboarding_scaffold.dart';

/// Screen 5 -- Display Name. [initialValue] is pre-filled from the
/// Google account's name (per the design spec's "สามารถใช้ชื่อจาก Google
/// เป็นค่าเริ่มต้น") -- OnboardingFlow passes
/// `user.userMetadata['full_name']`/`['name']`; the user can freely edit
/// or replace it.
class DisplayNameStep extends StatefulWidget {
  const DisplayNameStep({
    super.key,
    required this.initialValue,
    required this.onSubmit,
    required this.onBack,
    required this.stepIndex,
    required this.stepCount,
    this.isLoading = false,
    this.errorText,
  });

  final String initialValue;
  final Future<void> Function(String displayName) onSubmit;
  final VoidCallback onBack;
  final int stepIndex;
  final int stepCount;
  final bool isLoading;
  final String? errorText;

  @override
  State<DisplayNameStep> createState() => _DisplayNameStepState();
}

class _DisplayNameStepState extends State<DisplayNameStep> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  bool get _canSubmit =>
      _controller.text.trim().isNotEmpty && !widget.isLoading;

  Future<void> _submit() async {
    await widget.onSubmit(_controller.text.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'เราจะเรียกคุณว่าอะไรดี',
      description:
          'ชื่อที่แสดงบนโปรไฟล์ของคุณ ต่างจาก @username และแก้ไขทีหลังได้เสมอ',
      stepIndex: widget.stepIndex,
      stepCount: widget.stepCount,
      primaryLabel: 'ดำเนินการต่อ',
      isLoading: widget.isLoading,
      onBack: widget.onBack,
      errorText: widget.errorText,
      onPrimaryPressed: _canSubmit ? _submit : null,
      body: LabeledField(
        key: const Key('onboarding_display_name_field'),
        label: 'ชื่อที่แสดง',
        controller: _controller,
        maxLength: 50,
        helper: '1-50 ตัวอักษร',
        alwaysShowHelper: true,
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
