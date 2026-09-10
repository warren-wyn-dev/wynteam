from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected exactly one match, found {count}: {old[:100]!r}")
    write(path, text.replace(old, new, 1))


def replace_between(path: str, start: str, end: str, replacement: str) -> None:
    text = read(path)
    i = text.find(start)
    if i < 0:
        raise RuntimeError(f"{path}: start marker not found: {start[:100]!r}")
    j = text.find(end, i + len(start))
    if j < 0:
        raise RuntimeError(f"{path}: end marker not found: {end[:100]!r}")
    write(path, text[:i] + replacement + text[j:])


# ---------------------------------------------------------------------------
# Founder-approved screenshot metrics. These are deliberately isolated from
# the legacy DS values so the screenshot-driven surfaces have one source of
# truth and can be visually diffed/tuned without scattering magic numbers.
# ---------------------------------------------------------------------------
write(
    "app/lib/core/design/wynos_founder_metrics.dart",
    r'''class WynosFounderMetrics {
  WynosFounderMetrics._();

  // Profile reference: 864x1536 screenshot, normalized to a 390 logical-px
  // mobile viewport. The SliverAppBar adds the device top inset itself.
  static const double profileCoverExpandedHeight = 108;
  static const double profileAvatarRadius = 42;
  static const double profileAvatarOuterDiameter = 92;
  static const double profileIdentityLeftInset = 120;
  static const double profileActionHeight = 48;
  static const double profileSecondaryActionSize = 48;
  static const double profileTabHeight = 52;

  // Post-detail reference.
  static const double detailEdgeInset = 16;
  static const double detailMediaRadius = 18;
  static const double activityRowHeight = 54;
  static const double commentComposerHeight = 46;

  // Root navigation reference.
  static const double bottomNavContentHeight = 72;
  static const double createActionDiameter = 56;
}
''',
)

# The screenshot explicitly uses a bright online dot. Founder approval of the
# screenshot is the approval for this semantic status token.
replace_once(
    "app/lib/core/design/wyn_colors.dart",
    "  static const Color inkSoft = Color(0xFF2B2A26);\n",
    "  static const Color inkSoft = Color(0xFF2B2A26);\n\n"
    "  /// Founder-approved online-presence dot from the final Profile UI.\n"
    "  static const Color online = Color(0xFF57D65B);\n",
)

# ---------------------------------------------------------------------------
# Profile cover persistence. This is the only schema addition in this visual
# pass, and is necessary because the approved profile screenshot contains a
# real per-user cover rather than a decorative app asset.
# ---------------------------------------------------------------------------
profile_path = "app/lib/features/profile/data/profile.dart"
replace_once(profile_path, "    this.avatarUrl,\n", "    this.avatarUrl,\n    this.coverUrl,\n")
replace_once(
    profile_path,
    "        avatarUrl: map['avatar_url'] as String?,\n",
    "        avatarUrl: map['avatar_url'] as String?,\n        coverUrl: map['cover_url'] as String?,\n",
)
replace_once(profile_path, "  final String? avatarUrl;\n", "  final String? avatarUrl;\n  final String? coverUrl;\n")

repo_path = "app/lib/features/profile/data/profile_repository.dart"
text = read(repo_path)
text = text.replace(
    "id, username, display_name, bio, avatar_url, platform_role",
    "id, username, display_name, bio, avatar_url, cover_url, platform_role",
)
text = text.replace(
    "'id, username, display_name, bio, avatar_url')",
    "'id, username, display_name, bio, avatar_url, cover_url')",
    1,
)
# fetchProfilesByIds has the same full profile select; the global replacement
# above covers it. Search results do not need cover_url just to render rows.
anchor = "  /// Fetches multiple profiles by id in a single query, returning them\n"
if anchor not in text:
    raise RuntimeError("profile_repository.dart: uploadCover insertion anchor missing")
upload_cover = r'''  /// Uploads the approved wide profile cover into the existing public
  /// `avatars` bucket under the owner's folder. Reusing this bucket keeps the
  /// already-deployed owner-folder storage RLS authoritative; only the URL
  /// metadata column is new.
  Future<String> uploadCover({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = '$userId/cover.$fileExtension';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final url =
        '${_client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('profiles').update({'cover_url': url}).eq('id', userId);
    return url;
  }

'''
text = text.replace(anchor, upload_cover + anchor, 1)
write(repo_path, text)

write(
    "supabase/migrations_wyn141_founder_profile_cover.sql",
    r'''-- WYN-141 — Founder final UI: profile cover metadata.
-- The existing public `avatars` bucket is reused; no storage policy changes.

begin;

alter table public.profiles
  add column if not exists cover_url text;

commit;
''',
)

