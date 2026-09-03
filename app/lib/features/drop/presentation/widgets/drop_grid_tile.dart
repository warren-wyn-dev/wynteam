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

/// One square tile in DropFeedScreen's grid. Deliberately minimal (just
/// the image + a like-count scrim) -- full detail (caption, comments,
/// Share/Save) only shows in DropDetailScreen after tapping in. See
/// .wyn/docs/design/wyn-005-drop.md (Screen 1).
class DropGridTile extends StatelessWidget {
  const DropGridTile({super.key, required this.drop, required this.onTap});

  final Drop drop;
  final VoidCallback onTap;

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
