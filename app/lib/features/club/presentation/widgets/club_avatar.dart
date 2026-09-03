import 'package:flutter/material.dart';

import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/club.dart';

/// A Club's identity image as a circle -- the one way a Club is shown
/// wherever it appears small: "Club ของฉัน", the discovery cards, the
/// recommendation rows, the ranked rows, the mini cards, the Club page
/// header.
///
/// Beta4 §7/§22. Five widgets were each hand-rolling the same
/// `CircleAvatar(backgroundColor: primary, backgroundImage:
/// NetworkImage(club.iconUrl!), child: Text(club.name[0]...))` -- five
/// copies of one idea, and five copies of the same three defects:
///
/// * **No decode bound.** A bare `NetworkImage` decodes a Club's
///   full-size upload into memory whatever size it is painted at. A
///   1600x1600 upload is ~10MB of bitmap for a 36px disc, and Explore
///   shows a screenful of them at once. [AvatarCircle] bounds the
///   decode to the size actually painted, scaled by device pixel ratio,
///   so nothing gets blurrier and the memory stops being absurd.
/// * **No failure fallback.** `backgroundImage` renders nothing at all
///   if the load fails, so a Club whose signed URL had expired (Club
///   media is a private bucket -- see [ClubRepository], one-hour signed
///   URLs) painted an empty coloured disc rather than its initial.
///   [AvatarCircle] flips to the letter on the image's own error
///   callback.
/// * **`club.name[0]` on an empty string.** Each copy guarded it
///   separately, correctly but separately.
///
/// Reads [Club.identityImageUrl], never `iconUrl`/`coverUrl` directly,
/// which is what makes §8.1's "one image per Club" hold at every one of
/// these call sites at once.
class ClubAvatar extends StatelessWidget {
  const ClubAvatar({super.key, required this.club, this.radius = 20, this.ring = false});

  final Club club;
  final double radius;

  /// The 1px sapphire-at-20% ring. Off by default -- most Club
  /// surfaces show the avatar inline in a card, where a ring reads as
  /// clutter; the Club page header turns it on to match the profile
  /// header's own treatment.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return AvatarCircle(
      imageUrl: club.identityImageUrl,
      fallbackText: club.name,
      radius: radius,
      ring: ring,
    );
  }
}