# Keep the executable schema baseline honest for clean-db CI runs.
schema_path = Path("supabase/schema.sql")
schema = schema_path.read_text()
profiles_i = schema.find("create table if not exists public.profiles")
if profiles_i < 0:
    raise RuntimeError("schema.sql: profiles table not found")
next_table = schema.find("create table", profiles_i + 30)
profile_region_end = next_table if next_table >= 0 else len(schema)
profile_region = schema[profiles_i:profile_region_end]
if "cover_url text" not in profile_region:
    avatar_i = schema.find("avatar_url text", profiles_i, profile_region_end)
    if avatar_i < 0:
        raise RuntimeError("schema.sql: profiles.avatar_url declaration not found")
    line_end = schema.find("\n", avatar_i)
    avatar_line = schema[schema.rfind("\n", profiles_i, avatar_i) + 1:line_end]
    indent = avatar_line[: len(avatar_line) - len(avatar_line.lstrip())]
    schema = schema[: line_end + 1] + f"{indent}cover_url text,\n" + schema[line_end + 1:]
schema_path.write_text(schema)

# ---------------------------------------------------------------------------
# Founder final Profile hero/header.
# ---------------------------------------------------------------------------
write(
    "app/lib/features/profile/presentation/widgets/wynos_founder_profile_header.dart",
    r'''import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wynos_founder_metrics.dart';
import '../../data/profile.dart';
import 'avatar_circle.dart';
import 'verified_badge.dart';

class WynosProfileCover extends StatelessWidget {
  const WynosProfileCover({super.key, required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ColoredBox(
      color: WynColors.inkSoft,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _CoverFallback(),
            )
          else
            const _CoverFallback(),
          // Keeps white top-bar controls readable over arbitrary photos,
          // while remaining visually almost invisible over normal covers.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x52000000), Color(0x00000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WynColors.graphite, WynColors.inkSoft],
        ),
      ),
    );
  }
}

/// Pixel-targeted identity/action block for the Founder-approved Profile
/// screenshot. Business behavior remains owned by ViewProfileScreen; this
/// widget only owns composition, proportions and visual hierarchy.
class WynosFounderProfileHeader extends StatelessWidget {
  const WynosFounderProfileHeader({
    super.key,
    required this.profile,
    required this.followingCount,
    required this.followerCount,
    required this.isOwnProfile,
    required this.showStats,
    required this.actions,
    required this.onFollowingTap,
    required this.onFollowersTap,
    this.onDisplayNameTap,
    this.footer,
    this.showOnline = false,
  });

  final Profile profile;
  final int followingCount;
  final int followerCount;
  final bool isOwnProfile;
  final bool showStats;
  final Widget actions;
  final VoidCallback onFollowingTap;
  final VoidCallback onFollowersTap;
  final VoidCallback? onDisplayNameTap;
  final Widget? footer;
  final bool showOnline;

  String get _membershipLabel => switch (profile.platformRole) {
        PlatformRole.admin => 'ผู้ดูแลระบบ',
        PlatformRole.moderator => 'ผู้ดูแล',
        PlatformRole.user => 'สมาชิกทั่วไป',
      };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WynColors.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  WynosFounderMetrics.profileIdentityLeftInset,
                  10,
                  WynSpacing.space4,
                  2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onDisplayNameTap,
                      borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                profile.nameOrUsername,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 21,
                                  height: 1.12,
                                  fontWeight: FontWeight.w700,
                                  color: WynColors.ink,
                                ),
                              ),
                            ),
                            if (profile.isVerified) ...[
                              const SizedBox(width: 4),
                              const VerifiedBadge(),
                            ],
                            if (isOwnProfile) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 22,
                                color: WynColors.ink,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '@${profile.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.1,
                              color: WynColors.graphite,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: WynColors.surfaceTint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _membershipLabel,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1,
                              color: WynColors.graphite,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        profile.bio!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.34,
                          color: WynColors.ink,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: -46,
                left: WynSpacing.space4,
                child: _ProfileAvatar(
                  profile: profile,
                  showOnline: showOnline,
                ),
              ),
            ],
          ),
          if (showStats) ...[
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 72),
              child: Row(
                children: [
                  Expanded(
                    child: _ProfileStat(
                      count: followingCount,
                      label: 'กำลังติดตาม',
                      onTap: onFollowingTap,
                    ),
                  ),
                  const SizedBox(
                    height: 31,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: WynColors.hairline,
                    ),
                  ),
                  Expanded(
                    child: _ProfileStat(
                      count: followerCount,
                      label: 'ผู้ติดตาม',
                      onTap: onFollowersTap,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: actions,
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile, required this.showOnline});

  final Profile profile;
  final bool showOnline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: WynosFounderMetrics.profileAvatarOuterDiameter,
      height: WynosFounderMetrics.profileAvatarOuterDiameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: WynosFounderMetrics.profileAvatarOuterDiameter,
            height: WynosFounderMetrics.profileAvatarOuterDiameter,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: WynColors.paper,
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: AvatarCircle(
              imageUrl: profile.avatarUrl,
              fallbackText: profile.username,
              radius: WynosFounderMetrics.profileAvatarRadius,
            ),
          ),
          if (showOnline)
            Positioned(
              right: 1,
              bottom: 8,
              child: Container(
                width: 19,
                height: 19,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: WynColors.online,
                  border: Border.fromBorderSide(
                    BorderSide(color: WynColors.paper, width: 3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 20,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: WynColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.1,
                color: WynColors.graphite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WynosProfileIconAction extends StatelessWidget {
  const WynosProfileIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: WynosFounderMetrics.profileSecondaryActionSize,
      height: WynosFounderMetrics.profileSecondaryActionSize,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 23, color: WynColors.ink),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: WynColors.hairline),
          ),
          backgroundColor: WynColors.paper,
        ),
      ),
    );
  }
}
''',
)

