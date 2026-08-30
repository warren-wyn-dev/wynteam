import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../data/home_feed_item.dart';
import '../../../drop/presentation/widgets/poll_placeholder_tile.dart';

/// One square tile in Home's "กำลังนิยม" (Trending) row -- WYN-017.
/// Visually modeled on DropGridTile (image + like-count scrim), but
/// accepts a [HomeFeedItem] so one tile handles both Drop and Pop
/// content, since neither DropGridTile nor PopGridTile is content-type
/// agnostic. See .wyn/docs/design/wyn-017-home-trending-recommended-clubs.md.
class TrendingTile extends StatelessWidget {
  const TrendingTile({
    super.key,
    required this.item,
    required this.onTap,
    this.showRainbowRing = true,
  });

  final HomeFeedItem item;
  final VoidCallback onTap;

  // WYN-042: off switch for WYN Top 100's leaderboard list, which
  // deliberately does NOT get the Rainbow ring -- Top 100 is a
  // distinct concept from "Trending" (a 7-day chart, not the 48h
  // Trending Now row/section this ring's meaning is scoped to per
  // DS-009), and repeating the ring down a 100-row list would stretch
  // DS-009's "2 points only" rule past what it approved. Both existing
  // callers (Home's Trending row, Discovery's Trending Now) are
  // unaffected -- this defaults to true, their exact prior behavior.
  // See .wyn/docs/design/wyn-042-top-100.md.
  final bool showRainbowRing;

  @override
  Widget build(BuildContext context) {
    final isPop = item.contentType == HomeContentType.pop;
    final imageUrl = isPop ? item.thumbnailUrl : item.imageUrl;

    final tile = SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(imageUrl, fit: BoxFit.cover)
          else if (item.isPoll)
            const PollPlaceholderTile()
          else
            Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest),
          if (isPop)
            const Center(
              child: ExcludeSemantics(
                child: Icon(Icons.play_circle, color: Colors.white, size: 28),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, WynColors.imageScrim],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite, size: 13, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      '${item.likeCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: isPop
          ? 'วิดีโอของ ${item.authorNameOrUsername}, ถูกใจ ${item.likeCount} ครั้ง'
          : 'รูปของ ${item.authorNameOrUsername}, ถูกใจ ${item.likeCount} ครั้ง',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        // DS-009: every tile in this row is, by definition, trending
        // content -- so the Rainbow ring applies unconditionally here
        // rather than needing its own "is this trending?" flag. See
        // .wyn/docs/design/ds-009-rainbow-accent.md.
        child: showRainbowRing
            ? Container(
                width: 94,
                height: 94,
                padding: const EdgeInsets.all(2),
                decoration:
                    const BoxDecoration(gradient: WynColors.rainbowAccent),
                child: tile,
              )
            : tile,
      ),
    );
  }
}
