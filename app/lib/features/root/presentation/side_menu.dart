import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/my_clubs_screen.dart';
import '../../drop/data/drop_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../saved/data/saved_repository.dart';
import '../../saved/presentation/bookmarks_screen.dart';

/// 10-side-menu.tsx -- the drawer opened by the ☰ icon (currently only
/// wired up from Notifications; see home_feed_screen.dart's own doc
/// comment on why Home no longer owns a top row to put one in). A real
/// Flutter `Drawer` gives the "slides in over a dimmed screen" behavior
/// the reference describes for free, rather than a hand-built overlay.
///
/// Real destinations, no placeholders: identity block and "โปรไฟล์" both
/// open the viewer's own [ViewProfileScreen] (same screen -- an entry
/// point, not a duplicate profile, per the reference's own design note),
/// "Club ของฉัน" opens the existing [MyClubsScreen], and "บันทึกไว้" opens
/// the same [BookmarksScreen] [ViewProfileScreen]'s own `_openSaved`
/// already pushes.
///
/// No verified badge or follower/following counts of "0" placeholders --
/// counts are fetched for real ([FollowRepository.countFollowers]/
/// [countFollowing]); "verified" has no field anywhere in the real
/// [Profile] model (confirmed -- grepped the whole app), so it's omitted
/// entirely rather than hardcoded, per SPEC.md's "keep the app's real
/// data" rule. No logout row -- WYN-071 already moved that to Settings,
/// same as this reference file's own doc comment says.
class SideMenu extends StatefulWidget {
  const SideMenu({
    super.key,
    required this.profileRepository,
    required this.followRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.savedRepository,
    required this.clubRepository,
    required this.clubPostRepository,
  });

  final ProfileRepository profileRepository;
  final FollowRepository followRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  late final String _userId = Supabase.instance.client.auth.currentUser!.id;

  Profile? _profile;
  int? _followerCount;
  int? _followingCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.profileRepository.fetchProfile(_userId),
        widget.followRepository.countFollowers(userId: _userId),
        widget.followRepository.countFollowing(userId: _userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Profile;
        _followerCount = results[1] as int;
        _followingCount = results[2] as int;
      });
    } catch (_) {
      // Silent -- same posture as every other identity-summary fetch in
      // this codebase (e.g. HomeFeedScreen's own chat-badge count): a
      // failed count/profile fetch just leaves the identity block blank
      // rather than blocking the whole drawer with an error state.
    }
  }

  void _openOwnProfile() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: _userId,
        ),
      ),
    );
  }

  void _openMyClubs() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyClubsScreen(
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
        ),
      ),
    );
  }

  // 15-bookmarks.tsx: mirrors ViewProfileScreen._openSaved exactly --
  // both push the same real [BookmarksScreen] destination.
  void _openSaved() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookmarksScreen(
          savedRepository: widget.savedRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Drawer(
      backgroundColor: WynColors.paper,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, size: 20, color: WynColors.graphite),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'ปิด',
              ),
            ),
            InkWell(
              onTap: profile == null ? null : _openOwnProfile,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(WynSpacing.space4, 0,
                    WynSpacing.space4, WynSpacing.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AvatarCircle(
                      imageUrl: profile?.avatarUrl,
                      fallbackText: profile?.username ?? '',
                      radius: 26,
                      ring: true,
                    ),
                    const SizedBox(width: WynSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.nameOrUsername ?? '',
                            style: _textStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, color: WynColors.ink),
                          ),
                          if (profile != null)
                            Text(
                              '@${profile.username}',
                              style: _textStyle(fontSize: 12.5, color: WynColors.mutedNeutral),
                            ),
                          const SizedBox(height: WynSpacing.space1),
                          // Wrap, not Row -- the drawer's fixed Material
                          // width (~304dp) leaves this column narrower
                          // than "N ผู้ติดตาม" + "N กำลังติดตาม" can
                          // always fit side by side (confirmed by a real
                          // RenderFlex overflow with realistic counts);
                          // wrapping to a second line degrades gracefully
                          // instead of clipping/overflowing.
                          Wrap(
                            spacing: WynSpacing.space3,
                            runSpacing: 2,
                            children: [
                              _CountLabel(count: _followerCount, label: 'ผู้ติดตาม'),
                              _CountLabel(count: _followingCount, label: 'กำลังติดตาม'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.chevron_right, size: 16, color: WynColors.faint),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: WynColors.hairline),
            const SizedBox(height: WynSpacing.space2),
            _MenuRow(icon: Icons.person_outline, label: 'โปรไฟล์', onTap: _openOwnProfile),
            _MenuRow(icon: Icons.groups_outlined, label: 'Club ของฉัน', onTap: _openMyClubs),
            _MenuRow(icon: Icons.bookmark_border, label: 'บันทึกไว้', onTap: _openSaved),
          ],
        ),
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.count, required this.label});

  final int? count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${count ?? 0} ',
            style: _textStyle(fontSize: 12, fontWeight: FontWeight.w700, color: WynColors.ink),
          ),
          TextSpan(
            text: label,
            style: _textStyle(fontSize: 12, color: WynColors.graphite),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space4, vertical: WynSpacing.space3),
        child: Row(
          children: [
            Icon(icon, size: 19, color: WynColors.ink),
            const SizedBox(width: WynSpacing.space3),
            Text(
              label,
              style: _textStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: WynColors.ink),
            ),
          ],
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
