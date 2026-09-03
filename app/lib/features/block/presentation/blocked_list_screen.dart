import 'package:flutter/material.dart';

import '../../profile/data/profile.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../../core/design/wyn_spacing.dart';
import '../data/block_repository.dart';
import 'block_dialogs.dart';

/// Screen 5 of .wyn/docs/design/wyn-027-block-system.md -- the only
/// place Unblock happens (Product spec: "ไม่มีปุ่ม Unblock ด่วนจาก
/// Profile เพื่อกันมือลื่น"). Reuses FollowListScreen's row layout, but
/// rows are deliberately *not* a tap-to-profile target -- this list
/// isn't meant to become a shortcut back into a blocked person's
/// profile.
class BlockedListScreen extends StatefulWidget {
  const BlockedListScreen({super.key, required this.blockRepository});

  final BlockRepository blockRepository;

  @override
  State<BlockedListScreen> createState() => _BlockedListScreenState();
}

class _BlockedListScreenState extends State<BlockedListScreen> {
  final _scrollController = ScrollController();
  final List<Profile> _profiles = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  final Set<String> _unblockingIds = {};

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
      final profiles = await widget.blockRepository.fetchBlockedUsers(page: 0);
      setState(() {
        _profiles
          ..clear()
          ..addAll(profiles);
        _page = 0;
        _hasMore = profiles.length == BlockRepository.pageSize;
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
      final profiles = await widget.blockRepository.fetchBlockedUsers(page: nextPage);
      setState(() {
        _profiles.addAll(profiles);
        _page = nextPage;
        _hasMore = profiles.length == BlockRepository.pageSize;
      });
    } catch (_) {
      // Silent, same posture as FollowListScreen's load-more failure.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _unblock(Profile profile) async {
    final confirmed = await confirmUnblock(context, username: profile.username);
    if (!confirmed || !mounted) return;

    setState(() => _unblockingIds.add(profile.id));
    try {
      await widget.blockRepository.unblockUser(profile.id);
      if (!mounted) return;
      setState(() {
        _profiles.removeWhere((p) => p.id == profile.id);
        _unblockingIds.remove(profile.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _unblockingIds.remove(profile.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เลิกบล็อกไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('บัญชีที่ถูกบล็อก')),
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

    if (_profiles.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Text('ยังไม่มีบัญชีที่ถูกบล็อก', textAlign: TextAlign.center),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _profiles.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _profiles.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final profile = _profiles[index];
          final isUnblocking = _unblockingIds.contains(profile.id);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
            child: Row(
              children: [
                AvatarCircle(
                  imageUrl: profile.avatarUrl,
                  fallbackText: profile.username,
                  radius: 20,
                ),
                const SizedBox(width: WynSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nameOrUsername,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '@${profile.username}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'เลิกบล็อก @${profile.username}',
                  excludeSemantics: true,
                  child: OutlinedButton(
                    onPressed: isUnblocking ? null : () => _unblock(profile),
                    child: isUnblocking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('เลิกบล็อก'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
