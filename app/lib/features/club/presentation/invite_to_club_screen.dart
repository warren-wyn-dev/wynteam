import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/interaction/wyn_feedback.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/shared_content_type.dart';
import '../../follow/data/follow_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';

enum _InviteState { idle, sending, invited }

/// WYN-123 -- pick people to invite into a Club from the current user's
/// own Followers **and** Following, merged and de-duplicated (Founder
/// decision, 2026-09-06 -- see .wyn/tasks/active/
/// WYN-123-invite-followers-to-club.md's "Founder Decision": Instagram's
/// Close Friends uses followers, X's Community invite uses following,
/// no single industry standard, so both are included here, matching
/// Instagram's own Group Chat "Add People").
///
/// Row layout/search/pagination copies `FollowListScreen`'s structure
/// verbatim (same avatar/name/@username shape, same search-filters-
/// already-loaded-page behavior) -- the only real difference is the
/// trailing widget (an "เชิญ"/"เชิญแล้ว" button instead of
/// [FollowActionButton]) and that a row itself isn't tappable (this
/// screen's only job is inviting, unlike Followers/Following which also
/// let you open a profile). Sending reuses WYN-033's existing
/// mechanism -- `ChatRepository.getOrCreateConversation` +
/// `sendMessage(sharedContentType: club)` -- exactly like
/// `ShareToChatScreen`'s own search-result tap, so a club invite is
/// just a Chat message with the club's shared-content card, no new
/// notification type or DB table.
///
/// Deliberately does not close itself after a successful invite (unlike
/// `ShareToChatScreen`, which pops back immediately) -- the point of
/// this screen is inviting several people in one visit, so the row that
/// was just invited flips to "เชิญแล้ว" and stays on screen instead.
class InviteToClubScreen extends StatefulWidget {
  const InviteToClubScreen({
    super.key,
    required this.followRepository,
    required this.chatRepository,
    required this.clubId,
    required this.clubName,
  });

  final FollowRepository followRepository;
  final ChatRepository chatRepository;
  final String clubId;
  final String clubName;

  @override
  State<InviteToClubScreen> createState() => _InviteToClubScreenState();
}

class _InviteToClubScreenState extends State<InviteToClubScreen> {
  final List<Profile> _profiles = [];
  final Set<String> _seenIds = {};
  final Map<String, _InviteState> _inviteStates = {};
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  int _followersPage = 0;
  int _followingPage = 0;
  bool _followersHasMore = true;
  bool _followingHasMore = true;

  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  String? _error;

  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  List<Profile> get _visibleProfiles {
    if (_searchQuery.isEmpty) return _profiles;
    final q = _searchQuery.toLowerCase();
    return _profiles
        .where((p) =>
            p.nameOrUsername.toLowerCase().contains(q) ||
            p.username.toLowerCase().contains(q))
        .toList();
  }

