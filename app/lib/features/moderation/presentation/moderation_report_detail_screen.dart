import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/club_page.dart';
import '../../club/presentation/club_post_detail_screen.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../report/data/report_category.dart';
import '../../report/data/report_target_type.dart';
import '../../saved/data/saved_repository.dart';
import '../data/moderation_action_type.dart';
import '../data/moderation_report.dart';
import '../data/moderation_repository.dart';
import '../data/moderation_target_summary.dart';
import 'moderation_action_sheet.dart';

/// Severity order the design doc specifies exactly (Screen 3): from
/// least to most impactful. `removeContent` is filtered out for
/// `user`/`club` targets right before rendering (Product spec: only
/// content targets support it).
const _actionOrder = [
  ModerationActionType.noAction,
  ModerationActionType.warning,
  ModerationActionType.removeContent,
  ModerationActionType.restrict,
  ModerationActionType.suspend,
  ModerationActionType.ban,
];

/// Screen 3 -- read-mostly report detail: a link card to the actual
/// target content/profile, the reporter's category/detail/time (never
/// their identity), and the 6 (or 5, for user/club targets) action
/// buttons that each open ModerationActionSheet (Screen 4).
class ModerationReportDetailScreen extends StatefulWidget {
  const ModerationReportDetailScreen({
    super.key,
    required this.moderationRepository,
    required this.report,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.savedRepository,
    required this.clubRepository,
    required this.clubPostRepository,
  });

  final ModerationRepository moderationRepository;
  final ModerationReport report;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  @override
  State<ModerationReportDetailScreen> createState() => _ModerationReportDetailScreenState();
}

