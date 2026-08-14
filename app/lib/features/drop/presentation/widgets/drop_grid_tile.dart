import 'package:flutter/material.dart';

import '../../data/drop.dart';

/// One square tile in DropFeedScreen's grid. Deliberately minimal (just
/// the image + a like-count scrim) -- full detail (caption, comments,
/// Share/Save) only shows in DropDetailScreen after tapping in. See
/// .wyn/docs/design/wyn-005-drop.md (Screen 1).
class DropGridTile extends StatelessWidget {
  const DropGridTile({super.key, required this.drop, required this.onTap});

  final Drop drop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'รูปของ ${drop.authorNameOrUsername}, ถูกใจ ${drop.likeCount} ครั้ง',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(drop.imageUrl, fit: BoxFit.cover),
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
                        colors: [Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite, size: 13, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          '${drop.likeCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
