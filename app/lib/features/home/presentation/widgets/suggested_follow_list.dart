import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wyn_typography.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../follow/data/follow_request_repository.dart';
import '../../../follow/presentation/widgets/follow_action_button.dart';
import '../../../profile/data/profile.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import 'verified_badge.dart';

/// WYNOSHomeSpec.md 4.5 -- the empty state's headline + suggested-
/// accounts list, shown when "สำหรับคุณ"/"ติดตาม" has nothing to show
/// because the account follows no one yet. [discoveryRepository]'s own
/// `fetchSuggestedUsers` is reused as-is (same source
/// ProfileRecommendationSection already uses on a profile page) rather
/// than a new "for this empty state specifically" ranking.
class SuggestedFollowList extends StatefulWidget {
  const SuggestedFollowList({
    super.key,
    required this.fetchSuggestedUsers,
    required this.followRepository,
    required this.followRequestRepository,
    required this.onOpenProfile,
  });

  final Future<List<Profile>> Function() fetchSuggestedUsers;
  final FollowRepository followRepository;
  final FollowRequestRepository followRequestRepository;
  final ValueChanged<String> onOpenProfile;

  @override
  State<SuggestedFollowList> createState() => _SuggestedFollowListState();
}

class _SuggestedFollowListState extends State<SuggestedFollowList> {
  // Null while the fetch is in flight -- the list section just doesn't
  // render (not a loading skeleton) until it resolves, same posture as
  // ProfileRecommendationSection's own _profiles.
  List<Profile>? _profiles;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profiles = await widget.fetchSuggestedUsers();
      if (!mounted) return;
      setState(() => _profiles = profiles);
    } catch (_) {
      // Leave null -- the headline/subtext above this still renders
      // regardless (see the caller), this row list is the only part
      // that silently doesn't show.
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'ยังไม่มีอะไรให้ดูตรงนี้',
          style: WynTypography.fraunces(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: WynSpacing.space1 + 2),
        const Text(
          'ลองติดตามคนที่คุณสนใจ เพื่อเริ่มเห็นโพสต์ในหน้านี้',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: WynColors.graphite),
        ),
        if (profiles != null && profiles.isNotEmpty) ...[
          const SizedBox(height: WynSpacing.space6),
          for (var i = 0; i < profiles.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : WynSpacing.space4),
              child: _SuggestedAccountRow(
                profile: profiles[i],
                followRepository: widget.followRepository,
                followRequestRepository: widget.followRequestRepository,
                onTap: () => widget.onOpenProfile(profiles[i].id),
              ),
            ),
        ],
      ],
    );
  }
}

class _SuggestedAccountRow extends StatelessWidget {
  const _SuggestedAccountRow({
    required this.profile,
    required this.followRepository,
    required this.followRequestRepository,
    required this.onTap,
  });

  final Profile profile;
  final FollowRepository followRepository;
  final FollowRequestRepository followRequestRepository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
            child: Row(
              children: [
                AvatarCircle(
                  imageUrl: profile.avatarUrl,
                  fallbackText: profile.username,
                  radius: 19,
                ),
                const SizedBox(width: WynSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.nameOrUsername,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: WynColors.ink,
                              ),
                            ),
                          ),
                          if (profile.isVerified) ...[
                            const SizedBox(width: WynSpacing.space1),
                            const VerifiedBadge(),
                          ],
                        ],
                      ),
                      Text(
                        '@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: WynColors.graphite),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: WynSpacing.space2),
        FollowActionButton(
          profile: profile,
          followRepository: followRepository,
          followRequestRepository: followRequestRepository,
          compact: true,
        ),
      ],
    );
  }
}