class _ModerationReportDetailScreenState extends State<ModerationReportDetailScreen> {
  late Future<ModerationTargetSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = widget.moderationRepository.fetchTargetSummary(widget.report);
  }

  Future<void> _openTarget(ModerationTargetSummary summary) async {
    if (!summary.exists) {
      final label = widget.report.targetType == ReportTargetType.user
          ? 'บัญชีนี้ถูกลบไปแล้ว'
          : 'เนื้อหานี้ถูกลบไปแล้ว';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
      return;
    }

    switch (widget.report.targetType) {
      case ReportTargetType.user:
        _openProfile(widget.report.targetId);
      case ReportTargetType.drop:
        await _openDrop(widget.report.targetId);
      case ReportTargetType.dropComment:
        final dropId = summary.parentId;
        if (dropId == null) return;
        await _openDrop(dropId);
      case ReportTargetType.club:
        _openClub(widget.report.targetId);
      case ReportTargetType.clubPost:
        await _openClubPost(widget.report.targetId);
      case ReportTargetType.clubPostComment:
        final postId = summary.parentId;
        if (postId == null) return;
        await _openClubPost(postId);
      case ReportTargetType.message:
        // No moderator-facing conversation view exists this round (no
        // admin panel yet, and messages' RLS is participant-only by
        // design) -- the reported text/image is already shown in the
        // target card itself (see ModerationTargetSummary), so this is
        // an honest no-op rather than a broken navigation attempt.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปิดดูบทสนทนานี้ได้')),
        );
    }
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: userId,
        ),
      ),
    );
  }

  Future<void> _openDrop(String dropId) async {
    final drop = await widget.dropRepository.fetchById(dropId);
    if (!mounted) return;
    if (drop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โพสต์นี้ถูกลบไปแล้ว')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: widget.dropRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          drop: drop,
        ),
      ),
    );
  }

  void _openClub(String clubId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPage(
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
          clubId: clubId,
        ),
      ),
    );
  }

  Future<void> _openClubPost(String postId) async {
    final post = await widget.clubPostRepository.fetchById(postId);
    if (!mounted) return;
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โพสต์นี้ถูกลบไปแล้ว')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPostDetailScreen(
          clubPostRepository: widget.clubPostRepository,
          post: post,
          myRole: null,
        ),
      ),
    );
  }

  /// Pops this screen with the SnackBar text ModerationQueueScreen
  /// should show after removing this report's row from the list --
  /// `null` means "the moderator backed out, nothing changed, don't pop
  /// with a result at all" (the default `Navigator.pop()` a plain back
  /// button triggers).
  Future<void> _chooseAction(ModerationActionType actionType) async {
    final outcome = await showModerationActionSheet(
      context,
      moderationRepository: widget.moderationRepository,
      reportId: widget.report.id,
      actionType: actionType,
    );
    if (outcome == null || !mounted) return;

    final message = outcome == ModerationActionSheetOutcome.alreadyActionedByOthers
        ? 'รายงานนี้ถูกดำเนินการไปแล้วโดยผู้ตรวจสอบคนอื่น'
        : 'ดำเนินการแล้ว: ${actionType.label}';
    Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดรายงาน')),
      body: FutureBuilder<ModerationTargetSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildBody(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildBody(ModerationTargetSummary summary) {
    final report = widget.report;
    final actions = _actionOrder.where((action) {
      if (action != ModerationActionType.removeContent) return true;
      // WYN-031: apply_moderation_action() has no message-removal
      // effect wired up this round -- a moderator can still Warn/
      // Restrict/Suspend/Ban the sender based on a reported message's
      // content, just not force-remove the message itself through this
      // flow (the sender can already delete_message() their own).
      return report.targetType != ReportTargetType.user &&
          report.targetType != ReportTargetType.club &&
          report.targetType != ReportTargetType.message;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(WynSpacing.space4),
      children: [
        Semantics(
          label: _targetCardLabel(report, summary),
          button: true,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
            onTap: () => _openTarget(summary),
            child: Container(
              padding: const EdgeInsets.all(WynSpacing.space4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(_targetIcon(report.targetType)),
                  const SizedBox(width: WynSpacing.space3),
                  Expanded(
                    child: Text(
                      _targetCardLabel(report, summary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: WynSpacing.space6),
        Text(report.category.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: WynSpacing.space2),
        Text(
          (report.detail == null || report.detail!.isEmpty) ? 'ไม่มีรายละเอียดเพิ่มเติม' : report.detail!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: (report.detail == null || report.detail!.isEmpty)
                    ? Theme.of(context).colorScheme.outline
                    : null,
              ),
        ),
        const SizedBox(height: WynSpacing.space2),
        Text(
          relativeTimeLabel(report.createdAt, now: DateTime.now()),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: WynSpacing.space6),
        for (final action in actions) ...[
          SizedBox(
            width: double.infinity,
            child: Semantics(
              label: 'ดำเนินการ: ${action.label}',
              excludeSemantics: true,
              child: OutlinedButton(
                onPressed: () => _chooseAction(action),
                child: Text(action.label),
              ),
            ),
          ),
          const SizedBox(height: WynSpacing.space2),
        ],
      ],
    );
  }

  String _targetCardLabel(ModerationReport report, ModerationTargetSummary summary) {
    if (!summary.exists) return summary.label;
    if (report.targetType == ReportTargetType.user ||
        report.targetType == ReportTargetType.club) {
      return '${report.targetType.label}: ${summary.label}';
    }
    final owner = summary.ownerUsername;
    final suffix = owner == null ? '' : ' ของ @$owner';
    return '${report.targetType.label}$suffix: ${summary.label}';
  }

  IconData _targetIcon(ReportTargetType type) => switch (type) {
        ReportTargetType.user => Icons.person_outline,
        ReportTargetType.drop => Icons.image_outlined,
        ReportTargetType.dropComment => Icons.comment_outlined,
        ReportTargetType.club => Icons.groups_outlined,
        ReportTargetType.clubPost => Icons.article_outlined,
        ReportTargetType.clubPostComment => Icons.comment_outlined,
        ReportTargetType.message => Icons.chat_bubble_outline,
      };
}
