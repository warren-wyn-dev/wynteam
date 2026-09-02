import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/design/wyn_colors.dart';
import '../../../../../core/design/wyn_spacing.dart';
import '../onboarding_scaffold.dart';

/// Founder-approved minimum age for a WYNOS account (2026-09-02) -- the
/// common minimum across mainstream social platforms. Mirrored verbatim
/// as `profile_private_date_of_birth_min_age` in supabase/schema.sql;
/// keep both in sync.
const int kMinOnboardingAge = 13;

/// Screen 3 -- Birthday. First step of the onboarding flow (no [onBack]
/// -- there is nothing local to go back to; the only way "back" from here
/// is signing out, which this screen deliberately doesn't offer).
class BirthdayStep extends StatefulWidget {
  const BirthdayStep({
    super.key,
    required this.onSubmit,
    required this.stepIndex,
    required this.stepCount,
    this.isLoading = false,
    this.errorText,
  });

  final Future<void> Function(DateTime dateOfBirth) onSubmit;
  final int stepIndex;
  final int stepCount;
  final bool isLoading;
  final String? errorText;

  @override
  State<BirthdayStep> createState() => _BirthdayStepState();
}

class _BirthdayStepState extends State<BirthdayStep> {
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();
  final _dayFocus = FocusNode();
  final _monthFocus = FocusNode();
  final _yearFocus = FocusNode();

  String? _localError;

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _dayFocus.dispose();
    _monthFocus.dispose();
    _yearFocus.dispose();
    super.dispose();
  }

  DateTime? _parse() {
    final day = int.tryParse(_dayController.text);
    final month = int.tryParse(_monthController.text);
    final year = int.tryParse(_yearController.text);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31 || year < 1900) {
      return null;
    }
    final date = DateTime(year, month, day);
    // DateTime silently rolls an out-of-range day (e.g. Feb 30) into the
    // next month instead of throwing -- reject that instead of accepting
    // a different date than what was actually typed.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  int _ageOn(DateTime birth, DateTime now) {
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  Future<void> _submit() async {
    final date = _parse();
    final now = DateTime.now();
    if (date == null) {
      setState(() => _localError = 'กรุณากรอกวันเกิดให้ถูกต้อง');
      return;
    }
    if (date.isAfter(DateTime(now.year, now.month, now.day))) {
      setState(() => _localError = 'วันเกิดต้องไม่ใช่วันที่ในอนาคต');
      return;
    }
    if (_ageOn(date, now) < kMinOnboardingAge) {
      setState(() => _localError =
          'คุณต้องมีอายุอย่างน้อย $kMinOnboardingAge ปีจึงจะใช้งาน WYNOS ได้');
      return;
    }
    setState(() => _localError = null);
    await widget.onSubmit(date);
  }

  Widget _box({
    required TextEditingController controller,
    required String hint,
    required int maxLen,
    required FocusNode focusNode,
    FocusNode? nextFocus,
  }) {
    return SizedBox(
      width: maxLen == 4 ? 84 : 60,
      child: TextField(
        key: Key('birthday_${hint.toLowerCase()}_field'),
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLen),
        ],
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 20, color: WynColors.ink, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: const TextStyle(color: WynColors.faint),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: WynColors.hairline)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: WynColors.sapphire, width: 2)),
        ),
        onChanged: (value) {
          if (_localError != null) setState(() => _localError = null);
          if (value.length == maxLen && nextFocus != null) {
            nextFocus.requestFocus();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'วันเกิดของคุณ',
      description:
          'ใช้เพื่อยืนยันอายุขั้นต่ำในการใช้งาน WYNOS เท่านั้น จะไม่แสดงบนโปรไฟล์สาธารณะของคุณ',
      stepIndex: widget.stepIndex,
      stepCount: widget.stepCount,
      primaryLabel: 'ดำเนินการต่อ',
      isLoading: widget.isLoading,
      errorText: _localError ?? widget.errorText,
      onPrimaryPressed: widget.isLoading ? null : _submit,
      body: Row(
        children: [
          _box(
            controller: _dayController,
            hint: 'DD',
            maxLen: 2,
            focusNode: _dayFocus,
            nextFocus: _monthFocus,
          ),
          const SizedBox(width: WynSpacing.space3),
          _box(
            controller: _monthController,
            hint: 'MM',
            maxLen: 2,
            focusNode: _monthFocus,
            nextFocus: _yearFocus,
          ),
          const SizedBox(width: WynSpacing.space3),
          _box(
            controller: _yearController,
            hint: 'YYYY',
            maxLen: 4,
            focusNode: _yearFocus,
          ),
        ],
      ),
    );
  }
}