# ---------------------------------------------------------------------------
# Edit Profile: cover can be selected and uploaded, so the visual feature is
# not a dead display-only surface.
# ---------------------------------------------------------------------------
edit_path = "app/lib/features/profile/presentation/edit_profile_screen.dart"
replace_once(
    edit_path,
    "  String? _pickedImageExtension;\n",
    "  String? _pickedImageExtension;\n  Uint8List? _pickedCoverBytes;\n  String? _pickedCoverExtension;\n",
)
replace_once(
    edit_path,
    "      _pickedImageBytes != null;\n",
    "      _pickedImageBytes != null ||\n      _pickedCoverBytes != null;\n",
)
cover_methods_anchor = "  Future<void> _showImageSourceSheet() {\n"
cover_methods = r'''  Future<void> _pickCoverImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1800,
      maxHeight: 1000,
      imageQuality: 88,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    setState(() {
      _pickedCoverBytes = bytes;
      _pickedCoverExtension = ext == 'png' ? 'png' : 'jpg';
    });
  }

  Future<void> _showCoverImageSourceSheet() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายภาพหน้าปก'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickCoverImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกภาพหน้าปกจากคลังภาพ'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickCoverImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

'''
replace_once(edit_path, cover_methods_anchor, cover_methods + cover_methods_anchor)

replace_once(
    edit_path,
    "      final displayName = _displayNameController.text.trim();\n",
    "      var coverUrl = widget.profile.coverUrl;\n"
    "      if (_pickedCoverBytes != null) {\n"
    "        coverUrl = await widget.profileRepository.uploadCover(\n"
    "          userId: widget.profile.id,\n"
    "          bytes: _pickedCoverBytes!,\n"
    "          fileExtension: _pickedCoverExtension ?? 'jpg',\n"
    "        );\n"
    "      }\n\n"
    "      final displayName = _displayNameController.text.trim();\n",
)
replace_once(
    edit_path,
    "          avatarUrl: avatarUrl,\n",
    "          avatarUrl: avatarUrl,\n          coverUrl: coverUrl,\n",
)

cover_ui_anchor = "              Center(\n                child: GestureDetector(\n                  key: const Key('avatar_edit_button'),\n"
cover_ui = r'''              GestureDetector(
                key: const Key('cover_edit_button'),
                onTap: _isSaving ? null : _showCoverImageSourceSheet,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
                  child: SizedBox(
                    height: 124,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_pickedCoverBytes != null)
                          Image.memory(_pickedCoverBytes!, fit: BoxFit.cover)
                        else if (widget.profile.coverUrl != null &&
                            widget.profile.coverUrl!.isNotEmpty)
                          Image.network(
                            widget.profile.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: WynColors.surfaceTint),
                          )
                        else
                          const ColoredBox(color: WynColors.surfaceTint),
                        const Positioned(
                          right: 10,
                          bottom: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: WynColors.ink,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.photo_camera_outlined,
                                size: 17,
                                color: WynColors.paper,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: WynSpacing.space5),
'''
replace_once(edit_path, cover_ui_anchor, cover_ui + cover_ui_anchor)

