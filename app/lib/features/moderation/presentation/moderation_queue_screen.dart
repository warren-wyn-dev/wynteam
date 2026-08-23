import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../drop/data/drop_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../../report/data/report_category.dart';
import '../../report/data/report_target_type.dart';
import '../data/appeal.dart';
import '../data/appeal_repository.dart';
import '../data/moderation_action_type.dart';
import '../data/moderation_report.dart';
import '../data/moderation_repository.dart';
import '../data/moderation_target_summary.dart';
import 'appeal_detail_screen.dart';
import 'moderation_report_detail_screen.dart';

/// Screen 2 -- the Moderation Queue: a "รายงาน" tab (`pending`/
/// `reviewing` reports, oldest first, unchanged from WYN-029) and a
/// WYN-030 "อุทธรณ์" tab (`pending` appeals, oldest first, same FIFO
/// convention). See .wyn/docs/design/wyn-029-moderation-queue.md,
/// Screen 2, and .wyn/docs/design/wyn-030-appeal-system.md, Screen 5.
class ModerationQueueScreen extends StatelessWidget {
  const ModerationQueueScreen({
    super.key,
    required this.moderationRepository,
    required this.appealRepository,
    required this.currentModeratorId,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.savedRepository,
    required this.clubRepository,
    required this.clubPostRepository,
  });

  final ModerationRepository moderationRepository;
  final AppealRepository appealRepository;

  // See AppealDetailScreen's identical doc comment -- sourced from
  // Supabase.instance.client.auth.currentUser at the call site
  // (SettingsScreen), not read from Supabase.instance in this screen.
  final String? currentModeratorId;

  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('คิวตรวจสอบ'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'รายงาน'),
              Tab(text: 'อุทธรณ์'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ReportsTab(
              moderationRepository: moderationRepository,
              dropRepository: dropRepository,
              popRepository: popRepository,
              followRepository: followRepository,
              profileRepository: profileRepository,
              savedRepository: savedRepository,
              clubRepository: clubRepository,
              clubPostRepository: clubPostRepository,
            ),
            _AppealsTab(
              appealRepository: appealRepository,
              currentModeratorId: currentModeratorId,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsTab extends StatefulWidget {
  const _ReportsTab({
    required this.moderationRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.savedRepository,
    required this.clubRepository,
    required this.clubPostRepository,
  });

  final ModerationRepository moderationRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final _scrollController = ScrollController();
  final List<ModerationReport> _reports = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final reports = await widget.moderationRepository.fetchQueue(page: 0);
      setState(() {
        _reports
          ..clear()
          ..addAll(reports);
        _page = 0;
        _hasMore = reports.length == ModerationRepository.pageSize;
      });
    } catch (_) {
      setState(() => _error = 'โหลดรายชื่อไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final reports = await widget.moderationRepository.fetchQueue(page: nextPage);
      setState(() {
        _reports.addAll(reports);
        _page = nextPage;
        _hasMore = reports.length == ModerationRepository.pageSize;
      });
    } catch (_) {
      // Silent, same posture as every other list's load-more failure.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openReport(ModerationReport report) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ModerationReportDetailScreen(
          moderationRepository: widget.moderationRepository,
          report: report,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          savedRepository: widget.savedRepository,
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
        ),
      ),
    );
    if (message == null || !mounted) return;

    // Optimistic removal (BlockedListScreen._unblock's pattern) -- the
    // action already succeeded server-side by the time this screen sees
    // a non-null result, so there's nothing to roll back on failure.
    setState(() => _reports.removeWhere((r) => r.id == report.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: WynSpacing.space4),
              const Text('ไม่มีรายงานที่รอตรวจสอบ', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _reports.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _reports.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final report = _reports[index];
          return _ModerationQueueRow(
            report: report,
            moderationRepository: widget.moderationRepository,
            onTap: () => _openReport(report),
          );
        },
      ),
    );
  }
}

class _ModerationQueueRow extends StatefulWidget {
  const _ModerationQueueRow({
    required this.report,
    required this.moderationRepository,
    required this.onTap,
  });

