import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/club.dart';
import '../../data/club_badge_repository.dart';
import '../../data/club_channel.dart';
import '../../data/club_channel_chat_repository.dart';
import '../../data/club_member.dart';
import '../../data/club_member_badge.dart';
import '../../data/club_post.dart';
import '../../data/club_post_repository.dart';
import '../../data/club_repository.dart';
import '../club_post_detail_screen.dart';
import '../create_club_post_screen.dart';
import 'club_channel_chat_view.dart';
import 'club_channel_switcher.dart';
import 'club_post_card.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

/// WYN-128: which of the channel's 2 sub-views is showing -- the
/// Design's recommended "toggle เล็กๆ 'โพสต์ | แชท' ใต้แถบ channel" rather
/// than a separate navigation layer. Posts is always the default (both
/// on first open and after switching channels), matching this widget's
/// pre-WYN-128 behavior exactly for anyone who never touches the toggle.
enum _ClubChannelView { posts, chat }

/// Screen 4-5 — Posts tab. Gated behind approved membership: non-members
/// (myRole == null) see a join-prompt placeholder instead of the list,
/// per the Product spec ("โพสต์ Club มองเห็นเฉพาะสมาชิกที่ approved แล้ว
/// ไม่ว่า Public/Private"). See .wyn/docs/design/wyn-014-club-core.md,
/// Screens 4-5.
///
/// WYN-127: hosts the channel chip row above the feed, and scopes every
/// fetch to whichever channel is selected -- see
/// .wyn/tasks/backlog/WYN-127-club-channels.md.
///
/// WYN-128: also hosts the Group Chat for whichever channel is selected,
/// behind the "โพสต์ | แชท" toggle -- see
/// .wyn/tasks/backlog/WYN-128-club-group-chat.md. There is no separate
/// "Chat" tab/route at the Club level; the chat lives *inside* each
/// channel, exactly like the Posts feed does.
class ClubPostsTab extends StatefulWidget {
  const ClubPostsTab({
    super.key,
    required this.clubPostRepository,
    required this.clubRepository,
    required this.club,
    required this.myRole,
    required this.onJoinTapped,
    ClubBadgeRepository? clubBadgeRepository,
    ClubChannelChatRepository? clubChannelChatRepository,
    this.onBanned,
  })  : _clubBadgeRepository = clubBadgeRepository,
        _clubChannelChatRepository = clubChannelChatRepository;

  final ClubPostRepository clubPostRepository;

  /// WYN-127: owns `club_channels` reads/writes -- kept separate from
  /// [clubPostRepository], mirroring how ClubPage already threads a
  /// distinct ClubRepository/ClubPostRepository pair through today.
  final ClubRepository clubRepository;
  final Club club;
  final ClubMemberRole? myRole;
  final VoidCallback onJoinTapped;

  /// WYN-129: optional, same defaulted-to-a-real-instance shape as every
  /// other optional repository field in this app.
  final ClubBadgeRepository? _clubBadgeRepository;

  /// WYN-128: same optional shape again.
  final ClubChannelChatRepository? _clubChannelChatRepository;

  /// WYN-128: bubbled up from ClubChannelChatView when this user's own
  /// membership in [club] is banned/removed while the chat view is open
  /// -- see that widget's own doc comment for why this tab (not the chat
  /// view itself) is what reacts. Optional so existing call sites/tests
  /// that don't care about this edge case don't need to supply one.
  final VoidCallback? onBanned;

  @override
  State<ClubPostsTab> createState() => _ClubPostsTabState();
}

class _ClubPostsTabState extends State<ClubPostsTab> {
  late final ClubBadgeRepository _clubBadgeRepository =
      widget._clubBadgeRepository ?? ClubBadgeRepository(Supabase.instance.client);
  late final ClubChannelChatRepository _clubChannelChatRepository =
      widget._clubChannelChatRepository ?? ClubChannelChatRepository(Supabase.instance.client);

  final _scrollController = ScrollController();
  final List<ClubPost> _posts = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  List<ClubChannel>? _channels;
  String? _selectedChannelId;
  String? _channelsError;
  _ClubChannelView _viewMode = _ClubChannelView.posts;

