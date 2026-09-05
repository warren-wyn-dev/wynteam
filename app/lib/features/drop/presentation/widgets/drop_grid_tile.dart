import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/widgets/action_sheet_row.dart';
import '../../data/drop.dart';
import '../../../report/data/report_repository.dart';
import '../../../report/data/report_target_type.dart';
import '../../../report/presentation/report_sheet.dart';
import 'poll_placeholder_tile.dart';
import 'text_drop_placeholder_tile.dart';
import '../../../../core/widgets/network_thumbnail.dart';
import '../../../../core/widgets/wyn_heart_icon.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';

/// One square tile in a Drop grid. Deliberately minimal (just the image
/// + a like-count scrim) -- full detail (caption, comments, Share/Save)
/// only shows in DropDetailScreen after tapping in. See
/// .wyn/docs/design/wyn-005-drop.md (Screen 1).
///
/// [showAuthor] is off by default, matching this tile's original
/// single caller (ProfileDropGridTab, since replaced by a full
/// HomeDropCard list -- SearchDropResultsTab is the only caller left).
/// A profile grid already tells you whose posts you're looking at; a
/// *search* result grid mixes every author in the app into one 3-column
/// wall of near-identical squares with no name anywhere on them, which
/// is fine for a photo but actively confusing for a text-only Drop
/// (TextDropPlaceholderTile below) -- there is nothing on the tile to
/// say who wrote it. SearchDropResultsTab passes `showAuthor: true`;
/// nothing else needs to.
class DropGridTile extends StatelessWidget {
  const DropGridTile({
    super.key,
    required this.drop,
    required this.onTap,
    this.showAuthor = false,
  });

  final Drop drop;
  final VoidCallback onTap;
  final bool showAuthor;

  bool get _isOwnDrop =>
      drop.authorId == Supabase.instance.client.auth.currentUser!.id;

  // Grid tiles are deliberately clutter-free (no visible More icon) --
  // long-press opens the same report menu instead, with a
  // CustomSemanticsAction so screen-reader users can reach it without
  // the gesture. See .wyn/docs/design/wyn-026-report-system.md, Screen 4.
  Future<void> _openMoreMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        ActionSheetRow(
          icon: Icons.flag_outlined,
          label: 'รายงานโพสต์',
          onTap: () {
            Navigator.of(sheetContext).pop();
            showReportSheet(
              context,
              reportRepository: ReportRepository(Supabase.instance.client),
              targetType: ReportTargetType.drop,
              targetId: drop.id,
              targetLabel: 'รายงานโพสต์ของ ${drop.authorNameOrUsername}',
              associatedUserId: drop.authorId,
            );
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'รูปของ ${drop.authorNameOrUsername}, ถูกใจ ${drop.likeCount} ครั้ง',
      button: true,
      customSemanticsActions: _isOwnDrop
          ? null
          : {
              const CustomSemanticsAction(label: 'รายงานโพสต์'): () => _openMoreMenu(context),
            },
      child: GestureDetector(
        onTap: onTap,
        onLongPress: _isOwnDrop ? null : () => _openMoreMenu(context),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (drop.imageUrl != null)
                NetworkThumbnail(imageUrl: drop.imageUrl!)
              else if (drop.isPoll)
                const PollPlaceholderTile()
              else
                TextDropPlaceholderTile(caption: drop.caption ?? ''),
              // WYN-071: stacked-photos icon, no count badge -- just
              // enough to say "there's more" without cluttering the
              // dense grid with a number.
              if (drop.hasMultipleImages)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.filter_none,
                      size: 16,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                    ),
                  ),
                ),
              if (showAuthor)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: ExcludeSemantics(
                    // The tile's own Semantics label below already
                    // says who posted it -- this is a sighted-only
                    // label, same posture as the like-count scrim.
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [WynColors.imageScrim, Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          AvatarCircle(
                            imageUrl: drop.authorAvatarUrl,
                            fallbackText: drop.authorUsername,
                            radius: 9,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '@${drop.authorUsername}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        const WynHeartIcon(
                            filled: true, size: 13, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          '${drop.likeCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
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