# ---------------------------------------------------------------------------
# ViewProfileScreen: swap the legacy identity composition for the exact
# screenshot hierarchy while preserving all follow/block/chat/privacy logic.
# ---------------------------------------------------------------------------
view_path = "app/lib/features/profile/presentation/view_profile_screen.dart"
replace_once(
    view_path,
    "import '../../saved/data/saved_repository.dart';\n",
    "import '../../saved/data/saved_repository.dart';\n"
    "import '../../saved/presentation/bookmarks_screen.dart';\n",
)
replace_once(
    view_path,
    "import 'widgets/avatar_circle.dart';\n",
    "import 'widgets/avatar_circle.dart';\n"
    "import 'widgets/wynos_founder_profile_header.dart';\n",
)
replace_once(
    view_path,
    "import '../../../core/design/wyn_typography.dart';\n",
    "import '../../../core/design/wyn_typography.dart';\n"
    "import '../../../core/design/wynos_founder_metrics.dart';\n",
)
replace_once(
    view_path,
    "    this.followRequestRepository,\n  });\n",
    "    this.followRequestRepository,\n    this.onRootBack,\n  });\n",
)
replace_once(
    view_path,
    "  final FollowRequestRepository? followRequestRepository;\n",
    "  final FollowRequestRepository? followRequestRepository;\n\n"
    "  /// RootShell supplies this so the Founder-approved back affordance on\n"
    "  /// the own-profile root returns to Home instead of becoming a dead icon.\n"
    "  final VoidCallback? onRootBack;\n",
)

# Restore Saved as an explicit icon on the final Founder profile action row.
open_account_anchor = "  Future<void> _openAccountSwitcher() async {\n"
profile_helpers = r'''  void _openSaved() {
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

  Future<void> _shareProfile(Profile profile) {
    return showShareSheet(
      context,
      chatRepository: _chatRepository,
      profileRepository: widget.profileRepository,
      sharedContentType: SharedContentType.profile,
      sharedContentId: widget.userId,
      previewLabel: 'แชร์โปรไฟล์ @${profile.username}',
      nativeShareText: profileShareLink(profile.username),
      nativeShareTitle: profile.displayName ?? '@${profile.username}',
    );
  }

  Future<void> _openSettings(Profile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          platformRole: profile.platformRole,
          isPrivate: profile.isPrivate,
          dmPermission: profile.dmPermission,
          mentionPermission: profile.mentionPermission,
          commentPermission: profile.commentPermission,
          likesVisibility: profile.likesVisibility,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Widget _buildProfileSliverAppBar(Profile profile, bool isOwnProfile) {
    void goBack() {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        widget.onRootBack?.call();
      }
    }

    return SliverAppBar(
      primary: true,
      pinned: false,
      floating: false,
      backgroundColor: WynColors.inkSoft,
      surfaceTintColor: Colors.transparent,
      foregroundColor: WynColors.paper,
      expandedHeight: WynosFounderMetrics.profileCoverExpandedHeight,
      leading: IconButton(
        tooltip: 'ย้อนกลับ',
        icon: const Icon(Icons.chevron_left_rounded, size: 32),
        onPressed: goBack,
      ),
      titleSpacing: 0,
      title: const Text(
        'โปรไฟล์',
        style: TextStyle(
          color: WynColors.paper,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: isOwnProfile
          ? [
              IconButton(
                tooltip: 'แชร์โปรไฟล์',
                icon: const Icon(Icons.ios_share_outlined, size: 24),
                onPressed: () => _shareProfile(profile),
              ),
              IconButton(
                tooltip: 'ตั้งค่า',
                icon: const Icon(Icons.settings_outlined, size: 27),
                onPressed: () => _openSettings(profile),
              ),
              const SizedBox(width: 4),
            ]
          : [
              IconButton(
                tooltip: 'ค้นหา',
                icon: const Icon(Icons.search_rounded, size: 25),
                onPressed: _openSearch,
              ),
              IconButton(
                tooltip: 'เพิ่มเติม',
                icon: const Icon(Icons.more_vert_rounded, size: 24),
                onPressed: _openMoreMenu,
              ),
              const SizedBox(width: 4),
            ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: WynosProfileCover(imageUrl: profile.coverUrl),
      ),
    );
  }

  Widget _buildProfileActions({
    required Profile profile,
    required bool isOwnProfile,
    required bool isBlockedEitherWay,
  }) {
    if (isBlockedEitherWay) return _buildBlockedBanner();

    if (isOwnProfile) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: WynosFounderMetrics.profileActionHeight,
              child: FilledButton.icon(
                onPressed: () => _openEdit(profile),
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('แก้ไขโปรไฟล์'),
                style: FilledButton.styleFrom(
                  backgroundColor: WynColors.ink,
                  foregroundColor: WynColors.paper,
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          WynosProfileIconAction(
            icon: Icons.person_add_alt_1_outlined,
            tooltip: 'ค้นหาเพื่อน',
            onPressed: _openSearch,
          ),
          const SizedBox(width: 10),
          WynosProfileIconAction(
            icon: Icons.bookmark_border_rounded,
            tooltip: 'บันทึกไว้',
            onPressed: _openSaved,
          ),
        ],
      );
    }

    if (_isFollowing == null) {
      return const SizedBox(
        height: WynosFounderMetrics.profileActionHeight,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: WynosFounderMetrics.profileActionHeight,
            child: FilledButton(
              onPressed: _isFollowActionInFlight
                  ? null
                  : () => _onFollowButtonPressed(profile),
              style: FilledButton.styleFrom(
                backgroundColor:
                    _isFollowing! ? WynColors.surfaceTint : WynColors.ink,
                foregroundColor:
                    _isFollowing! ? WynColors.ink : WynColors.paper,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text(_followButtonLabel(profile)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: WynosFounderMetrics.profileActionHeight,
            child: OutlinedButton.icon(
              onPressed: _isStartingChat ? null : () => _openChat(profile),
              icon: _isStartingChat
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 18),
              label: const Text('ส่งข้อความ'),
              style: OutlinedButton.styleFrom(
                foregroundColor: WynColors.ink,
                side: const BorderSide(color: WynColors.hairline),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildProfileFooter(Profile profile, bool isOwnProfile) {
    if (!isOwnProfile || !profile.isPrivate || _pendingRequestCount <= 0) {
      return null;
    }
    return InkWell(
      onTap: _openFollowRequests,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add_alt, size: 18),
            const SizedBox(width: 6),
            Text('คำขอติดตาม ($_pendingRequestCount)'),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

'''
replace_once(view_path, open_account_anchor, profile_helpers + open_account_anchor)

