import 'package:flutter/material.dart';

import '../../profile/data/profile.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/follow_request_repository.dart';
import '../../../core/design/wyn_spacing.dart';

/// Design Screen 3 — Follow Requests list. Mirrors
/// MessageRequestListScreen's (WYN-032) list/pagination/state shape --
/// only reachable from the caller's own profile (a Private account with
/// at least 1 pending request), so there is no [userId] parameter at
/// all, unlike [FollowListScreen] -- every request here is always about
/// the current user.
class FollowRequestListScreen extends StatefulWidget {
  const FollowRequestListScreen({
    super.key,
    required this.followRequestRepository,
  });

  final FollowRequestRepository followRequestRepository;

  @override
  State<FollowRequestListScreen> createState() =>
      _FollowRequestListScreenState();
}

class _FollowRequestListScreenState extends State<FollowRequestListScreen> {
  final _scrollController = ScrollController();
  final List<Profile> _requesters = [];
  final Set<String> _inFlight = {};
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
      final requesters =
          await widget.followRequestRepository.fetchPendingRequests(page: 0);
      setState(() {
        _requesters
          ..clear()
          ..addAll(requesters);
        _page = 0;
        _hasMore = requesters.length == FollowRequestRepository.pageSize;
      });
    } catch (_) {
      setState(() => _error = 'โหลดคำขอติดตามไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final requesters = await widget.followRequestRepository
          .fetchPendingRequests(page: nextPage);
      setState(() {
        _requesters.addAll(requesters);
        _page = nextPage;
        _hasMore = requesters.length == FollowRequestRepository.pageSize;
      });
    } catch (_) {
      // Silent: same posture as every other infinite-scroll load-more in
      // this app -- scrolling again just retries it.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _accept(Profile requester) async {
    if (_inFlight.contains(requester.id)) return;
    setState(() => _inFlight.add(requester.id));
    try {
      await widget.followRequestRepository.acceptRequest(
        requesterId: requester.id,
      );
      if (!mounted) return;
      setState(() => _requesters.removeWhere((p) => p.id == requester.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยอมรับคำขอไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _inFlight.remove(requester.id));
    }
  }

  Future<void> _reject(Profile requester) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('ปฏิเสธคำขอติดตามจาก ${requester.nameOrUsername}?'),
            content: const Text('ผู้ขอจะไม่ได้รับแจ้งเตือน'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('ปฏิเสธ'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || _inFlight.contains(requester.id)) return;

    setState(() => _inFlight.add(requester.id));
    try {
      await widget.followRequestRepository.rejectRequest(
        requesterId: requester.id,
      );
      if (!mounted) return;
      setState(() => _requesters.removeWhere((p) => p.id == requester.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ปฏิเสธคำขอไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _inFlight.remove(requester.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คำขอติดตาม')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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

    if (_requesters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Text('ยังไม่มีคำขอติดตาม', textAlign: TextAlign.center),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _requesters.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _requesters.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final requester = _requesters[index];
          final isBusy = _inFlight.contains(requester.id);
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
            child: Row(
              children: [
                AvatarCircle(
                  imageUrl: requester.avatarUrl,
                  fallbackText: requester.username,
                  radius: 20,
                ),
                const SizedBox(width: WynSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requester.nameOrUsername,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '@${requester.username}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: WynSpacing.space2),
                if (isBusy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  OutlinedButton(
                    onPressed: () => _reject(requester),
                    child: const Text('ปฏิเสธ'),
                  ),
                  const SizedBox(width: WynSpacing.space2),
                  FilledButton(
                    onPressed: () => _accept(requester),
                    child: const Text('ยอมรับ'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
