import 'package:flutter/material.dart';

import '../../../drop/data/drop_repository.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../profile/data/profile.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/view_profile_screen.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../../saved/data/saved_repository.dart';
import 'search_state_message.dart';

/// Search's User tab (WYN-009) -- reuses FollowListScreen's own row
/// layout (WYN-008/013) exactly, since it's the same "tappable
/// avatar+name+@username row that opens a profile" shape. Query is
/// driven by [query], a prop from the shared search box in SearchScreen,
/// not typed here directly -- resets and re-searches whenever it changes.
class SearchUserResultsTab extends StatefulWidget {
  const SearchUserResultsTab({
    super.key,
    required this.query,
    required this.profileRepository,
    required this.followRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.savedRepository,
  });

  final String query;
  final ProfileRepository profileRepository;
  final FollowRepository followRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;

  @override
  State<SearchUserResultsTab> createState() => _SearchUserResultsTabState();
}

class _SearchUserResultsTabState extends State<SearchUserResultsTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<Profile> _profiles = [];
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  bool get _queryTooShort => widget.query.trim().length < 2;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (!_queryTooShort) _search(reset: true);
  }

  @override
  void didUpdateWidget(covariant SearchUserResultsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _profiles.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      if (!_queryTooShort) _search(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || !_hasMore || _queryTooShort) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _search(reset: false);
    }
  }

  Future<void> _search({required bool reset}) async {
    setState(() {
      _isLoading = true;
      if (reset) _error = null;
    });
    try {
      final page = reset ? 0 : _page + 1;
      final results = await widget.profileRepository.searchProfiles(
        query: widget.query.trim(),
        page: page,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _profiles
            ..clear()
            ..addAll(results);
        } else {
          _profiles.addAll(results);
        }
        _page = page;
        _hasMore = results.length == ProfileRepository.searchPageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'ค้นหาไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_queryTooShort) {
      return const SearchStateMessage(
        icon: Icons.person_search_outlined,
        text: 'พิมพ์ username หรือชื่อเพื่อค้นหาคน',
      );
    }

    if (_isLoading && _profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _search(reset: true),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_profiles.isEmpty) {
      return SearchStateMessage(
        icon: Icons.person_search_outlined,
        text: 'ไม่พบผู้ใช้สำหรับ "${widget.query.trim()}"',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _profiles.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _profiles.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  AvatarCircle(
                    imageUrl: profile.avatarUrl,
                    fallbackText: profile.username,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
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
    );
  }
}