# Scaffold appBar becomes the cover-backed SliverAppBar inside the loaded body.
scaffold_start = "      child: Scaffold(\n        backgroundColor: WynColors.paper,\n        appBar: AppBar(\n"
body_marker = "        body: FutureBuilder<_ProfileWithCounts>(\n"
replace_between(
    view_path,
    scaffold_start,
    body_marker,
    "      child: Scaffold(\n        backgroundColor: WynColors.paper,\n" + body_marker,
)

# Replace the old avatar-left/right-column header sliver only. Everything after
# it (recommendations, pinned tab bar and real tab bodies) remains intact.
old_header_start = "                SliverToBoxAdapter(\n                  child:\n                      // Beta4 §1"
recommendation_marker = "                if (!isOwnProfile)\n                  SliverToBoxAdapter(\n"
new_header = r'''                _buildProfileSliverAppBar(profile, isOwnProfile),
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
                ),
'''
replace_between(view_path, old_header_start, recommendation_marker, new_header + recommendation_marker)

# Final screenshot tabs: icon + Thai label, black active underline.
replace_once(
    view_path,
    "                      indicatorColor: WynColors.sapphire,\n",
    "                      indicatorColor: WynColors.ink,\n",
)
old_tabs = r'''                      tabs: const [
                        Tab(text: 'โพสต์'),
                        Tab(text: 'รีโพสต์'),
                        Tab(text: 'ถูกใจ'),
                        // Pop tab intentionally omitted here -- see the
                        // import comment above (WYNOS V1.0.0 Beta requirement 3).
                      ],
'''
new_tabs = r'''                      tabs: const [
                        Tab(
                          height: WynosFounderMetrics.profileTabHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined, size: 20),
                              SizedBox(width: 7),
                              Text('สื่อ'),
                            ],
                          ),
                        ),
                        Tab(
                          height: WynosFounderMetrics.profileTabHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.repeat_rounded, size: 20),
                              SizedBox(width: 7),
                              Text('รีโพสต์'),
                            ],
                          ),
                        ),
                        Tab(
                          height: WynosFounderMetrics.profileTabHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.favorite_border_rounded, size: 20),
                              SizedBox(width: 7),
                              Text('ถูกใจ'),
                            ],
                          ),
                        ),
                      ],
'''
replace_once(view_path, old_tabs, new_tabs)

