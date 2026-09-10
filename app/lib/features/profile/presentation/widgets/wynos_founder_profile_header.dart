import 'package:flutter/material.dart';

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
