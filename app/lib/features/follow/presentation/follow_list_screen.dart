import 'package:flutter/material.dart';

import '../../drop/data/drop_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../saved/data/saved_repository.dart';
import '../data/follow_repository.dart';
import '../../../core/design/wyn_spacing.dart';

enum FollowListMode { followers, following }

/// Screen 3 — Followers / Following list. One screen, mode parameter
/// (not two files) since the structure/state is identical, only the
/// query and title differ. Rows open the tapped user's profile (WYN-013)
/// -- originally left non-tappable in WYN-008 because no destination
/// screen existed yet.
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    required this.followRepository,
    required this.profileRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.savedRepository,
    required this.userId,
    required this.mode,
  });

  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final String userId;
  final FollowListMode mode;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final _scrollController = ScrollController();
  final List<Profile> _profiles = [];
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

  Future<List<Profile>> _fetchPage(int page) {
    return widget.mode == FollowListMode.followers
        ? widget.followRepository.fetchFollowers(
            userId: widget.userId,
            page: page,
          )
        : widget.followRepository.fetchFollowing(
            userId: widget.userId,
            page: page,
          );
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
      final profiles = await _fetchPage(0);
      setState(() {
        _profiles
          ..clear()
          ..addAll(profiles);
        _page = 0;
        _hasMore = profiles.length == FollowRepository.pageSize;
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
      final profiles = await _fetchPage(nextPage);
      setState(() {
        _profiles.addAll(profiles);
        _page = nextPage;
        _hasMore = profiles.length == FollowRepository.pageSize;
      });
    } catch (_) {
      // Silent: an infinite-scroll load-more failure doesn't need a
      // blocking error state -- scrolling again just retries it.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == FollowListMode.followers
        ? 'ผู้ติดตาม'
        : 'กำลังติดตาม';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
      final emptyText = widget.mode == FollowListMode.followers
          ? 'ยังไม่มีใครติดตามคุณเลย'
          : 'คุณยังไม่ได้ติดตามใครเลย ลองกดติดตามจาก Drop หรือ Pop ที่ชอบดูสิ';
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Text(emptyText, textAlign: TextAlign.center),
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
          return Semantics(
            label:
                'ผู้ใช้ ${profile.nameOrUsername} ยูสเซอร์เนม ${profile.username} กดเพื่อดูโปรไฟล์',
            button: true,
            excludeSemantics: true,
            child: InkWell(
              onTap: () => _openProfile(profile),
              child: Padding(
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