# ---------------------------------------------------------------------------
# Bottom navigation: exact 5-slot lightweight layout instead of Material 3's
# pill indicator. Root behavior/indexing remains unchanged.
# ---------------------------------------------------------------------------
write(
    "app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart",
    r'''import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wynos_founder_metrics.dart';

class WynosFounderBottomNavigation extends StatelessWidget {
  const WynosFounderBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.createAction,
    required this.notificationIcon,
    required this.selectedNotificationIcon,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget createAction;
  final Widget notificationIcon;
  final Widget selectedNotificationIcon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WynColors.paper,
        border: Border(top: BorderSide(color: WynColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: SizedBox(
          height: WynosFounderMetrics.bottomNavContentHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Destination(
                  label: 'หน้าหลัก',
                  selected: selectedIndex == 0,
                  icon: selectedIndex == 0
                      ? Icons.home_rounded
                      : Icons.home_outlined,
                  onTap: () => onDestinationSelected(0),
                ),
              ),
              Expanded(
                child: _Destination(
                  label: 'ค้นหา',
                  selected: selectedIndex == 1,
                  icon: Icons.search_rounded,
                  onTap: () => onDestinationSelected(1),
                ),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'สร้างโพสต์ใหม่',
                  child: InkResponse(
                    onTap: () => onDestinationSelected(2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        createAction,
                        const SizedBox(height: 2),
                        const Text(
                          'โพสต์',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1,
                            color: WynColors.graphite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _DestinationWidget(
                  label: 'การแจ้งเตือน',
                  selected: selectedIndex == 3,
                  icon: selectedIndex == 3
                      ? selectedNotificationIcon
                      : notificationIcon,
                  onTap: () => onDestinationSelected(3),
                ),
              ),
              Expanded(
                child: _Destination(
                  label: 'โปรไฟล์',
                  selected: selectedIndex == 4,
                  icon: selectedIndex == 4
                      ? Icons.person_rounded
                      : Icons.person_outline_rounded,
                  onTap: () => onDestinationSelected(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DestinationWidget(
      label: label,
      selected: selected,
      icon: Icon(icon, size: 28),
      onTap: onTap,
    );
  }
}

class _DestinationWidget extends StatelessWidget {
  const _DestinationWidget({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? WynColors.ink : WynColors.graphite;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        child: IconTheme(
          data: IconThemeData(color: color, size: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
''',
)

root_path = "app/lib/features/root/presentation/root_shell.dart"
replace_once(
    root_path,
    "import '../../../core/design/wyn_spacing.dart';\n",
    "import '../../../core/design/wyn_spacing.dart';\n"
    "import '../../../core/design/wyn_colors.dart';\n"
    "import '../../../core/design/wynos_founder_metrics.dart';\n"
    "import 'widgets/wynos_founder_bottom_navigation.dart';\n",
)
replace_once(
    root_path,
    "        userId: userId,\n        clubRepository: _clubRepository,\n        clubPostRepository: _clubPostRepository,\n      ),\n",
    "        userId: userId,\n        clubRepository: _clubRepository,\n        clubPostRepository: _clubPostRepository,\n"
    "        onRootBack: () => _onDestinationSelected(_homeDestinationIndex),\n"
    "      ),\n",
)
old_nav = r'''      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndexForTab[_tabIndex],
        onDestinationSelected: (navIndex) => _onDestinationSelected(navIndex),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: _buildDropAction(),
            selectedIcon: _buildDropAction(),
            label: 'โพสต์',
          ),
          NavigationDestination(
            icon: _buildNotificationsIcon(context, selected: false),
            selectedIcon: _buildNotificationsIcon(context, selected: true),
            label: 'Notifications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
'''
new_nav = r'''      bottomNavigationBar: WynosFounderBottomNavigation(
        selectedIndex: _navIndexForTab[_tabIndex],
        onDestinationSelected: (navIndex) => _onDestinationSelected(navIndex),
        createAction: _buildDropAction(),
        notificationIcon: _buildNotificationsIcon(context, selected: false),
        selectedNotificationIcon:
            _buildNotificationsIcon(context, selected: true),
      ),
'''
replace_once(root_path, old_nav, new_nav)
replace_once(root_path, "          width: 40,\n          height: 40,\n", "          width: WynosFounderMetrics.createActionDiameter,\n          height: WynosFounderMetrics.createActionDiameter,\n")
replace_once(root_path, "            color: scheme.primary,\n", "            color: WynColors.ink,\n")
replace_once(root_path, "                color: scheme.primary.withValues(alpha: 0.35),\n                blurRadius: 16,\n", "                color: WynColors.ink.withValues(alpha: 0.18),\n                blurRadius: 10,\n                offset: const Offset(0, 3),\n")
replace_once(root_path, "          child: Icon(Icons.add, color: scheme.onPrimary),\n", "          child: const Icon(Icons.add_rounded, size: 33, color: WynColors.paper),\n")
# scheme is still used to declare but no longer referenced after the visual
# change; remove it to keep analyze clean.
replace_once(root_path, "    final scheme = Theme.of(context).colorScheme;\n", "")

# Root tests tap visible labels. Keep behavior assertions, update only copy.
root_test = Path("app/test/root_shell_test.dart")
if root_test.exists():
    t = root_test.read_text()
    t = t.replace("find.text('Home')", "find.text('หน้าหลัก')")
    t = t.replace("find.text('Search')", "find.text('ค้นหา')")
    t = t.replace("find.text('Notifications')", "find.text('การแจ้งเตือน')")
    t = t.replace("find.text('Profile')", "find.text('โปรไฟล์')")
    root_test.write_text(t)

