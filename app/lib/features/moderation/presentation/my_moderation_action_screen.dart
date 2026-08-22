import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
import '../data/appeal_repository.dart';
import '../data/appeal_status.dart';
import '../data/moderation_action_type.dart';
import '../data/my_appeal.dart';
import '../data/my_moderation_action.dart';
import 'appeal_form_screen.dart';
import 'evidence_image_viewer.dart';

typedef _ActionWithAppeal = ({MyModerationAction action, MyAppeal? appeal});

/// Screen 4 of .wyn/docs/design/wyn-030-appeal-system.md -- the single
/// destination for all 4 moderation-related notification types
/// (moderation_warning/moderation_content_removed/appeal_approved/
/// appeal_rejected), all of which point back to the same
/// moderation_actions row. See the design doc's scope decision #2 for
/// why this replaces having a separate "appeal result" screen.
class MyModerationActionScreen extends StatefulWidget {
  const MyModerationActionScreen({
    super.key,
    required this.appealRepository,
    required this.actionId,
  });

  final AppealRepository appealRepository;
  final String actionId;

  @override
  State<MyModerationActionScreen> createState() => _MyModerationActionScreenState();
}

class _MyModerationActionScreenState extends State<MyModerationActionScreen> {
  late Future<_ActionWithAppeal> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<_ActionWithAppeal> _load() async {
    final action = await widget.appealRepository.fetchMyModerationAction(widget.actionId);
    final appeal = await widget.appealRepository.fetchMyAppeal(widget.actionId);
    return (action: action, appeal: appeal);
  }

  void _reload() => setState(() => _loadFuture = _load());

  Future<void> _openAppealForm(MyModerationAction action) async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppealFormScreen(
          appealRepository: widget.appealRepository,
          actionId: widget.actionId,
          actionLabel: action.actionType.label,
        ),
      ),
    );
    if (submitted == true) _reload();
  }

  Future<void> _openEvidence(String path) async {
    final url = await widget.appealRepository.evidenceSignedUrl(path);
    if (!mounted || url == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EvidenceImageViewer(signedUrl: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดการดำเนินการ')),
      body: FutureBuilder<_ActionWithAppeal>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('โหลดข้อมูลไม่สำเร็จ'),
                  const SizedBox(height: WynSpacing.space3),
                  TextButton(onPressed: _reload, child: const Text('ลองใหม่')),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(WynSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildActionCard(context, data.action),
                const SizedBox(height: WynSpacing.space4),
                _buildAppealSection(context, data.action, data.appeal),
              ],
            ),
          );
        },
      ),
    );
  }

  /// No link to the content, no moderator identity -- this is the
  /// affected-user's side, unlike ModerationReportDetailScreen (WYN-029,
  /// Screen 3) which moderators see. See the design doc, Screen 4.
  Widget _buildActionCard(BuildContext context, MyModerationAction action) {
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
          Text(action.actionType.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: WynSpacing.space2),
          Text(action.reason),
          const SizedBox(height: WynSpacing.space2),
          Text(
            relativeTimeLabel(action.createdAt, now: DateTime.now()),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppealSection(
    BuildContext context,
    MyModerationAction action,
    MyAppeal? appeal,
  ) {
    if (appeal == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => _openAppealForm(action),
          child: const Text('อุทธรณ์'),
        ),
      );
    }

    switch (appeal.status) {
      case AppealStatus.none:
      case AppealStatus.pending:
        return _buildStatusCard(
          context,
          title: 'อยู่ระหว่างการตรวจสอบ',
          child: _buildAppealSummary(context, appeal),
        );
      case AppealStatus.approved:
        return _buildStatusCard(
          context,
          title: _approvedMessage(action.actionType),
          // Remove Content specifically shows the appellant's own
          // reason for context, per the Product spec's Handoff -- no
          // mechanism anywhere snapshots the deleted content itself.
          child: action.actionType == ModerationActionType.removeContent
              ? _buildAppealSummary(context, appeal)
              : null,
        );
      case AppealStatus.rejected:
        return _buildStatusCard(
          context,
          title: 'อุทธรณ์ถูกปฏิเสธ',
          child: Text('เหตุผล: ${appeal.decisionReason ?? ''}'),
        );
    }
  }

  String _approvedMessage(ModerationActionType actionType) => switch (actionType) {
        ModerationActionType.warning =>
          'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว คำเตือนนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว',
        ModerationActionType.restrict =>
          'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว สิทธิ์การโพสต์ของคุณกลับมาใช้งานได้ตามปกติแล้ว',
        ModerationActionType.suspend =>
          'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว บัญชีของคุณกลับมาใช้งานได้ตามปกติแล้ว',
        ModerationActionType.ban =>
          'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว บัญชีของคุณกลับมาใช้งานได้ตามปกติแล้ว '
              'คุณสามารถเข้าสู่ระบบได้ทันที',
        // ห้ามใช้คำที่สื่อว่าเนื้อหากลับมา -- ดู Product spec's Handoff
        ModerationActionType.removeContent =>
          'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว การละเมิดนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว',
        ModerationActionType.noAction => 'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว',
      };

  Widget _buildStatusCard(BuildContext context, {required String title, Widget? child}) {
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
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          if (child != null) ...[
            const SizedBox(height: WynSpacing.space2),
            child,
          ],
        ],
      ),
    );
  }

  Widget _buildAppealSummary(BuildContext context, MyAppeal appeal) {
    final evidencePaths = appeal.evidencePaths;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('เหตุผลของคุณ: ${appeal.reason}'),
        if (evidencePaths != null && evidencePaths.isNotEmpty) ...[
          const SizedBox(height: WynSpacing.space2),
          SizedBox(
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
          ),
        ],
      ],
    );
  }
}
