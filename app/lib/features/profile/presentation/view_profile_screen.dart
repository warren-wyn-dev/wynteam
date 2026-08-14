import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../follow/data/follow_repository.dart';
import '../../follow/presentation/follow_list_screen.dart';
import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'edit_profile_screen.dart';
import 'widgets/avatar_circle.dart';

typedef _ProfileWithCounts = ({Profile profile, int followerCount, int followingCount});

/// Screen 1 — View Profile (own).
/// See .wyn/docs/design/wyn-003-user-profile.md, wyn-008-follow.md (Screen 4)
class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({
    super.key,
    required this.profileRepository,
    required this.followRepository,
    required this.userId,
  });

  final ProfileRepository profileRepository;
  final FollowRepository followRepository;
  final String userId;

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  late Future<_ProfileWithCounts> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
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

  Future<void> _openFollowList(FollowListMode mode) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          followRepository: widget.followRepository,
          userId: widget.userId,
          mode: mode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์'),
        actions: [
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

          return SafeArea(
            child: Padding(
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
                  OutlinedButton(
                    onPressed: () => _openEdit(profile),
                    child: const Text('แก้ไขโปรไฟล์'),
                  ),
                ],
              ),
            ),
          );
        },
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