# ---------------------------------------------------------------------------
# Post detail: media-led reference layout, metric-bearing action row, real
# activity affordance and rounded iOS-safe comment composer.
# ---------------------------------------------------------------------------
detail_path = "app/lib/features/drop/presentation/drop_detail_screen.dart"
replace_once(
    detail_path,
    "import '../../../core/design/wyn_typography.dart';\n",
    "import '../../../core/design/wyn_typography.dart';\n"
    "import '../../../core/design/wynos_founder_metrics.dart';\n",
)
old_gallery = r'''        else if (_drop.imageUrl != null)
          DropImageGallery(
            drop: _drop,
            dropRepository: widget.dropRepository,
            onLike: _toggleLike,
            onDropChanged: (updated) => setState(() => _drop = updated),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WynSpacing.space4, WynSpacing.space3, WynSpacing.space4, WynSpacing.space2,
          ),
          child: _buildStatLine(),
        ),
        _buildFocusedActionBar(),
'''
new_gallery = r'''        else if (_drop.imageUrl != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WynosFounderMetrics.detailEdgeInset,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                WynosFounderMetrics.detailMediaRadius,
              ),
              child: DropImageGallery(
                drop: _drop,
                dropRepository: widget.dropRepository,
                onLike: _toggleLike,
                onDropChanged: (updated) => setState(() => _drop = updated),
              ),
            ),
          ),
        const SizedBox(height: 7),
        _buildFocusedActionBar(),
        _buildActivityRow(),
'''
replace_once(detail_path, old_gallery, new_gallery)

methods_start = "  /// 07-post-detail.tsx: engagement shown as a plain-language stat line\n"
comment_marker = "  Widget _buildCommentRow(DropComment comment, String currentUserId, {required bool isReply}) {\n"
new_detail_methods = r'''  Widget _detailAction({
    required Widget icon,
    required String semanticsLabel,
    required VoidCallback? onPressed,
    int? count,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        label: semanticsLabel,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onPressed,
          radius: 25,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                if (count != null) ...[
                  const SizedBox(width: 7),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1,
                      color: WynColors.graphite,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFocusedActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _detailAction(
            icon: WynStatePop(
              state: _drop.likedByMe,
              child: WynHeartIcon(
                filled: _drop.likedByMe,
                size: 26,
                color: _drop.likedByMe
                    ? WynColors.iconLikeActive
                    : WynColors.ink,
              ),
            ),
            count: _drop.likeCount,
            semanticsLabel: _drop.likedByMe
                ? 'ถูกใจแล้ว ${_drop.likeCount} คน กดเพื่อเลิกถูกใจ'
                : 'ถูกใจ ${_drop.likeCount} คน กดเพื่อถูกใจ',
            onPressed: _toggleLike,
          ),
          _detailAction(
            icon: const Icon(
              Icons.mode_comment_outlined,
              size: 25,
              color: WynColors.ink,
            ),
            count: _drop.commentCount,
            semanticsLabel: 'ความคิดเห็น ${_drop.commentCount} รายการ',
            onPressed: () => _commentFocusNode.requestFocus(),
          ),
          if (_drop.audience == AudienceOption.everyone)
            _detailAction(
              icon: Icon(
                Icons.repeat_rounded,
                size: 27,
                color: _drop.redroppedByMe
                    ? WynColors.iconActive
                    : WynColors.ink,
              ),
              count: _drop.redropCount,
              semanticsLabel: 'รีโพสต์ ${_drop.redropCount} ครั้ง',
              onPressed: _openRedropSheet,
            ),
          _detailAction(
            icon: const Icon(
              Icons.ios_share_outlined,
              size: 24,
              color: WynColors.ink,
            ),
            semanticsLabel: 'แชร์โพสต์',
            onPressed: _openShareSheet,
          ),
          _detailAction(
            icon: WynStatePop(
              state: _drop.savedByMe,
              child: Icon(
                _drop.savedByMe
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                size: 26,
                color: WynColors.ink,
              ),
            ),
            semanticsLabel:
                _drop.savedByMe ? 'บันทึกแล้ว กดเพื่อเอาออก' : 'บันทึกโพสต์',
            onPressed: _toggleSave,
          ),
        ],
      ),
    );
  }

  List<DropComment> get _activityParticipants {
    final comments = _comments ?? const <DropComment>[];
    final seen = <String>{};
    final result = <DropComment>[];
    for (final comment in comments) {
      if (seen.add(comment.authorId)) result.add(comment);
      if (result.length == 3) break;
    }
    return result;
  }

  Widget _buildActivityRow() {
    final participants = _activityParticipants;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynosFounderMetrics.detailEdgeInset,
        2,
        WynosFounderMetrics.detailEdgeInset,
        10,
      ),
      child: Material(
        color: WynColors.surfaceTint,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _openActivitySheet,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: WynosFounderMetrics.activityRowHeight,
            child: Row(
              children: [
                const SizedBox(width: 14),
                if (participants.isNotEmpty)
                  SizedBox(
                    width: 58,
                    height: 36,
                    child: Stack(
                      children: [
                        for (final (index, participant)
                            in participants.indexed)
                          Positioned(
                            left: index * 15,
                            top: 1,
                            child: Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: const BoxDecoration(
                                color: WynColors.paper,
                                shape: BoxShape.circle,
                              ),
                              child: AvatarCircle(
                                imageUrl: participant.authorAvatarUrl,
                                fallbackText: participant.authorUsername,
                                radius: 15,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const SizedBox(
                    width: 42,
                    child: Icon(
                      Icons.insights_outlined,
                      size: 22,
                      color: WynColors.graphite,
                    ),
                  ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'ดูกิจกรรม',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: WynColors.ink,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 27,
                  color: WynColors.graphite,
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openActivitySheet() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: WynColors.paper,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'กิจกรรมโพสต์',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: WynColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.favorite_rounded,
                    color: WynColors.iconLikeActive),
                title: const Text('ถูกใจ'),
                trailing: Text('${_drop.likeCount}'),
              ),
              ListTile(
                leading: const Icon(Icons.mode_comment_outlined),
                title: const Text('ความคิดเห็น'),
                trailing: Text('${_drop.commentCount}'),
              ),
              ListTile(
                leading: const Icon(Icons.repeat_rounded),
                title: const Text('รีโพสต์'),
                trailing: Text('${_drop.redropCount}'),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('การเข้าชม'),
                trailing: Text('${_drop.viewCount}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

'''
replace_between(detail_path, methods_start, comment_marker, new_detail_methods + comment_marker)

