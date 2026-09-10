import 'package:flutter/material.dart';

import '../../data/profile.dart';
import 'avatar_circle.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Beta5 Profile V2 full header.
///
/// Founder decision: the old full-width "แก้ไขโปรไฟล์" + link/button band
/// is deliberately not rendered here. Editing lives in the compact top
/// bar, so the first post moves upward and the profile reads as one piece.
class ProfileV2Header extends StatelessWidget {
  const ProfileV2Header({
    super.key,
    required this.profile,
    required this.nameRow,
    required this.followingCount,
    required this.followerCount,
    required this.onFollowingTap,
    required this.onFollowersTap,
    this.onEditCover,
    this.blockedBanner,
    this.actionRow,
    this.pendingRequestEntry,
  });

  final Profile profile;
  final Widget nameRow;
  final int followingCount;
  final int followerCount;
  final VoidCallback onFollowingTap;
  final VoidCallback onFollowersTap;
  final VoidCallback? onEditCover;
  final Widget? blockedBanner;
  final Widget? actionRow;
  final Widget? pendingRequestEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('profile_v2_full_header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: double.infinity,
              height: 124,
              child: _CoverImage(url: profile.coverUrl),
            ),
            Positioned(
              left: WynSpacing.space5,
              bottom: -39,
              child: AvatarCircle(
                imageUrl: profile.avatarUrl,
                fallbackText: profile.username,
                radius: 42,
                ring: true,
              ),
            ),
            if (onEditCover != null)
              Positioned(
                right: WynSpacing.space3,
                bottom: WynSpacing.space3,
                child: Material(
                  color: WynColors.paper.withValues(alpha: 0.88),
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const Key('profile_cover_edit_button'),
                    tooltip: 'เปลี่ยนรูปปก',
                    icon: const Icon(Icons.photo_camera_outlined, size: 19),
                    onPressed: onEditCover,
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WynSpacing.space5,
            WynSpacing.space3,
            WynSpacing.space5,
            WynSpacing.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 94, height: 40),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        nameRow,
                        const SizedBox(height: WynSpacing.space1),
                        Text(
                          '@${profile.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: WynColors.mutedNeutral),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: WynSpacing.space2),
                Text(
                  profile.bio!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(height: 1.35, color: WynColors.graphite),
                ),
              ],
              if (blockedBanner != null) ...[
                const SizedBox(height: WynSpacing.space3),
                blockedBanner!,
              ] else ...[
                const SizedBox(height: WynSpacing.space3),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileStat(
                        count: followingCount,
                        label: 'กำลังติดตาม',
                        onTap: onFollowingTap,
                      ),
                    ),
                    const SizedBox(width: WynSpacing.space2),
                    Expanded(
                      child: _ProfileStat(
                        count: followerCount,
                        label: 'ผู้ติดตาม',
                        onTap: onFollowersTap,
                      ),
                    ),
                  ],
                ),
                if (actionRow != null) ...[
                  const SizedBox(height: WynSpacing.space3),
                  actionRow!,
                ],
                if (pendingRequestEntry != null) ...[
                  const SizedBox(height: WynSpacing.space1),
                  pendingRequestEntry!,
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WynColors.surfaceTint, WynColors.paper],
        ),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
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
      borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: WynSpacing.space1,
          horizontal: WynSpacing.space1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: WynColors.ink),
            ),
            const SizedBox(width: WynSpacing.space1),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: WynColors.mutedNeutral),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
