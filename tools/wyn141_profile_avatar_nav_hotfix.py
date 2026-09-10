from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
profile_path = ROOT / "app/lib/features/profile/presentation/view_profile_screen.dart"
metrics_path = ROOT / "app/lib/core/design/wynos_founder_metrics.dart"
nav_path = ROOT / "app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


profile = profile_path.read_text(encoding="utf-8")

method_start = profile.index(
    "  Widget _buildProfileSliverAppBar(Profile profile, bool isOwnProfile) {"
)
method_end = profile.index("\n  Widget _buildProfileActions({", method_start)
new_method = r'''  Widget _buildProfileCoverBar(Profile profile, bool isOwnProfile) {
    void goBack() {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        widget.onRootBack?.call();
      }
    }

    // The cover and the identity header must live in the same sliver.
    // The avatar intentionally paints 46px upward into this cover; keeping
    // the cover in a separate SliverAppBar clips that overflow at the sliver
    // boundary on real iOS/Web renderers even when the inner Stack uses
    // Clip.none. This fixed-height cover bar preserves the exact visual
    // height/controls while allowing the parent SliverToBoxAdapter to own
    // both paint regions.
    final topInset = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: topInset + WynosFounderMetrics.profileCoverExpandedHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WynosProfileCover(imageUrl: profile.coverUrl),
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            height: kToolbarHeight,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'ย้อนกลับ',
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    size: 32,
                    color: WynColors.paper,
                  ),
                  onPressed: goBack,
                ),
                const Text(
                  'โปรไฟล์',
                  style: TextStyle(
                    color: WynColors.paper,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (isOwnProfile) ...[
                  IconButton(
                    tooltip: 'แชร์โปรไฟล์',
                    icon: const Icon(
                      Icons.ios_share_outlined,
                      size: 24,
                      color: WynColors.paper,
                    ),
                    onPressed: () => _shareProfile(profile),
                  ),
                  IconButton(
                    tooltip: 'ตั้งค่า',
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 27,
                      color: WynColors.paper,
                    ),
                    onPressed: () => _openSettings(profile),
                  ),
                ] else ...[
                  IconButton(
                    tooltip: 'ค้นหา',
                    icon: const Icon(
                      Icons.search_rounded,
                      size: 25,
                      color: WynColors.paper,
                    ),
                    onPressed: _openSearch,
                  ),
                  IconButton(
                    tooltip: 'เพิ่มเติม',
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 24,
                      color: WynColors.paper,
                    ),
                    onPressed: _openMoreMenu,
                  ),
                ],
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
'''
profile = profile[:method_start] + new_method + profile[method_end:]

old_header = r'''                _buildProfileSliverAppBar(profile, isOwnProfile),
                SliverToBoxAdapter(
                  child: WynosFounderProfileHeader(
                    profile: profile,
                    followingCount: data.followingCount,
                    followerCount: data.followerCount,
                    isOwnProfile: isOwnProfile,
                    showStats: !isBlockedEitherWay,
                    showOnline: isOwnProfile,
                    onDisplayNameTap:
                        isOwnProfile ? _openAccountSwitcher : null,
                    onFollowingTap: () => _openFollowList(
                      FollowListMode.following,
                      isLockedPrivate: isLockedPrivate,
                    ),
                    onFollowersTap: () => _openFollowList(
                      FollowListMode.followers,
                      isLockedPrivate: isLockedPrivate,
                    ),
                    actions: _buildProfileActions(
                      profile: profile,
                      isOwnProfile: isOwnProfile,
                      isBlockedEitherWay: isBlockedEitherWay,
                    ),
                    footer: _buildProfileFooter(profile, isOwnProfile),
                  ),
                ),'''
new_header = r'''                // Keep cover + identity in one render box so the avatar's
                // intentional negative overlap is inside this sliver's paint bounds.
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildProfileCoverBar(profile, isOwnProfile),
                      WynosFounderProfileHeader(
                        profile: profile,
                        followingCount: data.followingCount,
                        followerCount: data.followerCount,
                        isOwnProfile: isOwnProfile,
                        showStats: !isBlockedEitherWay,
                        showOnline: isOwnProfile,
                        onDisplayNameTap:
                            isOwnProfile ? _openAccountSwitcher : null,
                        onFollowingTap: () => _openFollowList(
                          FollowListMode.following,
                          isLockedPrivate: isLockedPrivate,
                        ),
                        onFollowersTap: () => _openFollowList(
                          FollowListMode.followers,
                          isLockedPrivate: isLockedPrivate,
                        ),
                        actions: _buildProfileActions(
                          profile: profile,
                          isOwnProfile: isOwnProfile,
                          isBlockedEitherWay: isBlockedEitherWay,
                        ),
                        footer: _buildProfileFooter(profile, isOwnProfile),
                      ),
                    ],
                  ),
                ),'''
profile = replace_once(profile, old_header, new_header, "profile sliver composition")
profile_path.write_text(profile, encoding="utf-8")

metrics = metrics_path.read_text(encoding="utf-8")
metrics = replace_once(
    metrics,
    "  static const double bottomNavContentHeight = 72;",
    "  static const double bottomNavContentHeight = 80;",
    "bottom nav height",
)
metrics_path.write_text(metrics, encoding="utf-8")

nav = nav_path.read_text(encoding="utf-8")
nav = replace_once(
    nav,
    "                        const SizedBox(height: 2),\n                        const Text(\n                          'โพสต์',",
    "                        const SizedBox(height: 6),\n                        const Text(\n                          'โพสต์',",
    "create button label gap",
)
nav_path.write_text(nav, encoding="utf-8")

print("Applied WYN-141 live profile avatar/nav hotfix")