composer_start = "  Widget _buildCommentInput() {\n"
textstyle_marker = "}\n\nTextStyle _textStyle({\n"
new_composer = r'''  Widget _buildCommentInput() {
    final canSend = _commentController.text.trim().isNotEmpty &&
        !_isSendingComment &&
        !_isRestricted;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 9, 9),
        decoration: const BoxDecoration(
          color: WynColors.paper,
          border: Border(top: BorderSide(color: WynColors.hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRestricted)
              RestrictionBanner(
                reason: _restrictReason,
                expiresAt: _restrictExpiresAt,
                actionId: _restrictActionId,
                appealStatus: _restrictAppealStatus,
                onAppeal: _openAppeal,
              ),
            if (_replyingTo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(45, 0, 0, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ตอบกลับ ${_replyingTo!.authorNameOrUsername}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WynColors.graphite,
                      ),
                    ),
                    const SizedBox(width: 5),
                    InkWell(
                      onTap: _cancelReply,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: WynColors.graphite,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                AvatarCircle(
                  imageUrl: _myProfile?.avatarUrl,
                  fallbackText: _myProfile?.username ??
                      Supabase.instance.client.auth.currentUser!.id,
                  radius: 18,
                  ring: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: WynosFounderMetrics.commentComposerHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: WynColors.surfaceTint,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      enabled: !_isSendingComment,
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (canSend) _sendComment();
                      },
                      style: const TextStyle(
                        fontSize: 15,
                        color: WynColors.ink,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        hintText: 'แสดงความคิดเห็น...',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: WynColors.faint,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Semantics(
                  label: _isRestricted
                      ? 'ส่งคอมเมนต์ ปิดใช้งานเนื่องจากบัญชีถูกจำกัดการโพสต์ชั่วคราว'
                      : 'ส่งคอมเมนต์',
                  button: true,
                  child: IconButton(
                    onPressed: canSend ? _sendComment : null,
                    icon: Icon(
                      Icons.send_rounded,
                      size: 25,
                      color: canSend ? WynColors.ink : WynColors.faint,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
'''
replace_between(detail_path, composer_start, textstyle_marker, new_composer + "}\n\nTextStyle _textStyle({\n")

# ---------------------------------------------------------------------------
# Keep the active task doc aligned with the direct Founder reference that now
# supersedes the older TSX-only visual description.
# ---------------------------------------------------------------------------
task_path = Path(".wyn/tasks/active/WYN-141-frontend-ux-ui-system.md")
if task_path.exists():
    task = task_path.read_text()
    note = "\n\n## Founder final visual reference — 2026-09-10\n\nThe final Profile and Post Detail screenshots supplied directly by the Founder supersede conflicting older TSX composition for those two surfaces. Implementation target is screenshot-level visual parity while preserving Beta4 behavior and backend contracts; the only required data addition is `profiles.cover_url` for the visible profile cover.\n"
    if "## Founder final visual reference — 2026-09-10" not in task:
        task_path.write_text(task + note)

print("WYN-141 founder final UI patch applied")
