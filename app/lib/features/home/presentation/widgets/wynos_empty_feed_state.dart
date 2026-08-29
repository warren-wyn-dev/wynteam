import 'package:flutter/material.dart';

import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wynos_home_tokens.dart';
import '../../../../core/widgets/wynos_ringed_avatar.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../follow/data/follow_request_repository.dart';
import '../../../follow/presentation/widgets/follow_action_button.dart';
import '../../../profile/data/profile.dart';
import '../../../search/data/discovery_repository.dart';

/// SPEC.md Section 4.5 -- the empty state for a brand-new account (or
/// any account currently following 0 people), shown on the "สำหรับคุณ"/
/// "ติดตาม" tabs. See HomeFeedScreen._buildBodySlivers for the real
/// trigger condition (`followRepository.countFollowing() == 0`) -- WYN-
/// 072 Requirement R6 explicitly forbids the reference `.jsx`'s own
/// "ดูตัวอย่าง: ผู้ใช้ใหม่" mock toggle, so this widget only ever
/// mounts when that real condition is already true.
///
/// The suggested-accounts list is real
/// ([DiscoveryRepository.fetchSuggestedUsers], the same RPC-backed
/// source Search's "แนะนำให้ติดตาม" section and Profile's "แนะนำสำหรับ
/// คุณ" row already use) -- not the reference's own hardcoded 4-person
/// mock list.
class WynosEmptyFeedState extends StatefulWidget {
  const WynosEmptyFeedState({
    super.key,
    required this.discoveryRepository,
    required this.followRepository,
    required this.followRequestRepository,
  });

  final DiscoveryRepository discoveryRepository;
  final FollowRepository followRepository;
  final FollowRequestRepository followRequestRepository;

  @override
  State<WynosEmptyFeedState> createState() => _WynosEmptyFeedStateState();
}

class _WynosEmptyFeedStateState extends State<WynosEmptyFeedState> {
  // Null while loading, or on a failed fetch -- rendered as "no
  // suggestions yet" (just the headline/subtext, no rows), same
  // fail-open posture as ProfileRecommendationSection's identical
  // fetch (WYN-071).
  List<Profile>? _suggested;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profiles = await widget.discoveryRepository.fetchSuggestedUsers();
      if (!mounted) return;
      setState(() => _suggested = profiles);
    } catch (_) {
      // Leave null -- see field doc comment above.
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggested = _suggested ?? const <Profile>[];

    return Theme(
      // Recolors FollowActionButton's OutlinedButton (which reads
      // `Theme.of(context).colorScheme.primary`) to this screen's
      // sapphire accent, without touching that shared widget or the
      // app's global theme -- same technique HomeDropCard/HomePopCard
      // use for HashtagText's link color (`_wrapSapphireLinks`).
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context)
            .colorScheme
            .copyWith(primary: WynosHomeTokens.sapphire),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          WynSpacing.space6,
          40,
          WynSpacing.space6,
          WynSpacing.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Text(
                  'ยังไม่มีอะไรให้ดูตรงนี้',
                  style: WynosHomeTokens.emptyStateHeadline,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'ลองติดตามสัก 2-3 คนก่อน แล้วฟีดของคุณจะเริ่มมีเรื่องราว',
                  style: WynosHomeTokens.bodySmall(),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            if (suggested.isNotEmpty) ...[
              const SizedBox(height: 28),
              for (final profile in suggested) ...[
                _SuggestedRow(
                  profile: profile,
                  followRepository: widget.followRepository,
                  followRequestRepository: widget.followRequestRepository,
                ),
                const SizedBox(height: WynSpacing.space4),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestedRow extends StatelessWidget {
  const _SuggestedRow({
    required this.profile,
    required this.followRepository,
    required this.followRequestRepository,
  });

  final Profile profile;
  final FollowRepository followRepository;
  final FollowRequestRepository followRequestRepository;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        WynosRingedAvatar(
          imageUrl: profile.avatarUrl,
          fallbackText: profile.username,
          radius: 19,
        ),
        const SizedBox(width: WynSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SPEC.md Section 4.5: name and handle are two separate
              // lines here (unlike a post author's single-line
              // attribution elsewhere, which is what `nameOrUsername`'s
              // "real display name, else '@username'" fallback is for)
              // -- using `nameOrUsername` on this line duplicated
              // "@username" on both lines whenever displayName was unset
              // (every account in this app today, since there is no
              // Settings UI to set one yet). Falls back to the bare
              // username instead, matching the reference's own
              // `{ name: "WARREN", handle: "@warren" }` shape.
              Text(profile.displayName ?? profile.username,
                  style: WynosHomeTokens.suggestedFollowName),
              Text('@${profile.username}', style: WynosHomeTokens.caption()),
            ],
          ),
        ),
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
