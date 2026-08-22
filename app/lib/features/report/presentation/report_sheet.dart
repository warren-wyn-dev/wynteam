import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../data/report_category.dart';
import '../data/report_repository.dart';
import '../data/report_target_type.dart';

/// Opens the reusable report bottom sheet (WYN-026) for any target in the
/// app. Every entry point (Profile, Drop Detail, feed cards, comments,
/// Club, Club Post) calls this same function -- see
/// .wyn/docs/design/wyn-026-report-system.md, "ภาพรวมแนวทาง".
///
/// [targetLabel] is the short sentence shown as the sheet's title (e.g.
/// "รายงานโพสต์นี้" / "รายงาน @username").
Future<void> showReportSheet(
  BuildContext context, {
  required ReportRepository reportRepository,
  required ReportTargetType targetType,
  required String targetId,
  required String targetLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Explicit bound (not just isScrollControlled's default) -- 10 fixed
    // categories plus the detail field can exceed a short/landscape
    // viewport, and without a maxHeight here the sheet sizes to its
    // *content* instead of the screen, pushing the submit button
    // (inside the inner SingleChildScrollView) off-screen entirely
    // rather than scrolling it into view.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: ReportSheet(
        reportRepository: reportRepository,
        targetType: targetType,
        targetId: targetId,
        targetLabel: targetLabel,
      ),
    ),
  );
}

/// Screen 1 of .wyn/docs/design/wyn-026-report-system.md.
class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.reportRepository,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
  });

  final ReportRepository reportRepository;
  final ReportTargetType targetType;
  final String targetId;
  final String targetLabel;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

enum _LoadState { checking, ready, alreadyReported, checkError }

class _ReportSheetState extends State<ReportSheet> {
  _LoadState _loadState = _LoadState.checking;
  ReportCategory? _category;
  final _detailController = TextEditingController();
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _checkExisting() async {
    try {
      final hasOpenReport = await widget.reportRepository.hasOpenReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
      );
      if (!mounted) return;
      setState(() {
        _loadState = hasOpenReport ? _LoadState.alreadyReported : _LoadState.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadState = _LoadState.checkError);
    }
  }

  bool get _canSubmit {
    final category = _category;
    if (category == null || _isSubmitting) return false;
    if (category == ReportCategory.other) {
      return _detailController.text.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _submit() async {
    final category = _category;
    if (category == null) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      await widget.reportRepository.submitReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
        category: category,
        detail: _detailController.text.trim().isEmpty
            ? null
            : _detailController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งรายงานแล้ว ทีมงานจะตรวจสอบเร็วๆ นี้')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = 'ส่งไม่สำเร็จ ลองอีกครั้ง';
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
                    widget.targetLabel,
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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: WynSpacing.space2),
            Flexible(child: _buildBody()),
            const SizedBox(height: WynSpacing.space4),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_loadState) {
      case _LoadState.checking:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: WynSpacing.space8),
          child: Center(child: CircularProgressIndicator()),
        );
      case _LoadState.checkError:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('โหลดข้อมูลไม่สำเร็จ'),
              const SizedBox(height: WynSpacing.space2),
              TextButton(
                onPressed: () {
                  setState(() => _loadState = _LoadState.checking);
                  _checkExisting();
                },
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        );
      case _LoadState.alreadyReported:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: WynSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('คุณรายงานสิ่งนี้ไปแล้ว ทีมงานกำลังตรวจสอบ'),
            ],
          ),
        );
      case _LoadState.ready:
        return _buildForm();
    }
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A plain selectable ListTile rather than RadioListTile -- this
          // Flutter version deprecates Radio's groupValue/onChanged in
          // favor of a RadioGroup ancestor, which would be a heavier
          // structural change for a single-select list of 10 fixed
          // options with no reuse elsewhere in the app yet.
          for (final category in ReportCategory.values)
            Semantics(
              label: category.label,
              selected: _category == category,
              excludeSemantics: true,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _category == category
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _category == category
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(category.label),
                onTap: _isSubmitting
                    ? null
                    : () => setState(() => _category = category),
              ),
            ),
          const SizedBox(height: WynSpacing.space2),
          TextField(
            controller: _detailController,
            enabled: !_isSubmitting,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _category == ReportCategory.other
                  ? 'อธิบายเพิ่มเติม (จำเป็น)'
                  : 'อธิบายเพิ่มเติม (ถ้ามี)',
            ),
          ),
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
            child: Semantics(
              label: _canSubmit
                  ? 'ส่งรายงาน'
                  : 'ส่งรายงาน ปิดใช้งานจนกว่าจะเลือกหมวดหมู่',
              excludeSemantics: true,
              child: FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ส่งรายงาน'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
