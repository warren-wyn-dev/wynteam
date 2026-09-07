import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/developer_access/developer_access_service.dart';
import '../../data/club.dart';
import '../../data/club_badge_repository.dart';
import '../../data/club_member.dart';
import '../../data/club_member_badge.dart';
import '../../data/club_post.dart';
import '../../data/club_post_repository.dart';
import '../../data/club_repository.dart';
import '../club_post_detail_screen.dart';
import '../create_club_post_screen.dart';
import 'club_post_card.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Screen 4-5 — Posts tab. Gated behind approved membership: non-members
/// (myRole == null) see a join-prompt placeholder instead of the list,
/// per the Product spec ("โพสต์ Club มองเห็นเฉพาะสมาชิกที่ approved แล้ว
/// ไม่ว่า Public/Private"). See .wyn/docs/design/wyn-014-club-core.md,
/// Screens 4-5.
///
/// Club-wide feed, not scoped to a channel: the Founder's post-
/// restructuring decision (2026-09-07) dropped WYN-127's per-channel
/// post split -- channels are chat-only now (see ClubChatTab, the
/// sibling top-level "แชท" tab). Every post in the Club shows here
/// regardless of which channel it happens to be attached to at the DB
/// layer, and a new post is always created in the Club's oldest channel
/// (`_defaultChannelId` below) -- the channel concept never surfaces in
/// this tab's UI at all.
class ClubPostsTab extends StatefulWidget {
  const ClubPostsTab({
    super.key,
    required this.clubPostRepository,
    required this.clubRepository,
    required this.club,
    required this.myRole,
    required this.onJoinTapped,
    ClubBadgeRepository? clubBadgeRepository,
    DeveloperAccessService? developerAccessService,
  })  : _clubBadgeRepository = clubBadgeRepository,
        _developerAccessService = developerAccessService;

  final ClubPostRepository clubPostRepository;

  /// Used only to resolve [_defaultChannelId] (the Club's oldest
  /// channel) -- every post still needs a real `channel_id` at the DB
  /// layer (NOT NULL), even though this tab never lets the viewer choose
  /// or see one.
  final ClubRepository clubRepository;
  final Club club;
  final ClubMemberRole? myRole;
  final VoidCallback onJoinTapped;

  /// WYN-129: optional, same defaulted-to-a-real-instance shape as every
  /// other optional repository field in this app.
  final ClubBadgeRepository? _clubBadgeRepository;

  /// Staged-rollout gate (`.wyn/company/WORKFLOW.md`'s "Staged Rollout
  /// เป็นค่าเริ่มต้นสำหรับฟีเจอร์ใหม่ทุกตัว", mandatory since 2026-09-06) --
  /// WYN-129's badge pill is the only thing left in this tab that's
  /// still staged-rollout gated (the channel switcher/chat toggle this
  /// field used to also gate were removed along with the per-channel
  /// split -- see the class doc comment).
  final DeveloperAccessService? _developerAccessService;

  @override
  State<ClubPostsTab> createState() => _ClubPostsTabState();
}

class _ClubPostsTabState extends State<ClubPostsTab> {
  late final ClubBadgeRepository _clubBadgeRepository =
      widget._clubBadgeRepository ?? ClubBadgeRepository(Supabase.instance.client);
  late final DeveloperAccessService _developerAccessService =
      widget._developerAccessService ?? DeveloperAccessService();

  /// Staged-rollout gate -- see [ClubPostsTab._developerAccessService]'s
  /// doc comment. Fail-closed while still loading/on error (`snapshot.data
  /// == true`, same posture as settings_screen.dart's `_VersionFooter`):
  /// a regular account can only ever under-promise (briefly not seeing
  /// the badge pill while this resolves), never see it by mistake.
  late final Future<bool> _isDeveloperFuture = _developerAccessService.isDeveloperAccount();

  final List<ClubPost> _posts = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  /// The Club's oldest channel id -- resolved once on init purely to
  /// satisfy `club_posts.channel_id`'s NOT NULL constraint when creating
  /// a post. Never shown in this tab's UI (see the class doc comment).
  String? _defaultChannelId;

  /// WYN-129: every badge in this Club, keyed by user id.
  Map<String, ClubMemberBadge> _badges = {};

