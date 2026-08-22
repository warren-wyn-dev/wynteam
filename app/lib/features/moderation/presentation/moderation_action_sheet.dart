import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../data/moderation_action_type.dart';
import '../data/moderation_repository.dart';

/// What [showModerationActionSheet] resolved to -- `null` means the
/// moderator closed the sheet without submitting (Detail screen does
/// nothing). [success] and [alreadyActionedByOthers] both close the
/// Detail screen back to the Queue (Screen 3's own Interactions), the
/// only difference is the SnackBar message shown after.
enum ModerationActionSheetOutcome { success, alreadyActionedByOthers }

/// Screen 4 -- reusable confirm flow for all 6 actions. Reuses
/// ReportSheet's (WYN-026) exact bottom-sheet shape (handle bar,
/// header, close button, Flexible + SingleChildScrollView, disabled-
/// while-submitting form, inline error) rather than inventing a new
/// one -- see .wyn/docs/design/wyn-029-moderation-queue.md, Screen 4.
Future<ModerationActionSheetOutcome?> showModerationActionSheet(
  BuildContext context, {
  required ModerationRepository moderationRepository,
  required String reportId,
  required ModerationActionType actionType,
}) {
  return showModalBottomSheet<ModerationActionSheetOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: ModerationActionSheet(
        moderationRepository: moderationRepository,
        reportId: reportId,
        actionType: actionType,
      ),
    ),
  );
}

/// 1 day / 3 days / 7 days -- the only durations Restrict/Suspend
/// support (Product spec).
const _durationOptions = [1, 3, 7];

class ModerationActionSheet extends StatefulWidget {
  const ModerationActionSheet({
    super.key,
    required this.moderationRepository,
    required this.reportId,
    required this.actionType,
  });

  final ModerationRepository moderationRepository;
  final String reportId;
  final ModerationActionType actionType;

  @override
  State<ModerationActionSheet> createState() => _ModerationActionSheetState();
}

class _ModerationActionSheetState extends State<ModerationActionSheet> {
  final _reasonController = TextEditingController();
  int? _durationDays;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isSubmitting) return false;
    if (_reasonController.text.trim().isEmpty) return false;
    if (widget.actionType.needsDuration && _durationDays == null) return false;
    return true;
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      await widget.moderationRepository.applyAction(
        reportId: widget.reportId,
        actionType: widget.actionType,
        reason: _reasonController.text.trim(),
        durationDays: widget.actionType.needsDuration ? _durationDays : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(ModerationActionSheetOutcome.success);
    } catch (e) {
      if (!mounted) return;
      // apply_moderation_action() raises this exact text (see
      // supabase/schema.sql) when another moderator already closed the
      // report first -- surfaced here instead of a generic retry error,
      // since retrying would never succeed.
      if (e.toString().contains('already been actioned')) {
        Navigator.of(context).pop(ModerationActionSheetOutcome.alreadyActionedByOthers);
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submitError = 'ดำเนินการไม่สำเร็จ ลองอีกครั้ง';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: WynSpacing.space2),
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: WynSpacing.space4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.actionType.confirmSheetTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SizedBox(
                  width: WynSpacing.touchTargetMin,
                  height: WynSpacing.touchTargetMin,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close),
                    tooltip: 'ปิด',
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: WynSpacing.space2),
            Flexible(child: SingleChildScrollView(child: _buildForm())),
            const SizedBox(height: WynSpacing.space4),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.actionType.needsDuration) ...[
          Text('ระยะเวลา', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: WynSpacing.space2),
          Wrap(
            spacing: WynSpacing.space2,
            children: [
              for (final days in _durationOptions)
                ChoiceChip(
                  label: Text('$days วัน'),
                  selected: _durationDays == days,
                  onSelected: _isSubmitting
                      ? null
                      : (selected) => setState(() => _durationDays = selected ? days : null),
                ),
            ],
          ),
          const SizedBox(height: WynSpacing.space4),
        ],
        Text(
          'เหตุผล (จำเป็น)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: WynSpacing.space1),
        TextField(
          controller: _reasonController,
          enabled: !_isSubmitting,
          minLines: 3,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'อธิบายเหตุผลของการดำเนินการนี้'),
        ),
        const SizedBox(height: WynSpacing.space1),
        Text(
          widget.actionType.reasonHelperText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (widget.actionType == ModerationActionType.ban) ...[
          const SizedBox(height: WynSpacing.space2),
          Text(
            'แบนถาวร -- ยกเลิกได้เฉพาะทาง Database โดย admin เท่านั้นในรอบนี้ '
            '(ยังไม่มีปุ่ม Unban ในแอป)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
        if (_submitError != null) ...[
          const SizedBox(height: WynSpacing.space2),
          Text(
            _submitError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: WynSpacing.space4),
        SizedBox(
          width: double.infinity,
          // Same "never red, even for Ban" rule as confirmBlock/
          // confirmDeletePost/ClubPage._confirmLeave (WYN-027 Screen 2)
          // -- severity is communicated through the warning copy above,
          // not button color. Plain FilledButton, no color override.
          child: FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('ยืนยัน'),
          ),
        ),
      ],
    );
  }
}
