import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
import '../data/appeal.dart';
import '../data/appeal_repository.dart';
import '../data/moderation_action_type.dart';
import 'appeal_decision_sheet.dart';
import 'evidence_image_viewer.dart';

/// Screen 6 -- moderator-side appeal review: the original moderation
/// action, the appellant's identity/reason/evidence, and Approve/Reject.
/// Mirrors ModerationReportDetailScreen's (WYN-029, Screen 3) exact
/// shape (Container target-summary-style cards, OutlinedButton actions,
/// pop-with-a-SnackBar-message-string back to the list). See
/// .wyn/docs/design/wyn-030-appeal-system.md, Screen 6.
class AppealDetailScreen extends StatefulWidget {
  const AppealDetailScreen({
    super.key,
    required this.appealRepository,
    required this.appeal,
    required this.currentModeratorId,
  });

  final AppealRepository appealRepository;
  final Appeal appeal;

  // Passed in explicitly by the caller (ModerationQueueScreen, sourced
  // from Supabase.instance.client.auth.currentUser there) rather than
  // read from Supabase.instance directly in this widget -- keeps this
  // screen testable without a live/fake Supabase session, same
  // "repository/identity injected in, never reached for" shape as every
  // other screen in this app.
  final String? currentModeratorId;

  @override
  State<AppealDetailScreen> createState() => _AppealDetailScreenState();
}

class _AppealDetailScreenState extends State<AppealDetailScreen> {
  bool _isDeciding = false;

  /// Self-review guard (UI layer -- the real boundary is decide_appeal()
  /// itself raising an exception, see supabase/schema.sql). A moderator
  /// who happens to be the target of their own moderation action must
  /// never see Approve/Reject for it.
  bool get _isSelfReview =>
      widget.currentModeratorId != null &&
      widget.currentModeratorId == widget.appeal.actionTargetUserId;

  Future<void> _openEvidence(String path) async {
    final url = await widget.appealRepository.evidenceSignedUrl(path);
    if (!mounted || url == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EvidenceImageViewer(signedUrl: url)),
    );
  }

  Future<void> _decide(bool approve) async {
    setState(() => _isDeciding = true);
    final outcome = await showAppealDecisionSheet(
      context,
      appealRepository: widget.appealRepository,
      appealId: widget.appeal.id,
      approve: approve,
    );
    if (!mounted) return;
    setState(() => _isDeciding = false);
    if (outcome == null) return;

    final message = outcome == AppealDecisionSheetOutcome.alreadyDecided
        ? 'อุทธรณ์นี้ถูกตัดสินไปแล้วโดยผู้ตรวจสอบคนอื่น'
        : approve
            ? 'อนุมัติอุทธรณ์แล้ว'
            : 'ปฏิเสธอุทธรณ์แล้ว';
    Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    final appeal = widget.appeal;
    final appellantLabel = appeal.appellantDisplayName?.isNotEmpty == true
        ? '${appeal.appellantDisplayName} (@${appeal.appellantUsername ?? '-'})'
        : '@${appeal.appellantUsername ?? '-'}';

    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดอุทธรณ์')),
      body: ListView(
        padding: const EdgeInsets.all(WynSpacing.space4),
        children: [
          Text('ผู้ยื่นอุทธรณ์', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: WynSpacing.space1),
          Text(appellantLabel),
          const SizedBox(height: WynSpacing.space6),
          _buildCard(
            context,
            title: 'บทลงโทษเดิม: ${appeal.actionType.label}',
            children: [
              Text(appeal.actionReason),
              const SizedBox(height: WynSpacing.space2),
              Text(
                relativeTimeLabel(appeal.actionCreatedAt, now: DateTime.now()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              if (appeal.actionReviewerUsername != null) ...[
                const SizedBox(height: WynSpacing.space1),
                Text(
                  'ผู้ดำเนินการ: @${appeal.actionReviewerUsername}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: WynSpacing.space4),
          _buildCard(
            context,
            title: 'เหตุผลของผู้ยื่นอุทธรณ์',
            children: [
              Text(appeal.reason),
              if (appeal.evidencePaths != null && appeal.evidencePaths!.isNotEmpty) ...[
                const SizedBox(height: WynSpacing.space3),
                _buildEvidenceRow(context, appeal.evidencePaths!),
              ],
            ],
          ),
          const SizedBox(height: WynSpacing.space6),
          if (_isSelfReview)
            Text(
              'คุณไม่สามารถตัดสินอุทธรณ์นี้ได้ เนื่องจากเป็นบทลงโทษที่มีต่อบัญชีของคุณเอง',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isDeciding ? null : () => _decide(true),
                child: const Text('อนุมัติ'),
              ),
            ),
            const SizedBox(height: WynSpacing.space2),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isDeciding ? null : () => _decide(false),
                child: const Text('ปฏิเสธ'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WynSpacing.space4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: WynSpacing.space2),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEvidenceRow(BuildContext context, List<String> evidencePaths) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: evidencePaths.length,
        separatorBuilder: (context, index) => const SizedBox(width: WynSpacing.space2),
        itemBuilder: (context, index) {
          return Semantics(
            label: 'หลักฐานรูปที่ ${index + 1}',
            button: true,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => _openEvidence(evidencePaths[index]),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.image_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