  bool get _isMember => widget.myRole != null;

  @override
  void initState() {
    super.initState();
    if (_isMember) {
      _loadDefaultChannelThenPosts();
      // WYN-129's badge pill is gated behind the staged-rollout flag --
      // only fetch badges (and therefore only ever populate `_badges`,
      // the one thing ClubPostCard actually checks to decide whether to
      // render a pill) once this resolves `true`. A regular account's
      // `_badges` map simply stays empty forever, which is
      // indistinguishable from "nobody in this Club has a badge" -- the
      // exact pre-WYN-129 look.
      _isDeveloperFuture.then((isDeveloper) {
        if (isDeveloper) _loadBadges();
      });
    }
  }

  Future<void> _loadBadges() async {
    try {
      final badges = await _clubBadgeRepository.fetchBadges(widget.club.id);
      if (!mounted) return;
      setState(() => _badges = badges);
    } catch (_) {
      // Fails open -- a badge is cosmetic, never worth blocking the feed
      // over.
    }
  }

  Future<void> _loadDefaultChannelThenPosts() async {
    try {
      // fetchChannels() sorts oldest-first, and every Club always has at
      // least its auto-created "ทั่วไป" channel (clubs_add_default_channel()
      // in supabase/schema.sql), so `.first` always exists.
      final channels = await widget.clubRepository.fetchChannels(widget.club.id);
      if (!mounted) return;
      setState(() => _defaultChannelId = channels.isNotEmpty ? channels.first.id : null);
    } catch (_) {
      // Fails open for reading (the feed query below doesn't need a
      // channel id at all) -- only post-creation needs
      // [_defaultChannelId], and its FAB is already disabled while this
      // is null.
    }
    await _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final posts = await widget.clubPostRepository.fetchPosts(
        clubId: widget.club.id,
        page: 0,
      );
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _page = 0;
        _hasMore = posts.length == ClubPostRepository.pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดโพสต์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final posts = await widget.clubPostRepository.fetchPosts(
        clubId: widget.club.id,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _posts.addAll(posts);
        _page = nextPage;
        _hasMore = posts.length == ClubPostRepository.pageSize;
      });
    } catch (_) {
      // Silent -- same infinite-scroll convention as every other feed.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // Re-reads the live _posts[index] by id instead of a ClubPost captured
  // at the last build -- same double-tap-safety pattern as
  // DropDetailScreen/HomeFeedScreen. See .wyn/learning/PATTERNS.md.
  Future<void> _toggleLike(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final previous = _posts[index];

    setState(() => _posts[index] = previous.toggledLike());
    try {
      await widget.clubPostRepository.toggleLike(
        postId: previous.id,
        currentlyLiked: previous.likedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = previous);
    }
  }

  Future<void> _toggleSave(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final previous = _posts[index];

    setState(() => _posts[index] = previous.toggledSave());
    try {
      await widget.clubPostRepository.toggleSave(
        postId: previous.id,
        currentlySaved: previous.savedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = previous);
    }
  }

  // WYN-115: optimistic vote, same double-tap-safety/revert-on-error
  // shape as _toggleLike/_toggleSave above (and HomeFeedScreen._votePoll
  // for Drop's own Poll).
  Future<void> _votePoll(String postId, int optionIndex) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final previous = _posts[index];

    setState(() => _posts[index] = previous.votedPoll(optionIndex));
    try {
      await widget.clubPostRepository.votePoll(
        pollId: previous.pollId!,
        optionIndex: optionIndex,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = previous);
    }
  }

  Future<void> _togglePin(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final previous = _posts[index];

    setState(() => _posts[index] = previous.toggledPin());
    try {
      await widget.clubPostRepository.togglePin(
        postId: previous.id,
        currentlyPinned: previous.pinned,
      );
      // Pin state affects sort order (pinned-first), so a full reload
      // keeps the list correctly ordered rather than leaving the row in
      // its pre-toggle position.
      _loadInitial();
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = previous);
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await widget.clubPostRepository.deletePost(postId);
      if (!mounted) return;
      setState(() => _posts.removeWhere((p) => p.id == postId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _openPost(ClubPost post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPostDetailScreen(
          clubPostRepository: widget.clubPostRepository,
          post: post,
          myRole: widget.myRole,
          clubBadgeRepository: _clubBadgeRepository,
          developerAccessService: _developerAccessService,
        ),
      ),
    );
    _loadInitial();
  }

  Future<void> _openCreatePost() async {
    final channelId = _defaultChannelId;
    if (channelId == null) return;
    // channelName is always '' now -- CreateClubPostScreen's locked chip
    // falls back to its exact pre-WYN-127 text ("โพสต์ใน [ชื่อ Club]", no
    // "· #ห้อง" suffix) whenever channelName is empty, which is correct
    // unconditionally now that posting never involves picking/seeing a
    // channel (channelId still targets a real channel under the hood,
    // just never surfaced here).
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateClubPostScreen(
          clubPostRepository: widget.clubPostRepository,
          club: widget.club,
          channelId: channelId,
          channelName: '',
        ),
      ),
    );
    if (created == true) _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMember) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('เข้าร่วม Club เพื่อดูโพสต์', textAlign: TextAlign.center),
              const SizedBox(height: WynSpacing.space3),
              OutlinedButton(onPressed: widget.onJoinTapped, child: const Text('เข้าร่วม')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: WynColors.sapphire,
        foregroundColor: WynColors.paper,
        onPressed: _defaultChannelId == null ? null : _openCreatePost,
        tooltip: 'สร้างโพสต์',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      // RefreshIndicator needs a scrollable descendant to detect the pull
      // gesture at all -- a bare Center() (the previous shape here) has
      // none, so pull-to-refresh silently did nothing whenever this Club
      // had 0 posts or a failed load, even though every other state in
      // this same tab already supports it. AlwaysScrollableScrollPhysics
      // is required too: content this short wouldn't otherwise be
      // draggable far enough to trigger the indicator.
      return RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: WynSpacing.space8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: WynSpacing.space3),
                  TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: WynSpacing.space8),
              child: Center(child: Text('ยังไม่มีโพสต์ใน Club นี้ เป็นคนแรกสิ!')),
            ),
          ],
        ),
      );
    }

    // CustomScrollView (not ListView.separated) with a manual "load
    // more" button instead of scroll-triggered pagination -- same
    // trade-off decision as ClubPage's other tabs (see
    // club_members_tab.dart's identical "ดูสมาชิกเพิ่มเติม" button,
    // which already established this pattern in this same screen).
    // The previous version drove pagination off a private
    // ScrollController's own position, which is exactly what stops a
    // scrollable from being "primary" -- the one thing required for it
    // to participate in ClubPage's staged-rollout NestedScrollView
    // layout's shared header-collapse scroll position. A manual button
    // needs no ScrollController of its own at all, so this tab is now a
    // genuinely primary scrollable, same as club_members_tab.dart.
    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: CustomScrollView(
        // Same reasoning as the empty/error states above -- a Club with
        // just 1-2 short posts may not fill the viewport either, which
        // would otherwise make it undraggable far enough to trigger
        // pull-to-refresh.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 80),
            sliver: SliverList.separated(
              itemCount: _posts.length,
              // A hairline divider between posts, same as Home Feed
              // (DS-003).
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final post = _posts[index];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index == 0 && post.pinned)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            Icon(Icons.push_pin,
                                size: 14, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(width: WynSpacing.space1),
                            Text(
                              'ปักหมุด',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ClubPostCard(
                      key: ValueKey(post.id),
                      post: post,
                      myRole: widget.myRole,
                      authorBadge: _badges[post.authorId],
                      onTap: () => _openPost(post),
                      onToggleLike: () => _toggleLike(post.id),
                      onToggleSave: () => _toggleSave(post.id),
                      onTogglePin: () => _togglePin(post.id),
                      onDelete: () => _deletePost(post.id),
                      onVotePoll: (optionIndex) => _votePoll(post.id, optionIndex),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(WynSpacing.space4),
                child: Center(
                  child: _isLoadingMore
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          key: const Key('club_posts_load_more'),
                          onPressed: _loadMore,
                          child: const Text('ดูโพสต์เพิ่มเติม'),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
