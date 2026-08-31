import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/home_liker.dart';

/// "ถูกใจโดย {name} และอีก N คน" with up to 3 overlapping mini-avatars --
/// WYNOSHomeSpec.md 4.8. Deliberately keyed off [likedBy] being non-empty
/// (not [totalLikeCount] directly) -- a fetch path that doesn't embed
/// `home_feed.liked_by` yet leaves [likedBy] empty even when likes exist,
/// and there's nothing meaningful to render without any actual likers.
class LikedByRow extends StatelessWidget {
  const LikedByRow({
    super.key,
    required this.likedBy,
    required this.totalLikeCount,
  });

  final List<HomeLiker> likedBy;
  final int totalLikeCount;

  static const double _avatarDiameter = 18;
  static const double _avatarOverlapOffset = 12;
  static const double _borderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    if (likedBy.isEmpty) return const SizedBox.shrink();

    final shown = likedBy.take(3).toList();
    final extra = totalLikeCount - shown.length;
    final stackWidth =
        _avatarDiameter + (shown.length - 1) * _avatarOverlapOffset;

    return Semantics(
      label: extra > 0
          ? 'ถูกใจโดย ${shown[0].nameOrUsername} และอีก $extra คน'
          : 'ถูกใจโดย ${shown[0].nameOrUsername}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: stackWidth,
            height: _avatarDiameter,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * _avatarOverlapOffset,
                    child: Container(
                      width: _avatarDiameter,
                      height: _avatarDiameter,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: WynColors.paper, width: _borderWidth),
                        ),
                      ),
                      child: AvatarCircle(
                        imageUrl: shown[i].avatarUrl,
                        fallbackText: shown[i].nameOrUsername,
                        radius: (_avatarDiameter - _borderWidth * 2) / 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: WynSpacing.space2),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12, color: WynColors.graphite),
                children: [
                  const TextSpan(text: 'ถูกใจโดย '),
                  TextSpan(
                    text: shown[0].nameOrUsername,
                    style: const TextStyle(
                      color: WynColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (extra > 0) TextSpan(text: ' และอีก $extra คน'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
