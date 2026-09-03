import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../drop/data/drop_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../saved/data/saved_repository.dart';
import '../data/follow_repository.dart';
import '../data/follow_request_repository.dart';
import 'widgets/follow_action_button.dart';

enum FollowListMode { followers, following }

/// Screen 3 -- Followers / Following list. Restyled to 14-followers.tsx:
/// one screen with both lists reachable via a "ผู้ติดตาม"/"กำลังติดตาม"
/// tab pair (rather than two separately-pushed screens) plus a real
/// search box that filters whichever tab's already-loaded page is
/// showing, and a header that names the profile being looked at (matching
/// the mockup's own header, which reads "ZEN" -- the profile owner's
/// name -- not a generic "ผู้ติดตาม" title). Each tab keeps its own
/// independent pagination state and only loads on first visit, so
/// switching tabs back and forth doesn't re-fetch.
///
/// Every row shows the shared [FollowActionButton] (same 3-state Follow/
/// กำลังติดตาม/ขอติดตามแล้ว widget Search's Discovery page and
/// ViewProfileScreen already use) -- new, real functionality the old
/// screen never had (rows were view-only). The one exception: WYN-039's
/// "ลบ" (remove follower) row, kept exactly as it already was --
/// unchanged behavior/tests -- since it's a real, already-shipped
/// capability specific to your own Followers tab that the mockup's own
/// generic person-row template has no room to depict alongside a Follow
/// button; showing both raises no functional conflict (you can follow
/// someone back *and* separately remove them as a follower), so "ลบ"
/// simply takes the follow button's place on that one tab instead of a
/// second button being added to an already-tight row.
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
    this.followRequestRepository,
  });

  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final String userId;
  final FollowListMode mode;

  /// Optional/defaulted to Supabase.instance.client when omitted, same
  /// shape as every other repository this app threads through
  /// optionally -- needed only by each row's [FollowActionButton].
  final FollowRequestRepository? followRequestRepository;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

/// Per-tab pagination state -- kept separate for [FollowListMode.followers]
/// and [FollowListMode.following] so switching tabs doesn't disturb the
/// other one's already-loaded page/scroll position.
class _TabState {
  final List<Profile> profiles = [];
  int page = 0;
  bool isLoadingInitial = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  bool hasLoadedOnce = false;
  String? error;
}

class _FollowListScreenState extends State<FollowListScreen> {
  late final FollowRequestRepository _followRequestRepository =
      widget.followRequestRepository ??
          FollowRequestRepository(Supabase.instance.client);

  late FollowListMode _selectedMode = widget.mode;
  final Map<FollowListMode, _TabState> _tabs = {
    FollowListMode.followers: _TabState(),
    FollowListMode.following: _TabState(),
  };
  final _scrollController = ScrollController();
  final Set<String> _removingIds = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';

  String? _ownerDisplayName;

  // WYN-039 Requirement 3 ("Remove Follower") -- the remove action only
  // ever makes sense on your *own* Followers list (not Following, and
  // not someone else's Followers list, which the RLS DELETE policy
  // would reject anyway -- this just keeps the button from ever
  // appearing somewhere it can't work).
  bool get _isOwnFollowersList =>
      _selectedMode == FollowListMode.followers &&
      widget.userId == Supabase.instance.client.auth.currentUser!.id;

  _TabState get _activeTab => _tabs[_selectedMode]!;

