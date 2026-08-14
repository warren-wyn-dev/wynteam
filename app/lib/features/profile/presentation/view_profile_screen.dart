import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../club/data/club.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/club_page.dart';
import '../../club/presentation/widgets/club_mini_card.dart';
import '../../drop/data/drop_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../follow/presentation/follow_list_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'edit_profile_screen.dart';
import 'widgets/avatar_circle.dart';
import 'widgets/profile_drop_grid_tab.dart';
import 'widgets/profile_pop_grid_tab.dart';
import 'widgets/profile_saved_tab.dart';

typedef _ProfileWithCounts = ({Profile profile, int followerCount, int followingCount});

/// Screen 1 — View Profile. Doubles as both personas WYN-013 needs (the
/// current user's own profile, or someone else's) rather than being two
/// separate screens -- only the header actions/tab count differ. See
/// .wyn/docs/design/wyn-003-user-profile.md, wyn-008-follow.md (Screen 4),
/// wyn-013-profile-v2.md (Screen 1-2).
class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({
    super.key,
    required this.profileRepository,
    required this.followRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.savedRepository,
    required this.userId,
    this.clubRepository,
    this.clubPostRepository,
  });

  final ProfileRepository profileRepository;
  final FollowRepository followRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final String userId;

  // Optional (unlike every other repository here): the "My Clubs"
  // section (WYN-015) only ever shows for the viewer's own profile, and
  // ViewProfileScreen is only ever opened as *your own* profile from
  // RootShell's Profile tab -- every other call site (tap-to-profile
  // from a Drop/Pop, a Follow list row, a Search result) opens someone
  // *else's* profile, where the section wouldn't render anyway even if
  // these were supplied. Making them optional avoids threading Club
  // repositories through every one of those unrelated call sites just
  // for a feature that would never actually use them there.
  final ClubRepository? clubRepository;
  final ClubPostRepository? clubPostRepository;

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  late Future<_ProfileWithCounts> _loadFuture;

  // Whether the *current viewer* follows this profile's owner -- null
  // until the real status has loaded. Only relevant (and only loaded)
  // when this isn't the viewer's own profile. See
  // DropDetailScreen._isFollowing (WYN-008) for why this stays hidden
  // rather than defaulting to false.
  bool? _isFollowing;

  // Only ever loaded for the viewer's own profile with a ClubRepository
  // supplied -- see ClubRepository's doc comment on ViewProfileScreen.
  Future<List<Club>>? _myClubsFuture;

  bool get _isOwnProfile =>
      widget.userId == Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
    if (!_isOwnProfile) _loadFollowStatus();
    final clubRepository = widget.clubRepository;
    if (_isOwnProfile && clubRepository != null) {
      _myClubsFuture = clubRepository.fetchMyClubs();
    }
  }

  // Profile and Follower/Following counts are loaded together as one
  // future so there's a single loading state, not counts appearing in a
  // separate flicker after the profile itself. See
  // .wyn/docs/design/wyn-008-follow.md, Screen 4.
  Future<_ProfileWithCounts> _load() async {
    final profile = await widget.profileRepository.fetchProfile(widget.userId);
    final followerCount =
        await widget.followRepository.countFollowers(userId: widget.userId);
    final followingCount =
        await widget.followRepository.countFollowing(userId: widget.userId);
    return (
      profile: profile,
      followerCount: followerCount,
      followingCount: followingCount,
    );
  }

  void _reload() {
    setState(() => _loadFuture = _load());
  }

  Future<void> _loadFollowStatus() async {
    try {
      final isFollowing =
          await widget.followRepository.isFollowing(userId: widget.userId);
      if (!mounted) return;
      setState(() => _isFollowing = isFollowing);
    } catch (_) {
      // Leave _isFollowing null -- the button stays hidden rather than
      // showing a possibly-wrong state.
    }
  }

  Future<void> _toggleFollow() async {
    final previous = _isFollowing;
    if (previous == null) return;
    setState(() => _isFollowing = !previous);
    try {
      await widget.followRepository.toggleFollow(
        userId: widget.userId,
        currentlyFollowing: previous,
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFollowing = previous);
    }
  }

  Future<void> _openEdit(Profile profile) async {
    await Navigator.of(context).push<Profile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profileRepository: widget.profileRepository,
          profile: profile,
        ),
      ),
    );
    _reload();
  }

  void _openClub(Club club) {
    final clubRepository = widget.clubRepository;
    final clubPostRepository = widget.clubPostRepository;
    if (clubRepository == null || clubPostRepository == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPage(
          clubRepository: clubRepository,
          clubPostRepository: clubPostRepository,
          clubId: club.id,
        ),
      ),
    );
  }

  Future<void> _openFollowList(FollowListMode mode) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: widget.userId,
          mode: mode,
        ),
      ),
    );
  }

  /// "Club ของฉัน" (WYN-015, Screen 4) -- a compact horizontal row of
  /// ClubMiniCard, reused directly from Home's CLUB section (WYN-014).
  /// Unlike that section, this one renders nothing at all (no label, no
  /// empty-state message) when the user hasn't joined any Club --
  /// Profile isn't the app's entry point for encouraging Club creation/
  /// discovery the way Home is, so an empty section here would just be
  /// dead space. See .wyn/docs/design/wyn-015-club-discovery-integration.md,
  /// Screen 4.
  Widget _buildMyClubsSection() {
    final future = _myClubsFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<List<Club>>(
      future: future,
      builder: (context, snapshot) {
        final clubs = snapshot.data;
        if (clubs == null || clubs.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'Club ของฉัน',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: clubs.length,
                  itemBuilder: (context, index) {
                    final club = clubs[index];
                    return ClubMiniCard(club: club, onTap: () => _openClub(club));
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = _isOwnProfile;

    return DefaultTabController(
      length: isOwnProfile ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('โปรไฟล์'),
          actions: [
            if (isOwnProfile)
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'ออกจากระบบ',
                onPressed: () => Supabase.instance.client.auth.signOut(),
              ),
          ],
        ),
        body: FutureBuilder<_ProfileWithCounts>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('โหลดโปรไฟล์ไม่สำเร็จ'),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _reload, child: const Text('ลองใหม่')),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final profile = data.profile;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      AvatarCircle(
                        imageUrl: profile.avatarUrl,
                        fallbackText: profile.username,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile.nameOrUsername,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${profile.username}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(profile.bio!, textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FollowCountTarget(
                            count: data.followerCount,
                            label: 'ผู้ติดตาม',
                            onTap: () => _openFollowList(FollowListMode.followers),
                          ),
                          const SizedBox(width: 24),
                          _FollowCountTarget(
                            count: data.followingCount,
                            label: 'กำลังติดตาม',
                            onTap: () => _openFollowList(FollowListMode.following),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (isOwnProfile)
                        OutlinedButton(
                          onPressed: () => _openEdit(profile),
                          child: const Text('แก้ไขโปรไฟล์'),
                        )
                      else if (_isFollowing != null)
                        Semantics(
                          label: _isFollowing!
                              ? 'กำลังติดตาม กดเพื่อเลิกติดตาม'
                              : 'กดเพื่อติดตาม',
                          excludeSemantics: true,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            onPressed: _toggleFollow,
                            child: Text(_isFollowing! ? 'กำลังติดตาม' : 'ติดตาม'),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildMyClubsSection(),
                TabBar(
                  tabs: [
                    const Tab(icon: Icon(Icons.grid_view_outlined), text: 'Drop'),
                    const Tab(icon: Icon(Icons.play_circle_outline), text: 'Pop'),
                    if (isOwnProfile)
                      const Tab(icon: Icon(Icons.bookmark_border), text: 'บันทึก'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ProfileDropGridTab(
                        dropRepository: widget.dropRepository,
                        followRepository: widget.followRepository,
                        profileRepository: widget.profileRepository,
                        popRepository: widget.popRepository,
                        savedRepository: widget.savedRepository,
                        authorId: widget.userId,
                        emptyText: isOwnProfile
                            ? 'ยังไม่มี Drop เลย'
                            : '${profile.nameOrUsername} ยังไม่มี Drop เลย',
                      ),
                      ProfilePopGridTab(
                        popRepository: widget.popRepository,
                        followRepository: widget.followRepository,
                        profileRepository: widget.profileRepository,
                        dropRepository: widget.dropRepository,
                        savedRepository: widget.savedRepository,
                        authorId: widget.userId,
                        emptyText: isOwnProfile
                            ? 'ยังไม่มี Pop เลย'
                            : '${profile.nameOrUsername} ยังไม่มี Pop เลย',
                      ),
                      if (isOwnProfile)
                        ProfileSavedTab(
                          savedRepository: widget.savedRepository,
                          dropRepository: widget.dropRepository,
                          popRepository: widget.popRepository,
                          followRepository: widget.followRepository,
                          profileRepository: widget.profileRepository,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FollowCountTarget extends StatelessWidget {
  const _FollowCountTarget({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count $label',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
