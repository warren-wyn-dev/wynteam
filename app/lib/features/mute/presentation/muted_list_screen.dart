import 'package:flutter/material.dart';

import '../../drop/data/drop_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../saved/data/saved_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../../core/design/wyn_spacing.dart';
import '../data/mute_repository.dart';

/// Screen 4 of .wyn/docs/design/wyn-028-mute-system.md. Unlike
/// BlockedListScreen, rows here *are* a tap-to-profile target (same
/// shape as FollowListScreen) -- mute doesn't restrict profile access
/// at all, so there's no reason to block the shortcut the way Block's
/// list deliberately does. Unmute has no confirm dialog (unlike
/// Block's "เลิกบล็อก") since it's fully reversible and invisible to
/// the other party.
class MutedListScreen extends StatefulWidget {
  const MutedListScreen({
    super.key,
    required this.muteRepository,
    required this.profileRepository,
    required this.followRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.savedRepository,
  });

  final MuteRepository muteRepository;
  final ProfileRepository profileRepository;
  final FollowRepository followRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;

  @override
  State<MutedListScreen> createState() => _MutedListScreenState();
}

class _MutedListScreenState extends State<MutedListScreen> {
  final _scrollController = ScrollController();
  final List<Profile> _profiles = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  final Set<String> _unmutingIds = {};

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
      final profiles = await widget.muteRepository.fetchMutedUsers(page: 0);
      setState(() {
        _profiles
          ..clear()
          ..addAll(profiles);
        _page = 0;
        _hasMore = profiles.length == MuteRepository.pageSize;
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
      final profiles = await widget.muteRepository.fetchMutedUsers(page: nextPage);
      setState(() {
        _profiles.addAll(profiles);
        _page = nextPage;
        _hasMore = profiles.length == MuteRepository.pageSize;
      });
    } catch (_) {
      // Silent, same posture as FollowListScreen's load-more failure.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _openProfile(Profile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: profile.id,
        ),
      ),
    );
  }

  Future<void> _unmute(Profile profile) async {
    setState(() => _unmutingIds.add(profile.id));
    try {
      await widget.muteRepository.unmuteUser(profile.id);
      if (!mounted) return;
      setState(() {
        _profiles.removeWhere((p) => p.id == profile.id);
        _unmutingIds.remove(profile.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _unmutingIds.remove(profile.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิดเสียงไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('บัญชีที่ปิดเสียง')),
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
          child: Text('ยังไม่มีบัญชีที่ปิดเสียง', textAlign: TextAlign.center),
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
          final isUnmuting = _unmutingIds.contains(profile.id);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label:
                        'ผู้ใช้ ${profile.nameOrUsername} ยูสเซอร์เนม ${profile.username} กดเพื่อดูโปรไฟล์',
                    button: true,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => _openProfile(profile),
                      borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
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
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: WynSpacing.space2),
                Semantics(
                  label: 'เปิดเสียง @${profile.username}',
                  excludeSemantics: true,
                  child: OutlinedButton(
                    onPressed: isUnmuting ? null : () => _unmute(profile),
                    child: isUnmuting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('เปิดเสียง'),
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
