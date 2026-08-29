import 'package:flutter/material.dart';

import '../../../profile/data/profile.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../design/wynos_home_tokens.dart';
import 'wynos_avatar_ring.dart';
import 'wynos_verified_badge.dart';

/// WYNOS Home reference spec 4.5 -- shown when the current tab
/// ("สำหรับคุณ"/"ติดตาม") has zero posts because the account follows no
/// one yet. HomeFeedScreen owns deciding *when* this real condition
/// applies (see its own doc comments); this widget just renders it.
///
/// [suggestions] is deliberately allowed to be empty (renders just the
/// headline block) -- fetchSuggestedToFollow failing or the candidate
/// pool being empty is not itself an error state worth blocking on.
class WynosEmptyFeedState extends StatelessWidget {
  const WynosEmptyFeedState({
    super.key,
    required this.suggestions,
    required this.onFollow,
    required this.onOpenProfile,
  });

  final List<Profile> suggestions;
  final ValueChanged<Profile> onFollow;
  final ValueChanged<Profile> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // pt-10 pb-8 (spec's own vertical rhythm for this section, distinct
      // from a post's pt-4 pb-4).
      padding: const EdgeInsets.fromLTRB(
        WynosHomeSpacing.pagePadding, 40, WynosHomeSpacing.pagePadding, 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 28), // mb-7
            child: Column(
              children: [
                Text(
                  'ยังไม่มีอะไรให้ดูตรงนี้',
                  textAlign: TextAlign.center,
                  style: WynosHomeText.emptyHeadline,
                ),
                const SizedBox(height: 6), // mt-1.5
                Text(
                  'ลองติดตามสัก 2-3 คนก่อน แล้วฟีดของคุณจะเริ่มมีเรื่องราว',
                  textAlign: TextAlign.center,
                  style: WynosHomeText.emptyStateSubtext,
                ),
              ],
            ),
          ),
          for (var i = 0; i < suggestions.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == suggestions.length - 1
                    ? 0
                    : WynosHomeSpacing.suggestedRowGap,
              ),
              child: _SuggestedRow(
                profile: suggestions[i],
                onFollow: () => onFollow(suggestions[i]),
                onOpenProfile: () => onOpenProfile(suggestions[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestedRow extends StatelessWidget {
  const _SuggestedRow({
    required this.profile,
    required this.onFollow,
    required this.onOpenProfile,
  });

  final Profile profile;
  final VoidCallback onFollow;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onOpenProfile,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                WynosAvatarRing(
                  size: 38,
                  child: AvatarCircle(
                    imageUrl: profile.avatarUrl,
                    fallbackText: profile.username,
                    radius: 19,
                  ),
                ),
                const SizedBox(width: 12), // gap-3
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              profile.nameOrUsername,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: WynosHomeText.suggestedFollowName,
                            ),
                          ),
                          // WYNOS Home reference spec 4.6/4.5.
                          if (profile.isVerified) ...[
                            const SizedBox(width: 4),
                            const WynosVerifiedBadge(size: 13),
                          ],
                        ],
                      ),
                      Text(
                        '@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WynosHomeText.suggestedFollowHandle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: onFollow,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: WynosHomeColors.sapphire, width: 1),
            foregroundColor: WynosHomeColors.sapphire,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            shape: const StadiumBorder(),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('ติดตาม', style: WynosHomeText.followButton),
        ),
      ],
    );
  }
}