  bool get _hasMore => _followersHasMore || _followingHasMore;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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
      await _fetchNextChunk();
    } catch (_) {
      if (mounted) setState(() => _error = 'โหลดรายชื่อไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      await _fetchNextChunk();
    } catch (_) {
      // Silent -- same posture as FollowListScreen's own load-more
      // failure: scrolling again just retries it, no blocking error UI.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Fetches one page from whichever of Followers/Following still has
  /// more, merges new (not-already-seen) profiles into [_profiles], and
  /// keeps doing so for a bounded number of rounds -- a page that
  /// merges down to zero new rows (heavy overlap between the two lists)
  /// would otherwise make one "load more" trigger an unbounded fetch
  /// loop against two paginated sources with no single combined cursor.
  /// Stopping early and letting the scroll listener call this again is
  /// the same degrade-gracefully shape `FollowListScreen`'s own
  /// `_loadMore` already relies on for a single source.
  Future<void> _fetchNextChunk() async {
    const maxRounds = 5;
    for (var round = 0; round < maxRounds; round++) {
      if (!_hasMore) return;

      final results = await Future.wait([
        _followersHasMore
            ? widget.followRepository.fetchFollowers(
                userId: _currentUserId, page: _followersPage)
            : Future.value(<Profile>[]),
        _followingHasMore
            ? widget.followRepository.fetchFollowing(
                userId: _currentUserId, page: _followingPage)
            : Future.value(<Profile>[]),
      ]);

      final followersBatch = results[0];
      final followingBatch = results[1];

      if (_followersHasMore) {
        _followersPage++;
        _followersHasMore = followersBatch.length == FollowRepository.pageSize;
      }
      if (_followingHasMore) {
        _followingPage++;
        _followingHasMore = followingBatch.length == FollowRepository.pageSize;
      }

      final newProfiles = <Profile>[];
      for (final profile in [...followersBatch, ...followingBatch]) {
        if (_seenIds.add(profile.id)) newProfiles.add(profile);
      }

      if (newProfiles.isNotEmpty) {
        if (!mounted) return;
        setState(() => _profiles.addAll(newProfiles));
        return;
      }
      // This round merged down to nothing new -- try the next round
      // only if a source still has more left, otherwise stop.
    }
  }

  Future<void> _invite(Profile profile) async {
    if (_inviteStates[profile.id] != null &&
        _inviteStates[profile.id] != _InviteState.idle) {
      return;
    }
    setState(() => _inviteStates[profile.id] = _InviteState.sending);
    try {
      final conversationId =
          await widget.chatRepository.getOrCreateConversation(profile.id);
      await widget.chatRepository.sendMessage(
        conversationId: conversationId,
        sharedContentType: SharedContentType.club,
        sharedContentId: widget.clubId,
      );
      if (!mounted) return;
      setState(() => _inviteStates[profile.id] = _InviteState.invited);
      WynFeedback.toggle();
    } catch (_) {
      if (!mounted) return;
      setState(() => _inviteStates[profile.id] = _InviteState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เชิญไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'เชิญเพื่อนเข้ากลุ่ม',
          style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WynSpacing.space4, WynSpacing.space3, WynSpacing.space4, 0,
            ),
            child: Text.rich(
              TextSpan(
                text: 'เชิญเข้า Club ',
                style: _textStyle(fontSize: 12.5, color: WynColors.graphite),
                children: [
                  TextSpan(
                    text: widget.clubName,
                    style: _textStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: WynColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space6, WynSpacing.space3, WynSpacing.space6, WynSpacing.space2,
      ),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
        decoration: BoxDecoration(
          color: WynColors.surfaceTint,
          borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
          border: Border.all(color: WynColors.hairline),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 14, color: WynColors.mutedNeutral),
            const SizedBox(width: WynSpacing.space2),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: _textStyle(fontSize: 16, color: WynColors.ink),
                decoration: InputDecoration(
                  hintText: 'ค้นหา',
                  hintStyle: _textStyle(fontSize: 16, color: WynColors.mutedNeutral),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial && _profiles.isEmpty) {
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
          child: Text(
            'คุณยังไม่มีผู้ติดตามให้เชิญตอนนี้ — ลองแชร์ลิงก์ผ่านช่องทางอื่นดูก่อนได้',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final visible = _visibleProfiles;
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Text(
            'ไม่พบผู้ใช้ที่ตรงกับ "$_searchQuery"',
            textAlign: TextAlign.center,
            style: _textStyle(fontSize: 13, color: WynColors.faint),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: visible.length + (_hasMore && _searchQuery.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= visible.length) {
          return const Padding(
            padding: EdgeInsets.all(WynSpacing.space4),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildRow(visible[index]);
      },
    );
  }

  Widget _buildRow(Profile profile) {
    final state = _inviteStates[profile.id] ?? _InviteState.idle;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space6, vertical: WynSpacing.space2),
      child: Row(
        children: [
          Semantics(
            label: 'ผู้ใช้ ${profile.nameOrUsername} ยูสเซอร์เนม ${profile.username}',
            excludeSemantics: true,
            child: AvatarCircle(
              imageUrl: profile.avatarUrl,
              fallbackText: profile.username,
              radius: 21,
              ring: true,
            ),
          ),
          const SizedBox(width: WynSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.nameOrUsername,
                  style: _textStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WynColors.ink),
                ),
                Text(
                  '@${profile.username}',
                  style: _textStyle(fontSize: 13, color: WynColors.mutedNeutral),
                ),
              ],
            ),
          ),
          const SizedBox(width: WynSpacing.space2),
          _buildInviteButton(profile, state),
        ],
      ),
    );
  }

  Widget _buildInviteButton(Profile profile, _InviteState state) {
    return SizedBox(
      height: WynSpacing.touchTargetMin,
      child: switch (state) {
        _InviteState.sending => Semantics(
            label: 'กำลังเชิญ ${profile.nameOrUsername}',
            excludeSemantics: true,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: WynSpacing.space4),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        _InviteState.invited => Semantics(
            label: 'เชิญ ${profile.nameOrUsername} แล้ว',
            excludeSemantics: true,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check, size: 14, color: WynColors.mutedNeutral),
              label: Text(
                'เชิญแล้ว',
                style: _textStyle(fontSize: 12.5, color: WynColors.mutedNeutral),
              ),
            ),
          ),
        _InviteState.idle => Semantics(
            label: 'เชิญ ${profile.nameOrUsername} เข้ากลุ่ม',
            button: true,
            excludeSemantics: true,
            child: OutlinedButton(
              onPressed: () => _invite(profile),
              child: const Text('เชิญ'),
            ),
          ),
      },
    );
  }
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) =>
    TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