  List<Profile> get _visibleProfiles {
    final all = _activeTab.profiles;
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all
        .where((p) =>
            p.nameOrUsername.toLowerCase().contains(q) ||
            p.username.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadOwnerName();
    _loadTab(_selectedMode, initial: true);
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

  Future<void> _loadOwnerName() async {
    try {
      final profile = await widget.profileRepository.fetchProfile(widget.userId);
      if (mounted) setState(() => _ownerDisplayName = profile.nameOrUsername);
    } catch (_) {
      // Silent -- same posture as every other identity-summary fetch in
      // this codebase (SideMenu's own profile load). The list itself
      // still works; only the header's name is blank.
    }
  }

  void _selectTab(FollowListMode mode) {
    if (mode == _selectedMode) return;
    setState(() => _selectedMode = mode);
    if (!_tabs[mode]!.hasLoadedOnce) _loadTab(mode, initial: true);
  }

  Future<List<Profile>> _fetchPage(FollowListMode mode, int page) {
    return mode == FollowListMode.followers
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
    final tab = _activeTab;
    if (tab.isLoadingMore || !tab.hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore(_selectedMode);
    }
  }

  Future<void> _loadTab(FollowListMode mode, {required bool initial}) async {
    final tab = _tabs[mode]!;
    setState(() {
      tab.isLoadingInitial = true;
      tab.error = null;
    });
    try {
      final profiles = await _fetchPage(mode, 0);
      if (!mounted) return;
      setState(() {
        tab.profiles
          ..clear()
          ..addAll(profiles);
        tab.page = 0;
        tab.hasMore = profiles.length == FollowRepository.pageSize;
        tab.hasLoadedOnce = true;
      });
    } catch (_) {
      if (mounted) setState(() => tab.error = 'โหลดรายชื่อไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => tab.isLoadingInitial = false);
    }
  }

  Future<void> _loadMore(FollowListMode mode) async {
    final tab = _tabs[mode]!;
    setState(() => tab.isLoadingMore = true);
    try {
      final nextPage = tab.page + 1;
      final profiles = await _fetchPage(mode, nextPage);
      if (!mounted) return;
      setState(() {
        tab.profiles.addAll(profiles);
        tab.page = nextPage;
        tab.hasMore = profiles.length == FollowRepository.pageSize;
      });
    } catch (_) {
      // Silent: an infinite-scroll load-more failure doesn't need a
      // blocking error state -- scrolling again just retries it.
    } finally {
      if (mounted) setState(() => tab.isLoadingMore = false);
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

  Future<void> _removeFollower(Profile profile) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('เอา ${profile.nameOrUsername} ออกจากผู้ติดตาม?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('เอาออก'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted || _removingIds.contains(profile.id)) return;

    setState(() => _removingIds.add(profile.id));
    try {
      await widget.followRepository.removeFollower(followerId: profile.id);
      if (!mounted) return;
      setState(() => _tabs[FollowListMode.followers]!
          .profiles
          .removeWhere((p) => p.id == profile.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _removingIds.remove(profile.id));
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
          _ownerDisplayName ?? '',
          style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: Column(
        children: [
          _buildTabs(),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WynColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTab(FollowListMode.followers, 'ผู้ติดตาม')),
          Expanded(child: _buildTab(FollowListMode.following, 'กำลังติดตาม')),
        ],
      ),
    );
  }

  Widget _buildTab(FollowListMode mode, String label) {
    final selected = _selectedMode == mode;
    return InkWell(
      onTap: () => _selectTab(mode),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: _textStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? WynColors.ink : WynColors.mutedNeutral,
              ),
            ),
          ),
          Container(
            height: 2,
            width: 30,
            color: selected ? WynColors.sapphire : Colors.transparent,
          ),
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
          color: const Color(0xFFF1EFE9),
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
    final tab = _activeTab;

    if (tab.isLoadingInitial && tab.profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tab.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tab.error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(
              onPressed: () => _loadTab(_selectedMode, initial: true),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (tab.profiles.isEmpty) {
      final emptyText = _selectedMode == FollowListMode.followers
          ? 'ยังไม่มีใครติดตามคุณเลย'
          // WYN-102: was "...โพสต์หรือ Pop ที่ชอบดูสิ" -- Pop is hidden.
          : 'คุณยังไม่ได้ติดตามใครเลย ลองกดติดตามจากโพสต์ที่ชอบดูสิ';
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Text(emptyText, textAlign: TextAlign.center),
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

    return RefreshIndicator(
      onRefresh: () => _loadTab(_selectedMode, initial: true),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: visible.length + (tab.hasMore && _searchQuery.isEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= visible.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildRow(visible[index]);
        },
      ),
    );
  }

  Widget _buildRow(Profile profile) {
    return Semantics(
      label:
          'ผู้ใช้ ${profile.nameOrUsername} ยูสเซอร์เนม ${profile.username} กดเพื่อดูโปรไฟล์',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _openProfile(profile),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: WynSpacing.space6, vertical: WynSpacing.space2),
          child: Row(
            children: [
              AvatarCircle(
                imageUrl: profile.avatarUrl,
                fallbackText: profile.username,
                radius: 21,
                ring: true,
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
              if (_isOwnFollowersList)
                if (_removingIds.contains(profile.id))
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  OutlinedButton(
                    onPressed: () => _removeFollower(profile),
                    child: const Text('ลบ'),
                  )
              else
                FollowActionButton(
                  profile: profile,
                  followRepository: widget.followRepository,
                  followRequestRepository: _followRequestRepository,
                  compact: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) =>
    TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