  /// WYN-128: unread message count per channel id -- Requirement 6's
  /// badge on the "แชท" toggle. Kept live by [_unreadSubscription] while
  /// [_viewMode] is [_ClubChannelView.posts] (the chat view marks its
  /// own channel read and keeps its own realtime subscription once
  /// [_viewMode] switches to chat -- see [_setViewMode]).
  Map<String, int> _unreadCounts = {};
  RealtimeChannel? _unreadSubscription;

  /// WYN-129: every badge in this Club, keyed by user id -- club-wide,
  /// not channel-scoped, so it's fetched once (not re-fetched on channel
  /// switch) and passed down to each ClubPostCard as `authorBadge`.
  Map<String, ClubMemberBadge> _badges = {};

  bool get _isMember => widget.myRole != null;
  bool get _canManageChannels => widget.myRole?.canManageClub ?? false;

  @override
  void initState() {
    super.initState();
    if (_isMember) {
      _loadChannelsThenPosts();
      _loadBadges();
    }
    _scrollController.addListener(_onScroll);
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

  @override
  void dispose() {
    _unsubscribeUnread();
    _scrollController.dispose();
    super.dispose();
  }

  void _unsubscribeUnread() {
    final subscription = _unreadSubscription;
    if (subscription != null) {
      _clubChannelChatRepository.unsubscribe(subscription);
      _unreadSubscription = null;
    }
  }

  /// Keeps [_unreadCounts] live for [channelId] while the chat view for
  /// it isn't open -- a lighter-weight subscription than the one
  /// ClubChannelChatView itself opens (no presence tracking), and never
  /// runs at the same time as that one (see [_setViewMode]/
  /// [_selectChannel]).
  void _subscribeUnread(String channelId) {
    _unsubscribeUnread();
    _unreadSubscription = _clubChannelChatRepository.subscribeToNewMessagesOnly(
      channelId,
      (message) {
        if (!mounted || message.authorId == Supabase.instance.client.auth.currentUser!.id) return;
        setState(() {
          _unreadCounts = {...(_unreadCounts), channelId: (_unreadCounts[channelId] ?? 0) + 1};
        });
      },
    );
  }

  Future<void> _loadUnreadCounts() async {
    try {
      final counts = await _clubChannelChatRepository.fetchUnreadCounts(widget.club.id);
      if (!mounted) return;
      setState(() => _unreadCounts = counts);
    } catch (_) {
      // Fails open -- an unread badge is a nicety, never worth blocking
      // the channel switcher over.
    }
  }

  void _setViewMode(_ClubChannelView mode) {
    if (mode == _viewMode) return;
    setState(() => _viewMode = mode);
    final channelId = _selectedChannelId;
    if (channelId == null) return;
    if (mode == _ClubChannelView.chat) {
      // The chat view marks its own channel read and keeps its own
      // (heavier, presence-tracking) subscription from here on --
      // stopping this lighter one avoids double-counting the same
      // inserts twice.
      _unsubscribeUnread();
      setState(() => _unreadCounts = {..._unreadCounts, channelId: 0});
    } else {
      _subscribeUnread(channelId);
    }
  }

  /// WYN-128: see ClubChannelChatView.onBanned's own doc comment for why
  /// this tab, not the chat view, is what reacts.
  void _onBanned() {
    if (!mounted) return;
    setState(() => _viewMode = _ClubChannelView.posts);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คุณถูกนำออกจาก Club นี้แล้ว')),
    );
    widget.onBanned?.call();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadChannelsThenPosts() async {
    setState(() => _channelsError = null);
    try {
      final channels = await widget.clubRepository.fetchChannels(widget.club.id);
      if (!mounted) return;
      setState(() {
        _channels = channels;
        // Design's User Flow: "แถบ channel ... เริ่มที่ #ทั่วไป เสมอ" --
        // fetchChannels() already sorts oldest-first, and "ทั่วไป" is
        // always the oldest (created by clubs_add_default_channel() at
        // the same moment as the Club itself), so this is simply the
        // first channel, unless one is already selected.
        _selectedChannelId ??= channels.isNotEmpty ? channels.first.id : null;
      });
      await _loadInitial();
      await _loadUnreadCounts();
      final channelId = _selectedChannelId;
      if (channelId != null && _viewMode == _ClubChannelView.posts) {
        _subscribeUnread(channelId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _channelsError = 'โหลดห้องไม่สำเร็จ';
        _isLoadingInitial = false;
      });
    }
  }

  Future<void> _loadInitial() async {
    final channelId = _selectedChannelId;
    if (channelId == null) {
      setState(() => _isLoadingInitial = false);
      return;
    }
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final posts = await widget.clubPostRepository.fetchPosts(
        clubId: widget.club.id,
        channelId: channelId,
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
    final channelId = _selectedChannelId;
    if (channelId == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final posts = await widget.clubPostRepository.fetchPosts(
        clubId: widget.club.id,
        channelId: channelId,
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

  void _selectChannel(String channelId) {
    if (channelId == _selectedChannelId) return;
    setState(() => _selectedChannelId = channelId);
    _loadInitial();
    if (_viewMode == _ClubChannelView.posts) _subscribeUnread(channelId);
  }

  bool _isChannelNameTaken(String name, {String? excludingChannelId}) {
    final channels = _channels ?? const [];
    final lower = name.trim().toLowerCase();
    return channels.any(
      (c) => c.id != excludingChannelId && c.name.trim().toLowerCase() == lower,
    );
  }

  Future<void> _createChannel() async {
    final name = await showClubChannelNameDialog(
      context,
      title: 'สร้างห้องใหม่',
      isNameTaken: _isChannelNameTaken,
    );
    if (name == null) return;
    try {
      final channel =
          await widget.clubRepository.createChannel(clubId: widget.club.id, name: name);
      if (!mounted) return;
      setState(() {
        _channels = [...?_channels, channel];
        _selectedChannelId = channel.id;
      });
      _loadInitial();
      if (_viewMode == _ClubChannelView.posts) _subscribeUnread(channel.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สร้างห้องไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _editChannel(ClubChannel channel) async {
    final name = await showClubChannelNameDialog(
      context,
      title: 'แก้ไขชื่อห้อง',
      initialName: channel.name,
      isNameTaken: (n) => _isChannelNameTaken(n, excludingChannelId: channel.id),
    );
    if (name == null || name == channel.name) return;
    try {
      await widget.clubRepository.renameChannel(channelId: channel.id, name: name);
      if (!mounted) return;
      setState(() {
        _channels = _channels
            ?.map((c) => c.id == channel.id
                ? ClubChannel(
                    id: c.id,
                    clubId: c.clubId,
                    name: name,
                    createdBy: c.createdBy,
                    createdAt: c.createdAt,
                  )
                : c)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('แก้ไขชื่อห้องไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _deleteChannel(ClubChannel channel) async {
    final deleted = await showDeleteClubChannelDialog(
      context,
      channelName: channel.name,
      onConfirm: () => widget.clubRepository.deleteChannel(channel.id),
    );
    if (!deleted || !mounted) return;
    setState(() {
      _channels = _channels?.where((c) => c.id != channel.id).toList();
      _unreadCounts = {..._unreadCounts}..remove(channel.id);
      if (_selectedChannelId == channel.id) {
        final remaining = _channels;
        _selectedChannelId =
            remaining != null && remaining.isNotEmpty ? remaining.first.id : null;
      }
    });
    _loadInitial();
    final newChannelId = _selectedChannelId;
    if (newChannelId != null && _viewMode == _ClubChannelView.posts) {
      _subscribeUnread(newChannelId);
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
        ),
      ),
    );
    _loadInitial();
  }

  String? get _selectedChannelName {
    final channelId = _selectedChannelId;
    final channels = _channels;
    if (channelId == null || channels == null) return null;
    for (final channel in channels) {
      if (channel.id == channelId) return channel.name;
    }
    return null;
  }

  Future<void> _openCreatePost() async {
    final channelId = _selectedChannelId;
    if (channelId == null) return;
    final channelName = _selectedChannelName ?? '';
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateClubPostScreen(
          clubPostRepository: widget.clubPostRepository,
          club: widget.club,
          channelId: channelId,
          channelName: channelName,
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
      body: Column(
        children: [
          _buildChannelSwitcher(),
          if (_channels != null) _buildViewToggle(),
          Expanded(
            child: _viewMode == _ClubChannelView.chat ? _buildChatView() : _buildBody(),
          ),
        ],
      ),
      floatingActionButton: _viewMode == _ClubChannelView.posts
          ? FloatingActionButton(
              backgroundColor: WynColors.sapphire,
              foregroundColor: WynColors.paper,
              onPressed: _selectedChannelId == null ? null : _openCreatePost,
              tooltip: 'สร้างโพสต์',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// WYN-128 -- Design's recommended "toggle เล็กๆ 'โพสต์ | แชท' ใต้แถบ
  /// channel". The "แชท" segment carries the current channel's unread
  /// badge (Requirement 6).
  Widget _buildViewToggle() {
    final channelId = _selectedChannelId;
    final unread = channelId == null ? 0 : (_unreadCounts[channelId] ?? 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space4, 0, WynSpacing.space4, WynSpacing.space2,
      ),
      child: SegmentedButton<_ClubChannelView>(
        style: SegmentedButton.styleFrom(
          selectedForegroundColor: WynColors.paper,
          selectedBackgroundColor: WynColors.sapphire,
          foregroundColor: WynColors.ink,
          side: const BorderSide(color: WynColors.hairline),
        ),
        segments: [
          const ButtonSegment(value: _ClubChannelView.posts, label: Text('โพสต์')),
          ButtonSegment(
            value: _ClubChannelView.chat,
            label: Badge(
              label: Text('$unread'),
              isLabelVisible: unread > 0,
              child: const Text('แชท'),
            ),
          ),
        ],
        selected: {_viewMode},
        onSelectionChanged: (selection) => _setViewMode(selection.first),
      ),
    );
  }

  Widget _buildChatView() {
    final channelId = _selectedChannelId;
    final channelName = _selectedChannelName;
    if (channelId == null || channelName == null) {
      return const SizedBox.shrink();
    }
    return ClubChannelChatView(
      key: ValueKey('club-chat-$channelId'),
      repository: _clubChannelChatRepository,
      clubRepository: widget.clubRepository,
      clubId: widget.club.id,
      channelId: channelId,
      channelName: channelName,
      myRole: widget.myRole,
      onBanned: _onBanned,
    );
  }

  Widget _buildChannelSwitcher() {
    final channels = _channels;
    if (channels == null) {
      // Reserves the same height as the loaded switcher so the feed
      // below doesn't jump once channels resolve.
      return const SizedBox(height: WynSpacing.touchTargetMin + WynSpacing.space2 * 2);
    }
    if (_channelsError != null) {
      return Padding(
        padding: const EdgeInsets.all(WynSpacing.space3),
        child: Row(
          children: [
            Expanded(child: Text(_channelsError!)),
            TextButton(onPressed: _loadChannelsThenPosts, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }
    return ClubChannelSwitcher(
      channels: channels,
      selectedChannelId: _selectedChannelId,
      canManage: _canManageChannels,
      onSelect: _selectChannel,
      onCreate: _createChannel,
      onEdit: _editChannel,
      onDelete: _deleteChannel,
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

    if (_posts.isEmpty) {
      return const Center(child: Text('ยังไม่มีโพสต์ใน Club นี้ เป็นคนแรกสิ!'));
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        // A hairline divider between posts, same as Home Feed (DS-003) --
        // never before the loading spinner. See that screen's identical
        // comment for why Divider() alone (no color) is correct here.
        separatorBuilder: (context, index) =>
            index + 1 < _posts.length ? const Divider(height: 1) : const SizedBox.shrink(),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final post = _posts[index];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index == 0 && post.pinned)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.push_pin, size: 14, color: Theme.of(context).colorScheme.outline),
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
    );
  }
}