  final ModerationReport report;
  final ModerationRepository moderationRepository;
  final VoidCallback onTap;

  @override
  State<_ModerationQueueRow> createState() => _ModerationQueueRowState();
}

class _ModerationQueueRowState extends State<_ModerationQueueRow> {
  late Future<ModerationTargetSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = widget.moderationRepository.fetchTargetSummary(widget.report);
  }

  IconData _targetIcon() => switch (widget.report.targetType) {
        ReportTargetType.user => Icons.person_outline,
        ReportTargetType.drop => Icons.image_outlined,
        ReportTargetType.dropComment => Icons.comment_outlined,
        ReportTargetType.club => Icons.groups_outlined,
        ReportTargetType.clubPost => Icons.article_outlined,
        ReportTargetType.clubPostComment => Icons.comment_outlined,
        ReportTargetType.message => Icons.chat_bubble_outline,
      };

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final time = relativeTimeLabel(report.createdAt, now: DateTime.now());
    final headline = '${report.category.label} · ${report.targetType.label}';

    return FutureBuilder<ModerationTargetSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final summaryLabel = summary?.label ?? '';
        final detail = report.detail;

        return Semantics(
          label: '$headline. $summaryLabel. ${detail ?? ''} $time',
          button: true,
          excludeSemantics: true,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WynSpacing.space4,
                vertical: WynSpacing.space2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Icon(
                      _targetIcon(),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: WynSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(headline, style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          summaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (detail != null && detail.isNotEmpty)
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: WynSpacing.space2),
                  Text(
                    time,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// WYN-030 -- mirrors _ReportsTab's exact pagination/list/optimistic-
/// removal shape, querying `appeals` (status = 'pending') instead of
/// `reports`.
class _AppealsTab extends StatefulWidget {
  const _AppealsTab({required this.appealRepository, required this.currentModeratorId});

  final AppealRepository appealRepository;
  final String? currentModeratorId;

  @override
  State<_AppealsTab> createState() => _AppealsTabState();
}

class _AppealsTabState extends State<_AppealsTab> {
  final _scrollController = ScrollController();
  final List<Appeal> _appeals = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final appeals = await widget.appealRepository.fetchPendingAppeals(page: 0);
      setState(() {
        _appeals
          ..clear()
          ..addAll(appeals);
        _page = 0;
        _hasMore = appeals.length == AppealRepository.pageSize;
      });
    } catch (_) {
      setState(() => _error = 'โหลดรายชื่อไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final appeals = await widget.appealRepository.fetchPendingAppeals(page: nextPage);
      setState(() {
        _appeals.addAll(appeals);
        _page = nextPage;
        _hasMore = appeals.length == AppealRepository.pageSize;
      });
    } catch (_) {
      // Silent, same posture as every other list's load-more failure.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openAppeal(Appeal appeal) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AppealDetailScreen(
          appealRepository: widget.appealRepository,
          appeal: appeal,
          currentModeratorId: widget.currentModeratorId,
        ),
      ),
    );
    if (message == null || !mounted) return;

    setState(() => _appeals.removeWhere((a) => a.id == appeal.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_appeals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.gavel_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: WynSpacing.space4),
              const Text('ไม่มีอุทธรณ์ที่รอตรวจสอบ', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _appeals.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _appeals.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final appeal = _appeals[index];
          return _AppealQueueRow(appeal: appeal, onTap: () => _openAppeal(appeal));
        },
      ),
    );
  }
}

class _AppealQueueRow extends StatelessWidget {
  const _AppealQueueRow({required this.appeal, required this.onTap});

  final Appeal appeal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = relativeTimeLabel(appeal.createdAt, now: DateTime.now());
    final headline = 'อุทธรณ์: ${appeal.actionType.label}';
    final appellant = '@${appeal.appellantUsername ?? '-'}';

    return Semantics(
      label: '$headline จาก $appellant. ${appeal.reason} $time',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space4,
            vertical: WynSpacing.space2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Icon(
                  Icons.gavel_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      appellant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      appeal.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WynSpacing.space2),
              Text(
                time,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
