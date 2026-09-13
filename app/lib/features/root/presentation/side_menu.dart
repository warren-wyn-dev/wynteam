import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/pwa/open_in_new_tab.dart';
import '../../../core/pwa/pwa_install_hint.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/create_club_screen.dart';
import '../../club/presentation/explore_clubs_screen.dart';
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

/// 10-side-menu.tsx -- the drawer opened by the ☰ icon, wired up from
/// both Notifications and Home (WYN-100). A real Flutter `Drawer` gives
/// the "slides in over a dimmed screen" behavior the reference describes
/// for free, rather than a hand-built overlay.
///
/// Real destinations, no placeholders: the identity block opens the
/// viewer's own [ViewProfileScreen], "สำรวจ Club" opens the existing
/// [ExploreClubsScreen], "สร้าง Club" opens the existing
/// [CreateClubScreen] (WYN-100 -- the create-Club flow itself already
/// existed in full since WYN-014, this just adds the shortcut), "Club
/// ของฉัน" opens the existing [MyClubsScreen], and "บันทึกไว้" opens the
/// same [BookmarksScreen] [ViewProfileScreen]'s own `_openSaved` already
/// pushes.
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

  // WYN-100: shortcut into the create-Club flow that already existed in
  // full since WYN-014 -- mirrors _openMyClubs exactly (pop-then-push).
  void _openCreateClub() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateClubScreen(
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
        ),
      ),
    );
  }

  void _openExploreClubs() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExploreClubsScreen(
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
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

  // Opens the static "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" step-by-step guide page
  // in a new tab -- a permanent fallback for anyone who dismissed the
  // Home feed's AddToHomeScreenBanner (or never saw it) and wants the
  // fuller walkthrough the banner's own inline instructions don't have
  // room for. No push/pop here, unlike every other row: it isn't a
  // Flutter route, it's a separate static page (see openInNewTab's own
  // doc comment), so leaving the drawer open underneath the new tab is
  // the right behavior, not an oversight.
  void _openAddToHomeScreenGuide() {
    openInNewTab('/add-to-home.html');
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
            SizedBox(
              height: 52,
              child: Align(
                alignment: Alignment.centerRight,
                child: BrowserSystemTooltip(
                    message: 'ปิด',
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          size: 22, color: WynColors.ink),
                      onPressed: () => Navigator.of(context).pop(),
                    )),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
              child: Material(
                color: WynColors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: WynColors.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: profile == null ? null : _openOwnProfile,
                  child: Padding(
                    padding: const EdgeInsets.all(WynSpacing.space4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AvatarCircle(
                          imageUrl: profile?.avatarUrl,
                          fallbackText: profile?.username ?? '',
                          radius: 28,
                          ring: true,
                        ),
                        const SizedBox(width: WynSpacing.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BrowserSystemText(
                                profile?.nameOrUsername ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _textStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: WynColors.ink,
                                ),
                              ),
                              if (profile != null)
                                BrowserSystemText(
                                  '@${profile.username}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _textStyle(
                                    fontSize: 13,
                                    color: WynColors.graphite,
                                  ),
                                ),
                              const SizedBox(height: WynSpacing.space2),
                              Wrap(
                                spacing: WynSpacing.space3,
                                runSpacing: 2,
                                children: [
                                  _CountLabel(
                                      count: _followerCount,
                                      label: 'ผู้ติดตาม'),
                                  _CountLabel(
                                      count: _followingCount,
                                      label: 'กำลังติดตาม'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: WynColors.faint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: WynSpacing.space4),
            const Divider(height: 1, color: WynColors.hairline),
            const SizedBox(height: WynSpacing.space2),
            _MenuRow(
              icon: Icons.explore_outlined,
              label: 'สำรวจ Club',
              onTap: _openExploreClubs,
            ),
            _MenuRow(
              icon: Icons.add_circle_outline_rounded,
              label: 'สร้าง Club',
              onTap: _openCreateClub,
            ),
            _MenuRow(
              icon: Icons.groups_outlined,
              label: 'Club ของฉัน',
              onTap: _openMyClubs,
            ),
            _MenuRow(
              icon: Icons.bookmark_border_rounded,
              label: 'บันทึกไว้',
              onTap: _openSaved,
            ),
            if (PwaInstallHint.shouldOfferInstall)
              _MenuRow(
                icon: Icons.add_to_home_screen_rounded,
                label: 'เพิ่ม WYNOS ไว้ที่หน้าจอหลัก',
                onTap: _openAddToHomeScreenGuide,
              ),
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
    return BrowserSystemText.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${count ?? 0} ',
            style: _textStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: WynColors.ink),
          ),
          TextSpan(
            text: label,
            style: _textStyle(fontSize: 13, color: WynColors.graphite),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 54,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: WynColors.surfaceTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 19, color: WynColors.ink),
                  ),
                  const SizedBox(width: WynSpacing.space3),
                  Expanded(
                    child: BrowserSystemText(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _textStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: WynColors.ink,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: WynColors.faint,
                  ),
                ],
              ),
            ),
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
