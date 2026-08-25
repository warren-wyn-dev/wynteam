import 'package:flutter/material.dart';

import '../../../follow/data/follow_repository.dart';
import '../../../follow/data/follow_request_repository.dart';
import '../../../follow/presentation/widgets/follow_action_button.dart';
import '../../../search/data/discovery_repository.dart';
import '../../data/profile.dart';
import '../../data/profile_repository.dart';
import '../../../../core/design/wyn_spacing.dart';
import 'avatar_circle.dart';

/// "แนะนำสำหรับคุณ" -- WYN-071 Design, Screen 5. Shown only while
/// viewing someone *else's* profile (see `ViewProfileScreen`'s call
/// site) -- the viewer's own profile skips this since Home's Discovery
/// segment (WYN-063) already covers the same "accounts to follow"
/// need there, and duplicating it on the owner's own profile would be
/// dead space.
///
/// Content is [DiscoveryRepository.fetchSuggestedUsers] reused as-is,
/// not a new "similar to the profile being viewed" ranking -- true
/// per-profile personalization is deferred (see the Design doc's own
/// note on this), so what a viewer sees here is currently the same
/// "accounts you might want to follow" list Discovery's own Suggested
/// Users section shows.
class ProfileRecommendationSection extends StatefulWidget {
  const ProfileRecommendationSection({
    super.key,
    required this.discoveryRepository,
    required this.followRepository,
    required this.followRequestRepository,
    required this.profileRepository,
  });

  final DiscoveryRepository discoveryRepository;
  final FollowRepository followRepository;
  final FollowRequestRepository followRequestRepository;
  final ProfileRepository profileRepository;

  @override
  State<ProfileRecommendationSection> createState() =>
      _ProfileRecommendationSectionState();
}

class _ProfileRecommendationSectionState
    extends State<ProfileRecommendationSection> {
  // Null while the first fetch is in flight -- rendered as nothing
  // (not a loading skeleton) until it resolves, same "don't show an
  // empty-looking section" posture as ViewProfileScreen's own
  // _buildMyClubsSection, so a slow/failed fetch never flashes a
  // half-built row above the tab bar.
  List<Profile>? _profiles;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profiles = await widget.discoveryRepository.fetchSuggestedUsers();
      if (!mounted) return;
      setState(() => _profiles = profiles);
    } catch (_) {
      // Leave null -- section just doesn't render, no error UI for a
      // non-essential recommendation row.
    }
  }

  Future<void> _dismiss(Profile profile) async {
    final current = _profiles;
    if (current == null) return;
    // Optimistic -- remove immediately, restore on failure.
    setState(() => _profiles = List.of(current)..remove(profile));
    try {
      await widget.discoveryRepository.dismissSuggestedUser(profile.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _profiles = current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profiles;
    if (profiles == null || profiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              WynSpacing.space4, WynSpacing.space2, WynSpacing.space4, 0),
          child: Text(
            'แนะนำสำหรับคุณ',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return _RecommendationCard(
                key: ValueKey(profile.id),
                profile: profile,
                followRepository: widget.followRepository,
                followRequestRepository: widget.followRequestRepository,
                onDismiss: () => _dismiss(profile),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    super.key,
    required this.profile,
    required this.followRepository,
    required this.followRequestRepository,
    required this.onDismiss,
  });

  final Profile profile;
  final FollowRepository followRepository;
  final FollowRequestRepository followRequestRepository;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      margin: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
      padding: const EdgeInsets.all(WynSpacing.space3),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Semantics(
              label: 'ซ่อนคำแนะนำนี้',
              button: true,
              excludeSemantics: true,
              child: InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 16),
                ),
              ),
            ),
          ),
          AvatarCircle(
            imageUrl: profile.avatarUrl,
            fallbackText: profile.username,
            radius: 28,
          ),
          const SizedBox(height: WynSpacing.space2),
          Text(
            profile.nameOrUsername,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '@${profile.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: WynSpacing.space2),
          FollowActionButton(
            profile: profile,
            followRepository: followRepository,
            followRequestRepository: followRequestRepository,
            compact: true,
          ),
        ],
      ),
    );
  }
}
