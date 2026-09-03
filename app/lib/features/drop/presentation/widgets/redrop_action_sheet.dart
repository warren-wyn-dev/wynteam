import 'package:flutter/material.dart';

import '../../../../core/widgets/action_sheet_row.dart';

/// The two things you can do with the ReDrop button, as one sheet:
/// ReDrop (or undo it) and Quote ReDrop.
///
/// Beta4 §6. Two screens open this -- a feed card ([HomeDropCard]) and
/// the post itself ([DropDetailScreen]) -- and before this they each
/// built their own copy: a bare `Wrap` of two `ListTile`s whose labels
/// carried an emoji where an icon belonged ('🔄 รีโพสต์', '💬 Quote
/// รีโพสต์'). Two copies of the same menu is how the labels came to
/// disagree in the first place (only one of the two rows ever dropped
/// its emoji in the undo state), so there is one copy now.
///
/// Why the emoji had to go, specifically: an emoji is not an icon in
/// this design system. It paints in the platform's own colours (so it
/// ignores [WynColors] entirely), sits on the text baseline rather than
/// the icon baseline, sizes off the font rather than off the icon
/// scale, and -- the part that matters most here -- has no pressed,
/// active, selected, or disabled rendering to offer. These two rows are
/// the entry point to the single most consequential action a feed card
/// exposes, and they were the only two in the product that the icon
/// system's state rules could not reach.
///
/// [ActionSheetRow] gives all of that back for free: an 18px
/// [Icons.repeat]/[Icons.format_quote] in `WynColors.ink`, the same
/// 14px icon-to-label gap, the same trailing chevron, and the same
/// `InkWell` press ripple every other action row in the app has.
Future<void> showRedropSheet(
  BuildContext context, {
  required bool isRedropped,
  required VoidCallback onToggleRedrop,
  required VoidCallback onQuoteRedrop,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => ActionSheetBody(rows: [
      ActionSheetRow(
        key: const Key('redrop_sheet_toggle_row'),
        // The same glyph in both states, since it names the same
        // concept either way -- only the label says which direction
        // this tap goes. (The old emoji version showed '🔄' on the
        // ReDrop label but nothing at all on the "ยกเลิกรีโพสต์" one,
        // so the row visibly changed shape depending on your own
        // ReDrop state.)
        icon: Icons.repeat,
        label: isRedropped ? 'ยกเลิกรีโพสต์' : 'รีโพสต์',
        onTap: () {
          Navigator.of(sheetContext).pop();
          onToggleRedrop();
        },
      ),
      ActionSheetRow(
        key: const Key('redrop_sheet_quote_row'),
        // Quote marks, not a speech bubble: the destination
        // (QuoteRedropScreen) is "add your own words above this post",
        // and Icons.chat_bubble_outline is already spoken for by
        // "comment" in the action bar directly above this sheet.
        icon: Icons.format_quote,
        label: 'อ้างอิง',
        onTap: () {
          Navigator.of(sheetContext).pop();
          onQuoteRedrop();
        },
      ),
    ]),
  );
}
