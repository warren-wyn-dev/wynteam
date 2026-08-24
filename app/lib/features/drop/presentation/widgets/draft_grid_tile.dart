import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../data/drop_draft.dart';
import 'poll_placeholder_tile.dart';
import 'text_drop_placeholder_tile.dart';

/// One square tile in the Profile "ร่าง" (Draft) tab (WYN-036) -- same
/// 3-column grid shape as DropGridTile/SavedGridTile, but with no
/// like-count scrim (a Draft has no engagement to show) and a
/// long-press delete instead of a report menu (nobody else can ever
/// see a Draft to report it).
class DraftGridTile extends StatelessWidget {
  const DraftGridTile({
    super.key,
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  final DropDraft draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await confirmDeletePost(context, itemLabel: 'ร่าง');
    if (confirmed) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: draft.isPoll ? 'ร่างโพล' : 'ร่าง Drop',
      button: true,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'ลบร่าง'): () =>
            _confirmDelete(context),
      },
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () => _confirmDelete(context),
        child: AspectRatio(
          aspectRatio: 1,
          child: draft.imageUrl != null
              ? Image.network(draft.imageUrl!, fit: BoxFit.cover)
              : draft.isPoll
                  ? const PollPlaceholderTile()
                  : TextDropPlaceholderTile(caption: draft.caption ?? ''),
        ),
      ),
    );
  }
}
