import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wynos_founder_metrics.dart';
import '../../../home/presentation/widgets/verified_badge.dart';
import '../../data/profile.dart';
import 'avatar_circle.dart';

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
              // Keep the approved upward focal bias, but slightly relax the
              // crop so the cover reveals more of the lower cloud band seen
              // in the final reference screenshot.
              alignment: const Alignment(0, -0.10),
              errorBuilder: (_, __, ___) => const _CoverFallback(),
            )
          else
            const _CoverFallback(),
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

/// Founder-approved identity/action block for Profile.
///
/// The avatar deliberately sits inside the white identity body instead of
/// painting over the cover. That keeps the whole cover visible and also avoids
/// the renderer clipping bug that the earlier negative-overlap composition hit
/// on iOS/Flutter Web.
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

  Widget _nameRow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: BrowserSystemText(
                profile.nameOrUsername,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  height: 1.08,
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
                Icons.keyboard_arrow_down,
                size: 22,
                color: WynColors.ink,
              ),
            ],
          ],
        ),
        const SizedBox(height: 1),
        BrowserSystemText(
          '@${profile.username}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.0,
            color: WynColors.graphite,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _displayNameControl() {
    final row = _nameRow();
    if (!isOwnProfile || onDisplayNameTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: row,
      );
    }

    return Semantics(
      key: const Key('profile_account_switcher'),
      label: 'สลับบัญชี ${profile.nameOrUsername}',
      button: true,
      excludeSemantics: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: WynSpacing.touchTargetMin,
        ),
        child: InkWell(
          onTap: onDisplayNameTap,
          borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
          child: Align(alignment: Alignment.centerLeft, child: row),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WynColors.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WynSpacing.space4,
              8,
              WynSpacing.space4,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: WynosFounderMetrics.profileAvatarOuterDiameter,
                  height: 67,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -23,
                        left: 0,
                        child: _ProfileAvatar(
                          profile: profile,
                          showOnline: showOnline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _displayNameControl(),
                      if (profile.bio != null &&
                          profile.bio!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        BrowserSystemText(
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
              ],
            ),
          ),
          if (showStats) ...[
            const SizedBox(height: 7),
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 9),
            child: actions,
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
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
            BrowserSystemText(
              '$count',
              style: const TextStyle(
                fontSize: 20,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: WynColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            BrowserSystemText(
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
      child: BrowserSystemTooltip(
          message: tooltip,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 21, color: WynColors.ink),
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: WynColors.hairline),
              ),
              backgroundColor: WynColors.paper,
            ),
          )),
    );
  }
}
