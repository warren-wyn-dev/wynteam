import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../block/data/block_relationship.dart';
import '../../block/data/block_repository.dart';
import '../../block/presentation/block_dialogs.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
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
///
/// [associatedUserId] (WYN-027 Design, Screen 7) -- optional, set only
/// when the target has a single identifiable owner: the user themselves
/// for `user` reports, or the content's author for `drop`/`drop_comment`/
/// `club_post`/`club_post_comment`. Deliberately omitted for `club`
/// (a Club's owner isn't "the content's author" in the same sense, and
/// may not be personally responsible for whatever was reported). When
/// set and the report succeeds, the confirmation SnackBar offers a
/// "บล็อก" action -- but only if there isn't already a block
/// relationship with that user (checked here, after the sheet closes,
/// not inside ReportSheet itself).
Future<void> showReportSheet(
  BuildContext context, {
  required ReportRepository reportRepository,
  required ReportTargetType targetType,
  required String targetId,
  required String targetLabel,
  String? associatedUserId,
}) async {
  final submitted = await showModalBottomSheet<bool>(
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

  if (submitted != true || !context.mounted) return;

  SnackBarAction? blockAction;
  if (associatedUserId != null) {
    try {
      final relationship = await BlockRepository(Supabase.instance.client)
          .blockRelationship(associatedUserId);
      if (relationship == BlockRelationship.none && context.mounted) {
        blockAction = SnackBarAction(
          label: 'บล็อก',
          onPressed: () => _offerBlockAfterReport(context, associatedUserId),
        );
      }
    } catch (_) {
      // The report itself already succeeded -- a failed eligibility
      // check just means no block action is offered, not an error.
    }
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('ส่งรายงานแล้ว ทีมงานจะตรวจสอบเร็วๆ นี้'),
      action: blockAction,
    ),
  );
}

Future<void> _offerBlockAfterReport(BuildContext context, String userId) async {
  final Profile profile;
  try {
    profile = await ProfileRepository(Supabase.instance.client).fetchProfile(userId);
  } catch (_) {
    return;
  }
  if (!context.mounted) return;

  final confirmed = await confirmBlock(context, username: profile.username);
  if (!confirmed || !context.mounted) return;

  try {
    await BlockRepository(Supabase.instance.client).blockUser(userId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('บล็อก @${profile.username} แล้ว')),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บล็อกไม่สำเร็จ ลองใหม่อีกครั้ง')),
    );
  }
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
      // The confirmation SnackBar (and optional "บล็อก" action) is shown
      // by showReportSheet() itself, once this sheet has actually closed
      // -- not here, so it can use the *caller's* still-mounted context
      // instead of this sheet's, which is about to be torn down.
      Navigator.of(context).pop(true);
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
                    // 21-report-block.tsx: the reason-picker heading
                    // ("ทำไมคุณถึงรายงานโพสต์นี้") uses the screen-title style -- same
                    // wordmark/screen-title spot every other reference
                    // screen reserves for it.
                    style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink),
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
          // A plain selectable row rather than RadioListTile -- this
          // Flutter version deprecates Radio's groupValue/onChanged in
          // favor of a RadioGroup ancestor, which would be a heavier
          // structural change for a single-select list of 10 fixed
          // options with no reuse elsewhere in the app yet.
          //
          // 21-report-block.tsx: label on the left, a small circle
          // indicator on the right (not a leading radio icon), with a
          // hairline border between rows.
          for (final (index, category) in ReportCategory.values.indexed)
            Semantics(
              label: category.label,
              selected: _category == category,
              excludeSemantics: true,
              child: InkWell(
                onTap: _isSubmitting
                    ? null
                    : () => setState(() => _category = category),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: index == 0
                          ? const BorderSide(color: WynColors.hairline)
                          : BorderSide.none,
                      bottom: const BorderSide(color: WynColors.hairline),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.label,
                          style: const TextStyle(fontSize: 15, color: WynColors.ink),
                        ),
                      ),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _category == category
                                ? WynColors.sapphire
                                : WynColors.faint,
                            width: 1.5,
                          ),
                          color: _category == category ? WynColors.sapphire : null,
                        ),
                      ),
                    ],
                  ),
                ),
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
