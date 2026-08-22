import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../data/appeal_repository.dart';

/// What [showAppealDecisionSheet] resolved to -- `null` means the
/// moderator closed the sheet without submitting (Detail screen does
/// nothing). Mirrors ModerationActionSheetOutcome's exact shape (WYN-029).
enum AppealDecisionSheetOutcome { success, alreadyDecided }

/// Screen 6's decision sheet -- reuses ModerationActionSheet's (WYN-029)
/// exact bottom-sheet shape. Approve needs no reason (decide_appeal()
/// always nulls decision_reason on approve -- see supabase/schema.sql);
/// Reject requires one, since it's shown to the appellant verbatim.
/// See .wyn/docs/design/wyn-030-appeal-system.md, Screen 6.
Future<AppealDecisionSheetOutcome?> showAppealDecisionSheet(
  BuildContext context, {
  required AppealRepository appealRepository,
  required String appealId,
  required bool approve,
}) {
  return showModalBottomSheet<AppealDecisionSheetOutcome>(
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
      child: AppealDecisionSheet(
        appealRepository: appealRepository,
        appealId: appealId,
        approve: approve,
      ),
    ),
  );
}

class AppealDecisionSheet extends StatefulWidget {
  const AppealDecisionSheet({
    super.key,
    required this.appealRepository,
    required this.appealId,
    required this.approve,
  });

  final AppealRepository appealRepository;
  final String appealId;
  final bool approve;

  @override
  State<AppealDecisionSheet> createState() => _AppealDecisionSheetState();
}

class _AppealDecisionSheetState extends State<AppealDecisionSheet> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isSubmitting) return false;
    if (!widget.approve && _reasonController.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      await widget.appealRepository.decideAppeal(
        appealId: widget.appealId,
        approve: widget.approve,
        decisionReason: widget.approve ? null : _reasonController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(AppealDecisionSheetOutcome.success);
    } catch (e) {
      if (!mounted) return;
      // decide_appeal() raises this exact text (see supabase/schema.sql)
      // when another moderator already decided this appeal first --
      // surfaced here instead of a generic retry error, since retrying
      // would never succeed.
      if (e.toString().contains('already been decided')) {
        Navigator.of(context).pop(AppealDecisionSheetOutcome.alreadyDecided);
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
                    widget.approve ? 'ยืนยัน: อนุมัติอุทธรณ์' : 'ยืนยัน: ปฏิเสธอุทธรณ์',
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
        if (widget.approve) ...[
          Text(
            'บทลงโทษเดิมจะถูกยกเลิก ผู้ใช้จะได้รับการแจ้งเตือนทันที',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ] else ...[
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
            decoration: const InputDecoration(hintText: 'อธิบายเหตุผลที่ปฏิเสธอุทธรณ์นี้'),
          ),
          const SizedBox(height: WynSpacing.space1),
          Text(
            'ผู้ใช้จะเห็นข้อความนี้โดยตรง เขียนให้ผู้ใช้เข้าใจได้',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
